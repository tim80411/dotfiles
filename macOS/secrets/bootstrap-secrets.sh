#!/usr/bin/env bash
# ============================================================
# bootstrap-secrets.sh — 新機:從 Bitwarden 拉回機密並還原到 $HOME
# ============================================================
# 何時跑:新機跑完 install.sh(裝好 bw/jq、環境就緒)之後,執行這支把機密還原。
# 前提:先 'bw login'(並確認 bw config server 指向你的自架 vault)。

set -euo pipefail

C_G="\033[1;32m"; C_Y="\033[1;33m"; C_R="\033[1;31m"; C_N="\033[0m"
info(){ printf "${C_Y}==>${C_N} %s\n" "$1"; }
ok(){   printf "${C_G}ok${C_N}  %s\n" "$1"; }
die(){  printf "${C_R}error${C_N} %s\n" "$1" >&2; exit 1; }

# bootstrap 只需要 item 名與附件名,不需要 pack 的完整路徑清單 —— 所以自帶預設,
# 讓 `bash <(curl ...)` 也能直接跑(那時旁邊沒有 secret-paths.sh 可 source)。
# 這兩個預設必須與 secret-paths.sh 一致;要覆蓋就設環境變數。
DOTFILES_SECRETS_ITEM="${DOTFILES_SECRETS_ITEM:-dotfiles-secrets}"
DOTFILES_SECRETS_ARCHIVE="${DOTFILES_SECRETS_ARCHIVE:-dotfiles-secrets.tar.gz}"
# 若在 ~/bin 本機執行、旁邊剛好有 secret-paths.sh,就 source 它以維持單一真相(curl 直跑會略過)。
_sp="$(dirname "$0")/secret-paths.sh"
if [ -f "$_sp" ]; then source "$_sp"; fi

for bin in bw jq tar; do
  command -v "$bin" >/dev/null 2>&1 || die "$bin 未安裝(先跑 install.sh 讓 brew bundle 裝好)"
done

# --- 1) 解鎖 Bitwarden ---
bw login --check >/dev/null 2>&1 || die "尚未登入 Bitwarden:先 'bw config server <你的 vault>' 再 'bw login'"
UNLOCKED_HERE=0
if [ -z "${BW_SESSION:-}" ]; then
  info "解鎖 Bitwarden(輸入主密碼)"
  export BW_SESSION="$(bw unlock --raw)"
  UNLOCKED_HERE=1
fi
bw sync >/dev/null

# --- 2) 取得機密附件 ---
raw="$(bw get item "$DOTFILES_SECRETS_ITEM" 2>/dev/null || true)"
[ -n "$raw" ] || die "Bitwarden 找不到 item '$DOTFILES_SECRETS_ITEM' —— 先在有機密的機器上跑 pack-secrets.sh"
item_id="$(printf '%s' "$raw" | jq -r '.id // empty')"
att_id="$(printf '%s' "$raw" | jq -r --arg f "$DOTFILES_SECRETS_ARCHIVE" \
  '.attachments[]? | select(.fileName==$f) | .id' | head -1)"
[ -n "$att_id" ] || die "item 底下沒有附件 '$DOTFILES_SECRETS_ARCHIVE' —— 先跑 pack-secrets.sh 上傳"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
archive="$tmp/$DOTFILES_SECRETS_ARCHIVE"
info "從 Bitwarden 下載機密包…"
bw get attachment "$att_id" --itemid "$item_id" --output "$archive" >/dev/null
ok "已下載 $(du -h "$archive" | cut -f1)"

# --- 3) 還原到 $HOME(-p 保留權限位)---
info "還原到 $HOME …"
set +e
tar -xzpf "$archive" -C "$HOME"
rc=$?
set -e
[ "$rc" -le 1 ] || die "tar 解開失敗(exit $rc)"
ok "已解開機密包"

# --- 4) 修正權限(tar -p 通常會保留,但保險起見再夾一次)---
chmod 700 ~/.ssh ~/.gnupg ~/.aws 2>/dev/null || true
chmod 600 ~/.ssh/* 2>/dev/null || true
chmod 644 ~/.ssh/*.pub 2>/dev/null || true
find ~/.gnupg -type d -exec chmod 700 {} \; 2>/dev/null || true
find ~/.gnupg -type f -exec chmod 600 {} \; 2>/dev/null || true
find ~/.aws -type f -exec chmod 600 {} \; 2>/dev/null || true
chmod 600 ~/.netrc ~/.npmrc ~/.git-credentials 2>/dev/null || true
chmod -R go-rwx ~/.oci ~/.cloudflared ~/.shioaji ~/.atlas ~/.mcp-auth 2>/dev/null || true
ok "已修正機密檔權限"

# --- 5) 收尾 ---
[ "$UNLOCKED_HERE" -eq 1 ] && bw lock >/dev/null 2>&1 || true
cat <<'EOF'

機密已還原。接下來(依需要):
  - 驗證憑證:ssh -T git@github.com · gh auth status · aws sts get-caller-identity · gpg --list-secret-keys
  - 排程 plist 已就位,但要對應腳本(git repo)clone 到同路徑後才 load:
      launchctl load ~/Library/LaunchAgents/com.*.plist
EOF
