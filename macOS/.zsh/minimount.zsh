# ~/.zsh/minimount.zsh
# 一鍵掛載 mini（devbox）家目錄到本機 /Volumes/tim80411（SMB over Tailscale）。
# 用途：瀏覽/Quick Look mini 上的檔案、讓本機 CC 用 /Volumes/... 路徑原生讀取。
# 首次掛載已把密碼存入鑰匙圈（2026-07-20），之後掛載全自動免密。
# macOS 的 SMB 掛載在「筆電睡醒/換網路」後常 stale——斷了就再跑一次 minimount。
# 主機別名沿用 cmux-mini.zsh 的 DEVBOX_HOST（secret bundle notify.env）。
# 由 ~/.zshrc 一行 source 進來（沿用 ~/.zsh/*.zsh 模組慣例）。

MINIMOUNT_SHARE="tim80411"   # mini 端分享點名稱（= 家目錄 /Users/tim80411）

minimount() {
  emulate -L zsh
  local vol="/Volumes/${MINIMOUNT_SHARE}"
  if mount | grep -q "on ${vol} (smbfs"; then
    print -r -- "minimount: 已掛載 → ${vol}"
    return 0
  fi
  local host="${DEVBOX_HOST:-$( . "$HOME/.config/dotfiles/notify.env" 2>/dev/null; printf '%s' "$DEVBOX_HOST" )}"
  [[ -n "$host" ]] || { print -r -- "minimount: DEVBOX_HOST 未設定（見 cmux-mini.zsh 註解）" >&2; return 1 }

  open "smb://${USER}@${host}/${MINIMOUNT_SHARE}" || return 1
  # Finder 掛載是非同步的（鑰匙圈免密約 1~3 秒），輪詢最多 10 秒
  local i
  for i in {1..20}; do
    mount | grep -q "on ${vol} (smbfs" && { print -r -- "minimount: ✅ ${vol}"; return 0 }
    sleep 0.5
  done
  print -r -- "minimount: ⚠️ 已觸發掛載但 10 秒內未完成（檢查 Tailscale / mini 是否在線）" >&2
  return 1
}

# 卸載（要拔除前、或掛載 stale 想重掛時先跑這個）
miniumount() {
  emulate -L zsh
  diskutil unmount "/Volumes/${MINIMOUNT_SHARE}"
}
