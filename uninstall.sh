#!/bin/bash
set -u
LABEL="com.campus-net.keepalive"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Library/Application Support/campus-net"
echo "已停止并移除 $LABEL"
