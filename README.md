# aTrust Desktop Kit

面向 Windows + Docker Desktop 的 aTrust 自动登录工具，提供代理、浏览器 VNC 和可切换的密码存储方式。

## 与相关项目的区别

| 项目 | 侧重点 |
| --- | --- |
| [docker-easyconnect](https://github.com/docker-easyconnect/docker-easyconnect) | 提供 EasyConnect / aTrust 容器、代理和网关；aTrust 自动登录推荐配合 aTrustLogin。 |
| [aTrustLogin](https://github.com/kenvix/aTrustLogin) | 跨平台浏览器登录自动化，支持 TOTP、Cookie 恢复、保活，以及人工完成 SSO / CAS。 |
| **本项目** | 面向 Windows 的双击配置与启动、明文 / DPAPI 存储切换、浏览器 VNC；使用独立登录程序，每次启动建立新会话，提交前校验输入，认证被拒后停止重试。 |

本项目使用 aTrustLogin 的运行镜像，不提供完整的跨平台、TOTP 或 SSO 自动化功能。

## 使用

需要 Windows 10/11、PowerShell 5.1+，以及已启动的 Docker Desktop（Linux / x86-64 容器）。

1. 下载仓库，双击 `Configure.cmd`，填写门户、账号和密码。
2. 后续双击 `Start.cmd` 自动登录；`Stop.cmd` 停止服务。
3. `Logs.cmd` 查看状态，`Manual-Login.cmd` 切换为手动登录；需要浏览器桌面时运行 `Open-VNC.cmd`，按需启动 VNC 网页服务。

默认地址均为本机：SOCKS5 `127.0.0.1:1080`、HTTP `127.0.0.1:8888`、VNC `127.0.0.1:5901`。浏览器 VNC 使用 6080 / 6081。已有服务占用端口时，修改配置中的端口或先停止旧服务。

默认只启动 VPN 容器，浏览器 VNC 不随 Docker 自动启动。VPN 内存上限为 768 MiB（0.75 GiB），不额外使用交换空间；不同门户需求有差异，可在 `compose.yaml` 中调整。

## 配置

首次运行根据 `credentials.example.json` 创建本地 `credentials.json`：

| 字段 | 用途 |
| --- | --- |
| `Portal` / `Username` / `Password` | VPN 门户、账号、密码 |
| `VncPassword` | 独立 VNC 密码，首次随机生成 |
| `EncryptPasswords` | `true`：Windows 账户加密；`false`：明文 |
| `GatewayAddress` | 可选的网关真实 IP，用于处理虚拟 DNS 与 VPN 路由冲突 |

修改存储开关后运行 `Start.cmd`，或双击 `Use-Plaintext.cmd` / `Use-Encrypted.cmd` 立即转换。加密模式默认开启，只能由原 Windows 账户解密。

配置文件不受 Git 跟踪。明文可被文件读取者查看，Docker 管理员也能读取运行中的凭据。验证码、短信或扫码仍需人工完成；应通过代理访问实际内网服务确认连接。

## 许可与致谢

感谢 kenvix / aTrustLogin 和 docker-easyconnect 的作者及贡献者。本仓库原创代码采用 [MIT](LICENSE)，第三方镜像和客户端保留原有权利；来源与许可说明见 [NOTICE.md](NOTICE.md)。
