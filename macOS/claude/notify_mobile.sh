#!/bin/bash

# 讀取 stdin JSON（Claude Code hook 傳入的上下文）
if command -v gtimeout &>/dev/null; then
  STDIN_JSON=$(gtimeout 1 cat || true)
elif command -v timeout &>/dev/null; then
  STDIN_JSON=$(timeout 1 cat || true)
else
  # macOS fallback: read with perl timeout
  STDIN_JSON=$(perl -e 'alarm 1; local $/; print <STDIN>' 2>/dev/null || true)
fi

# 從 stdin JSON 取得欄位
if [ -n "$STDIN_JSON" ]; then
  MESSAGE=$(echo "$STDIN_JSON" | jq -r '.message // empty')
  NOTIFICATION_TYPE=$(echo "$STDIN_JSON" | jq -r '.notification_type // empty')
  HOOK_EVENT=$(echo "$STDIN_JSON" | jq -r '.hook_event_name // empty')
  LAST_MSG=$(echo "$STDIN_JSON" | jq -r '.last_assistant_message // empty')
  CWD=$(echo "$STDIN_JSON" | jq -r '.cwd // empty')
fi

# 「是哪一個 station」標籤：專案資料夾名 +（若在 git repo）分支名
STATION=""
if [ -n "$CWD" ]; then
  STATION=$(basename "$CWD")
  BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
  [ -n "$BRANCH" ] && STATION="$STATION ($BRANCH)"
fi
[ -z "$STATION" ] && STATION="$(hostname -s)"   # 沒 cwd 時退回機器名（分得出本機/mini）

# 依事件決定 emoji / 標題 / ntfy tag
EMOJI="🔔"; TAGS="bell"
if [ "$HOOK_EVENT" = "Stop" ]; then
  EMOJI="✅"; TAGS="white_check_mark"
  TITLE="$EMOJI $STATION 完成"
  # head -c 是按 byte 截斷，中文（3 bytes/字）會被砍成半個字元 → 無效 UTF-8。
  # ntfy 收到非合法 UTF-8 的 body 會判定成二進位附件，而 server 沒開 attachment，
  # 於是回 400 code=40014「attachments not allowed」。iconv -c 剝掉尾端殘骸。
  MESSAGE="${LAST_MSG:+$(printf '%s' "$LAST_MSG" | head -c 100 | iconv -f UTF-8 -t UTF-8 -c 2>/dev/null)}"
  MESSAGE="${MESSAGE:-任務完成}"
elif [ -n "$NOTIFICATION_TYPE" ]; then
  case "$NOTIFICATION_TYPE" in
    permission_prompt) EMOJI="🔐"; TAGS="lock,warning"; TITLE="$EMOJI $STATION 需要授權" ;;
    idle_prompt)       EMOJI="⌛"; TAGS="hourglass";     TITLE="$EMOJI $STATION 等待輸入" ;;
    auth_success)      EMOJI="🔓"; TAGS="unlock";        TITLE="$EMOJI $STATION 認證成功" ;;
    *)                 TITLE="$EMOJI $STATION" ;;
  esac
else
  TITLE="$EMOJI ${1:-$STATION}"
  MESSAGE="${MESSAGE:-${2:-需要您的注意}}"
fi

PRIORITY=${3:-3}
# 私有端點(ntfy host / tailscale)不進 public repo：從本機檔載入(由 secret bundle 帶著走)；
# 缺檔則 NTFY_HOST 留空 → 下方跳過手機推播。
[ -f "$HOME/.config/dotfiles/notify.env" ] && . "$HOME/.config/dotfiles/notify.env"

# TAILSCALE_HOST（通知的 Click: ssh:// 目標）是「每台機器都不同」的值，但 notify.env
# 由跨機器共用的 secret bundle 帶著走 → 必然漂移。實際踩過：mini 上的 env 帶著筆電的
# macbook-pro-3，推播照收、點下去卻 SSH 到另一台（且那台離線，只看得到連線失敗）。
# 改為直接問系統「我是誰」，問不到才沿用 env 值。
#
# 必須取 DNSName 的第一段，不能用 HostName——HostName 是使用者可見的機器名稱，可能含
# 中文與空格（本機實測為「YITING的Mac mini」），放進 ssh:// URL 會直接壞掉；DNSName
# 第一段才是 MagicDNS 可解析的短名。--peers=false 讓輸出從 ~15KB 降到 ~2.8KB，約 37ms。
_ts_bin=$(command -v tailscale 2>/dev/null)
[ -z "$_ts_bin" ] && [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ] \
  && _ts_bin="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
if [ -n "$_ts_bin" ]; then
  _ts_self=$("$_ts_bin" status --json --peers=false 2>/dev/null | jq -r '.Self.DNSName // empty' | cut -d. -f1)
  [ -n "$_ts_self" ] && TAILSCALE_HOST="$_ts_self"
fi

TOPIC="claude_$(whoami)_$(hostname -s | tr '[:upper:]' '[:lower:]')"

# 情境 B（claude 跑在 mini、不在 cmux）：devbox 連線時會把「筆電的 cmux workspace id」
# 寫進 mini 的檔（讀檔而非靠 tmux 環境繼承，才不會被「既有 pane 不繼承新環境」坑到），
# 塞進 ntfy tag，讓筆電訂閱服務點擊時聚焦回那個 tab。
# 多開支援：devbox 每個 session 寫一個專屬檔 laptop_cmux_ws_<session>，避免多個 workspace 共用
# 單檔互相覆蓋（clobber）。這裡用「本 hook 所在的 tmux session 名」讀對應檔，讀不到再退回舊單檔。
if [ -z "$CMUX_WORKSPACE_ID" ]; then
  # 從 pane 解析自己所在的 tmux session（hook 繼承了 pane 的 TMUX_PANE）
  TSESS=""
  if [ -n "$TMUX_PANE" ]; then
    TSESS=$(tmux display-message -p -t "$TMUX_PANE" '#S' 2>/dev/null)
  elif [ -n "$TMUX" ]; then
    TSESS=$(tmux display-message -p '#S' 2>/dev/null)
  fi
  LAPTOP_CMUX_WS=""
  [ -n "$TSESS" ] && LAPTOP_CMUX_WS=$(cat "$HOME/.claude/laptop_cmux_ws_${TSESS}" 2>/dev/null)
  # per-session 檔讀不到 → 退回舊單檔
  [ -z "$LAPTOP_CMUX_WS" ] && LAPTOP_CMUX_WS=$(cat "$HOME/.claude/laptop_cmux_ws" 2>/dev/null)
  [ -n "$LAPTOP_CMUX_WS" ] && TAGS="$TAGS,cmuxws_$LAPTOP_CMUX_WS"
fi

# 推送到 ntfy (手機端) — 背景化但把非 200 記進 log；沒有私有端點(NTFY_HOST 空)就跳過
if [ -n "$NTFY_HOST" ]; then
(
  NTFY_CODE=$(curl -s -m 8 -o /dev/null -w '%{http_code}' \
    -H "Title: $TITLE" \
    -H "Priority: $PRIORITY" \
    -H "Tags: $TAGS" \
    -H "Click: ssh://${TAILSCALE_USER}@${TAILSCALE_HOST}" \
    -d "$MESSAGE" \
    "https://$NTFY_HOST/$TOPIC")
  [ "$NTFY_CODE" = "200" ] || printf '%s ntfy publish FAILED http=%s topic=%s\n' "$(date '+%F %T')" "$NTFY_CODE" "$TOPIC" >> ~/.claude/notify_mobile.log
) &
fi

# 桌面通知：情境 A（claude 在筆電 cmux pane）→ cmux notify（點擊跳回該 tab）；否則退回 OSC 777
if [ -n "$CMUX_WORKSPACE_ID" ] && command -v cmux >/dev/null 2>&1; then
  # hook 是 pane 內 claude 的子行程，繼承了 pane 的 CMUX_* 環境 → cmux notify 天生有 socket 存取、
  # 綁到這個 workspace；「點擊 → 跳回這個 tab」由 cmux 內部處理（不必烘 socket 密碼、cmux 重啟也不失效）。
  cmux notify --workspace "$CMUX_WORKSPACE_ID" --title "$TITLE" --body "$MESSAGE" >/dev/null 2>&1
elif [ -n "$TMUX" ]; then
  PANE_TTY=$(tmux display-message -p '#{pane_tty}')
  if [ -w "$PANE_TTY" ]; then
    printf '\ePtmux;\e\e]777;notify;%s;%s\a\e\\' "$TITLE" "$MESSAGE" > "$PANE_TTY"
  fi
else
  printf '\e]777;notify;%s;%s\a' "$TITLE" "$MESSAGE"
fi
