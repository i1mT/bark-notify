# BarkDesk 项目约定

## 架构

- `BarkCore` 是 GUI 与 CLI 唯一的业务实现入口；网络、配置、Keychain、历史记录以及 Bark 参数编码不得在两个可执行目标中重复实现。
- GUI 与 CLI 必须通过 `SharedStorage` 使用同一份本地配置和 SQLite 历史。
- BarkDesk 只调用现有 Bark Server，不实现推送接收、代理服务、服务器历史同步或新的后端。
- Xcode 开发必须打开 `BarkDesk.xcodeproj` 并运行 `BarkDesk` scheme，确保 GUI 使用真正的 macOS App target；不得把 Swift Package 的裸可执行目标当作 GUI App 运行。
- Swift 动态代码文件应当尽量少于 400 行，每层目录应当尽量不超过 8 个文件。

## 行为

- 所有发送尝试都需要写入本地历史，包括 Bark Server 返回失败和网络失败的情况。
- `notify run` 必须返回被执行命令原本的退出码；通知发送失败不得覆盖命令退出码。
- Device Key、Basic Auth 用户名和密码必须存储在 macOS Keychain，不得写入普通配置文件。
- 新增 Bark 参数时，应当先在 `BarkPushRequest` 中实现，再由 GUI 或 CLI 调用。

## 验证与 Git

- 修改代码后至少执行 `swift test` 和 `swift build`。
- 修复输入、焦点或键盘交互问题时，必须使用真实键盘事件验证绑定值或者界面文本确实发生变化；只看到光标或焦点边框不算验证通过。
- 修改多栏界面后，必须使用窗口允许的最小宽度检查侧边栏选中背景、长文本和操作按钮，确保任何内容都不会超出窗口边界。
- 每次完成代码修改后都需要创建 Git commit，并在提交信息中说明主要改动。
