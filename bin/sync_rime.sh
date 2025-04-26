#!/bin/bash

# 定义颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 定义目录 - 正确的同步方向：本地到iCloud
LOCAL_DIR="$HOME/Library/Rime"                                                                   # 源目录
ICLOUD_DIR="$HOME/Library/Mobile Documents/iCloud~dev~fuxiao~app~hamsterapp/Documents/RIME/Rime" # 目标目录

# 定义排除列表 - 更易于维护
EXCLUDE_LIST=(
    '.git/'
    '.github/'
    'build/'
    'sync/'
    'bin/'
    'custom/'
    'zc.userdb/'
    'lua/tips.userdb/'
    '*.userdb/'
    'zc.userdb*'
    '*.userdb.txt'
    'user.yaml'
    '.gitignore'
    'installation.yaml'
    '.DS_Store'
    '*.bin'
    '*.table.bin'
    '*.txt.bin'
    'DELETED_*'
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

# 如果源目录为空，发出警告
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

    # 使用构建的排除参数执行rsync
    rsync -av $RSYNC_EXCLUDE_OPTS "$LOCAL_DIR/" "$ICLOUD_DIR/"

    return $?
}

# 执行同步并捕获输出
echo -e "${YELLOW}同步进度:${NC}"
sync_output=$(sync_rime)
sync_result=$?

# 显示结果
if [ $sync_result -eq 0 ]; then
    echo -e "${GREEN}同步完成!${NC}"
    echo -e "${GREEN}成功将Rime配置同步到iCloud${NC}"

    # 提示iCloud同步
    echo -e "${YELLOW}注意：请等待iCloud将文件上传到云端，这可能需要一些时间${NC}"
    echo -e "${GREEN}======== 同步操作结束 ========${NC}"
else
    echo -e "${RED}同步失败，错误码: $sync_result${NC}"
    echo -e "${RED}错误详情:${NC}"
    echo "$sync_output" | grep -i "error\|failed"
    exit 1
fi
