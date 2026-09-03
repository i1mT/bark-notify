# barkdesk-notify

`barkdesk-notify` 是独立、跨平台的 Bark CLI。它通过 npm 发布，可在 Linux、macOS 和 Windows 上运行；安装后提供简短的 `notify` 命令。

该 package 只连接你配置的 Bark Server，不需要安装 BarkDesk macOS App。

## 安装

需要 Node.js 20.9 或更高版本：

```bash
npm install -g barkdesk-notify
notify --version
```

不全局安装也可以直接运行：

```bash
npx barkdesk-notify "任务完成"
```

## 配置

个人电脑可以写入本机配置文件：

```bash
notify config set \
  --server https://bark.example.com \
  --device DEVICE_KEY

notify config test
notify config show
```

配置文件会使用仅限当前用户读取的权限。执行 `notify config path` 可以查看实际位置。

Linux 服务器、容器和 CI 推荐使用环境变量，不需要在磁盘中保存 Device Key：

```bash
export BARK_SERVER=https://bark.example.com
export BARK_DEVICE_KEY=DEVICE_KEY
notify "部署完成"
```

支持的变量：

- `BARK_SERVER`
- `BARK_DEVICE_KEY` 或 `BARK_DEVICE_KEY_FILE`
- `BARK_USERNAME`
- `BARK_PASSWORD` 或 `BARK_PASSWORD_FILE`
- `BARK_GROUP`、`BARK_LEVEL`、`BARK_SOUND`、`BARK_ARCHIVE`
- `BARKDESK_CONFIG` 和 `BARKDESK_HISTORY`，用于修改默认文件位置

Basic Auth 密码也可以通过 stdin 保存，避免直接出现在 shell 历史中：

```bash
printf '%s' "$BARK_PASSWORD" | \
  notify config set --username USER --password-stdin
```

## 使用

```bash
notify "任务执行完成"
notify -t "Build" "构建完成"
echo "备份完成" | notify -t "Server"

notify "服务不可用" --level critical --volume 8
notify "查看产物" --image https://example.com/result.png
notify "发布完成" --url https://example.com/releases/42
notify --markdown $'## Build\n\n**Success**'
```

等待命令结束后发送通知：

```bash
notify run pnpm build
notify run -g deploy -- ./deploy.sh --production
```

`notify run` 始终返回原命令的退出码。Bark 发送失败只会输出警告，不会把失败命令改成成功。

查看本机历史：

```bash
notify history
notify history --search deploy --limit 50
```

在同一台 Mac 上，CLI 与 BarkDesk 通过本机历史文件互通记录；CLI、Coding Agent hook 和 BarkDesk 发送的通知可以从两边查看。Linux 与 Windows 继续独立保存 CLI 历史，历史记录不会跨设备同步。

## Coding Agent 完成通知

`notify` 可以扫描本机已经安装的 Coding Agent，并且把完成 hook 配置到各自的用户级配置中：

```bash
notify agent-hook install
```

交互界面使用方向键移动、空格选择、Enter 确认。自动化环境可以跳过交互：

```bash
notify agent-hook install --all
notify agent-hook install --agents codex,claude,opencode
notify agent-hook install --all --dry-run
```

当前支持：

| Agent | 事件 | 用户级配置 |
| --- | --- | --- |
| Codex | `Stop` | `~/.codex/hooks.json` |
| Claude Code | `Stop` | `~/.claude/settings.json` |
| Grok Build | `Stop`（只处理 `end_turn`） | `~/.grok/hooks/barkdesk-notify.json` |
| Cursor | `stop` | `~/.cursor/hooks.json` |
| Gemini CLI | `AfterAgent` | `~/.gemini/settings.json` |
| OpenCode | `session.idle` plugin event | `~/.config/opencode/plugins/barkdesk-notify.js` |
| GitHub Copilot CLI | `agentStop` | `~/.copilot/hooks/barkdesk-notify.json` |
| DeepSeek Harness | 原生 `agent/turn-stopping` plugin | `$DSH_HOME`（默认 `~/.dsh`）中的 profile |

安装器不会替换原有 hook；再次执行会识别已经添加的配置。OpenCode 和独立 hook 文件由 `notify` 管理；如果同名 OpenCode plugin 不是由 `notify` 创建，安装器会拒绝覆盖。DeepSeek Harness 使用 `notify` 生成的无第三方 dependency 原生 plugin，不会修改 profile 的 npm dependencies；安装后会通过 DSH CLI 验证 plugin tree，验证失败会自动恢复原 patch。

各家 hook 输入最终会转换成统一的 Bark 通知：标题包含 Agent 名称、项目目录和完成状态，正文优先使用 Agent 提供的最后一条回复。部分 Agent 的完成事件不提供回复内容，此时正文会使用状态和目录说明。发送失败只会写入 stderr，hook 始终返回成功，避免通知服务影响 Coding Agent 结束会话。

## 自动发布 package

正式版本由仓库根目录的 GitHub Actions Release workflow 发布。先更新 `cli/package.json` 的版本并且提交，然后创建完全一致的版本 tag：

```bash
git tag v1.0.0
git push origin main v1.0.0
```

workflow 会执行测试、生成 npm tarball、发布到 npm，并且把 tarball 与 macOS DMG 一起添加到对应的 GitHub Release。npm Trusted Publishing 是推荐方式；第一次发布也可以临时配置 `NPM_TOKEN` repository secret。

GitHub Release 中的 tarball 也可以直接安装，不经过 npm Registry：

```bash
npm install -g \
  https://github.com/i1mT/bark-notify/releases/download/v1.0.0/barkdesk-notify-1.0.0.tgz
```

手动发布仅用于维护或故障恢复。发布前需要确认 npm 账号、package 名称和版本，然后执行：

```bash
npm ci
npm test
npm pack --dry-run
npm login
npm publish
```

不要把 npm token、Device Key、Bark Server 凭据或个人配置文件提交到仓库。

项目采用 MIT License。BarkDesk 是第三方开源项目，与 Bark 官方项目没有隶属关系。
