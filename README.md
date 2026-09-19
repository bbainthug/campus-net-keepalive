# campus-net-keepalive

macOS 校园网自动保活脚本：每 5 秒探测一次联网状态，掉线后立即自动重新认证，无需手动打开登录页。

## 原理

校园网 Web 认证本质是浏览器向认证服务器发一个 HTTP 请求。本项目用 `curl` 定时访问苹果的联网探测页（`captive.apple.com`）：

- 返回 `Success` → 在线，什么都不做
- 被网关劫持 → 判定掉线，从跳转 URL 中解析出本机 IP/MAC，重放登录请求

通过 `launchd` 注册为用户代理，开机自启、崩溃自动拉起。连续登录失败时指数退避（最长 60 秒），不会疯狂刷认证服务器。

## 适用范围

认证接口形如下面这样的校园网（多见于某些国产 Portal 网关）：

```
GET http://<portal>/api/public/auth/login?username=<32位hex>&password=<32位hex>&id=&code=&ip=<本机IP>&mac=<本机MAC>&domain=&_=<时间戳>
→ {"code":0,"msg":"认证成功", ...}
```

其他认证系统（锐捷、深澜 Srun、Dr.COM 等）请求格式不同，需要自行改 `login.sh` 里 `do_login` 中的 curl。

## 安装

**1. 抓取登录请求**

断网状态下打开校园网登录页，按 `⌥⌘I` 打开开发者工具 → Network，正常登录一次，找到 `auth/login` 请求，右键 → Copy as cURL。从 URL 里取出 `username=`、`password=`、`mac=` 三个值。

> 账号密码在前端已经加密成 32 位 hex，脚本直接重放这两串即可，不需要明文密码。

**2. 填写配置**

```bash
git clone https://github.com/bbainthug/campus-net-keepalive.git
cd campus-net-keepalive
cp config.example.sh config.sh
# 编辑 config.sh，填入 PORTAL / USER_ENC / PASS_ENC / FALLBACK_MAC
```

**3. 测试一次**

```bash
./login.sh --once
```

**4. 安装为后台服务**

```bash
./install.sh
```

脚本和配置会被复制到 `~/Library/Application Support/campus-net/` 运行（`~/Documents` 等目录受 macOS 隐私保护，后台进程读不了）。改了 `config.sh` 后重新执行 `./install.sh` 即可生效。

## 日志

只在掉线重登 / 登录失败时写入：

```bash
tail -f ~/Library/Logs/campus-net.log
```

## 卸载

```bash
./uninstall.sh
```

## 常见问题

- **改了密码怎么办** — 重新抓一次登录请求，更新 `config.sh` 里的 `PASS_ENC`，然后 `./install.sh` 重启服务。
- **学校定时强制下线** — 脚本无法阻止被踢，但会在 5 秒内自动重登。
- **日志里一直"登录失败"** — 看 `resp=` 后面服务器返回的 `msg`，常见原因是账号在别的设备在线、欠费、或加密串过期。
- **想改检测间隔** — 改 `config.sh` 里的 `INTERVAL`，然后 `./install.sh`。

## 免责声明

仅供在自己的账号上使用，请遵守所在学校的网络管理规定。

## License

MIT
