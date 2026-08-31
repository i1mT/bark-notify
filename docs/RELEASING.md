# BarkDesk 自动发布指南

正式版本由 [Release workflow](../.github/workflows/release.yml) 统一发布。版本 tag、macOS App 版本和 npm package 版本必须一致，并且只能使用 `vMAJOR.MINOR.PATCH` 格式，例如 `v1.0.0`。

## GitHub Actions Secrets

在 GitHub 仓库的 **Settings → Secrets and variables → Actions** 中配置以下 Repository secrets：

| Secret | 内容 |
| --- | --- |
| `APPLE_CERTIFICATE_BASE64` | 包含私钥的 `Developer ID Application` `.p12` 文件的 Base64 |
| `APPLE_CERTIFICATE_PASSWORD` | 导出 `.p12` 时设置的密码 |
| `APPLE_KEYCHAIN_PASSWORD` | GitHub runner 临时 Keychain 使用的随机密码 |
| `APPLE_API_KEY_BASE64` | App Store Connect team API key `.p8` 文件的 Base64 |
| `APPLE_API_KEY_ID` | App Store Connect API Key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect API Issuer ID |
| `NPM_TOKEN` | 第一次 npm 发布使用的 granular access token；配置 Trusted Publishing 后可以删除 |

workflow 不需要 Apple ID、Team ID 或本机 `BarkDesk-Notary` profile。所有临时证书、API Key 文件和 Keychain 都会在 GitHub runner 构建结束时删除。

如果本机已经使用 `gh auth login` 登录，可以通过 stdin 安全写入 Secrets：

```bash
base64 -i DeveloperID.p12 |
  gh secret set APPLE_CERTIFICATE_BASE64 --repo i1mT/bark-notify
printf '%s' "$APPLE_CERTIFICATE_PASSWORD" |
  gh secret set APPLE_CERTIFICATE_PASSWORD --repo i1mT/bark-notify
openssl rand -base64 32 |
  gh secret set APPLE_KEYCHAIN_PASSWORD --repo i1mT/bark-notify

base64 -i AuthKey_KEY_ID.p8 |
  gh secret set APPLE_API_KEY_BASE64 --repo i1mT/bark-notify
printf '%s' "$APPLE_API_KEY_ID" |
  gh secret set APPLE_API_KEY_ID --repo i1mT/bark-notify
printf '%s' "$APPLE_API_ISSUER_ID" |
  gh secret set APPLE_API_ISSUER_ID --repo i1mT/bark-notify

printf '%s' "$NPM_TOKEN" |
  gh secret set NPM_TOKEN --repo i1mT/bark-notify
```

其中密码、Key ID、Issuer ID 和 npm token 只存在于当前 shell 环境与 GitHub Secrets 中，不要把这些值写入 `.env`、脚本或仓库文件。

## 准备 Apple 凭据

### Developer ID Application 证书

在 Keychain Access 中找到 `Developer ID Application` 证书及其私钥，把两者一起导出为受密码保护的 `.p12`。随后执行：

```bash
base64 -i DeveloperID.p12 | pbcopy
```

把剪贴板内容保存为 `APPLE_CERTIFICATE_BASE64`，把导出密码保存为 `APPLE_CERTIFICATE_PASSWORD`。`APPLE_KEYCHAIN_PASSWORD` 可以使用密码管理器生成一个新的随机值，它不是你的 macOS 登录密码。

### App Store Connect API Key

在 App Store Connect 的 **Users and Access → Integrations** 创建 team API key，并且下载一次性的 `AuthKey_*.p8`。不要使用 individual API key，因为它不能用于 `notarytool`。随后执行：

```bash
base64 -i AuthKey_KEY_ID.p8 | pbcopy
```

把剪贴板内容保存为 `APPLE_API_KEY_BASE64`，并且分别保存 Key ID 与 Issuer ID。`.p8` 文件无法再次下载，应当保存在密码管理器或其他加密存储中。

## 准备 npm 发布认证

第一次发布时，在 npm 创建只允许发布 `barkdesk-notify` 的 granular access token，并且保存为 GitHub Secret `NPM_TOKEN`。

第一次发布成功后，推荐在 npm package 设置中配置 Trusted Publisher：

- Organization or user：`i1mT`
- Repository：`bark-notify`
- Workflow filename：`release.yml`
- Environment：留空
- Allowed action：`npm publish`

配置完成后删除 `NPM_TOKEN`。workflow 拥有 `id-token: write` 权限，并且使用 Node.js 24 与支持 OIDC 的 npm，因此后续发布不需要长期 npm token。

## 创建版本

先更新 npm package 版本：

```bash
npm --prefix cli version 1.0.1 --no-git-tag-version
npm --prefix cli test
git add cli/package.json cli/package-lock.json
git commit -m "chore: prepare v1.0.1"
git push origin main
```

确认 `main` 的 CI 通过后创建并推送 tag：

```bash
git tag -a v1.0.1 -m "BarkDesk v1.0.1"
git push origin v1.0.1
```

workflow 会拒绝格式不正确或者与 `cli/package.json` 不一致的 tag。成功后，GitHub Release 会包含：

```text
BarkDesk-1.0.1.dmg
barkdesk-notify-1.0.1.tgz
SHA256SUMS.txt
```

## 验证公开产物

```bash
gh release download v1.0.1 --repo i1mT/bark-notify --dir release-check
cd release-check
shasum -a 256 -c SHA256SUMS.txt
spctl --assess --type open --context context:primary-signature -v BarkDesk-1.0.1.dmg
gh attestation verify BarkDesk-1.0.1.dmg --repo i1mT/bark-notify
npm view barkdesk-notify@1.0.1 version
```

npm 已经发布的版本不能覆盖。如果 GitHub Release 创建失败，可以在修复 workflow 后重新运行同一次 Actions run；workflow 会跳过已经存在的 npm 版本，并且重新上传 Release assets。

如果失败原因需要修改 workflow，可以在修复并推送 `main` 后，针对已有 tag 手动启动恢复流程：

```bash
gh workflow run Release \
  --repo i1mT/bark-notify \
  --ref main \
  -f tag=v1.0.1
```

这个入口会先确认远端 tag 存在，并且再次检查 tag 版本与当前 `cli/package.json` 一致，因此不需要删除或强制移动已经推送的 tag。
