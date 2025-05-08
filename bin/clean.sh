#!/bin/bash

SCRIPT_DIR="$HOME/Library/Rime"

cd "$SCRIPT_DIR" || exit 1

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
