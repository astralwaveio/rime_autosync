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

# 同步函数 - 移除--delete参数以保留目标目录的独有内容
function sync() {
    echo -e "${YELLOW}开始同步 Rime 配置...${NC}"

    # 使用-a确保递归同步所有子目录，-v显示详细信息，-u只更新更新的文件
    rsync -avu \
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

# 显示将要同步的信息
echo "======== Rime 配置同步 ========"
echo "源目录: $ICLOUD_DIR"
echo "目标目录: $LOCAL_DIR"
echo
echo "同步模式: 仅更新已有文件和添加新文件，不会删除目标目录中的独有文件"
echo

# 列出排除的文件和目录
echo "将排除以下用户数据和系统文件:"
echo " - zc.userdb 目录及相关文件"
echo " - build 目录 (编译生成的文件)"
echo " - user.yaml 文件 (用户偏好设置)"
echo " - .git 目录及 .gitignore 文件"
echo " - lua/tips.userdb 目录"
echo " - .github 目录"
echo " - installation.yaml 文件 (安装信息)"
echo " - .DS_Store 文件"
echo " - sync 目录 (同步相关目录)"
echo " - 所有 *.userdb 目录和 *.userdb.txt 文件 (用户词库)"
echo " - 所有编译文件 (*.bin, *.table.bin, *.txt.bin)"
echo " - DELETED_* 文件"
echo

# 确认操作
read -p "是否继续同步操作? (y/n): " confirm
if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
    echo -e "${YELLOW}操作已取消${NC}"
    exit 0
fi

# 执行同步
sync
sync_result=$?

# 显示结果
if [ $sync_result -eq 0 ]; then
    echo -e "${GREEN}同步完成!${NC}"
else
    echo -e "${RED}同步失败，错误码: $sync_result${NC}"
    exit 1
fi

# 提示用户需要重新部署输入法
echo
echo -e "${YELLOW}提示: 同步完成后，您可能需要「重新部署」Rime 输入法以应用更改。${NC}"

# 询问是否自动重新部署
echo
read -p "是否自动重新部署 Rime 输入法? (y/n): " deploy_confirm
if [[ $deploy_confirm == [yY] || $deploy_confirm == [yY][eE][sS] ]]; then
    echo -e "${YELLOW}正在重新部署 Rime...${NC}"
    # 检查Squirrel(鼠须管)是否存在
    if [ -f "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" ]; then
        "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" --reload
        echo -e "${GREEN}重新部署完成!${NC}"
    else
        echo -e "${RED}无法找到 Squirrel 程序，请手动重新部署${NC}"
    fi
fi

# 结束
echo
echo "======== 同步操作结束 ========"
