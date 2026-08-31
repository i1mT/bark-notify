#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_DIR}/build}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
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

if [[ -n "${NOTARY_PROFILE}" && "${SIGN_IDENTITY}" == "-" ]]; then
  echo "NOTARY_PROFILE 需要配合 Developer ID Application 签名使用。" >&2
  exit 1
fi

OUTPUT_DIR="${OUTPUT_DIR}" \
APP_VERSION="${VERSION}" \
BUILD_NUMBER="${BUILD_NUMBER}" \
SIGN_IDENTITY="${SIGN_IDENTITY}" \
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
  xcrun stapler staple "${DMG_PATH}"
  xcrun stapler validate "${DMG_PATH}"
fi

hdiutil verify "${DMG_PATH}"
hdiutil attach -readonly -nobrowse -mountpoint "${MOUNT_DIR}" "${DMG_PATH}" >/dev/null
MOUNTED=true
test -x "${MOUNT_DIR}/BarkDesk.app/Contents/MacOS/BarkDesk"
test -x "${MOUNT_DIR}/BarkDesk.app/Contents/Resources/notify"
test -L "${MOUNT_DIR}/Applications"
codesign --verify --strict --verbose=2 "${MOUNT_DIR}/BarkDesk.app"
hdiutil detach "${MOUNT_DIR}" -quiet
MOUNTED=false

echo "Built and verified ${DMG_PATH}"
