#!/bin/bash

set -euo pipefail

### ============ 颜色输出函数 ============ ###
print_msg() {
  local color="$1"
  local message="$2"
  echo -e "\033[0;${color}m${message}\033[0m"
}

### ============ 主要功能函数 ============ ###
update_rime_config() {
  # 本地Rime目录
  local REPO_DIR="$HOME/Library/Rime"

  cd "$REPO_DIR" || {
    print_msg "31" "错误: 无法进入仓库目录"
    exit 1
  }

  print_msg "34" "开始更新Rime配置..."

  # 强制更新本地仓库到远程状态
  git fetch --all
  git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)

  # 更新自定义配置
  if [ -d "custom" ]; then
    cp -f custom/* . 2>/dev/null || true
    [ -d "custom/lua" ] && {
      mkdir -p lua
      cp -f custom/lua/* lua/ 2>/dev/null || true
    }
    print_msg "32" "自定义配置已更新"
  fi
}

### ============ 部署函数 ============ ###
deploy_rime() {
  print_msg "34" "正在部署Rime..."

  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    [ -f "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" ] && {
      "/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" --reload
      print_msg "32" "鼠须管已重新部署"
    }
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if command -v ibus-daemon &>/dev/null; then
      ibus-daemon -rdx
      print_msg "32" "ibus-rime已重新部署"
    elif command -v fcitx &>/dev/null; then
      fcitx -r
      print_msg "32" "fcitx-rime已重新部署"
    fi
  fi
}

# 执行更新和部署
update_rime_config
deploy_rime
print_msg "32" "配置更新完成！"
