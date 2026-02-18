#!/bin/bash
TOPIC="claude_$(whoami)_$(hostname -s | tr '[:upper:]' '[:lower:]')" # 自動生成唯一 Topic
TITLE="${1:-Claude Code}"
MESSAGE="${2:-需要您的注意}"
PRIORITY=${3:-3}
TAILSCALE_USER="tim80411"  # 替換為實際使用者名稱
# 使用 Tailscale MagicDNS 機器名稱，不受 IP 變動影響
TAILSCALE_HOST="macbook-pro-3"

# 推送到 ntfy (手機端) — 點擊通知後透過 ssh:// 開啟 Secure ShellFish
curl -s \
  -H "Title: $TITLE" \
  -H "Priority: $PRIORITY" \
  -H "Tags: computer,warning" \
  -H "Click: ssh://${TAILSCALE_USER}@${TAILSCALE_HOST}" \
  -d "$MESSAGE" \
  "https://ntfy.sh/$TOPIC" > /dev/null 2>&1 &

# 推送到本地 (電腦端 macOS) — 點擊通知跳回 iTerm
if [[ "$(uname)" == "Darwin" ]] && command -v terminal-notifier &>/dev/null; then
  terminal-notifier -title "$TITLE" -message "$MESSAGE" -activate com.googlecode.iterm2 -sound default &>/dev/null &
elif [[ "$(uname)" == "Darwin" ]]; then
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" 2>/dev/null
fi
