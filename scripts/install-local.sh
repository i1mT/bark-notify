#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BIN_INSTALL_DIR="${BIN_INSTALL_DIR:-${HOME}/.local/bin}"
APP_INSTALL_DIR="${APP_INSTALL_DIR:-${HOME}/Applications}"

cd "${PROJECT_DIR}"
swift build -c release --product notify
BIN_DIR="$(swift build -c release --show-bin-path)"
"${PROJECT_DIR}/scripts/build-app.sh"

mkdir -p "${BIN_INSTALL_DIR}" "${APP_INSTALL_DIR}"
install -m 755 "${BIN_DIR}/notify" "${BIN_INSTALL_DIR}/notify"
ditto "${PROJECT_DIR}/build/BarkDesk.app" "${APP_INSTALL_DIR}/BarkDesk.app"

echo "Installed notify to ${BIN_INSTALL_DIR}/notify"
echo "Installed BarkDesk to ${APP_INSTALL_DIR}/BarkDesk.app"
