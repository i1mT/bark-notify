# BarkDesk 项目约定

## 架构

- `BarkCore` 是 macOS App 的业务实现入口；SwiftUI View 不得重复实现网络、配置、Keychain、历史记录或 Bark 参数编码。
- `cli` 是独立发布的 Node.js package，不得依赖 Swift、macOS App bundle、Keychain 或 Apple 专属框架，并且必须支持 Linux、macOS 与 Windows。
- macOS App 与 npm CLI 分别管理配置和本机历史，不得假设两者安装在同一台设备上。
- BarkDesk 只调用现有 Bark Server，不实现推送接收、代理服务、服务器历史同步或新的后端。
- Xcode 开发必须打开 `BarkDesk.xcodeproj` 并运行 `BarkDesk` scheme，确保 GUI 使用真正的 macOS App target；不得把 Swift Package 的裸可执行目标当作 GUI App 运行。
- 本地 Debug App 必须显示为 `BarkDesk Dev`，并且使用独立的 bundle identifier、Application Support 目录和 Keychain service，避免与已经安装的正式版冲突；Release App 继续使用 `BarkDesk`。
- BarkDesk UI 使用 Dropbox 官方配色体系，以 Dropbox Blue、Coconut、Graphite、Cloud、Navy 与官方暖灰阶为基础；布局调整不得擅自更换主题方向。
- Swift 动态代码文件应当尽量少于 400 行，每层目录应当尽量不超过 8 个文件。

## 行为

- 所有发送尝试都需要写入本地历史，包括 Bark Server 返回失败和网络失败的情况。
- macOS App 默认进入通知记录；记录列表应当优先展示发送时间，选中记录后需要显示完整详情。
- macOS App 保留具有产品视觉的侧边栏；连接与设置入口固定在侧边栏底部，并且只展示掩码后的 Device Key。
- `notify run` 必须返回被执行命令原本的退出码；通知发送失败不得覆盖命令退出码。
- macOS App 的 Device Key、Basic Auth 用户名和密码必须存储在 macOS Keychain，不得写入普通配置文件。
- npm CLI 在服务器环境中应当优先支持 `BARK_*` 环境变量和 secret file；写入本机配置时必须限制文件权限。
- 新增 Bark 参数时，应当先在 `BarkPushRequest` 中实现，再由 GUI 或 CLI 调用。

## 验证与 Git

- 修改代码后至少执行 `swift test` 和 `swift build`；修改 npm CLI 后还必须执行 `npm --prefix cli test`、`npm --prefix cli run typecheck` 和 `npm --prefix cli pack --dry-run`。
- 修复输入、焦点或键盘交互问题时，必须使用真实键盘事件验证绑定值或者界面文本确实发生变化；只看到光标或焦点边框不算验证通过。
- 修改多栏界面后，必须使用窗口允许的最小宽度检查侧边栏选中背景、长文本和操作按钮，确保任何内容都不会超出窗口边界。
- 面向其他用户分发 macOS App 时，必须使用 `Developer ID Application` 签名、`notarytool` 公证和 `stapler` 附加票据；ad-hoc 签名的 DMG 仅用于本机或内部测试。
- 每次完成代码修改后都需要创建 Git commit，并在提交信息中说明主要改动。

## 开源与发布安全

- 公开仓库不得包含真实的 Apple ID、Team ID、App Store Connect API Key、Device Key、Bark Server 地址、Basic Auth、签名证书或公证凭据。
- 项目的公开仓库地址固定为 `https://github.com/i1mT/bark-notify`，官网的 GitHub 与 DMG 下载链接直接使用该地址；只有实际站点域名使用 `NEXT_PUBLIC_SITE_URL` 配置。
- 签名、公证和发布使用的凭据只允许保存在 macOS Keychain、GitHub Actions Secrets 或本机未跟踪文件中。
- 正式版本必须通过 `vMAJOR.MINOR.PATCH` tag 触发 GitHub Release，并且同时发布经过签名、公证的 universal DMG、npm CLI package、SHA-256 校验文件与 provenance attestation。

## 对外文档

- README 与官网必须明确说明前置要求：安装 Bark iOS App、选择官方或自建 Bark Server、在 iOS App 中完成 Server 设置与设备注册，并且先通过测试通知确认接收成功。
- Server 说明必须同时提供无需部署的 Bark 官方服务和可信的自建方案；推荐 Cloudflare Workers 等第三方实现时，需要链接其源码与部署文档，并且说明适用范围。
- 对外说明不得暗示 BarkDesk 或 `notify` 可以替代 Bark iOS App，也不得把 Device Key 描述成可以公开分享的信息。
