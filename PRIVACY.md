# BarkDesk 隐私说明

BarkDesk macOS App 与 `barkdesk-notify` CLI 都在本机运行，不提供账号系统、分析服务或中间转发服务。

## 数据如何处理

- macOS App 的 Bark Server 地址、默认分组和通知偏好保存在本机配置文件中。
- macOS App 的 Device Key、Basic Auth 用户名和密码保存在 macOS Keychain 中。
- npm CLI 可以使用 `BARK_*` 环境变量、secret file 或权限受限的本机配置文件。
- macOS App 的发送历史保存在本机 SQLite；CLI 的历史独立保存在当前系统的 JSONL 文件中。
- 发送通知时，BarkDesk 只会把通知内容和你选择的参数发送到你配置的 Bark Server。
- 使用图片通知时，你提供的公开图片 URL 会传递给 Bark Server 和 Bark 客户端。BarkDesk 不会上传本地图片。

BarkDesk 不包含遥测、广告、崩溃上报或第三方分析 SDK。Apple Push Notification service 与你选择的 Bark Server 可能分别适用其自身的隐私政策。

## 删除本机数据

可以在 BarkDesk 中删除单条 App 发送历史。若要删除全部 App 数据，请退出 BarkDesk，然后删除以下内容：

```text
~/Library/Application Support/BarkDesk/
```

Keychain 中的 BarkDesk 凭据需要在“钥匙串访问”中单独删除。

CLI 可以通过 `notify config path` 查看配置位置，通过 `notify config show` 查看历史位置。删除这两个文件即可删除 CLI 的本机配置与历史；CLI 与 App 互不删除对方的数据。

## 安全问题

请不要在公开 Issue 中提交 Device Key、Bark Server 凭据或可复现的敏感请求。安全漏洞请按照 [SECURITY.md](.github/SECURITY.md) 中的方式报告。
