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
cd "$REPO_DIR" || {
    print_red "无法进入仓库目录: $REPO_DIR"
    exit 1
}

# 清理 build
echo "清理  build 目录..."
rm -rf build

# 清理用户数据
echo "清理  用户数据..."
rm -rf easy_en.userdb wanxiang.userdb installation.yaml user.yaml zc.userdb lua/tips.userdb

# 清理自定义配置
echo "清理  自定义配置..."
rm -rf *custom.yaml

echo "清理完成！"
exit 0
