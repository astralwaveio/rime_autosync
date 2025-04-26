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

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 获取仓库根目录
REPO_DIR="$(dirname "$SCRIPT_DIR")"
# 设置临时备份目录
BACKUP_DIR="/tmp/rime_update_backup"

# 记录时间戳
print_blue "===== 更新开始: $(date) ====="

# 进入仓库目录
cd "$REPO_DIR" || {
    print_red "无法进入仓库目录: $REPO_DIR"
    exit 1
}

print_blue "开始更新Rime配置..."

# 1. 识别并备份所有未被Git跟踪的文件
print_blue "备份未被Git跟踪的文件..."
mkdir -p "$BACKUP_DIR"
# 获取未被跟踪的文件列表
UNTRACKED_FILES=$(git ls-files --others --exclude-standard)

# 备份未被跟踪的文件
if [ -n "$UNTRACKED_FILES" ]; then
    print_blue "备份以下未跟踪的文件:"
    for file in $UNTRACKED_FILES; do
        # 创建目标目录结构
        mkdir -p "$BACKUP_DIR/$(dirname "$file")"
        # 复制文件
        cp -f "$file" "$BACKUP_DIR/$file" 2>/dev/null
        echo " - $file"
    done
    print_green "已备份 $(echo "$UNTRACKED_FILES" | wc -w | xargs) 个本地文件"
else
    print_blue "没有找到未跟踪的文件"
fi

# 2. 获取远程更新并重置本地仓库
print_blue "从远程仓库获取更新..."

# 保存当前分支名称
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# 获取最新的更改
git fetch --all || {
    print_red "获取远程更新失败"
    exit 1
}

# 重置本地文件到远程状态 (忽略所有本地更改)
git reset --hard "origin/$CURRENT_BRANCH" || {
    print_red "重置到远程状态失败"
    exit 1
}

# 3. 恢复备份的本地文件
if [ -n "$UNTRACKED_FILES" ]; then
    print_blue "恢复本地特有文件..."
    for file in $UNTRACKED_FILES; do
        # 如果备份文件存在，则恢复
        if [ -f "$BACKUP_DIR/$file" ]; then
            # 确保目标目录存在
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
    print_green "自定义配置文件已更新"
else
    print_red "custom目录不存在"
fi

# 5. 清理备份
rm -rf "$BACKUP_DIR"

print_green "更新完成！"

# 6. 重新部署Squirrel
print_blue "正在重新部署Rime..."

# 检测系统类型并执行相应的部署命令
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

print_blue "===== 更新结束: $(date) ====="
