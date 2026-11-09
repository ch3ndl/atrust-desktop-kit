# aTrust Desktop Kit

Windows + Docker Desktop 的 aTrust 自动登录部署工具，提供 SOCKS5/HTTP 代理、
浏览器 VNC，以及可切换的明文 / Windows 账户加密凭据存储。

这是独立的部署辅助项目。感谢 [kenvix/aTrustLogin](https://github.com/kenvix/aTrustLogin)
和 [docker-easyconnect](https://github.com/docker-easyconnect/docker-easyconnect)
的前期工作。项目引用前者提供的运行镜像，但登录辅助程序独立编写，未复制其
Python 源码。许可边界和完整致谢见 [NOTICE.md](NOTICE.md)。

## 环境要求

- Windows 10/11，Windows PowerShell 5.1 或 PowerShell 7。
- Docker Desktop 已启动，使用 Linux 容器和 x86-64 环境。
- 能合法使用所在机构的 aTrust 账户；需要人工认证时仍须完成验证。
- 第三方镜像约占若干 GB 空间，具体大小以实际下载为准。

## 快速开始

1. 下载本仓库到单独目录。请勿将真实部署目录直接当成公开仓库。
2. 双击 `Configure.cmd`，输入自己的门户、用户名和密码。
3. 双击 `Logs.cmd` 查看登录状态；需要桌面时打开 `Open-VNC.cmd`。
4. 后续双击 `Start.cmd` 即可自动启动。`Stop.cmd` 停止本项目的容器。

如已有其他 aTrust 容器占用这些端口，请先停止旧部署，或在本地配置中改用另一组端口。
本项目使用独立 Compose 项目和数据卷，不会自动删除旧容器或旧数据。

| 入口 | 用途 |
| --- | --- |
| `Start.cmd` | 自动填写账号密码并保活 |
| `Configure.cmd` | 设置门户、账号、密码，随后启动 |
| `Manual-Login.cmd` | 启动桌面，完全由用户登录 |
| `Open-VNC.cmd` | 显示独立 VNC 密码并打开浏览器桌面 |
| `Use-Plaintext.cmd` | 转换为明文保存，不重启 |
| `Use-Encrypted.cmd` | 转换为 Windows DPAPI 加密保存，不重启 |
| `Logs.cmd` / `Stop.cmd` | 查看日志 / 停止本项目容器 |

默认 SOCKS5 为 `127.0.0.1:1080`，HTTP 为 `127.0.0.1:8888`；VNC 为
`127.0.0.1:5901`，浏览器页面与 WebSocket 分别使用 6080 和 6081。
所有入口只绑定本机。普通浏览器不能直接打开 5901，请使用 `Open-VNC.cmd`。
本项目不修改 Windows 全局代理或你的 SSH 配置。

## 本地配置和存储开关

首次运行从 `credentials.example.json` 生成 **不受 Git 跟踪的** `credentials.json`。
示例不含可用密码、真实机构域名、内网地址或个人身份信息。

`Password` 是 VPN 密码，`VncPassword` 是单独的桌面连接密码；首次配置会随机生成
VNC 密码。传统 VNC 仅使用前 8 个字符，不要复用 VPN 密码。

`EncryptPasswords` 为统一开关：`true` 使用 Windows 当前账户 DPAPI 加密（默认），
`false` 明文保存。JSON 布尔值不要加引号。修改开关后运行启动脚本会转换现有字段；
也可以用两个 `Use-*.cmd` 文件立即转换。脚本能够识别现有 DPAPI 密文，转换不改变实际密码。
加密配置应由原 Windows 账户读取；解密失败会停止，绝不静默覆盖密码。

```powershell
.\Start-ATrust.ps1 -StorageMode Plaintext -PrepareOnly
.\Start-ATrust.ps1 -StorageMode Encrypted -PrepareOnly
```

明文模式下可以直接编辑密码字段。配置文件会限制为当前 Windows 用户和 SYSTEM 可读，
但能读取该文件的人仍能看到明文。Docker 管理员可以读取容器环境里的凭据，DPAPI 不防护
这一环节。不要分享配置、Docker 导出、Cookie、会话数据或完整诊断日志。

## 这次修复解决了什么

### 输入框与页面状态不同步

某些门户的密码控件在 Selenium `clear()` 后没有同步内部表单状态，可能导致丢字或
错误提交。辅助程序使用全选、退格的实际键盘事件，再逐字符输入，并在点击登录前
检查两次输入值。任一不一致都会停止提交。隐藏的诱饵输入框不会被选择。

### 容器重建后恢复旧会话被注销

服务器可能将旧 Cookie 与新客户端身份的组合视为会话风险。本项目每次启动使用独立、
临时浏览器配置，不导入 Cookie 或 localStorage，完成完整的新认证。登录后定期刷新检查；
被注销或认证遭拒绝时停止辅助进程，保留 VNC 供用户检查，不循环消耗密码尝试次数。

### Clash 虚拟 DNS 地址与 VPN 网段冲突

部分环境的 DNS 虚拟地址与 VPN 隧道路由重叠，使网关连接绕回自己的隧道。仅在确有
冲突时，将 `GatewayAddress` 设置为自己通过可信渠道核实的 VPN 网关真实公网 IP。
脚本生成本地 `compose.gateway.yaml` 将配置的门户主机映射到该地址；该文件不会提交。
仓库不预置任何机构的网关 IP。网关地址变化时须更新配置。

## 验证与限制

容器运行、代理端口开放、Web 登录成功，分别是不同的检查。要确认 VPN 真正可用，
还需通过代理访问你有权限的内网服务，例如 SSH，并确认返回的是实际服务的响应。
本仓库包含无真实账户的输入控件、凭据切换和参数解析测试；原部署的修复方式曾在
真实环境验证，但新独立实现不承诺兼容所有门户、语言、认证布局或客户端版本。

验证码、短信、扫码、SSO/CAS 及设备审批可能需要通过 VNC 完成。当前程序针对标准
账号密码表单；不自动生成 TOTP、不绕过机构的认证或设备安全要求。人工登录页面
应先选择正确的认证方式，必要时使用手动模式。日志只报告阶段和异常类型，不主动输出密码。

已固定第三方镜像摘要以约束兼容范围。不要随意换版本；镜像内容与第三方许可均由上游负责。
项目不会发布包含第三方客户端或上游源码的 Docker 镜像。

## 测试

Python 测试：在已有 Selenium 环境执行 `python -m unittest discover -s tests -v`。
密码存储测试：`powershell -NoProfile -File tests/Test-CredentialStore.ps1`。
两个测试均使用合成数据，不需要真实 VPN 账号。浏览器集成测试见 `tests/browser_smoke.py`，
它使用合成网页，只验证输入、同意条款和单次提交，不连接 VPN。

## 许可与贡献

本仓库原创文件采用 MIT。上游 aTrustLogin 在核对的修订中未声明许可证，所以本项目
不以 MIT 重新发布其代码。依赖镜像、aTrust 客户端、noVNC 等不属于本仓库 MIT 授权范围。
请先阅读 [NOTICE.md](NOTICE.md)。欢迎提交不含真实凭据或机构数据的改进与复现案例。
