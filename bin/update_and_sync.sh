#!/bin/bash

### ============ 全局颜色输出函数（合并所有需要） ============ ###
print_green() { echo -e "\033[0;32m$1\033[0m"; }
print_red() { echo -e "\033[0;31m$1\033[0m"; }
print_blue() { echo -e "\033[0;34m$1\033[0m"; }
print_yellow() { echo -e "\033[0;33m$1\033[0m"; }

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

### ============ Begin 1st Script (Git 更新和推送) ============ ###

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 获取仓库根目录
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# 处理自定义提交信息
COMMIT_MSG="更新自定义配置 $(date '+%Y-%m-%d %H:%M')"
if [ $# -gt 0 ]; then
    COMMIT_MSG="$*"
fi

# 进入仓库目录
cd "$REPO_DIR" || {
    print_red "无法进入仓库目录: $REPO_DIR"
    exit 1
}

# 检查是否为git仓库
if [ ! -d ".git" ]; then
    print_red "当前目录不是git仓库"
    exit 1
fi

# 检查custom目录是否存在
if [ ! -d "custom" ]; then
    print_red "custom目录不存在"
    exit 1
fi

print_blue "开始处理自定义配置更新..."

# 1. 将custom目录的文件复制到上层目录
print_blue "将custom目录中的文件复制到根目录..."
cp -f custom/* . 2>/dev/null || true

# 2. 检查目录是否有变更
print_blue "检查custom目录变更..."
git status --porcelain custom/ bin/ | grep -q . || {
    print_blue "检查整个仓库是否有变更..."
    git status --porcelain | grep -q . || {
        print_yellow "没有检测到任何变更，无需提交"
        # 提前结束第一个脚本，直接进行下个脚本
        echo "==== 跳过后续提交与推送 ===="
        goto_second=1
    }
}

if [ "${goto_second}" != "1" ]; then
    # 3. 添加变更到暂存区
    print_blue "添加变更到Git（含所有新文件）..."
    git add -A || {
        print_red "无法添加变更"
        exit 1
    }

    # 4. 提交变更
    print_blue "提交变更: $COMMIT_MSG"
    git commit -m "$COMMIT_MSG" || {
        print_red "提交变更失败"
        exit 1
    }

    # 5. 推送到远程仓库
    print_blue "推送到远程仓库..."
    git push || {
        print_red "推送到远程仓库失败"
        exit 1
    }

    print_green "自定义配置已成功更新并推送到远程仓库！"
fi

### ============ End 1st Script ============ ###

### ============ Begin 2nd Script (拉远程+本地配置恢复+部署Rime) ============ ###

# 设置临时备份目录
BACKUP_DIR="/tmp/rime_update_backup"
print_blue "===== 更新开始: $(date) ====="

# 进入仓库目录（已在1st Script加过）
cd "$REPO_DIR" || {
    print_red "无法进入仓库目录: $REPO_DIR"
    exit 1
}

print_blue "开始更新Rime配置..."

# 1. 识别并备份所有未被Git跟踪的文件
print_blue "备份未被Git跟踪的文件..."
mkdir -p "$BACKUP_DIR"
UNTRACKED_FILES=$(git ls-files --others --exclude-standard)

if [ -n "$UNTRACKED_FILES" ]; then
    print_blue "备份以下未跟踪的文件:"
    for file in $UNTRACKED_FILES; do
        mkdir -p "$BACKUP_DIR/$(dirname "$file")"
        cp -f "$file" "$BACKUP_DIR/$file" 2>/dev/null
        echo " - $file"
    done
    print_green "已备份 $(echo "$UNTRACKED_FILES" | wc -w | xargs) 个本地文件"
else
    print_blue "没有找到未跟踪的文件"
fi

# 2. 获取远程更新并重置本地仓库
print_blue "从远程仓库获取更新..."
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git fetch --all || {
    print_red "获取远程更新失败"
    exit 1
}
git reset --hard "origin/$CURRENT_BRANCH" || {
    print_red "重置到远程状态失败"
    exit 1
}

# 3. 恢复备份的本地文件
if [ -n "$UNTRACKED_FILES" ]; then
    print_blue "恢复本地特有文件..."
    for file in $UNTRACKED_FILES; do
        if [ -f "$BACKUP_DIR/$file" ]; then
            mkdir -p "$(dirname "$file")"
            cp -f "$BACKUP_DIR/$file" "$file"
        fi
    done
    print_green "本地特有文件已恢复"
fi

# 4. 将custom目录下的所有文件复制到根目录
if [ -d "custom" ]; then
    print_blue "将custom目录中的文件复制到根目录..."
    cp -f custom/* . 2>/dev/null || {
        print_blue "复制文件时出现一些警告 (这通常是正常的)"
    }
    cp -fv custom/lua/* lua/
    print_green "自定义配置文件已更新"
else
    print_red "custom目录不存在"
fi

rm -rf "$BACKUP_DIR"

print_green "更新完成！"

print_blue "===== 更新结束: $(date) ====="

### ============ End 2nd Script ============ ###

### ============ Begin 3rd Script（rsync 同步到iCloud） ============ ###

# 定义目录
LOCAL_DIR="$HOME/Library/Rime"                                                                   # 源目录
ICLOUD_DIR="$HOME/Library/Mobile Documents/iCloud~dev~fuxiao~app~hamsterapp/Documents/RIME/Rime" # 目标目录

# 定义排除列表
EXCLUDE_LIST=(
    '.git/' '.github/' 'build/' '.vscode/' 'sync/' 'bin/' 'custom/' 'zc.userdb/' 'lua/tips.userdb/'
    '*.userdb/' 'zc.userdb*' 'custom_phrase.txt' '*.userdb.txt' 'user.yaml' '.gitignore'
    'installation.yaml' '.DS_Store' '*.bin' '*.table.bin' '*.txt.bin' 'DELETED_*'
)

# 检查rsync命令是否存在
if ! command -v rsync &>/dev/null; then
    echo -e "${RED}错误: rsync命令未找到，请先安装rsync${NC}"
    exit 1
fi

# 检查源目录是否存在
if [ ! -d "$LOCAL_DIR" ]; then
    echo -e "${RED}错误: 源目录不存在: $LOCAL_DIR${NC}"
    exit 1
fi

# 检查目标目录是否存在，不存在则创建
if [ ! -d "$ICLOUD_DIR" ]; then
    echo -e "${YELLOW}目标目录不存在，正在创建: $ICLOUD_DIR${NC}"
    mkdir -p "$ICLOUD_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: 无法创建目标目录。请检查iCloud权限。${NC}"
        exit 1
    fi
fi

# 检查本地源目录中的文件数量
echo -e "${YELLOW}检查源目录中的Rime配置文件...${NC}"
file_count=$(find "$LOCAL_DIR" -type f ! -name ".DS_Store" ! -path "*/\.*" | wc -l | xargs)
echo -e "源目录中的Rime配置文件数量: ${YELLOW}$file_count${NC}"

if [ "$file_count" -eq 0 ]; then
    echo -e "${RED}警告: 源目录似乎为空，没有配置文件可同步${NC}"
    read -p "是否继续? (y/n): " continue_empty
    if [[ $continue_empty != [yY] && $continue_empty != [yY][eE][sS] ]]; then
        echo -e "${YELLOW}同步已取消${NC}"
        exit 0
    fi
fi

# 执行同步函数 - 使用排除列表变量
function sync_rime() {
    echo -e "${YELLOW}开始同步 Rime 配置...${NC}"
    echo -e "${YELLOW}从: $LOCAL_DIR${NC}"
    echo -e "${YELLOW}到: $ICLOUD_DIR${NC}"

    # 构建rsync排除参数
    RSYNC_EXCLUDE_OPTS=""
    for item in "${EXCLUDE_LIST[@]}"; do
        RSYNC_EXCLUDE_OPTS+="--exclude=$item "
    done

    rsync -av $RSYNC_EXCLUDE_OPTS "$LOCAL_DIR/" "$ICLOUD_DIR/"
    return $?
}

echo -e "${YELLOW}同步进度:${NC}"
sync_output=$(sync_rime)
sync_result=$?

if [ $sync_result -eq 0 ]; then
    echo -e "${GREEN}同步完成!${NC}"
    echo -e "${GREEN}成功将Rime配置同步到iCloud${NC}"
    echo -e "${YELLOW}注意：请等待iCloud将文件上传到云端，这可能需要一些时间${NC}"
    echo -e "${GREEN}======== 同步操作结束 ========${NC}"
else
    echo -e "${RED}同步失败，错误码: $sync_result${NC}"
    echo -e "${RED}错误详情:${NC}"
    echo "$sync_output" | grep -i "error\|failed"
    exit 1
fi

# === 询问是否重新部署Rime ===
echo -e "\n${YELLOW}是否现在重新部署Rime输入法？(推荐同步后使修改生效) [Y/n]${NC}"
read -p "请输入回车（默认部署）或 n (不部署): " deploy_rime_ask

# 如果输入为空（直接回车），默认为 "y"
if [[ -z "$deploy_rime_ask" ]]; then
    deploy_rime_ask="y"
fi

if [[ $deploy_rime_ask == [yY] || $deploy_rime_ask == [yY][eE][sS] ]]; then
    print_blue "正在重新部署Rime..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS系统 - 重新部署鼠须管(Squirrel)
        if [ -f "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" ]; then
            "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" --reload
            print_green "鼠须管(Squirrel)已重新部署"
        else
            print_red "未找到鼠须管(Squirrel)，请手动部署"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux系统 - 重新部署ibus-rime或fcitx-rime
        if command -v ibus-daemon &>/dev/null; then
            ibus-daemon -rdx
            print_green "ibus-rime已重新部署"
        elif command -v fcitx &>/dev/null; then
            fcitx -r
            print_green "fcitx-rime已重新部署"
        else
            print_red "未找到ibus或fcitx，请手动部署Rime"
        fi
    else
        print_red "未知操作系统，请手动部署Rime"
    fi
else
    echo -e "${YELLOW}已跳过重新部署Rime，请在输入法中手动部署以应用配置。${NC}"
fi

### ============ End 3rd Script ============ ###
