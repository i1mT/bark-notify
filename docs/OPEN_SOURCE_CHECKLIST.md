# BarkDesk 开源与发布检查表

## 第一次公开仓库之前

- [ ] 使用 `git status --ignored` 确认 `.env.local`、构建目录、证书与公证文件没有被跟踪。
- [ ] 搜索真实的 Apple ID、Team ID、API Key、Device Key、Bark Server 地址和 Basic Auth。
- [ ] 在 `website/.env.local` 中配置 GitHub、下载和站点地址，并且确认该文件不会提交。
- [ ] 确认 `LICENSE`、`PRIVACY.md`、贡献指南、行为准则和安全政策符合当前项目。
- [ ] 在 GitHub 开启 Private vulnerability reporting、分支保护和 Actions。
- [ ] 确认 CI 的 Swift、CLI 三系统矩阵与 Website Job 全部通过。

## 发布 npm CLI

1. 确认 `barkdesk-notify` 的版本号、README 和 package 文件列表；GitHub 仓库公开后，在 `cli/package.json` 中补充真实的 `repository`、`homepage` 和 `bugs` 地址。
2. 在 `cli` 目录执行：

```bash
npm ci
npm test
npm run typecheck
npm pack --dry-run
```

3. 使用 npm 账号登录后执行 `npm publish`。
4. 不要把 npm token 写入仓库、`.npmrc` 或 shell 脚本；CI 发布时应当使用 npm trusted publishing 或仓库 Secret。
5. 在 Linux、macOS 和 Windows 分别确认 `npm install -g barkdesk-notify` 后可以执行 `notify --version`。

## 发布签名 DMG

1. 确认 `Developer ID Application` 证书和 `BarkDesk-Notary` profile 位于本机 Keychain。
2. 构建、公证并验证：

```bash
make release-dmg VERSION=1.0.0
shasum -a 256 build/BarkDesk-1.0.0.dmg
spctl --assess --type open --context context:primary-signature -v build/BarkDesk-1.0.0.dmg
```

3. 创建对应版本的 Git tag 与 GitHub Release。
4. 上传 DMG，并且在 Release Notes 中提供 SHA-256、最低 macOS 版本和主要变化。
5. 下载一次公开附件，重新检查校验值与 Gatekeeper 结果。

## 官网发布

官网使用 Next.js 静态导出，构建结果位于 `website/out`。部署环境需要配置：

```text
NEXT_PUBLIC_SITE_URL
NEXT_PUBLIC_GITHUB_URL
NEXT_PUBLIC_DOWNLOAD_URL
NEXT_PUBLIC_NPM_URL
```

`NEXT_PUBLIC_DOWNLOAD_URL` 建议指向 GitHub Releases 的 latest 地址。每次发布 DMG 后检查首页下载按钮是否能够直接打开最新版本。
