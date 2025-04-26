#!/bin/bash

# 定义颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 定义目录
ICLOUD_DIR="$HOME/Library/Mobile Documents/iCloud~dev~fuxiao~app~hamsterapp/Documents/RIME/Rime"
LOCAL_DIR="$HOME/Library/Rime"

# 检查源目录是否存在
if [ ! -d "$ICLOUD_DIR" ]; then
    echo -e "${RED}错误: 源目录不存在: $ICLOUD_DIR${NC}"
    exit 1
fi

# 检查目标目录是否存在，不存在则创建
if [ ! -d "$LOCAL_DIR" ]; then
    echo -e "${YELLOW}目标目录不存在，正在创建: $LOCAL_DIR${NC}"
    mkdir -p "$LOCAL_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: 无法创建目标目录${NC}"
        exit 1
    fi
fi

# 显示目录信息（调试用）
echo -e "${YELLOW}源目录: $ICLOUD_DIR${NC}"
echo -e "${YELLOW}目标目录: $LOCAL_DIR${NC}"
echo

# 检查源目录是否有文件
file_count=$(find "$ICLOUD_DIR" -type f | wc -l)
echo -e "${YELLOW}源目录中的文件数量: $file_count${NC}"
if [ "$file_count" -eq 0 ]; then
    echo -e "${RED}警告: 源目录似乎为空，请检查路径是否正确${NC}"
    exit 1
fi

# 执行同步函数 - 显示执行过程
function sync_rime() {
    echo -e "${YELLOW}开始同步 Rime 配置...${NC}"

    # 使用-a确保递归同步所有子目录，-v显示详细信息
    # 不使用-u参数，确保所有文件都会被同步
    rsync -av \
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
sync_rime
sync_result=$?

# 显示结果
if [ $sync_result -eq 0 ]; then
    echo -e "${GREEN}同步完成!${NC}"
else
    echo -e "${RED}同步失败，错误码: $sync_result${NC}"
    exit 1
fi

# 自动重新部署输入法
echo -e "${YELLOW}正在重新部署 Rime...${NC}"
if [ -f "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" ]; then
    "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" --reload
    echo -e "${GREEN}重新部署完成!${NC}"
else
    echo -e "${RED}无法找到 Squirrel 程序，请手动重新部署${NC}"
fi

echo -e "${GREEN}======== 同步操作结束 ========${NC}"
