# Rime 自动同步配置

字符


󱓞



󰐳





󰀹



󰄼












这个仓库提供了一套自动化工具，用于保持您的Rime输入法配置与最新版本同步，同时保留您的自定义内容。

## 功能特点

- **自动字典同步**：每日同步最新的`cn_dicts`词库
- **词库自动更新**：每周自动从上游仓库同步最新发布版本
- **本地自定义保护**：更新过程中保留所有本地自定义文件
- **定时执行**：支持macOS系统定时自动更新
- **自定义配置简便化**：只需将配置放入custom目录即可自动应用
- **更新自定义配置**：一键更新自定义配置
- **更新万象拼音词典**：一键更新万象拼音词典

## 安装指南

### 1. 克隆仓库

```bash
# 备份原有配置（如有需要）
mv ~/Library/Rime ~/Library/Rime_backup_$(date +%Y%m%d)

# 克隆仓库
git clone https://github.com/astralwaveio/rime_autosync.git ~/Library/Rime
```

### 2. 初始化配置

```bash
cd ~/Library/Rime

# 确保脚本具有执行权限
chmod +x bin/update.sh

# 首次运行更新脚本
./bin/update.sh
```

### 3. 设置定时更新（macOS）

```bash
# 创建plist文件
cat > ~/Library/LaunchAgents/io.astralwave.rime.updater.plist << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>io.astralwave.rime.updater</string>
    <key>ProgramArguments</key>
    <array>
        <string>${HOME}/Library/Rime/bin/update.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>22</integer>
        <key>Minute</key>
        <integer>30</integer>
    </dict>
    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/rime_update_error.log</string>
    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/rime_update.log</string>
</dict>
</plist>
EOL

# 加载plist文件
launchctl load ~/Library/LaunchAgents/io.astralwave.rime.updater.plist
```

## 自定义配置

### 添加自定义内容

本仓库设计为可以轻松添加自定义配置而不会被更新覆盖：

1. **custom目录**：将您的自定义配置文件放入`custom/`目录
   - 更新脚本会自动将此目录中的文件复制到根目录
   - 例如：`custom/default.custom.yaml`将自动复制到根目录

2. **直接添加文件**：
   - 直接在根目录添加的文件会在更新时自动保留
   - 脚本会识别未被Git追踪的文件并在更新后恢复

### 保护特定文件不被Git跟踪

对于包含敏感信息的文件（如个人词典），建议使用Git的`--skip-worktree`标记：

```bash
# 标记文件为本地修改但不提交
git update-index --skip-worktree my_custom_dict.txt

# 查看当前被标记的文件
git ls-files -v | grep '^S'

# 如需取消标记
# git update-index --no-skip-worktree my_custom_dict.txt
```

## 更新自定义配置

如果您修改了custom目录中的配置文件，可以使用以下命令快速更新并推送到远程仓库：

```bash
# 使用默认提交信息
./bin/push_custom.sh

# 使用自定义提交信息
./bin/push_custom.sh "添加了新的自定义词库"
```

## 更新万象拼音词典

要获取最新版本的万象拼音词典文件，请运行:

```bash
./bin/update_wanxiang.sh
```

## 更新机制说明

### 自动更新流程

本仓库配置了两种自动更新：

1. **每日字典同步**：
   - 每天自动从上游仓库同步`cn_dicts`目录
   - 通过GitHub Actions自动执行

2. **每周完整更新**：
   - 每周从上游仓库同步最新发布版本
   - 智能识别最新有效版本标签（v开头的数字版本）

### 本地定时更新

通过`bin/update.sh`脚本执行的更新过程：

1. 备份所有未跟踪的本地文件
2. 从远程获取最新变更并强制更新
3. 恢复之前备份的本地文件
4. 将`custom/`目录中的文件复制到根目录

默认配置每天晚上10:30自动执行更新。

## 日志与调试

更新过程的日志记录在以下位置：

- 更新执行日志：`~/Library/Rime/bin/update_log.log`
- launchd错误日志：`~/Library/Logs/rime_update_error.log`
- launchd标准输出：`~/Library/Logs/rime_update.log`

如遇问题，查看这些日志可帮助诊断原因。

## 手动更新

如需手动触发更新，可以执行：

```bash
# 在Rime目录下
./bin/update.sh
```

## 常见问题

### 定时任务未执行
- 检查launchd服务是否已加载：`launchctl list | grep rime`
- 确认权限：`chmod +x ~/Library/Rime/bin/update.sh`
- 查看日志文件检查错误信息

### 更新后配置未生效
- 在Rime输入法菜单中选择"重新部署"
- 确认`custom/`目录中的文件正确无误

### 如何禁用自动更新
```bash
# 禁用launchd服务
launchctl unload ~/Library/LaunchAgents/io.astralwave.rime.updater.plist
```

### 如何恢复某个文件到官方版本
```bash
# 恢复单个文件
git checkout origin/main -- 文件路径
```

## 贡献与反馈

如有问题或建议，欢迎提交Issue或Pull Request。

---

**注意**：本仓库只是配置同步工具，Rime输入法本身的安装和基本使用请参考[Rime输入法官方文档](https://rime.im)。