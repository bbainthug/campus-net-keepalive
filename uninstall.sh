#!/bin/bash
set -u
LABEL="com.campus-net.keepalive"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
echo "已停止并移除 $LABEL"
