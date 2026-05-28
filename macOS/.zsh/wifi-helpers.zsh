# ============================================================
# wifi-pw: Wi-Fi password helper (macOS)
# 繞開 macOS Sonoma+ 系統設定「拷貝密碼」GUI bug
# 處理 macOS Sequoia (15) 起 CLI 取 SSID 的 <redacted> 限制
#
# 第一次跑 wifi-pw copy / wifi-pw show 會跳一次 Keychain GUI
# 請輸入登入密碼並點【Always Allow】，之後該 SSID 永久靜默
#
# 用法：
#   wifi-pw ls               列出 Keychain 內所有 Wi-Fi SSID
#   wifi-pw ssid             印出目前連線的 SSID
#   wifi-pw show [SSID]      印密碼到 stdout
#   wifi-pw copy [SSID]      複製密碼到剪貼簿
#   wifi-pw qr   [SSID]      在 terminal 畫 Wi-Fi QR code
#   wifi-pw help             顯示說明
#
# 省略 SSID 時用目前連線的網路
# 可選依賴：brew install qrencode（qr 子命令才需要）
# ============================================================

# ---- internal helpers -------------------------------------------------------

_wifi_pw_current_ssid() {
  emulate -L zsh
  local iface
  iface=$(networksetup -listnetworkserviceorder \
    | sed -En 's/^\(Hardware Port: (Wi-Fi|AirPort), Device: (en[0-9]+)\)$/\2/p' \
    | head -n1)
  [[ -z "$iface" ]] && { echo "no Wi-Fi interface" >&2; return 1; }

  ipconfig setverbose 1 2>/dev/null
  local ssid
  ssid=$(ipconfig getsummary "$iface" 2>/dev/null \
    | awk -F ' SSID : ' '/ SSID : / {print $2; exit}')
  ipconfig setverbose 0 2>/dev/null

  if [[ -z "$ssid" ]]; then
    ssid=$(system_profiler SPAirPortDataType 2>/dev/null \
      | awk '/Current Network Information:/ {getline; gsub(/^[ \t]+|:$/, ""); print; exit}')
  fi

  if [[ "$ssid" == "<redacted>" || -z "$ssid" ]]; then
    cat >&2 <<'EOF'
無法自動取得目前 SSID（macOS 隱私限制）。
請選一個處理方式：

  方式 A（一次性）：明確傳 SSID
    wifi-pw copy "你的SSID"
    wifi-pw ls    # 看 Keychain 內有哪些 SSID 可選

  方式 B（一勞永逸）：給 terminal Location 權限
    System Settings → Privacy & Security → Location Services
    → 打開總開關 → 找到 Terminal / iTerm / Ghostty 並打勾
    → 重啟 terminal app
    之後 wifi-pw 不用傳 SSID 就會用目前連線網路
EOF
    return 1
  fi

  print -r -- "$ssid"
}

_wifi_pw_list() {
  emulate -L zsh
  security dump-keychain 2>/dev/null \
    | awk '
        /"desc"<blob>="AirPort network password"/ { airport=1 }
        airport && /"acct"<blob>=/ {
          sub(/^[[:space:]]*"acct"<blob>=/, "")
          if ($0 ~ /^0x[0-9A-Fa-f]+/) {
            hex=$0
            sub(/^0x/, "", hex)
            sub(/[[:space:]].*/, "", hex)
            print "HEX\t" hex
          } else {
            gsub(/^"|"$/, "")
            print "STR\t" $0
          }
          airport=0
        }' \
    | while IFS=$'\t' read -r kind val; do
        if [[ "$kind" == "HEX" ]]; then
          print -r -- "$(printf '%s' "$val" | xxd -r -p)"
        else
          print -r -- "$val"
        fi
      done | sort -u
}

_wifi_pw_show() {
  emulate -L zsh
  local ssid="${1:-$(_wifi_pw_current_ssid)}"
  [[ -z "$ssid" ]] && return 1
  security find-generic-password -w -D "AirPort network password" -a "$ssid" 2>/dev/null \
    || { echo "no keychain entry for SSID: $ssid" >&2; return 1; }
}

_wifi_pw_copy() {
  emulate -L zsh
  local ssid="${1:-$(_wifi_pw_current_ssid)}"
  [[ -z "$ssid" ]] && return 1
  if security find-generic-password -w -D "AirPort network password" -a "$ssid" 2>/dev/null \
       | tr -d '\n' | pbcopy
  then
    print -r -- "copied password for: $ssid"
  else
    echo "no keychain entry for SSID: $ssid" >&2
    return 1
  fi
}

_wifi_pw_qr() {
  emulate -L zsh
  command -v qrencode >/dev/null || { echo "需要 qrencode：brew install qrencode" >&2; return 1; }
  local ssid="${1:-$(_wifi_pw_current_ssid)}"
  [[ -z "$ssid" ]] && return 1
  local pw
  pw=$(security find-generic-password -w -D "AirPort network password" -a "$ssid" 2>/dev/null) \
    || { echo "no keychain entry for: $ssid" >&2; return 1; }
  local esc_ssid=${ssid//\\/\\\\} esc_pw=${pw//\\/\\\\}
  for c in ';' ',' ':' '"'; do
    esc_ssid=${esc_ssid//$c/\\$c}
    esc_pw=${esc_pw//$c/\\$c}
  done
  qrencode -t ANSIUTF8 -- "WIFI:T:WPA;S:${esc_ssid};P:${esc_pw};;"
}

_wifi_pw_help() {
  cat <<'EOF'
wifi-pw — Wi-Fi password helper (macOS)

Usage:
  wifi-pw ls               列出 Keychain 內所有 Wi-Fi SSID
  wifi-pw ssid             印出目前連線的 SSID
  wifi-pw show [SSID]      印密碼到 stdout
  wifi-pw copy [SSID]      複製密碼到剪貼簿
  wifi-pw qr   [SSID]      在 terminal 畫 Wi-Fi QR code
  wifi-pw help             顯示說明

省略 SSID 時用目前連線的網路。
EOF
}

# ---- entry point ------------------------------------------------------------

wifi-pw() {
  emulate -L zsh
  local verb="${1-}"
  (( $# > 0 )) && shift
  case "${verb:-help}" in
    ls|list)         _wifi_pw_list "$@" ;;
    ssid|current)    _wifi_pw_current_ssid "$@" ;;
    show|get|print)  _wifi_pw_show "$@" ;;
    copy|cp)         _wifi_pw_copy "$@" ;;
    qr)              _wifi_pw_qr "$@" ;;
    help|-h|--help)  _wifi_pw_help ;;
    *)
      echo "wifi-pw: unknown verb: $verb" >&2
      _wifi_pw_help >&2
      return 1
      ;;
  esac
}

# ---- zsh tab completion -----------------------------------------------------

_wifi_pw_complete() {
  local -a verbs
  verbs=(
    'ls:list Wi-Fi entries in Keychain'
    'ssid:show current SSID'
    'show:print password to stdout'
    'copy:copy password to clipboard'
    'qr:render Wi-Fi QR code'
    'help:show usage'
  )
  if (( CURRENT == 2 )); then
    _describe 'verb' verbs
  elif (( CURRENT == 3 )); then
    case "$words[2]" in
      show|copy|qr)
        local -a ssids
        ssids=("${(@f)$(_wifi_pw_list 2>/dev/null)}")
        _describe 'ssid' ssids
        ;;
    esac
  fi
}
compdef _wifi_pw_complete wifi-pw 2>/dev/null
