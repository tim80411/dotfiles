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
#
# NTFY_TOKEN（notify.env 帶入，帳號 claude-notify）：$NTFY_HOST 目前仍是
# auth-default-access: read-write，匿名發得出去，所以這個標頭現在是 no-op。
# 但 ZHI-83 要把它翻成 read-only(#92) 再翻成 deny-all(#91)——翻下去之後沒有
# 這個標頭就是 403，而失敗形狀是安靜的：curl 背景化，只往 notify_mobile.log
# 寫一行，手機單純不再響。
#
# ${NTFY_TOKEN:+...} 守衛：token 沒設時整個參數不展開（不會送出空的 Bearer）。
# 已驗 bash/dash 下都只展開成單一參數。
#
# ⚠️ URL 一定要明確帶 https://，不可以靠 -L 從 http:// 跟著 308 跳。
# curl 在 scheme 改變（換 origin）時會主動剝掉 Authorization
# （CVE-2018-1000007 之後的既定防護），實測同一把假 token：
#   明確 https://…      → 401（標頭到得了 server）
#   -L + 不含 scheme    → 200（標頭被剝掉，退回匿名）
# 本行已經是明確 https://，維持這樣。
if [ -n "$NTFY_HOST" ]; then
(
  NTFY_CODE=$(curl -s -m 8 -o /dev/null -w '%{http_code}' \
    -H "Title: $TITLE" \
    -H "Priority: $PRIORITY" \
    -H "Tags: $TAGS" \
    -H "Click: ssh://${TAILSCALE_USER}@${TAILSCALE_HOST}" \
    ${NTFY_TOKEN:+-H "Authorization: Bearer $NTFY_TOKEN"} \
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

# ─────────────────────────────────────────────────────────────────────────────
# herdr sidebar 狀態回報（2026-08-04 實驗；append-only，上方邏輯完全未改）
# 目的：讓 herdr sidebar 顯示等同 cmux 圖中的「狀態圖示 + 狀態文字」。
# 評估文件：筆電 ~/self/misc/survey-report/2026-08-04-herdr-vs-cmux/migration-assessment.md
#
# 為什麼需要兩個指令（實測結論，非文件推測）：
#   report-agent    → 給語意狀態（sidebar 圖示顏色，且會 roll up 到 workspace 層）
#   report-metadata → 給顯示文字。report-agent 的 --message 實測「不會」存進 agent 物件，
#                     只影響 toast；要在 sidebar 常駐顯示文字必須走 $summary token。
# 為什麼 --seq 一定要給且單調遞增（實測）：
#   同一個 seq 再推 → 被當 stale 忽略；完全省略 --seq → 也被忽略。
#   所以用毫秒時戳（perl；此機沒有 gdate）。
# 為什麼用兩個不同的 --source：
#   seq 是 per-source 計數，兩個指令共用同一 source + 同一 seq 會讓後者被判 stale。
#
# 要停用整段：把 HERDR_REPORT_DISABLED=1 export 出來，或直接刪除本區塊。
# 還原原始檔：cp ~/.claude/notify_mobile.sh.pre-herdr.bak ~/.claude/notify_mobile.sh
# ─────────────────────────────────────────────────────────────────────────────
if [ -n "$HERDR_PANE_ID" ] && [ "$HERDR_REPORT_DISABLED" != "1" ] && command -v herdr >/dev/null 2>&1; then
  HLOG="$HOME/.claude/herdr-report.log"

  # 單調遞增的毫秒 seq
  HSEQ=$(perl -MTime::HiRes -e 'printf "%d", Time::HiRes::time()*1000' 2>/dev/null)
  [ -z "$HSEQ" ] && HSEQ=$(date +%s)

  # Claude Code hook 事件 → herdr 語意狀態
  case "$NOTIFICATION_TYPE" in
    permission_prompt|idle_prompt) HSTATE=blocked ;;
    *)
      if [ "$HOOK_EVENT" = "Stop" ]; then HSTATE=idle   # herdr 會在「你沒看到」時自動轉 done
      else HSTATE=unknown; fi
      ;;
  esac

  # sidebar 顯示文字：優先用 Claude Code 原生 .message（就是 cmux 圖中那行英文），
  # 沒有時退回自組的中文 TITLE。
  # 壓成單行：Claude Code 的 last_assistant_message 常含換行，直接塞進 sidebar 會弄壞版面
  # （實測 herdr-report.log 12:13:54 那筆就是多行）。順便把連續空白收斂成一個。
  HSUMMARY=$(printf '%s' "${MESSAGE:-$TITLE}" | tr '\n\r\t' '   ' | sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//')

  herdr pane report-agent "$HERDR_PANE_ID" \
    --source claude-hook-state --agent claude \
    --state "$HSTATE" --message "$HSUMMARY" --seq "$HSEQ" >/dev/null 2>>"$HLOG" \
    || printf '%s report-agent FAILED pane=%s state=%s\n' "$(date '+%F %T')" "$HERDR_PANE_ID" "$HSTATE" >>"$HLOG"

  herdr pane report-metadata "$HERDR_PANE_ID" \
    --source claude-hook-text \
    --token summary="$HSUMMARY" --seq "$HSEQ" >/dev/null 2>>"$HLOG" \
    || printf '%s report-metadata FAILED pane=%s\n' "$(date '+%F %T')" "$HERDR_PANE_ID" >>"$HLOG"

  printf '%s ok pane=%s state=%s seq=%s summary=[%s]\n' \
    "$(date '+%F %T')" "$HERDR_PANE_ID" "$HSTATE" "$HSEQ" "$HSUMMARY" >>"$HLOG"
fi
