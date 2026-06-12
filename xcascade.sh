#!/usr/bin/env bash
set -euo pipefail

CONFIG="/usr/local/etc/xray/config.json"
STATE_DIR="/etc/xcascade"
STATE_FILE="$STATE_DIR/config"
LINK_FILE="$STATE_DIR/link.txt"
SUB_DIR="$STATE_DIR/sub"
SUB_FILE="$SUB_DIR/sub"
SUB_PORT="2096"
VERSION="1.0"

mkdir -p "$STATE_DIR" "$SUB_DIR"

LANG_MODE="RU"
[[ -f "$STATE_FILE" ]] && source "$STATE_FILE" || true

tr() {
  local ru="$1" en="$2"
  if [[ "${LANG_MODE:-RU}" == "EN" ]]; then echo "$en"; else echo "$ru"; fi
}

pause() { read -rp "$(tr 'Нажми ENTER...' 'Press ENTER...')" _; }

get_public_ip() {
  curl -4 -s --max-time 5 ifconfig.me || curl -4 -s --max-time 5 icanhazip.com || echo "YOUR_SERVER_IP"
}

save_state() {
  cat > "$STATE_FILE" <<EOF_STATE
LANG_MODE="${LANG_MODE:-RU}"
ROLE="${ROLE:-}"
SERVER_IP="${SERVER_IP:-}"
SNI="${SNI:-}"
UUID="${UUID:-}"
PRIVATE_KEY="${PRIVATE_KEY:-}"
PUBLIC_KEY="${PUBLIC_KEY:-}"
SHORT_ID="${SHORT_ID:-}"
EXIT_IP="${EXIT_IP:-}"
EXIT_PORT="${EXIT_PORT:-10808}"
EXIT_USER="${EXIT_USER:-ru}"
EXIT_PASS="${EXIT_PASS:-SwedenCascade1337}"
EOF_STATE
}

banner() {
  clear
  echo "================================="
  echo "      Xray Cascade Manager       "
  echo "             v$VERSION           "
  echo "================================="
  echo "$(tr 'Язык' 'Language'): ${LANG_MODE:-RU}"
  [[ -n "${ROLE:-}" ]] && echo "$(tr 'Режим' 'Mode'): $ROLE"
  echo
}

select_language() {
  banner
  echo "1) Русский"
  echo "2) English"
  read -rp "> " n
  case "$n" in
    1) LANG_MODE="RU" ;;
    2) LANG_MODE="EN" ;;
  esac
  save_state
}

choose_sni() {
  echo "$(tr 'Выбери SNI:' 'Choose SNI:')"
  echo "1) yastatic.net"
  echo "2) www.microsoft.com"
  echo "3) api-maps.yandex.ru"
  echo "4) Свой / Custom"
  read -rp "> " n
  case "$n" in
    1) SNI="yastatic.net" ;;
    2) SNI="www.microsoft.com" ;;
    3) SNI="api-maps.yandex.ru" ;;
    4) read -rp "SNI: " SNI ;;
    *) SNI="yastatic.net" ;;
  esac
}

generate_reality() {
  UUID="$(xray uuid)"
  local keys
  keys="$(xray x25519)"
  PRIVATE_KEY="$(echo "$keys" | awk '/PrivateKey:/ {print $2}')"
  PUBLIC_KEY="$(echo "$keys" | awk '/Password|PublicKey/ {print $NF; exit}')"
  SHORT_ID="$(openssl rand -hex 8)"
}

make_link() {
  SERVER_IP="${SERVER_IP:-$(get_public_ip)}"
  local name="Xray-Cascade-${SERVER_IP}"
  local link="vless://${UUID}@${SERVER_IP}:443?encryption=none&type=tcp&security=reality&pbk=${PUBLIC_KEY}&fp=chrome&sni=${SNI}&sid=${SHORT_ID}#${name}"
  echo "$link" | tee "$LINK_FILE" >/dev/null
  printf '%s' "$link" | base64 -w0 > "$SUB_FILE"
}

write_gateway_config() {
  cat > "$CONFIG" <<EOF_JSON
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "$UUID" } ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "$SNI:443",
          "serverNames": [ "$SNI" ],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [ "$SHORT_ID" ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "exit-http",
      "protocol": "http",
      "settings": {
        "servers": [
          {
            "address": "$EXIT_IP",
            "port": $EXIT_PORT,
            "users": [ { "user": "$EXIT_USER", "pass": "$EXIT_PASS" } ]
          }
        ]
      }
    }
  ]
}
EOF_JSON
}

write_exit_config() {
  cat > "$CONFIG" <<EOF_JSON
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": $EXIT_PORT,
      "protocol": "http",
      "settings": {
        "accounts": [ { "user": "$EXIT_USER", "pass": "$EXIT_PASS" } ],
        "allowTransparent": false
      }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF_JSON
}

install_gateway() {
  banner
  ROLE="gateway"
  SERVER_IP="$(get_public_ip)"
  echo "$(tr 'Определён IP сервера:' 'Detected server IP:') $SERVER_IP"
  choose_sni
  generate_reality
  echo
  read -rp "$(tr 'IP Exit VPS: ' 'Exit VPS IP: ')" EXIT_IP
  read -rp "$(tr 'Порт HTTP proxy Exit [10808]: ' 'Exit HTTP proxy port [10808]: ')" EXIT_PORT
  EXIT_PORT="${EXIT_PORT:-10808}"
  read -rp "$(tr 'Пользователь Exit [ru]: ' 'Exit username [ru]: ')" EXIT_USER
  EXIT_USER="${EXIT_USER:-ru}"
  read -rp "$(tr 'Пароль Exit [SwedenCascade1337]: ' 'Exit password [SwedenCascade1337]: ')" EXIT_PASS
  EXIT_PASS="${EXIT_PASS:-SwedenCascade1337}"
  write_gateway_config
  xray run -test -config "$CONFIG"
  systemctl restart xray
  make_link
  save_state
  echo
  echo "$(tr 'Gateway готов.' 'Gateway ready.')"
  show_link
}

install_exit() {
  banner
  ROLE="exit"
  SERVER_IP="$(get_public_ip)"
  echo "$(tr 'Определён IP сервера:' 'Detected server IP:') $SERVER_IP"
  read -rp "$(tr 'Порт HTTP proxy [10808]: ' 'HTTP proxy port [10808]: ')" EXIT_PORT
  EXIT_PORT="${EXIT_PORT:-10808}"
  read -rp "$(tr 'Пользователь [ru]: ' 'Username [ru]: ')" EXIT_USER
  EXIT_USER="${EXIT_USER:-ru}"
  read -rp "$(tr 'Пароль [SwedenCascade1337]: ' 'Password [SwedenCascade1337]: ')" EXIT_PASS
  EXIT_PASS="${EXIT_PASS:-SwedenCascade1337}"
  write_exit_config
  xray run -test -config "$CONFIG"
  systemctl restart xray
  save_state
  echo
  echo "$(tr 'Exit сервер готов.' 'Exit server ready.')"
  echo "HTTP CONNECT: $SERVER_IP:$EXIT_PORT"
}

show_link() {
  if [[ ! -f "$LINK_FILE" ]]; then echo "$(tr 'Ссылка не найдена.' 'Link not found.')"; return; fi
  echo
  cat "$LINK_FILE"
  echo
}

show_qr() {
  if [[ ! -f "$LINK_FILE" ]]; then echo "$(tr 'Ссылка не найдена.' 'Link not found.')"; return; fi
  qrencode -t ANSIUTF8 < "$LINK_FILE"
}

start_subscription() {
  if [[ ! -f "$SUB_FILE" ]]; then echo "$(tr 'Сначала установи Gateway.' 'Install Gateway first.')"; return; fi
  cat > /etc/systemd/system/xcascade-sub.service <<EOF_SERVICE
[Unit]
Description=Xray Cascade Subscription Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$SUB_DIR
ExecStart=/usr/bin/python3 -m http.server $SUB_PORT --bind 0.0.0.0
Restart=always

[Install]
WantedBy=multi-user.target
EOF_SERVICE
  systemctl daemon-reload
  systemctl enable --now xcascade-sub.service
  echo "$(tr 'Подписка:' 'Subscription:') http://${SERVER_IP:-$(get_public_ip)}:${SUB_PORT}/sub"
}

status_xray() { systemctl status xray --no-pager; }
restart_xray() { systemctl restart xray && echo OK; }

update_script() {
  echo "$(tr 'Обновление: скачай свежие файлы с GitHub и снова запусти install.sh.' 'Update: download fresh files from GitHub and run install.sh again.')"
}

while true; do
  banner
  echo "1) $(tr 'Выбрать язык' 'Select language')"
  echo "2) $(tr 'Установить RU Gateway' 'Install Gateway Server')"
  echo "3) $(tr 'Установить Exit Server' 'Install Exit Server')"
  echo "4) $(tr 'Показать ссылку' 'Show connection link')"
  echo "5) $(tr 'Показать QR Code' 'Show QR Code')"
  echo "6) $(tr 'Запустить подписку' 'Start subscription')"
  echo "7) $(tr 'Статус Xray' 'Xray status')"
  echo "8) $(tr 'Перезапустить Xray' 'Restart Xray')"
  echo "9) $(tr 'Обновить скрипт' 'Update script')"
  echo "0) $(tr 'Выход' 'Exit')"
  echo
  read -rp "> " m
  case "$m" in
    1) select_language ;;
    2) install_gateway ;;
    3) install_exit ;;
    4) show_link ;;
    5) show_qr ;;
    6) start_subscription ;;
    7) status_xray ;;
    8) restart_xray ;;
    9) update_script ;;
    0) exit 0 ;;
    *) echo "?" ;;
  esac
  pause
 done
