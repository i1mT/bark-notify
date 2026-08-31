# BarkDesk

BarkDesk 包含两个独立产品：使用 SwiftUI 编写的 macOS 原生 Bark 控制中心，以及通过 npm 发布的跨平台 `notify` CLI。两者都直接连接现有 Bark Server，不需要部署代理服务，也不会修改 Bark Server。

[GitHub](https://github.com/i1mT/bark-notify) · [Releases](https://github.com/i1mT/bark-notify/releases/latest) · [npm](https://www.npmjs.com/package/barkdesk-notify)

![BarkDesk 应用图标](Assets/BarkDeskIcon.png)

## 快速开始

macOS 用户可以从 GitHub Releases 下载经过 Developer ID 签名和 Apple 公证的 DMG，把 `BarkDesk` 拖入 `Applications` 后打开。首次运行会引导填写 Bark Server 地址与 Device Key。

Linux、macOS 和 Windows 用户可以独立安装 CLI：

```bash
npm install -g barkdesk-notify
notify "任务完成"
```

从源码运行时，请打开 `BarkDesk.xcodeproj`，选择 `BarkDesk` scheme，然后按下 Run。

主要能力：

- 使用 macOS 原生界面配置 Bark Server、Device Key 和 Basic Auth。
- 从 GUI 发送通知，并且支持 Bark 的常用与高级参数。
- 使用独立 npm package 在 Linux、macOS 或 Windows 执行 `notify "完成"`、stdin 或 `notify run command`。
- macOS App 与 CLI 分别记录自己的本机发送历史，包括失败记录。
- 在 Integrations 页面复制 REST、兼容 Push URL、MCP URL 和调用示例。
- 提供菜单栏入口，可以快速打开发送页面和历史记录。

> Bark Server 没有历史查询 API。macOS App 与 CLI 的历史都是各自设备上的本机记录，不会互相同步。

## 系统要求

- macOS App：macOS 14 或更高版本；源码构建需要 Xcode 16 或对应的 Swift toolchain
- npm CLI：Node.js 20.9 或更高版本，支持 Linux、macOS 和 Windows
- 已经运行并且可以访问的 Bark Server
- 已经由 iPhone Bark App 注册的 Device Key

macOS App 仅依赖 Apple 系统框架与系统 SQLite，不需要下载第三方 Swift package。CLI 使用 Node.js 内置 API，发布产物没有第三方 runtime dependency。

## 构建与安装

### 使用 Xcode 运行

请打开仓库根目录的 `BarkDesk.xcodeproj`，选择 `BarkDesk` scheme，然后按下 Run。这个 scheme 只构建并运行真正的 macOS `BarkDesk.app`；跨平台 CLI 位于 `cli` 目录，不属于 Xcode 工程或 App bundle。

不要把 `Package.swift` 作为工程打开后直接运行 Swift Package 中的 `BarkDesk` executable；那个产物是裸命令行可执行文件，不是 macOS App bundle，不能用于 GUI 调试。

修改 `Xcode/project.yml` 后，可以重新生成工程：

```bash
make xcode-project
```

这一步需要本机安装 `xcodegen`；普通开发不需要重复生成，仓库已经包含生成好的 `BarkDesk.xcodeproj`。

### 使用命令行构建

开发构建和测试：

```bash
swift build
swift test
```

构建可直接打开的应用包：

```bash
make app
open build/BarkDesk.app
```

安装到当前用户目录：

```bash
make install
```

默认安装位置：

```text
~/Applications/BarkDesk.app
```

也可以在安装时修改路径：

```bash
APP_INSTALL_DIR=/Applications \
make install
```

### 制作可以分享的 DMG

在本机生成用于测试的 DMG：

```bash
make dmg
```

生成结果位于 `build/BarkDesk-1.0.0.dmg`。打开后，把 `BarkDesk` 拖入 `Applications` 即可安装。也可以指定版本号：

```bash
make dmg VERSION=1.1.0
```

这个默认产物使用 ad-hoc 签名，适合你自己的 Mac 或受信任的小范围测试。要把 DMG 正式发给其他用户，并且避免 Gatekeeper 显示“无法验证开发者”，需要加入 Apple Developer Program、安装 `Developer ID Application` 证书，并且先把公证凭据保存到 Keychain。推荐使用 App Store Connect API Key：

```bash
xcrun notarytool store-credentials "BarkDesk-Notary" \
  --key "/path/to/AuthKey_KEY_ID.p8" \
  --key-id "KEY_ID" \
  --issuer "ISSUER_ID"
```

也可以只运行 `xcrun notarytool store-credentials "BarkDesk-Notary"`，根据交互提示使用 Apple ID 与 App 专用密码。不要把密码、API Key 或 `.p8` 文件提交到仓库，也不要把密码直接写入 shell 命令历史。

随后执行签名、公证和 stapling：

```bash
make release-dmg VERSION=1.0.0
```

`release-dmg` 会自动选择 Keychain 中的 `Developer ID Application` 证书，并使用 `BarkDesk-Notary` 公证 profile。脚本会构建并签署 App、创建并签署 DMG、等待 Apple 公证、附加公证票据，并且挂载 DMG 检查 App 是否完整。证书和公证凭据只保存在 macOS Keychain，不会写入仓库。

### 使用 GitHub Release 正式发布

仓库包含 `.github/workflows/release.yml`。推送 `vMAJOR.MINOR.PATCH` tag 后，GitHub Actions 会自动完成以下工作：

- 构建同时支持 Apple Silicon 与 Intel Mac 的 universal DMG。
- 使用 Developer ID 签名、Apple 公证并且附加公证票据。
- 测试并打包 CLI，然后发布 `barkdesk-notify` 到 npm。
- 生成 `SHA256SUMS.txt` 和 GitHub provenance attestation。
- 创建 GitHub Release，并且上传 DMG、npm tarball 与校验文件。

需要在 GitHub 仓库中配置 Apple 与 npm Secrets。完整名称、生成方式和发布命令请参阅 [自动发布指南](docs/RELEASING.md)。

CLI tarball 也可以从 GitHub Release 直接安装，例如：

```bash
npm install -g \
  https://github.com/i1mT/bark-notify/releases/download/v1.0.0/barkdesk-notify-1.0.0.tgz
```

发布前的完整检查步骤请参阅 [开源与发布检查表](docs/OPEN_SOURCE_CHECKLIST.md)。

## 首次配置

第一次打开 BarkDesk 时，应用会自动显示三步配置引导，不需要先寻找设置页面：

1. Bark Server Base URL，例如 `https://bark.example.com` 或带 URL Prefix 的 `https://example.com/bark`。
2. iPhone Bark App 已经注册的 Device Key。
3. 如果服务器启用了 Basic Auth，请填写用户名和密码。
4. 选择默认分组、提醒方式、提示音与归档行为。
5. 使用“检查连接”和“发送测试通知”验证完整链路。

Device Key、Basic Auth 用户名和密码保存在 macOS Keychain。普通默认设置保存在：

```text
~/Library/Application Support/BarkDesk/configuration.json
```

CLI 需要通过 npm 单独安装，并且拥有自己的跨平台配置：

```bash
notify config set \
  --server https://bark.example.com \
  --device DEVICE_KEY \
  --group terminal \
  --level active \
  --archive

notify config show
notify config test
```

Linux 服务器、容器和 CI 推荐使用环境变量：

```bash
export BARK_SERVER=https://bark.example.com
export BARK_DEVICE_KEY=DEVICE_KEY
notify "部署完成"
```

CLI 还支持 `BARK_DEVICE_KEY_FILE`、`BARK_PASSWORD_FILE` 等 secret file。完整配置方式请参阅 [CLI README](cli/README.md)。

## CLI 用法

安装或升级：

```bash
npm install -g barkdesk-notify
```

最短用法：

```bash
notify "任务执行完成"
notify -t "Codex" "任务执行完成"
echo "Deploy finished" | notify -t "Server"
```

常用参数：

```bash
notify \
  -t "Deploy" \
  -s "Production" \
  -m "发布完成" \
  -g deploy \
  --level timeSensitive \
  --sound minuet \
  --url https://example.com/releases/42
```

Bark 高级类型：

```bash
# 重要警告，音量范围为 0 到 10
notify "服务不可用" --level critical --volume 8

# 重复铃声 30 秒
notify "请立即处理" --call

# 图片、图标、badge 与复制动作
notify "构建产物已经生成" \
  --image https://example.com/preview.png \
  --icon https://example.com/icon.png \
  --badge 3 \
  --copy "artifact-42"

# Bark 内归档，并且设置保留时间
notify "临时记录" --archive --ttl 3600

# Markdown 内容（需要较新的 Bark 与 Bark Server）
notify --markdown $'## Build\n\n**Success**'

# 点击通知时不执行动作
notify "仅供查看" --no-action
```

运行命令并在结束后提醒：

```bash
notify run pnpm build
notify run -g deploy --level timeSensitive -- ./deploy.sh --production
```

`notify run` 会继承命令的标准输入、标准输出和标准错误，等待命令结束，然后发送包含命令、耗时与退出码的通知。最终返回值始终是原命令的退出码；即使 Bark 发送失败，也不会将失败命令误报为成功。

查看 CLI 自己的本机历史：

```bash
notify history
notify history --search deploy --limit 50
```

完整参数说明：

```bash
notify --help
```

CLI 的完整开发、配置、环境变量和发布说明位于 [cli/README.md](cli/README.md)。

## GUI 页面

- 通知记录：按照今天、昨天、更早分组，支持搜索、复制、重新发送、打开链接和删除，并且为首次使用与无搜索结果提供明确引导。
- 发送通知：先选择普通通知、图片通知、链接通知、重要警告、快捷复制或 Markdown，再根据类型只显示必要字段；分组、提醒方式、提示音与归档位于可展开的发送选项中。
- 设置：实时校验 Server 地址、Device Key 与 Basic Auth，保存默认设置，并执行 ping、healthz、info、Device Key 检查和完整测试通知。
- 开发者接入：生成 Push URL、REST API、Bark Server MCP URL、curl、Shell 和 Claude Code 示例。

图片通知使用 Bark 官方的 `image` URL 参数。官方 Bark Server 没有文件上传接口，因此 GUI 会校验、预览并发送可以公开访问的图片链接，不会发送 iPhone 无法访问的 Mac 本地文件路径。

## 数据与架构

```text
BarkDesk macOS App ─ BarkCore ─┐
  ├─ macOS Keychain            ├─ HTTP ─ Bark Server ─ APNs ─ iPhone
  └─ App SQLite history        │
                               │
notify npm CLI ─ Node.js ──────┘
  ├─ BARK_* / private config
  └─ cross-platform JSONL history
```

`BarkCore` 统一实现 macOS App 的 API、参数编码、配置、Keychain、SQLite 和发送历史。`cli` 是独立 Node.js package，不导入 Swift 模块，也不依赖 macOS App、Keychain 或 Apple 专属框架。

## Bark 支持范围

发送统一使用官方 API V2 的 `POST /push`。当前实现支持 `title`、`subtitle`、`body`、`markdown`、`level`、`volume`、`badge`、`call`、`autoCopy`、`copy`、`sound`、`icon`、`image`、`group`、`isArchive`、`ttl`、`url`、`action` 和 `id`。

连接检查使用 `/ping`、`/healthz`、`/info` 和 `/register/:device_key`。其中部分辅助接口可能由于 Bark Server 版本差异而不可用，因此 GUI 会分别显示每项结果；发送测试通知仍然是验证 Server、认证、Device Key、APNs 与 iPhone 全链路的最终方式。

## 当前不包含的能力

BarkDesk 不注册 macOS APNs，不接收 iPhone 通知，不提供新 Server、代理、账号、云同步、定时任务，也不会尝试调用不存在的 Bark Server 历史接口。

## 项目官网

官网是位于 `website` 目录中的独立 Next.js 项目，使用静态导出，因此可以部署到 Cloudflare Pages、Vercel 或任何以域名根目录提供文件的静态托管服务。

```bash
cd website
cp .env.example .env.local
npm install
npm run dev
```

发布构建：

```bash
npm run lint
npm run typecheck
npm run build
```

静态文件会生成到 `website/out`。GitHub、Releases 与 npm 地址已经使用本项目的公开地址，不需要环境变量。公开部署时只需要配置实际站点域名：

```text
NEXT_PUBLIC_SITE_URL=https://你的官网地址
```

这些值只包含公开链接。Apple 开发者凭据、Device Key 和 Bark Server 凭据不属于官网环境变量。

## 参与开源项目

- 贡献代码前请阅读 [参与贡献](.github/CONTRIBUTING.md) 与 [社区行为准则](.github/CODE_OF_CONDUCT.md)。
- 安全漏洞请使用 GitHub Private vulnerability reporting，并且遵循 [安全政策](.github/SECURITY.md)。
- 数据处理方式请参阅 [隐私说明](PRIVACY.md)。
- 项目采用 [MIT License](LICENSE)。

BarkDesk 是第三方开源客户端，与 Bark 官方项目没有隶属关系。Bark 名称及其相关标识归各自权利人所有。
