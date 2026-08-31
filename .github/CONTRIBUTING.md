# 参与贡献

感谢你改进 BarkDesk。开始开发前，请先阅读根目录的 `AGENTS.md` 和本文件。

## 本机开发

macOS App 与 CLI：

```bash
swift test
swift build
open BarkDesk.xcodeproj
```

官网：

```bash
cd website
cp .env.example .env.local
npm install
npm run dev
```

## 架构约束

- GUI 与 CLI 的业务能力需要在 `BarkCore` 中实现，避免重复网络、配置和存储逻辑。
- Device Key 与 Basic Auth 必须保存在 Keychain 中。
- 所有发送尝试都需要写入本机历史。
- 官网保持静态导出能力，不得依赖仅能在常驻 Node.js Server 中运行的功能。

## 提交 Pull Request

1. 从最新的 `main` 创建功能分支。
2. 保持改动范围清晰，并为行为变化增加测试。
3. 提交前运行：

```bash
swift test
swift build
npm --prefix website ci
npm --prefix website run lint
npm --prefix website run typecheck
npm --prefix website run build
```

4. 在 Pull Request 中说明用户可见变化、验证方式和界面截图。
5. 不要提交 Device Key、服务器凭据、Apple 开发者信息、证书或 `.env.local`。
