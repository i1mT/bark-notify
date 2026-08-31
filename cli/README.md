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

查看 CLI 自己的本机历史：

```bash
notify history
notify history --search deploy --limit 50
```

CLI 历史与 BarkDesk macOS App 历史相互独立，不会跨设备或跨系统同步。

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
