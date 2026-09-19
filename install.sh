#!/bin/bash
# 安装为 macOS launchd 用户代理：开机自启、崩溃自动拉起
# 脚本会被复制到 ~/Library/Application Support/campus-net/ 运行，
# 因为 ~/Documents、~/Desktop 等目录受 macOS 隐私保护，launchd 后台进程无法直接读取。
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="com.campus-net.keepalive"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
APP="$HOME/Library/Application Support/campus-net"

[[ -f "$DIR/config.sh" ]] || { echo "请先: cp config.example.sh config.sh 并填写账号信息"; exit 1; }

mkdir -p "$APP" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cp "$DIR/login.sh" "$DIR/config.sh" "$APP/"
chmod 700 "$APP"; chmod 600 "$APP/config.sh"

cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$APP/login.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>5</integer>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/campus-net.err</string>
</dict>
</plist>
PL

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "已安装并启动: $LABEL"
echo "运行目录: $APP"
echo "日志: tail -f ~/Library/Logs/campus-net.log"
