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
fi

# 根據 hook event 和 notification type 產生 title
if [ "$HOOK_EVENT" = "Stop" ]; then
  TITLE="Claude Code"
  MESSAGE="${LAST_MSG:+$(echo "$LAST_MSG" | head -c 100)}"
  MESSAGE="${MESSAGE:-任務完成}"
elif [ -n "$NOTIFICATION_TYPE" ]; then
  case "$NOTIFICATION_TYPE" in
    permission_prompt) TITLE="需要授權" ;;
    idle_prompt)       TITLE="等待輸入" ;;
    auth_success)      TITLE="認證成功" ;;
    *)                 TITLE="Claude Code" ;;
  esac
else
  TITLE="${1:-Claude Code}"
  MESSAGE="${MESSAGE:-${2:-需要您的注意}}"
fi

PRIORITY=${3:-3}
TOPIC="claude_$(whoami)_$(hostname -s | tr '[:upper:]' '[:lower:]')"
TAILSCALE_USER="tim80411"
TAILSCALE_HOST="macbook-pro-3"

# 推送到 ntfy (手機端) — 點擊通知後透過 ssh:// 開啟 Secure ShellFish
curl -s \
  -H "Title: $TITLE" \
  -H "Priority: $PRIORITY" \
  -H "Tags: computer,warning" \
  -H "Click: ssh://${TAILSCALE_USER}@${TAILSCALE_HOST}" \
  -d "$MESSAGE" \
  "https://ntfy.sh/$TOPIC" > /dev/null 2>&1 &

# Ghostty 桌面通知 (OSC 777) — title/body 分開顯示，與原生通知風格一致
if [ -n "$TMUX" ]; then
  PANE_TTY=$(tmux display-message -p '#{pane_tty}')
  if [ -w "$PANE_TTY" ]; then
    printf '\ePtmux;\e\e]777;notify;%s;%s\a\e\\' "$TITLE" "$MESSAGE" > "$PANE_TTY"
  fi
else
  printf '\e]777;notify;%s;%s\a' "$TITLE" "$MESSAGE"
fi
