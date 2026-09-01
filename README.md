# BarkDesk

<img src="Assets/BarkDeskIcon.png" alt="BarkDesk 图标" width="88" height="88">

## 介绍

BarkDesk 是一套面向 [Bark](https://github.com/Finb/Bark) 的桌面与命令行工具：

- **BarkDesk for macOS**：使用原生 SwiftUI 编写，用于配置 Bark、发送不同类型的通知，并且查看本机发送历史。
- **`notify` CLI**：通过 npm 独立发布，可在 Linux、macOS 与 Windows 上使用，适合终端、服务器、脚本和 CI。

两者都会直接连接你自己的 Bark Server，不需要代理服务。它们分别保存配置与本机历史，因此 CLI 不需要安装 BarkDesk App，也不依赖 macOS。

[下载 BarkDesk](https://github.com/i1mT/bark-notify/releases/latest) · [安装 CLI](https://www.npmjs.com/package/barkdesk-notify) · [查看源码](https://github.com/i1mT/bark-notify)

### 开始前准备

BarkDesk 和 `notify` 是 Bark 的发送工具，不能替代 iPhone 上负责接收通知的 Bark App。第一次使用前，请按照这个顺序准备：

1. **安装 Bark iOS App**

   从 [App Store 下载 Bark](https://apps.apple.com/cn/app/bark-custom-notifications/id1403753865)，打开 App 并且允许通知权限。

2. **选择 Bark Server**

   - **不想部署：**直接使用 Bark App 默认的官方服务 `https://api.day.app`，不需要创建服务器。
   - **个人使用推荐：**部署 [`cwxiaos/bark-worker`](https://github.com/cwxiaos/bark-worker)。它是 Bark 官方部署文档列出的 Cloudflare Workers 实现，支持 D1 和 KV；推荐选择容量更高的 D1 版本，可以[一键部署到 Cloudflare Workers](https://deploy.workers.cloudflare.com/?url=https://github.com/cwxiaos/bark-worker)，也可以阅读[中文部署指南](https://github.com/cwxiaos/bark-worker/blob/master/doc/setup_guide.zh.md)。这个版本适合个人、低频通知，不适合高频或大规模推送；如果 `workers.dev` 在所在网络不可用，需要绑定自己的域名。
   - **使用自己的主机：**可以按照 [Bark 官方部署文档](https://bark.day.app/#/deploy) 通过 Docker 或可执行文件运行官方 `bark-server`。

3. **在 Bark iOS App 中完成设置**

   如果使用官方服务，Bark App 会直接生成测试推送地址。如果使用自建 Server，请先在 Bark App 中添加 Server 地址并完成设备注册。随后发送 App 内的测试通知，确认 iPhone 能够收到消息，再复制测试推送地址。地址通常类似：

   ```text
   https://api.day.app/YOUR_DEVICE_KEY/这里改成你自己的推送内容
   ```

   其中 `https://api.day.app` 是 Server 地址，`YOUR_DEVICE_KEY` 是需要填写到 BarkDesk 或 `notify config set` 的 Device Key。请把 Device Key 当作密码保存，不要提交到仓库或粘贴到公开页面。

## 如何使用

### BarkDesk for macOS

运行要求：macOS 14 或更高版本，并且已经完成上面的 Bark iOS App 与 Server 设置。

1. 从 [GitHub Releases](https://github.com/i1mT/bark-notify/releases/latest) 下载最新的 DMG。
2. 打开 DMG，把 BarkDesk 拖入 `Applications`。
3. 首次打开时，按照引导填写：
   - Bark Server 地址，例如 `https://bark.example.com`；
   - Device Key，也就是 Bark 推送地址中位于 Server 地址之后的那一段；
   - Basic Auth 用户名与密码，仅在你的 Server 启用了认证时填写。
4. 执行连接检查并发送测试通知，确认 Server、Device Key 与 iPhone 均可正常使用。

进入应用后，可以：

- 按照普通、图片、链接、重要警告、快捷复制或 Markdown 类型发送通知；
- 查看、搜索、复制、重新发送或删除本机发送记录；
- 设置默认分组、提醒方式、提示音和归档行为；
- 从“开发者接入”页面复制 Push URL、REST API 与调用示例。

Device Key 与 Basic Auth 凭据只保存在 macOS Keychain。Bark Server 没有历史查询 API，因此 BarkDesk 展示的是当前 Mac 上的发送记录，不是 iPhone 或 Server 的完整历史。

### `notify` CLI

CLI 需要 Node.js 20.9 或更高版本。首先全局安装：

```bash
npm install -g barkdesk-notify
```

安装后需要单独配置 Bark Server 与 Device Key：

```bash
notify config set \
  --server https://bark.example.com \
  --device DEVICE_KEY

notify config test
```

`notify config test` 会发送一条测试通知。测试成功后，可以直接使用简短命令：

```bash
notify "任务完成"
notify -t "Build" "构建完成"
echo "备份完成" | notify -t "Server"
```

查看当前配置与 CLI 自己的本机历史：

```bash
notify config show
notify history
notify history --search deploy --limit 50
```

在 Linux 服务器、容器或 CI 中，推荐使用环境变量，不把 Device Key 写入配置文件：

```bash
export BARK_SERVER=https://bark.example.com
export BARK_DEVICE_KEY=DEVICE_KEY
notify "部署完成"
```

CLI 还支持 Basic Auth、secret file 与更多 `BARK_*` 环境变量，完整说明请参阅 [`cli/README.md`](cli/README.md)。

如果希望 Coding Agent 在完成任务后自动发送通知，可以让 `notify` 扫描并配置本机支持的 Agent：

```bash
notify agent-hook install
```

目前支持 Codex、Claude Code、Grok Build、Cursor、Gemini CLI、OpenCode、GitHub Copilot CLI 和 DeepSeek Harness。交互界面可以使用空格选择 Agent；无人值守环境可以使用 `--all` 或 `--agents codex,claude`。完整的配置位置和事件说明请参阅 [`cli/README.md`](cli/README.md#coding-agent-完成通知)。

## 高级使用

### 发送不同类型的 Bark 通知

```bash
# 重要警告
notify "服务不可用" --level critical --volume 8

# 图片通知
notify "构建产物已经生成" \
  --image https://example.com/preview.png

# 点击通知后打开链接
notify "发布完成" \
  --url https://example.com/releases/42

# Markdown 内容
notify --markdown $'## Build\n\n**Success**'

# 快捷复制、分组与归档
notify "验证码已经生成" \
  --copy "123456" \
  --group automation \
  --archive
```

执行 `notify --help` 可以查看 `sound`、`badge`、`call`、`icon`、`ttl`、`no-action` 等完整参数。

### 等待命令结束后通知

在脚本或 CI 中，可以使用 `notify run`：

```bash
notify run pnpm build
notify run -g deploy -- ./deploy.sh --production
```

它会保留原命令的标准输入与输出，在命令结束后发送耗时和退出码，并且始终返回原命令的退出码。即使通知发送失败，也不会把原本失败的命令变成成功。

### 在 Zsh 中自动通知耗时命令

如果不想每次都写 `notify run`，可以通过 Zsh 的 `preexec` 与 `precmd` hooks 自动处理。你仍然像平时一样执行 `pnpm build`、`swift test` 或其他命令；只有运行时间超过阈值时，终端才会在后台发送完成或失败通知。

使用前请先完成 `notify config set` 和 `notify config test`。随后创建 `~/.zsh/auto-notify.zsh`：

```zsh
# ~/.zsh/auto-notify.zsh
autoload -Uz add-zsh-hook
zmodload zsh/datetime

typeset -gi AUTO_NOTIFY_THRESHOLD=${AUTO_NOTIFY_THRESHOLD:-30}
typeset -gi AUTO_NOTIFY_SHOW_COMMAND=${AUTO_NOTIFY_SHOW_COMMAND:-0}
typeset -g  AUTO_NOTIFY_STARTED_AT=0
typeset -g  AUTO_NOTIFY_COMMAND=""
typeset -g  AUTO_NOTIFY_DIRECTORY=""

_bark_auto_notify_preexec() {
  AUTO_NOTIFY_STARTED_AT=$EPOCHSECONDS
  AUTO_NOTIFY_COMMAND=$1
  AUTO_NOTIFY_DIRECTORY=$PWD
}

_bark_auto_notify_precmd() {
  local exit_code=$?
  local started_at=$AUTO_NOTIFY_STARTED_AT
  local command_text=$AUTO_NOTIFY_COMMAND
  local command_directory=$AUTO_NOTIFY_DIRECTORY

  AUTO_NOTIFY_STARTED_AT=0
  AUTO_NOTIFY_COMMAND=""
  AUTO_NOTIFY_DIRECTORY=""

  (( started_at > 0 )) || return 0

  local elapsed=$(( EPOCHSECONDS - started_at ))
  (( elapsed >= AUTO_NOTIFY_THRESHOLD )) || return 0
  [[ -n $command_text ]] || return 0

  local normalized=${command_text#"${command_text%%[![:space:]]*}"}
  [[ $normalized == notify || $normalized == notify\ * ]] && return 0

  local title="终端任务完成"
  (( exit_code == 0 )) || title="终端任务失败（exit ${exit_code}）"

  local directory_name=${command_directory:t}
  [[ -n $directory_name ]] || directory_name=$command_directory

  local body="目录：${directory_name}"$'\n'"耗时：${elapsed} 秒"
  if (( AUTO_NOTIFY_SHOW_COMMAND )); then
    body="${command_text}"$'\n'"${body}"
  fi

  command notify -t "$title" -g terminal "$body" >/dev/null 2>&1 &!
  return 0
}

# 重复加载 ~/.zshrc 时，避免重复注册 hooks。
add-zsh-hook -d preexec _bark_auto_notify_preexec 2>/dev/null
add-zsh-hook -d precmd _bark_auto_notify_precmd 2>/dev/null
add-zsh-hook preexec _bark_auto_notify_preexec
add-zsh-hook precmd _bark_auto_notify_precmd
```

然后在 `~/.zshrc` 中加入：

```zsh
# 运行超过 30 秒才通知。
AUTO_NOTIFY_THRESHOLD=30

# 默认不发送完整命令，避免把命令中的 token 或密码带入通知。
# 确认命令不含敏感内容后，可以改成 1。
AUTO_NOTIFY_SHOW_COMMAND=0

source ~/.zsh/auto-notify.zsh
```

重新载入配置并测试：

```bash
source ~/.zshrc
sleep 35
```

这个方案适合 Zsh 交互终端中的前台命令。脚本、CI 或后台任务仍然推荐使用 `notify run`，因为它能够明确保留目标命令的退出码与执行边界。

## 其他

- [CLI 完整文档](cli/README.md)：配置文件、环境变量、secret file、参数与独立发布说明。
- [参与贡献](.github/CONTRIBUTING.md)：Xcode、Swift、CLI 与官网的本机开发方式和测试命令。
- [版本发布](docs/RELEASING.md)：DMG 构建、Developer ID 签名、Apple 公证、npm 与 GitHub Release。
- [开源检查表](docs/OPEN_SOURCE_CHECKLIST.md)：公开仓库之前需要检查的敏感信息与发布事项。
- [安全政策](.github/SECURITY.md) · [隐私说明](PRIVACY.md) · [社区行为准则](.github/CODE_OF_CONDUCT.md) · [MIT License](LICENSE)

BarkDesk 是第三方开源客户端，与 Bark 官方项目没有隶属关系。Bark 名称及其相关标识归各自权利人所有。
