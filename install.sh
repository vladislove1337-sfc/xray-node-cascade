#!/usr/bin/env bash
set -euo pipefail

APP_NAME="xcascade"
APP_DIR="/opt/xcascade"
BIN_PATH="/usr/local/bin/xcascade"
SCRIPT_NAME="xcascade.sh"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo bash install.sh"
  exit 1
fi

clear
echo "================================="
echo " Xray Cascade Manager Installer"
echo "================================="

apt update
apt install -y curl wget unzip jq qrencode nano openssl python3 ca-certificates

if ! command -v xray >/dev/null 2>&1; then
  echo "[+] Installing Xray Core..."
  bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
else
  echo "[+] Xray already installed: $(xray version | head -n1)"
fi

mkdir -p "$APP_DIR" /etc/xcascade/sub

echo "[+] Downloading Xray Cascade menu..."

curl -Ls "https://raw.githubusercontent.com/vladislove1337-sfc/xray-node-cascade/main/xcascade.sh" \
    -o "$APP_DIR/$SCRIPT_NAME"

if [[ ! -f "$APP_DIR/$SCRIPT_NAME" ]]; then
    echo "Failed to download xcascade.sh"
    exit 1
fi

chmod +x "$APP_DIR/$SCRIPT_NAME"
ln -sf "$APP_DIR/$SCRIPT_NAME" "$BIN_PATH"

echo
echo "Installation completed."
echo "Run: xcascade"
