#!/bin/bash
# ntfy 訊息 → 各裝置自己的原生桌面通知（launchd 常駐訂閱 handler）。
#
# 架構（2026-09-13 解耦）：任何跑 Claude Code 的機器（目前是 mini）的
# ~/.claude/notify_mobile.sh 只負責把通知推到 ntfy 這個中轉站；桌面通知完全交給
# 「想在自己螢幕上看到通知的那台裝置」自己跑的這支訂閱器——每台都要各自裝一份：
# 對應的 launchd plist 是 com.tim80411.ntfy-desktop.plist，跑
#   ntfy subscribe <topic-url> ~/.claude/ntfy-desktop.sh
# 本檔就是那支 handler。目前只有使用者的筆電裝了這份；mini 如果哪天也想在自己
# 螢幕上收（例如有人坐在它前面），照同樣方式再裝一份即可，本次改動不做。
#
# 通知如果是某個 herdr pane 發出的（tags 帶 herdrhost_/herdrws_/herdrtab_，由
# notify_mobile.sh 塞入），點擊時會先 ssh 回那台機器把對應的 herdr workspace/tab
# 切到前面，再靠 terminal-notifier 的 -activate 把 Ghostty 帶到前景。
#
# env（ntfy subscribe 呼叫 handler 時注入）：$title $message $tags $topic
# 診斷用：NTFY_DESKTOP_DRY_RUN=1 只印出會執行的 terminal-notifier 參數，不真的發送
# （方便在還沒部署 launchd 的機器上，或不想真的彈通知時，先驗證解析邏輯對不對）。

[ -z "$message" ] && exit 0
LOG="$HOME/.claude/ntfy-desktop-received.log"
echo "$(date '+%F %T') recv title=[$title] msg=[$message] tags=[$tags]" >> "$LOG"

# 從 tags 拆出 herdrhost_/herdrws_/herdrtab_（notify_mobile.sh 塞進來的跳轉資訊）。
# tab id 本身可能含冒號（如 wA:t1）——實測 ntfy 會原樣保留在 tags 陣列裡（見
# notify_mobile.sh 改動當時的 curl 往返驗證），這裡不需要另外轉義或還原。
HOST=""; WS=""; TAB=""
IFS=',' read -ra _tags <<< "$tags"
for t in "${_tags[@]}"; do
  case "$t" in
    herdrhost_*) HOST="${t#herdrhost_}" ;;
    herdrws_*)   WS="${t#herdrws_}" ;;
    herdrtab_*)  TAB="${t#herdrtab_}" ;;
  esac
done

# 訊息理論上已經在 notify_mobile.sh 洗過 markdown，這裡再洗一次防呆（避免舊版
# 腳本、其他來源、或未來新增的發送端漏洗，殘留一堆星號反引號直接顯示出來）。
CLEAN_MSG=$(printf '%s' "$message" | sed -E -e 's/\*\*//g' -e 's/__//g' -e 's/`//g' -e 's/^#{1,6} //' -e 's/^> //' -e 's/^[-*] /• /')
# terminal-notifier 的 -message 若第一個字元是「[」會被誤判，補一個前導空白閃避。
case "$CLEAN_MSG" in
  \[*) CLEAN_MSG=" $CLEAN_MSG" ;;
esac

SUBTITLE="${HOST:-$topic}"
GROUP="ntfy-${HOST:-unknown}-${TAB:-$title}"

TN_ARGS=(-title "${title:-Claude}" -subtitle "$SUBTITLE" -message "$CLEAN_MSG" -group "$GROUP" -activate com.mitchellh.ghostty)
# 三個都有才知道要 ssh 去哪台、切哪個 workspace/tab；缺一個就不加 -execute，
# 靠 -activate 把 Ghostty 帶到前景就好。
if [ -n "$HOST" ] && [ -n "$WS" ] && [ -n "$TAB" ]; then
  EXEC_CMD="ssh -o BatchMode=yes -o ConnectTimeout=5 $HOST '/opt/homebrew/bin/herdr workspace focus $WS && /opt/homebrew/bin/herdr tab focus $TAB'"
  TN_ARGS+=(-execute "$EXEC_CMD")
fi
# 不加 -sound：用系統/ntfy 預設提示音，避免疊加。

if [ "$NTFY_DESKTOP_DRY_RUN" = "1" ]; then
  printf 'DRY_RUN terminal-notifier args:\n'
  printf '  %s\n' "${TN_ARGS[@]}"
  echo "$(date '+%F %T') -> dry-run host=${HOST:-none} ws=${WS:-none} tab=${TAB:-none}" >> "$LOG"
  exit 0
fi

/opt/homebrew/bin/terminal-notifier "${TN_ARGS[@]}" >/dev/null 2>&1
echo "$(date '+%F %T') -> terminal-notifier host=${HOST:-none} ws=${WS:-none} tab=${TAB:-none}" >> "$LOG"
