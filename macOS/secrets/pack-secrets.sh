#!/usr/bin/env bash
# ============================================================
# pack-secrets.sh — 把機密打包並上傳到 Bitwarden
# ============================================================
# 何時跑:新增/輪替了某個機密(換 SSH key、換 token…),或換機前想刷新備份時。
# 日常「改設定 → git push」用不到這支。
#
# 為什麼不用 age/git-crypt:Bitwarden 附件本身就在伺服器端加密存放,
# 你的主密碼(記在腦中)就是根信任 —— 機密全程不碰任何 git repo(公開或私有)。

set -euo pipefail

C_G="\033[1;32m"; C_Y="\033[1;33m"; C_R="\033[1;31m"; C_N="\033[0m"
info(){ printf "${C_Y}==>${C_N} %s\n" "$1"; }
ok(){   printf "${C_G}ok${C_N}  %s\n" "$1"; }
die(){  printf "${C_R}error${C_N} %s\n" "$1" >&2; exit 1; }

source "$(dirname "$0")/secret-paths.sh"

for bin in bw jq tar; do
  command -v "$bin" >/dev/null 2>&1 || die "$bin 未安裝(brew install $bin)"
done

# --- 1) 打包「存在的」機密路徑 ---
present=()
for p in "${SECRET_PATHS[@]}"; do [ -e "$HOME/$p" ] && present+=("$p"); done
[ "${#present[@]}" -gt 0 ] || die "沒有找到任何機密路徑可打包"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
archive="$tmp/$DOTFILES_SECRETS_ARCHIVE"
info "打包 ${#present[@]} 個機密路徑…"
# -p 保留權限位(600/700);排除清單見 secret-paths.sh。
# tar 遇到 runtime socket 之類無法打包的檔會回傳 1(僅警告);≤1 視為成功,>1 才是真失敗。
set +e
tar -czpf "$archive" "${SECRET_TAR_EXCLUDES[@]}" -C "$HOME" "${present[@]}"
rc=$?
set -e
[ "$rc" -le 1 ] || die "tar 打包失敗(exit $rc)"
ok "已打包 $(du -h "$archive" | cut -f1) → $DOTFILES_SECRETS_ARCHIVE"

# --- 2) 解鎖 Bitwarden(互動輸入主密碼一次)---
bw login --check >/dev/null 2>&1 || die "尚未登入 Bitwarden,請先跑一次 'bw login'"
UNLOCKED_HERE=0
if [ -z "${BW_SESSION:-}" ]; then
  info "解鎖 Bitwarden(輸入主密碼)"
  export BW_SESSION="$(bw unlock --raw)"
  UNLOCKED_HERE=1
fi
bw sync >/dev/null

# --- 3) 找/建放機密包的 item ---
raw="$(bw get item "$DOTFILES_SECRETS_ITEM" 2>/dev/null || true)"
item_id=""
[ -n "$raw" ] && item_id="$(printf '%s' "$raw" | jq -r '.id // empty')"
if [ -z "$item_id" ]; then
  info "Bitwarden 沒有 '$DOTFILES_SECRETS_ITEM',幫你建一個 Secure Note…"
  item_id="$(bw get template item \
    | jq --arg n "$DOTFILES_SECRETS_ITEM" \
        '.type=2 | .name=$n | .notes="dotfiles 機密包(由 pack-secrets.sh 管理)" | .secureNote={"type":0} | del(.login,.card,.identity)' \
    | bw encode | bw create item | jq -r '.id')"
  ok "已建立 item($item_id)"
fi

# --- 4) 刪舊附件、上傳新的(bw 附件是 add-only,更新=先刪再加)---
raw="$(bw get item "$DOTFILES_SECRETS_ITEM")"
old_att="$(printf '%s' "$raw" | jq -r --arg f "$DOTFILES_SECRETS_ARCHIVE" \
  '.attachments[]? | select(.fileName==$f) | .id' | head -1)"
if [ -n "$old_att" ]; then
  info "刪除舊附件…"
  bw delete attachment "$old_att" --itemid "$item_id" >/dev/null
fi
info "上傳新機密包到 Bitwarden…"
bw create attachment --file "$archive" --itemid "$item_id" >/dev/null
ok "已上傳 $DOTFILES_SECRETS_ARCHIVE → item '$DOTFILES_SECRETS_ITEM'"

# --- 5) 收尾(只在這支腳本自己解鎖時才 lock,避免打斷你既有 session)---
[ "$UNLOCKED_HERE" -eq 1 ] && bw lock >/dev/null 2>&1 || true
ok "完成。機密包已是最新;換機時用 bootstrap-secrets.sh 拉回。"
