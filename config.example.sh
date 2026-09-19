# 复制为 config.sh 后填写。config.sh 已在 .gitignore 中，不会被提交。

# 认证服务器地址（登录页的 host:port）
PORTAL="http://192.168.252.210:8080"

# 浏览器抓包得到的加密后账号/密码（登录请求 URL 里的 username= 和 password= 两串 32 位 hex）
USER_ENC="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
PASS_ENC="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# 检测间隔（秒）
INTERVAL=5

# 兜底 MAC：抓包时登录 URL 里的 mac= 值。脚本优先从网关跳转参数取，取不到再读网卡，最后用这个
FALLBACK_MAC=""

# 互踢保护：WINDOW 秒内重登超过 MAX_RELOGINS 次，视为账号超设备上限被其他设备反复挤下线，
# 暂停 COOLDOWN 秒不再重登，避免和自己的其他设备无限互踢、被服务器判为异常
MAX_RELOGINS=3
WINDOW=600
COOLDOWN=900

# 联网探测地址，正常联网时返回 "Success"
CHECK_URL="http://captive.apple.com/hotspot-detect.html"

# 日志路径
LOG="$HOME/Library/Logs/campus-net.log"
