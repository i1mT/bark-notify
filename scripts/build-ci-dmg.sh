#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
TEMP_DIR="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/BarkDesk-signing.XXXXXX")"
KEYCHAIN_PATH="${TEMP_DIR}/build.keychain-db"
CERTIFICATE_PATH="${TEMP_DIR}/DeveloperID.p12"
API_KEY_PATH="${TEMP_DIR}/AuthKey.p8"
ORIGINAL_KEYCHAINS=("${(@f)$(security list-keychains -d user | sed -E 's/^[[:space:]]*"(.*)"$/\1/')}")

require_env() {
  local name="$1"
  if [[ -z "${(P)name:-}" ]]; then
    echo "缺少必需的 GitHub Actions Secret：${name}" >&2
    exit 1
  fi
}

cleanup() {
  if (( ${#ORIGINAL_KEYCHAINS[@]} > 0 )); then
    security list-keychains -d user -s "${ORIGINAL_KEYCHAINS[@]}" >/dev/null 2>&1 || true
  fi
  security delete-keychain "${KEYCHAIN_PATH}" >/dev/null 2>&1 || true
  rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

for name in \
  APPLE_CERTIFICATE_BASE64 \
  APPLE_CERTIFICATE_PASSWORD \
  APPLE_KEYCHAIN_PASSWORD \
  APPLE_API_KEY_BASE64 \
  APPLE_API_KEY_ID \
  APPLE_API_ISSUER_ID; do
  require_env "${name}"
done

print -rn -- "${APPLE_CERTIFICATE_BASE64}" | base64 --decode > "${CERTIFICATE_PATH}"
print -rn -- "${APPLE_API_KEY_BASE64}" | base64 --decode > "${API_KEY_PATH}"
chmod 600 "${CERTIFICATE_PATH}" "${API_KEY_PATH}"

security create-keychain -p "${APPLE_KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
security set-keychain-settings -lut 21600 "${KEYCHAIN_PATH}"
security unlock-keychain -p "${APPLE_KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
security import "${CERTIFICATE_PATH}" \
  -P "${APPLE_CERTIFICATE_PASSWORD}" \
  -A -t cert -f pkcs12 -k "${KEYCHAIN_PATH}"
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s -k "${APPLE_KEYCHAIN_PASSWORD}" \
  "${KEYCHAIN_PATH}" >/dev/null
security list-keychains -d user -s "${KEYCHAIN_PATH}" "${ORIGINAL_KEYCHAINS[@]}"

SIGN_IDENTITY="$(security find-identity -v -p codesigning "${KEYCHAIN_PATH}" \
  | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
  | head -n 1)"
if [[ -z "${SIGN_IDENTITY}" ]]; then
  echo "导入的证书中没有可用的 Developer ID Application identity。" >&2
  exit 1
fi

VERSION="${VERSION:?VERSION is required}" \
BUILD_NUMBER="${BUILD_NUMBER:?BUILD_NUMBER is required}" \
SIGN_IDENTITY="${SIGN_IDENTITY}" \
APP_ARCHS="${APP_ARCHS:-arm64 x86_64}" \
NOTARY_KEY="${API_KEY_PATH}" \
NOTARY_KEY_ID="${APPLE_API_KEY_ID}" \
NOTARY_ISSUER="${APPLE_API_ISSUER_ID}" \
  "${PROJECT_DIR}/scripts/build-dmg.sh"
