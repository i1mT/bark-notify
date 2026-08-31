#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_INSTALL_DIR="${APP_INSTALL_DIR:-${HOME}/Applications}"

cd "${PROJECT_DIR}"
"${PROJECT_DIR}/scripts/build-app.sh"

mkdir -p "${APP_INSTALL_DIR}"
ditto "${PROJECT_DIR}/build/BarkDesk.app" "${APP_INSTALL_DIR}/BarkDesk.app"

echo "Installed BarkDesk to ${APP_INSTALL_DIR}/BarkDesk.app"
echo "Install the cross-platform CLI separately with: npm install -g barkdesk-notify"
