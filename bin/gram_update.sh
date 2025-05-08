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

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 获取仓库根目录
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# 文件信息
FILE_NAME="wanxiang-lts-zh-hans.gram"
FILE_URL="https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram"
TEMP_FILE="/tmp/${FILE_NAME}"

# 进入仓库目录
cd "$REPO_DIR" || {
    print_red "无法进入仓库目录: $REPO_DIR"
    exit 1
}

print_blue "开始更新 ${FILE_NAME}..."

# 下载文件
print_blue "正在下载最新版本，请稍候..."
if command -v curl &>/dev/null; then
    curl -L -s -o "$TEMP_FILE" "$FILE_URL" || {
        print_red "下载失败！请检查网络连接或URL是否有效"
        exit 1
    }
elif command -v wget &>/dev/null; then
    wget -q -O "$TEMP_FILE" "$FILE_URL" || {
        print_red "下载失败！请检查网络连接或URL是否有效"
        exit 1
    }
else
    print_red "错误: 需要 curl 或 wget 才能下载文件"
    exit 1
fi

# 验证下载文件
if [ ! -f "$TEMP_FILE" ]; then
    print_red "下载失败: 未找到临时文件"
    exit 1
fi

if [ ! -s "$TEMP_FILE" ]; then
    print_red "下载失败: 文件大小为零"
    rm -f "$TEMP_FILE"
    exit 1
fi

# 替换文件
print_blue "正在更新本地文件..."
mv -f "$TEMP_FILE" "$REPO_DIR/$FILE_NAME" || {
    print_red "无法移动文件到目标位置"
    exit 1
}

# 文件权限设置
chmod 644 "$REPO_DIR/$FILE_NAME" || {
    print_yellow "警告: 无法设置文件权限"
}

print_green "✓ ${FILE_NAME} 文件已成功更新!"
print_blue "文件位置: $REPO_DIR/$FILE_NAME"

# 提示用户进行Rime部署
print_yellow "提示: 请在Rime菜单中执行「重新部署」以应用更改"
