#!/bin/bash
TOPIC="claude_$(whoami)_$(hostname -s | tr '[:upper:]' '[:lower:]')" # 自動生成唯一 Topic
TITLE="${1:-Claude Code}"
MESSAGE="${2:-需要您的注意}"
PRIORITY=${3:-3}
TAILSCALE_USER="tim80411"  # 替換為實際使用者名稱
# NOTE: Tailscale IP 是動態分配的，重灌後需手動更新為新的 IP
# 可透過 `tailscale ip -4` 取得目前的 IP
TAILSCALE_HOST="100.93.76.116"

# 推送到 ntfy (手機端) — 使用 ssh:// URL Scheme 觸發 Termius
curl -s \
  -H "Title: $TITLE" \
  -H "Priority: $PRIORITY" \
  -H "Tags: computer,warning" \
  -H "Click: termius://" \
  -d "$MESSAGE" \
  "https://ntfy.sh/$TOPIC" > /dev/null 2>&1 &

# 推送到本地 (電腦端 macOS)
if [[ "$(uname)" == "Darwin" ]]; then
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" 2>/dev/null
fi
