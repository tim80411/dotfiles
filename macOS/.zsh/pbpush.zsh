# ~/.zsh/pbpush.zsh
# 把「本機（MacBook）剪貼簿的圖片」推到 Mac mini（devbox）的剪貼簿，
# 讓遠端（mosh + tmux）裡的 Claude Code 按 Ctrl+V 能直接貼圖。
#
# 背景：CC 的 Ctrl+V 貼圖是執行 osascript 讀「CC 所在機器」的剪貼簿；
#       mosh/tmux 這類終端協定只傳文字 bytes，圖片過不去，
#       所以唯一斷點是 MacBook 剪貼簿 → mini 剪貼簿 這段同步——本函式補上它。
# 用法：截圖到剪貼簿（Cmd+Ctrl+Shift+4）→ 跑 pbpush → 遠端 CC 按 Ctrl+V。
# 主機別名沿用 cmux-mini.zsh 的 DEVBOX_HOST（來自 secret bundle 的 notify.env）。
# 由 ~/.zshrc 一行 source 進來（沿用 ~/.zsh/*.zsh 模組慣例）。

pbpush() {
  emulate -L zsh
  local host="${DEVBOX_HOST:-$( . "$HOME/.config/dotfiles/notify.env" 2>/dev/null; printf '%s' "$DEVBOX_HOST" )}"
  [[ -n "$host" ]] || { print -r -- "pbpush: DEVBOX_HOST 未設定（見 cmux-mini.zsh 註解）" >&2; return 1 }

  # 本機剪貼簿 → PNG 暫存檔（與 CC binary 內部同一招；剪貼簿沒圖時 osascript 會失敗）
  local tmpdir file
  tmpdir="$(mktemp -d -t pbpush)" || return 1
  file="$tmpdir/clip.png"
  if ! osascript \
      -e 'set png_data to (the clipboard as «class PNGf»)' \
      -e "set fp to open for access POSIX file \"$file\" with write permission" \
      -e 'write png_data to fp' \
      -e 'close access fp' 2>/dev/null; then
    rm -rf "$tmpdir"
    print -r -- "pbpush: 剪貼簿裡沒有圖片（先 Cmd+Ctrl+Shift+4 截圖到剪貼簿）" >&2
    return 1
  fi

  # 走 ssh 管線送到 mini 並塞進它的剪貼簿（fixed path 避開遠端 quoting；用完即刪）
  # ConnectTimeout：pbwatch daemon 自動觸發時，mini 離線要快速失敗而非久等
  if ssh -o ConnectTimeout=3 "$host" 'cat > /tmp/pbpush.png &&
      osascript -e "set the clipboard to (read (POSIX file \"/tmp/pbpush.png\" as alias) as «class PNGf»)" &&
      rm -f /tmp/pbpush.png' < "$file"; then
    print -r -- "pbpush: ✅ 已推到 ${host} 剪貼簿 → 遠端 Claude Code 按 Ctrl+V 貼上"
    rm -rf "$tmpdir"
  else
    print -r -- "pbpush: ❌ 推送失敗（檢查 ssh ${host} 是否可連）" >&2
    rm -rf "$tmpdir"
    return 1
  fi
}
