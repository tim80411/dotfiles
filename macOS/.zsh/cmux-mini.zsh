# ~/.zsh/cmux-mini.zsh
# cmux workspace 命名 + Mac mini 遠端開發（devbox）。
# 由 ~/.zshrc 一行 source 進來（沿用既有 ~/.zsh/*.zsh 模組慣例，如 wifi-helpers.zsh）。
# 完整 runbook：~/self/misc/survey-report/2026-07-11-mac-mini-remote-dev/README.md

# ── 設定（可調；必須放在 _cmux_auto_name 之前，guard 會引用 DEVBOX_WS_PREFIX）──
# 私有主機名（Tailscale 別名）不進 public dotfiles repo：從 secret bundle 的 notify.env 取
# 專屬 key DEVBOX_HOST（用 subshell 取值，避免把 NTFY_* 等變數污染到互動 shell env）。
# 缺 notify.env / key 就留空（devbox 會連不到，請補上 secret bundle 或直接 export DEVBOX_HOST）。
DEVBOX_HOST="${DEVBOX_HOST:-$( . "$HOME/.config/dotfiles/notify.env" 2>/dev/null; printf '%s' "$DEVBOX_HOST" )}"
DEVBOX_WS_PREFIX="🖥"          # devbox tab 的醒目前綴；tab 命名成「<前綴> <session>」如「🖥 web」
DEVBOX_WS_COLOR="Aqua"        # devbox tab 的 workspace 顏色（cmux 具名色；左側色條一眼分辨）
DEVBOX_WS_CWD="$HOME"         # devbox tab 的 workspace cwd（決定通知/側欄灰路徑；只能是真實本機資料夾）
DEVBOX_DEFAULT=(main)         # 'devbox tab' 不給參數時要開的 session 清單

# 由 cwd/git 推導 workspace 名（_cmux_auto_name 與「前景 devbox 離開後還原」共用）
_cmux_derive_name() {
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    local project=$(basename "$(git rev-parse --show-toplevel)")
    local branch=$(git symbolic-ref --short HEAD 2>/dev/null | tr '/' '-')
    printf '%s' "${project}/${branch:-detached}"
  else
    printf '%s' "${PWD##*/}"
  fi
}

# ── cmux：依 git project/branch 自動把 workspace 命名 ─────────
# guard：若目前 workspace 名已是「<DEVBOX_WS_PREFIX> 」開頭（devbox 釘的名），就「不覆蓋」——
#        這解掉 devbox 命名被 auto-name 蓋掉的 race（不必靠 sleep/重試搶時機）。
# 整段背景化：chpwd 不因 socket / git 呼叫卡住 prompt。
if [[ -n "$CMUX_WORKSPACE_ID" ]]; then
  _cmux_auto_name() {
    {
      local cur
      cur=$(CMUX_QUIET=1 cmux workspace list --id-format both 2>/dev/null \
        | awk -v id="$CMUX_WORKSPACE_ID" 'index($0,id){p=index($0,id)+length(id);s=substr($0,p);gsub(/^[ \t]+|[ \t]+$/,"",s);sub(/[ \t]*\[selected\]$/,"",s);print s}')
      [[ "$cur" == "${DEVBOX_WS_PREFIX} "* ]] && return   # devbox 釘的名 → 不覆蓋
      cmux workspace-action --action rename --title "$(_cmux_derive_name)" &>/dev/null
    } &>/dev/null &
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _cmux_auto_name
  _cmux_auto_name   # 新 workspace 開啟時也命名一次
fi

# ── cmux：開新 workspace 並自動命名（cw [dir]）───────────────
cw() {
  local dir="${1:-.}"
  dir="$(cd "$dir" 2>/dev/null && pwd)" || return 1
  local name
  if git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
    local project=$(basename "$(git -C "$dir" rev-parse --show-toplevel)")
    local branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null | tr '/' '-')
    name="${project}/${branch:-detached}"
  else
    name="${dir##*/}"
  fi
  cmux new-workspace --cwd "$dir" --command "cmux workspace-action --action rename --title '${name}'"
}

# ── Ghostty + tmux：DCS passthrough 送 OSC 7，讓新 Tab/Split 拿得到 cwd ──
# （tmux 會把 TERM_PROGRAM 覆蓋為 "tmux"，故改用 client_termname 偵測）
if [[ -n "$TMUX" ]] && [[ "$(tmux display-message -p '#{client_termname}' 2>/dev/null)" == *ghostty* ]]; then
  _ghostty_osc7_passthrough() {
    printf '\ePtmux;\e\e]7;file://%s%s\a\e\\' "${HOST}" "${PWD}"
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _ghostty_osc7_passthrough
  _ghostty_osc7_passthrough
fi

# ── Mac mini 遠端開發（mosh + tmux + cmux）─────────────────────
# 一個開頭 devbox，用子指令分「進去（前景）」與「開 cmux tab（背景 orchestration）」：
#   devbox             → 在當前終端機前景 mosh 進 main session（不給名字=main）
#   devbox <session>   → 前景進指定 session（要多個獨立就給不同名字）
#   devbox ls          → 列出 mini 上現有 session（不用連進去）
#   devbox all         → 把 mini「已存在」的所有 session 各開成一個 cmux workspace（冪等）
#   devbox tab a b c   → 把指定 session 各開成一個 cmux workspace（命名「🖥 <session>」+ 上色，冪等）
# 保留字：ls / all / tab 為子指令；session 名請用其它簡單識別字（英數/底線/連字號）。
# 所有 devbox 用法（含前景）都會把 cmux tab 標成「🖥 <session>」+ Aqua 色，一眼認得出；
# 前景 devbox 離開後會自動還原成本機 cwd 推導名、清色。
devbox() {
  case "${1:-main}" in
    ls)  shift; ssh "$DEVBOX_HOST" tmux ls ;;
    all) shift; _devbox_tabs_all ;;
    tab) shift; _devbox_tabs "$@" ;;
    *)   _devbox_connect "${1:-main}" ;;
  esac
}

# 把一個 workspace 標成 devbox 專屬（醒目 title + 顏色）；冪等。
_devbox_mark_ws() {  # $1=workspace ref/id  $2=session
  CMUX_QUIET=1 cmux rename-workspace --workspace "$1" "${DEVBOX_WS_PREFIX} ${2}" >/dev/null 2>&1
  CMUX_QUIET=1 cmux workspace-action --action set-color --color "$DEVBOX_WS_COLOR" --workspace "$1" >/dev/null 2>&1
}
# 還原一個 workspace（用 cwd 推導名 + 清色）——給「前景 devbox 離開後」用。
_devbox_unmark_ws() {  # $1=workspace ref/id
  CMUX_QUIET=1 cmux rename-workspace --workspace "$1" "$(_cmux_derive_name)" >/dev/null 2>&1
  CMUX_QUIET=1 cmux workspace-action --action clear-color --workspace "$1" >/dev/null 2>&1
}

# 前景：在當前終端機 mosh 進一個 session。
# 轉送當前 cmux workspace id → mini 的 per-session 專屬檔（多開精準路由）＋舊單檔 fallback；
# 在 cmux pane 內 → 連線期間把這個 tab 標成「🖥 <session>」+ 色（醒目），離開後自動還原。
_devbox_connect() {
  local s="${1:-main}"
  ssh "$DEVBOX_HOST" "printf '%s' '${CMUX_WORKSPACE_ID:-}' > ~/.claude/laptop_cmux_ws_${s}; printf '%s' '${CMUX_WORKSPACE_ID:-}' > ~/.claude/laptop_cmux_ws" 2>/dev/null
  [ -n "$CMUX_WORKSPACE_ID" ] && _devbox_mark_ws "$CMUX_WORKSPACE_ID" "$s"
  mosh "$DEVBOX_HOST" -- tmux new -A -s "$s"
  [ -n "$CMUX_WORKSPACE_ID" ] && _devbox_unmark_ws "$CMUX_WORKSPACE_ID"
}

# 開 cmux tab：把每個 session 開成一個 workspace（命名「🖥 <session>」+ 上色），冪等（已開就聚焦）。
# 命名不需 sleep/重試——靠 --name ＋ _cmux_auto_name 的 guard（名字是「🖥 」開頭就不被覆蓋）。
# 每個新 workspace 內跑 `devbox <session>` → 走到 _devbox_connect 前景進該 session。
_devbox_tabs() {
  local -a sessions
  if (( $# )); then sessions=("$@"); else sessions=("${DEVBOX_DEFAULT[@]}"); fi
  local list first_ref="" s name ref uuid info
  list=$(CMUX_QUIET=1 cmux workspace list --id-format both 2>/dev/null)
  for s in "${sessions[@]}"; do
    name="${DEVBOX_WS_PREFIX} ${s}"
    # 找既有同名 workspace 的 ref + uuid（名字含空白，故比對「uuid 之後的整段」而非單一欄位）
    info=$(print -r -- "$list" | awk -v n="$name" '{r="";u="";for(j=1;j<=NF;j++){if($j ~ /^workspace:[0-9]+$/)r=$j;if($j ~ /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/)u=$j}if(u){p=index($0,u);nm=substr($0,p+length(u));gsub(/^[ \t]+|[ \t]+$/,"",nm);sub(/[ \t]*\[selected\]$/,"",nm);if(nm==n&&r){print r" "u;exit}}}')
    ref="${info%% *}"; uuid="${info#* }"; [ "$uuid" = "$ref" ] && uuid=""
    if [ -n "$ref" ]; then
      # 已存在→聚焦；刷新該 workspace 現在的 id 到 mini（cmux 重啟換 id / 路由檔被清也能精準跳回）+ 確保標記
      [ -n "$uuid" ] && [ -n "$DEVBOX_HOST" ] && \
        ssh "$DEVBOX_HOST" "printf '%s' '$uuid' > ~/.claude/laptop_cmux_ws_${s}" 2>/dev/null
      _devbox_mark_ws "$ref" "$s"
      print -r -- "→ ${name}  (${ref}, 已存在→聚焦・刷新路由)"
    else
      # 新開：pane 內跑的 devbox <s> → _devbox_connect 會轉送「這個新 workspace 自己的 id」，故此處不必再送。
      ref=$(CMUX_QUIET=1 cmux new-workspace --name "$name" --cwd "$DEVBOX_WS_CWD" --command "devbox ${s}" --focus false 2>/dev/null \
            | grep -oE 'workspace:[0-9]+' | head -1)
      [ -n "$ref" ] && _devbox_mark_ws "$ref" "$s"   # title 已由 --name 設，這裡主要補上色
      print -r -- "→ ${name}  (${ref:-建立失敗?}, 新開)  接 tmux '${s}'"
    fi
    [ -z "$first_ref" ] && first_ref="$ref"
  done
  [ -n "$first_ref" ] && CMUX_QUIET=1 cmux select-workspace --workspace "$first_ref" >/dev/null 2>&1
}

# 開 cmux tab（既有全部）：抓 mini 上所有既有 tmux session → 各開一個 workspace（冪等，靠 _devbox_tabs）。
_devbox_tabs_all() {
  local existing
  existing=$(ssh "$DEVBOX_HOST" "tmux ls -F '#S'" 2>/dev/null)
  if [ -z "$existing" ]; then
    print -r -- "mini（$DEVBOX_HOST）上目前沒有 tmux session。用 'devbox <名字>' 進去會自動建立一個。"
    return 1
  fi
  local -a sess
  sess=(${(f)existing})
  print -r -- "mini 既有 session：${sess[*]}"
  _devbox_tabs "${sess[@]}"
}

# 退役備援（launchd com.tim80411.ntfy-desktop 為通知主力、always-on，以下 in-pane workaround 已不需要）：
# 若哪天 launchd 掛了要臨時手動接通知，指令在 runbook 的通知段。
