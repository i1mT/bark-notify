#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_DIR}/build}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
NOTARY_KEY="${NOTARY_KEY:-}"
NOTARY_KEY_ID="${NOTARY_KEY_ID:-}"
NOTARY_ISSUER="${NOTARY_ISSUER:-}"
APP_ARCHS="${APP_ARCHS:-}"
DMG_PATH="${OUTPUT_DIR}/BarkDesk-${VERSION}.dmg"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/BarkDesk-dmg.XXXXXX")"
MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/BarkDesk-mount.XXXXXX")"
MOUNTED=false

cleanup() {
  if [[ "${MOUNTED}" == true ]]; then
    hdiutil detach "${MOUNT_DIR}" -quiet || true
  fi
  rm -rf "${STAGING_DIR}" "${MOUNT_DIR}"
}
trap cleanup EXIT

if [[ "${SIGN_IDENTITY}" == "auto" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
    | head -n 1)"
  if [[ -z "${SIGN_IDENTITY}" ]]; then
    echo "Keychain 中没有可用的 Developer ID Application 证书。" >&2
    exit 1
  fi
fi

DIRECT_NOTARY_VALUES=0
[[ -n "${NOTARY_KEY}" ]] && (( DIRECT_NOTARY_VALUES += 1 ))
[[ -n "${NOTARY_KEY_ID}" ]] && (( DIRECT_NOTARY_VALUES += 1 ))
[[ -n "${NOTARY_ISSUER}" ]] && (( DIRECT_NOTARY_VALUES += 1 ))

if (( DIRECT_NOTARY_VALUES > 0 && DIRECT_NOTARY_VALUES < 3 )); then
  echo "直接公证需要同时提供 NOTARY_KEY、NOTARY_KEY_ID 和 NOTARY_ISSUER。" >&2
  exit 1
fi
if [[ -n "${NOTARY_PROFILE}" && ${DIRECT_NOTARY_VALUES} -eq 3 ]]; then
  echo "NOTARY_PROFILE 与直接 App Store Connect API Key 参数不能同时使用。" >&2
  exit 1
fi
if [[ ( -n "${NOTARY_PROFILE}" || ${DIRECT_NOTARY_VALUES} -eq 3 ) && "${SIGN_IDENTITY}" == "-" ]]; then
  echo "Apple 公证需要配合 Developer ID Application 签名使用。" >&2
  exit 1
fi

OUTPUT_DIR="${OUTPUT_DIR}" \
APP_VERSION="${VERSION}" \
BUILD_NUMBER="${BUILD_NUMBER}" \
SIGN_IDENTITY="${SIGN_IDENTITY}" \
APP_ARCHS="${APP_ARCHS}" \
  "${PROJECT_DIR}/scripts/build-app.sh"

ditto "${OUTPUT_DIR}/BarkDesk.app" "${STAGING_DIR}/BarkDesk.app"
ln -s /Applications "${STAGING_DIR}/Applications"

rm -f "${DMG_PATH}"
hdiutil create \
  -volname "BarkDesk" \
  -srcfolder "${STAGING_DIR}" \
  -format UDZO \
  -ov \
  "${DMG_PATH}"

if [[ "${SIGN_IDENTITY}" != "-" ]]; then
  codesign --force --timestamp --sign "${SIGN_IDENTITY}" "${DMG_PATH}"
  codesign --verify --verbose=2 "${DMG_PATH}"
fi

if [[ -n "${NOTARY_PROFILE}" ]]; then
  xcrun notarytool submit "${DMG_PATH}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait
elif (( DIRECT_NOTARY_VALUES == 3 )); then
  xcrun notarytool submit "${DMG_PATH}" \
    --key "${NOTARY_KEY}" \
    --key-id "${NOTARY_KEY_ID}" \
    --issuer "${NOTARY_ISSUER}" \
    --wait
fi

if [[ -n "${NOTARY_PROFILE}" || ${DIRECT_NOTARY_VALUES} -eq 3 ]]; then
  xcrun stapler staple "${DMG_PATH}"
  xcrun stapler validate "${DMG_PATH}"
  spctl --assess --type open --context context:primary-signature -v "${DMG_PATH}"
fi

hdiutil verify "${DMG_PATH}"
hdiutil attach -readonly -nobrowse -mountpoint "${MOUNT_DIR}" "${DMG_PATH}" >/dev/null
MOUNTED=true
test -x "${MOUNT_DIR}/BarkDesk.app/Contents/MacOS/BarkDesk"
test -L "${MOUNT_DIR}/Applications"
codesign --verify --strict --verbose=2 "${MOUNT_DIR}/BarkDesk.app"
hdiutil detach "${MOUNT_DIR}" -quiet
MOUNTED=false

echo "Built and verified ${DMG_PATH}"
