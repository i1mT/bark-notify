# BarkDesk 开源与发布检查表

## 第一次公开仓库之前

- [ ] 使用 `git status --ignored` 确认 `.env.local`、构建目录、证书与公证文件没有被跟踪。
- [ ] 搜索真实的 Apple ID、Team ID、API Key、Device Key、Bark Server 地址和 Basic Auth。
- [ ] 确认官网 GitHub 与下载链接指向 `https://github.com/i1mT/bark-notify`，并且只在 `website/.env.local` 配置实际站点域名。
- [ ] 确认 `LICENSE`、`PRIVACY.md`、贡献指南、行为准则和安全政策符合当前项目。
- [ ] 在 GitHub 开启 Private vulnerability reporting、分支保护和 Actions。
- [ ] 确认 CI 的 Swift、CLI 三系统矩阵与 Website Job 全部通过。

## 发布 npm CLI

1. 确认 `barkdesk-notify` 的版本号、README、package 文件列表以及 `repository`、`homepage` 和 `bugs` 地址。
2. 在 `cli` 目录执行：

```bash
npm ci
npm test
npm run typecheck
npm pack --dry-run
```

3. 正式版本通过 `release.yml` 发布；第一次发布使用 `NPM_TOKEN`，成功后配置 npm Trusted Publishing 并且删除长期 token。
4. 不要把 npm token 写入仓库、`.npmrc` 或 shell 脚本。
5. 在 Linux、macOS 和 Windows 分别确认 `npm install -g barkdesk-notify` 后可以执行 `notify --version`。

## 发布 GitHub Release

1. 按照 [自动发布指南](RELEASING.md) 配置 GitHub Actions Secrets。
2. 确认 `cli/package.json` 版本已经更新，并且 `main` 的 CI 通过。
3. 创建并推送对应的版本 tag：

```bash
git tag -a v1.0.0 -m "BarkDesk v1.0.0"
git push origin v1.0.0
```

4. 确认 workflow 发布 npm package，并且 GitHub Release 包含 universal DMG、npm tarball 和 `SHA256SUMS.txt`。
5. 下载公开附件，重新检查 SHA-256、Gatekeeper 和 GitHub attestation。

## 官网发布

官网使用 Next.js 静态导出，构建结果位于 `website/out`。部署环境只需要配置：

```text
NEXT_PUBLIC_SITE_URL
```

GitHub、Releases 与 npm 链接已经固定为本项目公开地址。每次发布后检查首页下载按钮是否能够打开最新 GitHub Release。
