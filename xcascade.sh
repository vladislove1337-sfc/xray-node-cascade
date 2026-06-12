#!/bin/bash

CONFIG="/usr/local/etc/xray/config.json"
APP_DIR="/opt/xcascade"
ETC_DIR="/etc/xcascade"
SUB_DIR="$ETC_DIR/sub"
LINK_FILE="$ETC_DIR/link.txt"
SUB_FILE="$SUB_DIR/sub"
LANG_FILE="$ETC_DIR/lang"

DEFAULT_SNI="yastatic.net"
DEFAULT_SUB_PORT="2096"

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Run as root: sudo xcascade"
        exit 1
    fi
}

pause() {
    echo
    read -rp "Press ENTER..."
}

get_lang() {
    if [[ -f "$LANG_FILE" ]]; then
        LANG=$(cat "$LANG_FILE")
    else
        LANG="en"
    fi
}

save_lang() {
    mkdir -p "$ETC_DIR"
    echo "$LANG" > "$LANG_FILE"
}

tr() {
    local key="$1"
    get_lang
    case "$LANG:$key" in
        ru:title) echo "Xray Node Cascade" ;;
        ru:lang) echo "Язык" ;;
        ru:install_gateway) echo "Установить Gateway сервер" ;;
        ru:install_exit) echo "Установить Exit сервер" ;;
        ru:show_link) echo "Показать ссылку" ;;
        ru:show_qr) echo "Показать QR-код" ;;
        ru:subscription) echo "Настройки подписки" ;;
        ru:status) echo "Статус Xray" ;;
        ru:restart) echo "Перезапуск Xray" ;;
        ru:update) echo "Обновить скрипт" ;;
        ru:uninstall) echo "Удаление" ;;
        ru:exit) echo "Выход" ;;
        ru:select) echo "Выбери пункт" ;;
        ru:done) echo "Готово" ;;
        ru:cancel) echo "Отмена" ;;
        ru:no_link) echo "Ссылка ещё не создана. Сначала установи Gateway сервер." ;;
        ru:manager_only) echo "Удалить только менеджер" ;;
        ru:manager_xray) echo "Удалить менеджер + Xray Core" ;;
        ru:remove_title) echo "Удаление Xray Node Cascade" ;;
        ru:confirm_full) echo "ВНИМАНИЕ: будет удалён Xray Core и конфиги. Продолжить? [y/N]: " ;;
        *)
            case "$key" in
                title) echo "Xray Node Cascade" ;;
                lang) echo "Language" ;;
                install_gateway) echo "Install Gateway Server" ;;
                install_exit) echo "Install Exit Server" ;;
                show_link) echo "Show connection link" ;;
                show_qr) echo "Show QR Code" ;;
                subscription) echo "Subscription settings" ;;
                status) echo "Xray status" ;;
                restart) echo "Restart Xray" ;;
                update) echo "Update script" ;;
                uninstall) echo "Uninstall" ;;
                exit) echo "Exit" ;;
                select) echo "Select option" ;;
                done) echo "Done" ;;
                cancel) echo "Cancel" ;;
                no_link) echo "Link is not created yet. Install Gateway server first." ;;
                manager_only) echo "Remove manager only" ;;
                manager_xray) echo "Remove manager + Xray Core" ;;
                remove_title) echo "Remove Xray Node Cascade" ;;
                confirm_full) echo "WARNING: Xray Core and configs will be removed. Continue? [y/N]: " ;;
                *) echo "$key" ;;
            esac
            ;;
    esac
}

banner() {
    clear
    echo "================================="
    echo "      $(tr title)"
    echo "================================="
    echo "$(tr lang): $LANG"
    echo
}

select_language() {
    clear
    echo "Select language / Выбор языка"
    echo
    echo "1) English"
    echo "2) Русский"
    echo
    read -rp "> " choice
    case "$choice" in
        1) LANG="en" ;;
        2) LANG="ru" ;;
        *) return ;;
    esac
    save_lang
}

get_public_ip() {
    curl -4 -s --max-time 5 ifconfig.me || curl -4 -s --max-time 5 icanhazip.com || hostname -I | awk '{print $1}'
}

choose_sni() {
    echo
    echo "Choose SNI / Выбери SNI:"
    echo "1) yastatic.net"
    echo "2) www.microsoft.com"
    echo "3) www.cloudflare.com"
    echo "4) Custom / Свой"
    echo
    read -rp "> " sni_choice
    case "$sni_choice" in
        1) SNI="yastatic.net" ;;
        2) SNI="www.microsoft.com" ;;
        3) SNI="www.cloudflare.com" ;;
        4) read -rp "SNI: " SNI ;;
        *) SNI="$DEFAULT_SNI" ;;
    esac
    SNI=${SNI:-$DEFAULT_SNI}
}

install_gateway() {
    banner
    echo "Gateway Server / Входной сервер"
    echo

    choose_sni

    UUID=$(xray uuid)
    KEYS=$(xray x25519)
    PRIVATE=$(echo "$KEYS" | grep -i "Private" | awk '{print $2}')
    PUBLIC=$(echo "$KEYS" | grep -i "Password" | awk '{print $3}')
    SHORT_ID=$(openssl rand -hex 8)

    echo
    read -rp "Exit VPS IP: " EXIT_IP
    read -rp "Exit HTTP port [10808]: " EXIT_PORT
    EXIT_PORT=${EXIT_PORT:-10808}
    read -rp "Exit HTTP username [ru]: " EXIT_USER
    EXIT_USER=${EXIT_USER:-ru}
    read -rp "Exit HTTP password [SwedenCascade1337]: " EXIT_PASS
    EXIT_PASS=${EXIT_PASS:-SwedenCascade1337}

    mkdir -p "$(dirname "$CONFIG")" "$ETC_DIR" "$SUB_DIR"

    cat > "$CONFIG" <<XRAYEOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "$SNI:443",
          "serverNames": [
            "$SNI"
          ],
          "privateKey": "$PRIVATE",
          "shortIds": [
            "$SHORT_ID"
          ]
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
            "users": [
              {
                "user": "$EXIT_USER",
                "pass": "$EXIT_PASS"
              }
            ]
          }
        ]
      }
    }
  ]
}
XRAYEOF

    if ! xray run -test -config "$CONFIG"; then
        echo "Config test failed"
        pause
        return
    fi

    systemctl restart xray

    SERVER_IP=$(get_public_ip)
    LINK="vless://$UUID@$SERVER_IP:443?encryption=none&type=tcp&security=reality&pbk=$PUBLIC&fp=chrome&sni=$SNI&sid=$SHORT_ID#Xray-Node-Cascade"

    echo "$LINK" > "$LINK_FILE"
    echo -n "$LINK" | base64 -w 0 > "$SUB_FILE"

    echo
    echo "====== LINK ======"
    echo "$LINK"
    echo
    qrencode -t ANSIUTF8 "$LINK" 2>/dev/null || true
    pause
}

install_exit() {
    banner
    echo "Exit Server / Выходной сервер"
    echo

    read -rp "Listen IP [0.0.0.0]: " LISTEN_IP
    LISTEN_IP=${LISTEN_IP:-0.0.0.0}
    read -rp "HTTP proxy port [10808]: " PORT
    PORT=${PORT:-10808}
    read -rp "Username [ru]: " USERNAME
    USERNAME=${USERNAME:-ru}
    read -rp "Password [SwedenCascade1337]: " PASSWORD
    PASSWORD=${PASSWORD:-SwedenCascade1337}

    mkdir -p "$(dirname "$CONFIG")" "$ETC_DIR"

    cat > "$CONFIG" <<XRAYEOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "$LISTEN_IP",
      "port": $PORT,
      "protocol": "http",
      "settings": {
        "accounts": [
          {
            "user": "$USERNAME",
            "pass": "$PASSWORD"
          }
        ],
        "allowTransparent": false
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
XRAYEOF

    if ! xray run -test -config "$CONFIG"; then
        echo "Config test failed"
        pause
        return
    fi

    systemctl restart xray
    echo
    echo "Exit node ready on $LISTEN_IP:$PORT"
    pause
}

show_link() {
    banner
    if [[ ! -f "$LINK_FILE" ]]; then
        echo "$(tr no_link)"
    else
        cat "$LINK_FILE"
    fi
    pause
}

show_qr() {
    banner
    if [[ ! -f "$LINK_FILE" ]]; then
        echo "$(tr no_link)"
    else
        qrencode -t ANSIUTF8 "$(cat "$LINK_FILE")"
    fi
    pause
}

subscription_settings() {
    banner
    if [[ ! -f "$SUB_FILE" ]]; then
        echo "$(tr no_link)"
        pause
        return
    fi

    SUB_PORT="$DEFAULT_SUB_PORT"
    SERVER_IP=$(get_public_ip)
    echo "Subscription URL / Ссылка подписки:"
    echo
    echo "http://$SERVER_IP:$SUB_PORT/sub"
    echo
    echo "Starting simple subscription server on port $SUB_PORT..."
    echo "Stop: pkill -f 'python3 -m http.server $SUB_PORT'"

    cp "$SUB_FILE" "$SUB_DIR/sub"
    cd "$SUB_DIR" || return
    nohup python3 -m http.server "$SUB_PORT" >/tmp/xcascade-sub.log 2>&1 &
    pause
}

update_script() {
    banner
    echo "Updating xcascade.sh from GitHub..."
    curl -Ls "https://raw.githubusercontent.com/vladislove1337-sfc/xray-node-cascade/main/xcascade.sh" \
        -o "$APP_DIR/xcascade.sh"
    chmod +x "$APP_DIR/xcascade.sh"
    echo "$(tr done)"
    pause
}

uninstall_xcascade() {
    banner
    echo "=============================="
    echo " $(tr remove_title)"
    echo "=============================="
    echo
    echo "1) $(tr manager_only)"
    echo "2) $(tr manager_xray)"
    echo "0) $(tr cancel)"
    echo
    read -rp "> " choice

    case "$choice" in
        1)
            echo "[+] Removing manager..."
            rm -rf /opt/xcascade
            rm -rf /etc/xcascade
            rm -f /usr/local/bin/xcascade
            echo "$(tr done)"
            exit 0
            ;;
        2)
            read -rp "$(tr confirm_full)" confirm
            case "$confirm" in
                y|Y|yes|YES)
                    echo "[+] Stopping Xray..."
                    systemctl stop xray 2>/dev/null || true
                    systemctl disable xray 2>/dev/null || true

                    echo "[+] Removing Xray Core..."
                    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove

                    echo "[+] Removing files..."
                    rm -rf /usr/local/etc/xray
                    rm -rf /usr/local/share/xray
                    rm -f /usr/local/bin/xray
                    rm -rf /opt/xcascade
                    rm -rf /etc/xcascade
                    rm -f /usr/local/bin/xcascade
                    echo "$(tr done)"
                    exit 0
                    ;;
                *)
                    echo "$(tr cancel)"
                    pause
                    return
                    ;;
            esac
            ;;
        0)
            return
            ;;
        *)
            return
            ;;
    esac
}

main_menu() {
    while true; do
        banner
        echo "1) $(tr lang) / Language"
        echo "2) $(tr install_gateway)"
        echo "3) $(tr install_exit)"
        echo "4) $(tr show_link)"
        echo "5) $(tr show_qr)"
        echo "6) $(tr subscription)"
        echo "7) $(tr status)"
        echo "8) $(tr restart)"
        echo "9) $(tr update)"
        echo "10) $(tr uninstall)"
        echo "0) $(tr exit)"
        echo
        read -rp "$(tr select): " menu

        case "$menu" in
            1) select_language ;;
            2) install_gateway ;;
            3) install_exit ;;
            4) show_link ;;
            5) show_qr ;;
            6) subscription_settings ;;
            7) systemctl status xray --no-pager; pause ;;
            8) systemctl restart xray; echo "$(tr done)"; pause ;;
            9) update_script ;;
            10) uninstall_xcascade ;;
            0) exit 0 ;;
            *) pause ;;
        esac
    done
}

require_root
mkdir -p "$APP_DIR" "$ETC_DIR" "$SUB_DIR"
get_lang
main_menu
