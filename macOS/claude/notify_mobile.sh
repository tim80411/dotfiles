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
  # 2026-09-13：桌面通知解耦後這則 MESSAGE 同時也是桌面顯示來源，放寬到 300 bytes、
  # 保留換行；並先洗掉常見 markdown 記法（終端機／手機通知不會渲染 markdown，留著
  # 只會顯示一堆星號反引號）：**、__ 去掉、反引號去掉、行首 #+ 、行首 > 去掉、
  # 行首 -／* 換成 •。sed 逐行處理，多行訊息每一行都會套用。
  MESSAGE="${LAST_MSG:+$(printf '%s' "$LAST_MSG" | head -c 300 | iconv -f UTF-8 -t UTF-8 -c 2>/dev/null | \
    sed -E -e 's/\*\*//g' -e 's/__//g' -e 's/`//g' -e 's/^#{1,6} //' -e 's/^> //' -e 's/^[-*] /• /')}"
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

# 2026-09-13 解耦：桌面通知不再由本腳本直接發，改由各裝置自己的 ntfy 訂閱器
# （ntfy-desktop.sh）負責；這裡只負責把「這則通知是哪個 herdr pane 發的、點擊要
# 跳去哪裡」塞進 tags，讓訂閱器解析。H 優先用上面已經算好的 TAILSCALE_HOST
# （跨機器可解析的短名），沒有才退回 hostname -s。
# tab id 可能含冒號（如 wA:t1）——實測 ntfy 會原樣保留在 tags 陣列裡，不需要轉義
# 或用 - 代替（2026-09-13 curl 往返驗證過，見回報）。
if [ -n "$HERDR_PANE_ID" ]; then
  _herdr_host="${TAILSCALE_HOST:-$(hostname -s)}"
  TAGS="${TAGS},herdrhost_${_herdr_host},herdrws_${HERDR_WORKSPACE_ID},herdrtab_${HERDR_TAB_ID}"
fi

TOPIC="claude_$(whoami)_$(hostname -s | tr '[:upper:]' '[:lower:]')"


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

# 桌面通知：改由各裝置自己的 ntfy 訂閱器負責（2026-09-13 解耦，取代先前 herdr/
# terminal-notifier/OSC 777 三輪嘗試）——
#   使用者實際是在筆電操作，透過 ssh/mosh 連進這台 mini；不管是 mini 本機跳
#   terminal-notifier、還是 herdr 的 OSC 9，都只解決得了「mini 自己螢幕上」的通知，
#   對筆電使用者沒用。改成 mini 這支 hook 只管把訊息＋跳轉用的
#   herdrhost_/herdrws_/herdrtab_ tags（見上方 TAGS 組裝）推上 ntfy 當中轉站；
#   使用者的筆電（以及任何其他訂閱這個 topic 的裝置）各自跑一份
#   ~/.claude/ntfy-desktop.sh（launchd: com.tim80411.ntfy-desktop），收到後解析
#   tags、呼叫「自己那台機器」的 terminal-notifier，點擊時再經 ssh 連回 mini 執行
#   herdr workspace/tab focus。本腳本到此為止，不再直接呼叫任何桌面通知指令。

# ─────────────────────────────────────────────────────────────────────────────
# herdr sidebar 狀態回報（2026-08-04 實驗；append-only，上方邏輯完全未改）
# 目的：讓 herdr sidebar 顯示等同 cmux 圖中的「狀態圖示 + 狀態文字」。
# 評估文件：筆電 ~/self/misc/survey-report/2026-08-04-herdr-vs-cmux/migration-assessment.md
#
# 為什麼需要兩個指令（實測結論，非文件推測）：
#   report-agent    → 給語意狀態（sidebar 圖示顏色，且會 roll up 到 workspace 層）
#   report-metadata → 給顯示文字。report-agent 的 --message 實測「不會顯示在任何地方」
#                     （只存進內部欄位，無讀取點）；保留只為了介面相容，要在 sidebar
#                     常駐顯示文字必須走 report-metadata 的 $summary token。
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
