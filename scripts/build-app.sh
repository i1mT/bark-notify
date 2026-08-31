#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-release}"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_DIR}/build}"
APP_DIR="${OUTPUT_DIR}/BarkDesk.app"
ICONSET_DIR="${OUTPUT_DIR}/BarkDesk.iconset"
ICON_SOURCE="${PROJECT_DIR}/Assets/BarkDeskIcon.png"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP_VERSION="${APP_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
APP_ARCHS="${APP_ARCHS:-}"
MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-14.0}"

build_app_binary() {
  if [[ -z "${APP_ARCHS}" ]]; then
    swift build -c "${CONFIGURATION}" --product BarkDesk
    local bin_dir
    bin_dir="$(swift build -c "${CONFIGURATION}" --show-bin-path)"
    APP_BINARY="${bin_dir}/BarkDesk"
    return
  fi

  local architecture
  local scratch_dir
  local bin_dir
  local -a binaries
  for architecture in ${(z)APP_ARCHS}; do
    case "${architecture}" in
      arm64|x86_64) ;;
      *)
        echo "APP_ARCHS 只支持 arm64 和 x86_64，收到：${architecture}" >&2
        exit 1
        ;;
    esac
    scratch_dir="${OUTPUT_DIR}/swift-${architecture}"
    rm -rf "${scratch_dir}"
    swift build \
      -c "${CONFIGURATION}" \
      --product BarkDesk \
      --triple "${architecture}-apple-macosx${MACOS_DEPLOYMENT_TARGET}" \
      --scratch-path "${scratch_dir}"
    bin_dir="$(swift build \
      -c "${CONFIGURATION}" \
      --triple "${architecture}-apple-macosx${MACOS_DEPLOYMENT_TARGET}" \
      --scratch-path "${scratch_dir}" \
      --show-bin-path)"
    binaries+=("${bin_dir}/BarkDesk")
  done

  local universal_binary="${OUTPUT_DIR}/BarkDesk.universal"
  lipo -create "${binaries[@]}" -output "${universal_binary}"
  APP_BINARY="${universal_binary}"
}

cd "${PROJECT_DIR}"
mkdir -p "${OUTPUT_DIR}"
APP_BINARY=""
build_app_binary

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
ditto "${APP_BINARY}" "${APP_DIR}/Contents/MacOS/BarkDesk"
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
plutil -insert CFBundleShortVersionString -string "${APP_VERSION}" "${APP_DIR}/Contents/Info.plist"
plutil -insert CFBundleVersion -string "${BUILD_NUMBER}" "${APP_DIR}/Contents/Info.plist"
plutil -insert LSMinimumSystemVersion -string "${MACOS_DEPLOYMENT_TARGET}" "${APP_DIR}/Contents/Info.plist"
plutil -insert NSHighResolutionCapable -bool true "${APP_DIR}/Contents/Info.plist"
plutil -insert NSPrincipalClass -string "NSApplication" "${APP_DIR}/Contents/Info.plist"
if [[ "${SIGN_IDENTITY}" == "-" ]]; then
  codesign --force --sign - "${APP_DIR}"
else
  codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" "${APP_DIR}"
fi

codesign --verify --strict --verbose=2 "${APP_DIR}"

echo "Built ${APP_DIR}"
