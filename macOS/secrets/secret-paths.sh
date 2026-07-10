#!/usr/bin/env bash
# ============================================================
# secret-paths.sh — 機密清單(pack 與 bootstrap 共用的唯一真相)
# ============================================================
# 這裡列出「要跟著你換機、但不進 public dotfiles repo」的機密路徑。
# pack-secrets.sh 打包這些、bootstrap-secrets.sh 還原這些。
#
# 設計重點:
#   - 路徑相對於 $HOME。「不存在的路徑會自動略過」,所以可以放心多列。
#   - 列的是整個目錄(如 .ssh),所以你新增一把 key 不用改這裡,打包時自動含進去。
#   - 這個檔本身「不含任何機密」,放 public repo 完全安全(它只是一份路徑清單)。

# Bitwarden 裡存放機密包的 item 名稱(非機密,可公開)。
# 要換名稱就設環境變數:export DOTFILES_SECRETS_ITEM="my-item"
DOTFILES_SECRETS_ITEM="${DOTFILES_SECRETS_ITEM:-dotfiles-secrets}"
# item 底下的附件檔名
DOTFILES_SECRETS_ARCHIVE="${DOTFILES_SECRETS_ARCHIVE:-dotfiles-secrets.tar.gz}"

# 要打包的機密路徑(相對 $HOME)
SECRET_PATHS=(
  .ssh
  .gnupg
  .aws
  .kube
  .oci
  .cloudflared
  .shioaji
  .config/gcloud
  .config/gcloud-personal
  .config/gh
  .config/github-copilot
  .config/configstore
  .npmrc
  .netrc
  .docker/config.json
  .git-credentials
  .gitconfig-bitbucket
  .serverlessrc
  .bigqueryrc
  .atlas
  .mcp-auth
  .cache/huggingface/token
  .cache/huggingface/stored_tokens
  .claude.json
  .claude/CLAUDE.md
  # 累積的指令歷史(不可重建;高頻變動,包只更新到上次 pack 為止)
  .zsh_history
  .bash_history
  Library/LaunchAgents/com.career.session-map.plist
  Library/LaunchAgents/com.career.weekly-review.plist
  Library/LaunchAgents/com.local.shioaji-ticker.plist
  Library/LaunchAgents/com.claude-code.jsonl-upload.plist
)

# tar 排除:可重建的快取/大檔,不必進機密包(縮小體積、避免漂移)
SECRET_TAR_EXCLUDES=(
  --exclude='.shioaji/*.parquet'
  --exclude='.shioaji/*.parquet.lock'
  --exclude='.kube/cache'
  --exclude='.kube/http-cache'
  --exclude='.config/gcloud/logs'
  --exclude='.config/gcloud/cache'
  --exclude='.gnupg/S.*'
  --exclude='.gnupg/*.sock'
  --exclude='.ssh/agent'
)

# 需要 glob 展開的路徑(pack 會逐一展開;適合「多個同名子目錄」如各專案的 Claude 累積 memory)。
# 這些 memory 是不可重建的累積知識,且半機密(可能含端點/決策),放進加密 bundle 剛好。
SECRET_GLOBS=(
  ".claude/projects/*/memory"
)
