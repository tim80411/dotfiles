# ~/.zsh/laptop-open.zsh
# 在 mini（devbox）上執行：把檔案推到筆電並用預設 App 打開。
# 用途：遠端 (mosh+tmux) Claude Code 產出的文件，一個指令彈到 MacBook 螢幕上閱讀：
#   laptop-open report.md [more files...]
# （pbpush 的鏡像：pbpush 是筆電剪貼簿→mini；本指令是 mini 檔案→筆電開啟）
# 主機別名：LAPTOP_HOST（~/.config/dotfiles/notify.env，同 DEVBOX_HOST 模式，
#           私有主機名不進 public repo）。
# 需求：筆電開 Remote Login、mini 的金鑰已授權（2026-07-20 驗證已通）。
# 由 ~/.zshrc 一行 source 進來（沿用 ~/.zsh/*.zsh 模組慣例）。

laptop-open() {
  emulate -L zsh
  local host="${LAPTOP_HOST:-$( . "$HOME/.config/dotfiles/notify.env" 2>/dev/null; printf '%s' "$LAPTOP_HOST" )}"
  [[ -n "$host" ]] || { print -r -- "laptop-open: LAPTOP_HOST 未設定（~/.config/dotfiles/notify.env）" >&2; return 1 }
  (( $# )) || { print -r -- "用法：laptop-open <file> [file...]" >&2; return 1 }

  local dest="Downloads/mini-docs"
  ssh -o ConnectTimeout=4 "$host" "mkdir -p ~/$dest" || { print -r -- "laptop-open: 連不上 ${host}" >&2; return 1 }

  local f abs base rc=0
  for f in "$@"; do
    abs="${f:A}"   # 解析成絕對路徑（支援相對路徑，遠端 CC 的 cwd 直接可用）
    [[ -e "$abs" ]] || { print -r -- "laptop-open: 找不到 $f" >&2; rc=1; continue }
    base="${abs:t}"
    # ${(q)base}：檔名含空白/中文時，餵給遠端 shell 前先做 zsh quoting
    if scp -q -r "$abs" "${host}:~/$dest/" && ssh "$host" "open ~/$dest/${(q)base}"; then
      print -r -- "laptop-open: ✅ ${base} 已在筆電開啟（存於 ~/${dest}/）"
    else
      print -r -- "laptop-open: ❌ ${f} 推送或開啟失敗" >&2; rc=1
    fi
  done
  return $rc
}
