#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-release}"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_DIR}/build}"
APP_DIR="${OUTPUT_DIR}/BarkDesk.app"
ICONSET_DIR="${OUTPUT_DIR}/BarkDesk.iconset"
ICON_SOURCE="${PROJECT_DIR}/Assets/BarkDeskIcon.png"

cd "${PROJECT_DIR}"
swift build -c "${CONFIGURATION}" --product BarkDesk
BIN_DIR="$(swift build -c "${CONFIGURATION}" --show-bin-path)"

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
ditto "${BIN_DIR}/BarkDesk" "${APP_DIR}/Contents/MacOS/BarkDesk"
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"
sips -z 16 16 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
sips -z 32 32 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
sips -z 64 64 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
sips -z 256 256 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
sips -z 512 512 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
sips -z 1024 1024 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null
iconutil -c icns "${ICONSET_DIR}" -o "${APP_DIR}/Contents/Resources/BarkDesk.icns"
plutil -create xml1 "${APP_DIR}/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string "app.barkdesk.macos" "${APP_DIR}/Contents/Info.plist"
plutil -insert CFBundleName -string "BarkDesk" "${APP_DIR}/Contents/Info.plist"
plutil -insert CFBundleDisplayName -string "BarkDesk" "${APP_DIR}/Contents/Info.plist"
plutil -insert CFBundleExecutable -string "BarkDesk" "${APP_DIR}/Contents/Info.plist"
plutil -insert CFBundleIconFile -string "BarkDesk" "${APP_DIR}/Contents/Info.plist"
plutil -insert CFBundlePackageType -string "APPL" "${APP_DIR}/Contents/Info.plist"
plutil -insert CFBundleShortVersionString -string "1.0.0" "${APP_DIR}/Contents/Info.plist"
plutil -insert CFBundleVersion -string "1" "${APP_DIR}/Contents/Info.plist"
plutil -insert LSMinimumSystemVersion -string "14.0" "${APP_DIR}/Contents/Info.plist"
plutil -insert NSHighResolutionCapable -bool true "${APP_DIR}/Contents/Info.plist"
codesign --force --deep --sign - "${APP_DIR}"

echo "Built ${APP_DIR}"
