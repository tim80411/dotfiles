#!/bin/bash
# ntfy 訊息 → macOS 桌面通知（給遠端 mini session 用的 launchd 訂閱 handler）。
# automation 模式（socketControlMode=automation）拆掉 cmux 血緣牆後，launchd 這種 always-on 外部
# 行程也能直接呼叫 cmux notify → 原生卡片 + 點擊跳回 tab。cmux 不可用時退回 terminal-notifier 橫幅。
[ -z "$message" ] && exit 0
LOG="$HOME/.claude/ntfy-desktop-received.log"
echo "$(date '+%F %T') recv title=[$title] msg=[$message] tags=[$tags]" >> "$LOG"

# 從 tags 取出 cmuxws_<id>（notify_mobile.sh 在情境 B 塞進來的「筆電」cmux workspace id）
WS=""
IFS=',' read -ra _tags <<< "$tags"
for t in "${_tags[@]}"; do
  case "$t" in
    cmuxws_*) WS="${t#cmuxws_}" ;;
  esac
done

CMUX_BIN=/opt/homebrew/bin/cmux
# 主力：有 workspace id 且 cmux notify 成功 → 原生卡片 + 點擊跳 tab
if [ -n "$WS" ] && [ -x "$CMUX_BIN" ] && \
   "$CMUX_BIN" notify --workspace "$WS" --title "${title:-Claude}" --body "$message" >/dev/null 2>&1; then
  echo "$(date '+%F %T') -> cmux notify ws=$WS OK" >> "$LOG"
  exit 0
fi

# fallback：沒有 cmuxws tag，或 cmux notify 失敗（socket 沒開/模式沒套用）→ 退回 macOS 橫幅
echo "$(date '+%F %T') -> fallback terminal-notifier (WS=${WS:-none})" >> "$LOG"
/opt/homebrew/bin/terminal-notifier \
  -title "${title:-Claude}" -message "$message" -group "ntfy-${title:-claude}" \
  -execute "open -a cmux" >/dev/null 2>&1
