#!/bin/bash

# 设置错误时立即退出
set -e

# 定义目录
ICLOUD_DIR="$HOME/Library/Mobile Documents/iCloud~dev~fuxiao~app~hamsterapp/Documents/RIME/Rime"
LOCAL_DIR="$HOME/Library/Rime"

# 检查源目录是否存在
if [ ! -d "$ICLOUD_DIR" ]; then
    exit 1
fi

# 检查目标目录是否存在，不存在则创建
if [ ! -d "$LOCAL_DIR" ]; then
    mkdir -p "$LOCAL_DIR" || exit 1
fi

# 执行同步函数 - 静默模式
function sync_rime() {
    # 使用-a确保递归同步所有子目录，-q静默模式，-u只更新更新的文件
    rsync -aqu \
        --exclude='zc.userdb/' \
        --exclude='zc.userdb*' \
        --exclude='build/' \
        --exclude='user.yaml' \
        --exclude='.git/' \
        --exclude='lua/tips.userdb/' \
        --exclude='.gitignore' \
        --exclude='.github/' \
        --exclude='installation.yaml' \
        --exclude='.DS_Store' \
        --exclude='sync/' \
        --exclude='*.userdb/' \
        --exclude='*.userdb.txt' \
        --exclude='*.bin' \
        --exclude='*.table.bin' \
        --exclude='*.txt.bin' \
        --exclude='DELETED_*' \
        "$ICLOUD_DIR/" "$LOCAL_DIR/"

    return $?
}

# 执行同步
sync_result=0
sync_rime || sync_result=$?

# 如果同步成功且Squirrel存在，则自动重新部署
if [ $sync_result -eq 0 ] && [ -f "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" ]; then
    "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" --reload >/dev/null 2>&1 || true
fi

exit $sync_result
