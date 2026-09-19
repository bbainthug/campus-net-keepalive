#!/bin/bash
# 校园网自动保活守护进程：定时探测联网状态，掉线立即重新认证。
# 用法：./login.sh          常驻循环（launchd 调用）
#       ./login.sh --once   只检测/登录一次，用于手动测试
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${CAMPUS_NET_CONFIG:-$DIR/config.sh}"
if [[ ! -f "$CONFIG" ]]; then
  echo "缺少配置文件 $CONFIG，请先: cp config.example.sh config.sh 并填写" >&2
  exit 1
fi
# shellcheck source=config.example.sh
source "$CONFIG"
: "${PORTAL:?config.sh 缺少 PORTAL}" "${USER_ENC:?config.sh 缺少 USER_ENC}" "${PASS_ENC:?config.sh 缺少 PASS_ENC}"
: "${INTERVAL:=5}" "${FALLBACK_MAC:=}"
: "${CHECK_URL:=http://captive.apple.com/hotspot-detect.html}"
: "${LOG:=$HOME/Library/Logs/campus-net.log}"
# 互踢保护：WINDOW 秒内重登超过 MAX_RELOGINS 次，视为与其他设备互踢，暂停 COOLDOWN 秒
: "${MAX_RELOGINS:=3}" "${WINDOW:=600}" "${COOLDOWN:=900}"

UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15'

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

# 探测页正常返回 Success；被网关劫持时返回登录页或 302
is_online() {
  local body
  body=$(curl -s -m 3 -A "$UA" "$CHECK_URL" 2>/dev/null)
  [[ "$body" == *Success* ]]
}

# 优先从网关跳转 URL 取 wlanuserip / clientmac，其次读默认网卡，最后用 FALLBACK_MAC
detect_ip_mac() {
  local loc ifc
  loc=$(curl -s -m 3 -A "$UA" -o /dev/null -w '%{redirect_url}' "$CHECK_URL" 2>/dev/null)
  IP=$(sed -n 's/.*wlanuserip=\([^&]*\).*/\1/p' <<<"$loc")
  MAC=$(sed -n 's/.*clientmac=\([^&]*\).*/\1/p' <<<"$loc")
  if [[ -z "$IP" ]]; then
    ifc=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
    IP=$(ipconfig getifaddr "${ifc:-en0}" 2>/dev/null)
  fi
  if [[ -z "$MAC" ]]; then
    ifc=${ifc:-$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')}
    MAC=$(ifconfig "${ifc:-en0}" 2>/dev/null | awk '/ether/{print $2}')
  fi
  [[ -z "$MAC" ]] && MAC="$FALLBACK_MAC"
}

# 返回 0 = 登录成功
do_login() {
  detect_ip_mac
  if [[ -z "$IP" ]]; then
    log "拿不到本机 IP，可能还没连上网络"
    return 1
  fi
  local resp
  resp=$(curl -s -m 8 -A "$UA" \
    "$PORTAL/api/public/auth/login?username=$USER_ENC&password=$PASS_ENC&id=&code=&ip=$IP&mac=${MAC//:/%3A}&domain=&_=$(date +%s)000" \
    -H 'Accept: application/json, text/javascript, */*; q=0.01' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -H 'Language: zh-CN' \
    -H "Referer: $PORTAL/")
  if [[ "$resp" == *'"code":0'* ]]; then
    log "重新登录成功 ip=$IP mac=$MAC"
    return 0
  fi
  log "登录失败 ip=$IP mac=$MAC resp=${resp:-<无响应>}"
  return 1
}

if [[ "${1:-}" == "--once" ]]; then
  if is_online; then echo "在线，无需登录"; exit 0; fi
  do_login && echo "登录成功" || { echo "登录失败，详见 $LOG"; exit 1; }
  exit 0
fi

log "守护进程启动，检测间隔 ${INTERVAL}s，互踢保护 ${WINDOW}s 内 >${MAX_RELOGINS} 次则暂停 ${COOLDOWN}s"
fails=0
relogins=()   # 最近成功重登的时间戳
while true; do
  if is_online; then
    fails=0
    sleep "$INTERVAL"
  elif do_login; then
    fails=0
    now=$(date +%s)
    relogins+=("$now")
    # 只保留窗口内的记录
    keep=(); for t in "${relogins[@]}"; do (( now - t < WINDOW )) && keep+=("$t"); done
    relogins=("${keep[@]}")
    if (( ${#relogins[@]} > MAX_RELOGINS )); then
      log "警告：${WINDOW}s 内重登 ${#relogins[@]} 次，疑似账号超过设备上限在互踢，暂停 ${COOLDOWN}s 避免账号异常"
      relogins=()
      sleep "$COOLDOWN"
      continue
    fi
    sleep "$INTERVAL"
  else
    # 连续失败时指数退避（最长 60s），避免疯狂刷认证服务器
    fails=$((fails + 1))
    wait=$(( INTERVAL * (1 << (fails < 4 ? fails : 4)) ))
    (( wait > 60 )) && wait=60
    sleep "$wait"
  fi
done
