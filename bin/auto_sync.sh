#!/bin/bash

# 定义颜色输出函数
print_green() {
    echo -e "\033[0;32m$1\033[0m"
}

print_red() {
    echo -e "\033[0;31m$1\033[0m"
}

print_blue() {
    echo -e "\033[0;34m$1\033[0m"
}

print_yellow() {
    echo -e "\033[0;33m$1\033[0m"
}

# 本地Rime目录
REPO_DIR="$HOME/Library/Rime"

# 定义 rsync 的颜色输出，与前面的函数风格保持一致
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

cd "$REPO_DIR" || {
    print_red "无法进入仓库目录: $REPO_DIR"
    exit 1
}

### ============ Begin Git Sync and Push ============ ###

# 处理自定义提交信息
COMMIT_MSG="更新自定义配置 $(date '+%Y-%m-%d %H:%M')"
if [ $# -gt 0 ]; then
    COMMIT_MSG="$*"
fi

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
# 使用 -v 选项显示复制过程，方便调试
cp -fv custom/* . 2>/dev/null || print_yellow "复制 custom 文件时可能出现警告 (通常是正常的)"

# 2. 检查目录是否有变更
# 设置上游仓库 (如果还没设置的话) - 这个通常只需运行一次
git push --set-upstream origin main >/dev/null 2>&1 || true

print_blue "检查仓库是否有变更..."
git status --porcelain | grep -q . || {
    print_yellow "没有检测到任何变更，无需提交和推送"
    # 直接跳过Git部分，进入rsync和部署
    echo "==== 跳过Git提交与推送 ===="
    skip_git=1
}

if [ "${skip_git}" != "1" ]; then
    # 3. 添加变更到暂存区
    print_blue "添加变更到Git（含所有新文件）..."
    git add -A || {
        print_red "无法添加变更"
        # 注意：这里退出会导致后续rsync和部署也不执行，可能不是期望的行为
        # 如果希望rsync和部署无论Git是否成功都执行，可以移除这里的 exit 1
        exit 1
    }

    # 4. 提交变更
    print_blue "提交变更: $COMMIT_MSG"
    git commit -m "$COMMIT_MSG" || {
        print_red "提交变更失败 (可能是没有真正需要提交的变更)"
        # 如果 commit 失败（例如，没有实际变更），可能不需要退出
        # 检查commit是否真的失败（例如，因为没有变更会返回非零状态，但不是真正的错误）
        if [ $? -ne 0 ]; then
            # 再次检查是否有 staged changes，如果没有则忽略 commit 错误
            git diff --cached --quiet || {
                print_red "真正的提交错误发生！"
                exit 1
            }
            print_yellow "没有发现需要提交的实际变更，跳过 commit 和 push"
            skip_git=1 # 如果没有变更，设置标记跳过后续Git操作
        fi
    }
fi # End of if [ "${skip_git}" != "1" ] block for add/commit

if [ "${skip_git}" != "1" ]; then
    # 5. 拉取远程更新并合并 - 解决 non-fast-forward 问题
    print_blue "从远程仓库拉取更新并尝试合并..."
    # 使用 git pull origin main 来明确指定拉取源和分支，
    # 并尝试自动合并远程更改。
    git pull origin main || {
        print_red "拉取远程更新或自动合并失败！"
        print_red "错误提示：可能是存在合并冲突，请手动解决后再次运行脚本。"
        # 拉取失败通常是无法继续的，所以这里应该退出
        exit 1
    }
    print_green "远程更新已拉取并合并成功！"

    # 6. 推送到远程仓库 - 现在应该可以正常推送了
    print_blue "推送到远程仓库..."
    git push origin main || { # 明确指定推送源和分支
        print_red "推送到远程仓库失败"
        print_red "请检查网络连接或SSH密钥设置。"
        exit 1
    }

    print_green "自定义配置已成功更新并推送到远程仓库！"
fi

### ============ End Git Sync and Push ============ ###

### ============ Begin rsync Sync to iCloud + Deploy Rime ============ ###

# 注意：原脚本中的第二部分（拉远程+本地配置恢复+部署Rime）
# 在新的流程中不再需要硬重置，因为 Git pull 已经确保了本地仓库是最新的状态。
# 所以直接进入 rsync 同步和部署部分。

# 定义目录
LOCAL_DIR="$HOME/Library/Rime"                                                                   # 源目录
ICLOUD_DIR="$HOME/Library/Mobile Documents/iCloud~dev~fuxiao~app~hamsterapp/Documents/RIME/Rime" # 目标目录

# 定义排除列表
EXCLUDE_LIST=(
    '.git/' '.github/' 'build/' '.vscode/' 'sync/' 'bin/' 'custom/' 'zc.userdb/' 'lua/tips.userdb/'
    '*.userdb/' 'zc.userdb*' 'custom_phrase.txt' '*.userdb.txt' 'user.yaml' '.gitignore'
    'installation.yaml' '.DS_Store' '*.bin' '*.table.bin' '*.txt.bin' 'DELETED_*'
    # 根据需要，这里可以排除更多你不想同步到 iCloud 的文件或目录
)

# 检查rsync命令是否存在
if ! command -v rsync &>/dev/null; then
    echo -e "${RED}错误: rsync命令未找到，请先安装rsync${NC}"
    # 注意：rsync和部署部分与Git部分相对独立
    # 如果Git成功但rsync失败，我们仍然希望报告rsync失败
    # 所以这里的exit是针对rsync部分的失败
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
# 排除隐藏文件和目录，以及 .DS_Store 和排除列表中的路径
file_count=$(find "$LOCAL_DIR" -type f \
    ! -name ".DS_Store" \
    ! -path "*/\.*" \
    $(printf "! -path \"$LOCAL_DIR/%s*\" " "${EXCLUDE_LIST[@]}") |
    wc -l | xargs)
echo -e "源目录中将被同步的配置文件数量: ${YELLOW}$file_count${NC}"

if [ "$file_count" -eq 0 ]; then
    echo -e "${RED}警告: 根据排除列表，源目录似乎没有需要同步的配置文件${NC}"
    read -p "是否继续执行rsync? (y/n): " continue_empty
    if [[ $continue_empty != [yY] && $continue_empty != [yY][eE][sS] ]]; then
        echo -e "${YELLOW}同步到iCloud已取消${NC}"
        # 如果取消rsync，但Git部分成功了，应该允许继续部署
        # exit 0 # 不要在这里退出
        print_blue "===== 跳过同步到iCloud ======"
        skip_rsync=1
    fi
fi

if [ "${skip_rsync}" != "1" ]; then
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

        # 使用 -v 选项显示详细同步过程
        rsync -av --delete $RSYNC_EXCLUDE_OPTS "$LOCAL_DIR/" "$ICLOUD_DIR/"
        return $?
    }

    echo -e "${YELLOW}同步进度:${NC}"
    # 直接执行函数，rsync会打印进度
    sync_rime
    sync_result=$?

    if [ $sync_result -eq 0 ]; then
        echo -e "${GREEN}同步完成!${NC}"
        echo -e "${GREEN}成功将Rime配置同步到iCloud${NC}"
        echo -e "${YELLOW}注意：请等待iCloud将文件上传到云端，这可能需要一些时间${NC}"
        # 原脚本中单独复制了一个wanxiang文件，如果这个文件不在排除列表，rsync会处理。
        # 如果在排除列表但确实需要同步，则保留此行。
        # 如果wanxiang-lts-zh-hans.gram是你希望rsync同步的文件之一，可以删除下一行。
        # cp -f "${LOCAL_DIR}/wanxiang-lts-zh-hans.gram" "${ICLOUD_DIR}/wanxiang-lts-zh-hans.gram"
        echo -e "${GREEN}======== 同步操作结束 ========${NC}"
    else
        echo -e "${RED}同步失败，错误码: $sync_result${NC}"
        echo -e "${RED}请检查错误信息。${NC}"
        # rsync失败，但仍可以尝试部署Rime
        # exit 1 # 不在这里退出，继续尝试部署
    fi
fi # End of if [ "${skip_rsync}" != "1" ] block for rsync

# === 重新部署Rime ===
# 这个步骤应该在Git同步和rsync同步都尝试完成后执行
echo -e "\n现在重新部署Rime输入法"
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

print_blue "===== 脚本执行完毕 ====="
