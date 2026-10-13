# 新 Mac 設定 Checklist

搬到新 Mac 的完整流程。核心原則：**個人資料交給「移轉輔助程式」，開發環境交給 dotfiles，密鑰／登入手動處理。**

---

## 階段總覽

| 階段 | 負責工具 | 目的 |
|------|----------|------|
| Phase 0 | 舊機（手動） | 事前準備，確保 repo 與備份是最新 |
| Phase 1 | 移轉輔助程式 | 搬個人資料、App、系統設定 |
| Phase 2 | dotfiles `install.sh` | 乾淨重建開發環境 |
| Phase 3 | 手動 | 登入帳號、還原密鑰（repo 不含） |
| Phase 4 | 手動 | macOS 系統設定、字型、最終驗證 |

---

## dotfiles 涵蓋 vs 需手動（速查）

| 項目 | 狀態 | 來源 |
|------|------|------|
| Homebrew + 全套 CLI/Cask/VSCode/go/npm/uv 套件 | ✅ 自動 | `Brewfile` |
| zsh / p10k / git / vim / tmux / ghostty 設定 | ✅ 自動 | `install.sh` |
| Claude Code settings / hooks / plugins / scripts | ✅ 自動 | `install.sh` |
| ccstatusline、docker-compose、redis、ssh config | ✅ 自動 | `install.sh` |
| TCIM 輸入法**自動重啟**（launchd） | ✅ 自動 | `install.sh` |
| SSH 私鑰 / GPG 私鑰 | ❌ 手動 | repo 只含 `sshConfig`，不含密鑰 |
| 各雲端 CLI 登入（aws/azure/gcloud/oci/gh） | ❌ 手動 | 只裝工具，不含憑證 |
| Claude Code 登入 + OTEL token | ❌ 手動 | `settings.json` 內是 `placeholder` |
| Bitbucket / GitHub 私有 marketplace 存取 | ❌ 手動 | plugin 來源需 SSH/登入 |
| mkcert rootCA | ❌ 手動 | 需 `mkcert -install` 重新產生 |
| TCIM 輸入法**本體安裝** | ❌ 手動 | 只自動化重啟，不含安裝 |
| App 授權/登入（Discord/Termius/TablePlus…） | ❌ 手動 | |

---

## Phase 0 — 舊機事前準備

- [ ] dotfiles 全部變更已 `commit` + `push` 到 `master`（install 從 master 分支 curl，未 push 的變更不會生效）
- [ ] Brewfile 為最新：`brew bundle dump --file /tmp/Brewfile.new && diff <(sort macOS/Brewfile) <(sort /tmp/Brewfile.new)` 檢查有無漏套件
- [ ] 完成一次 Time Machine 完整備份（或確認新舊兩機可直接連線移轉）
- [ ] 記下不在 repo 的密鑰位置：`~/.ssh/`（私鑰）、`~/.gnupg/`（GPG）
- [ ] 確認 Bitwarden 主密碼可登入、雲端 CLI 帳號可重新認證
- [ ] 記下 mkcert rootCA 路徑：`~/Library/Application Support/mkcert/rootCA.pem`

---

## Phase 1 — 移轉輔助程式（個人資料）

新機開機設定時，或 `/應用程式/工具程式/移轉輔助程式`。四類勾選建議：

| 勾選項 | 建議 | 原因 |
|--------|------|------|
| 使用者帳號 | ✅ 全搬 | 含鑰匙圈（Wi-Fi/密碼）、郵件、瀏覽器、個人檔案 |
| 應用程式 | ✅ 一般全搬 | 開發類 App 之後會被 Brewfile 覆蓋重裝，無妨 |
| 電腦與網路設定 | ✅ | 網路、時區等 |
| 其他檔案與資料夾 | ⚠️ 個人散檔可搬 | **別依賴它搬 Homebrew / 開發環境**，移轉後常壞 |

> 想要最乾淨的開發環境：可「不勾應用程式」，全部交給 Phase 2 的 Brewfile 重裝。一般求方便則全勾，壞掉的開發環境再用 dotfiles 覆蓋。

---

## Phase 2 — dotfiles 重建開發環境

- [ ] 裝 Xcode Command Line Tools（Homebrew 前置）：`xcode-select --install`
- [ ] 一鍵安裝：
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/install.sh)"
  ```
- [ ] 驗證套件全裝：`brew bundle check --file macOS/Brewfile`（或重跑 `brew bundle`）
- [ ] 確認 `~/.zshrc`、`~/.gitconfig`、`~/.tmux.conf`、`~/.config/ghostty/config` 已就位
- [ ] 確認 `~/.claude/`（settings/hooks/plugins/scripts）已就位
- [ ] `~/.claude/mods/auto-rename` 已就位（settings env `CLAUDE_CODE_PLUGIN_DIRS`）
- [ ] 確認 `~/AGENTS.md` 與 `~/.claude/CLAUDE.md` 都在（CLAUDE.md 靠 `@~/AGENTS.md` import 共用規則，缺 AGENTS.md 規則會靜默失效）：`claude -p "你的指令裡有沒有 Canary 段？"` 應回「有」

---

## Phase 3 — 帳號登入與密鑰（repo 不含，務必手動）

- [ ] 還原 SSH 私鑰到 `~/.ssh/`，`chmod 600` 私鑰、`chmod 644` 公鑰
- [ ] 還原或重新產生 GPG 金鑰（`gpg --import`）
- [ ] `gh auth login`（GitHub CLI）
- [ ] 雲端 CLI 登入：`aws configure` / `az login` / `gcloud auth login` / `oci setup config`
- [ ] Bitwarden：`bw login`（`bitwarden-cli`）
- [ ] Claude Code 登入，並把 `~/.claude/settings.json` 的 `OTEL_EXPORTER_OTLP_HEADERS` 從 `placeholder` 換成真實 token
- [ ] Bitbucket SSH 存取（`nani_skill` marketplace 來源為 `git@bitbucket.org`）
- [ ] GitHub 私有 repo 存取（`tim-private-skills` marketplace）
- [ ] `mkcert -install` 產生並信任本機 rootCA（供 `NODE_EXTRA_CA_CERTS` / gRPC 使用）
- [ ] 各 App 登入/授權：Discord、Termius、TablePlus、Postman、Raycast、Shottr 等

---

## Phase 4 — macOS 系統設定、字型與驗證

- [ ] 終端機字型：Ghostty / iTerm 設 `Hack Nerd Font`
- [ ] VSCode `settings.json` 字型：
  ```jsonc
  "editor.fontFamily": "'Cascadia Code', Consolas, 'Courier New', monospace",
  "editor.fontLigatures": true,
  "terminal.integrated.fontFamily": "'Hack Nerd Font Mono'",
  ```
- [ ] 安裝 TCIM 輸入法本體，加入「輸入來源」，確認 auto-restart plist 運作：`launchctl list | grep restart-tcim`
- [ ] macOS 系統設定：鍵盤、觸控板、Dock、Finder、熱區、截圖儲存路徑
- [ ] （可選）`p10k configure` 微調提示字元

### 最終驗證

- [ ] 開新終端機 → 預設 shell 為 zsh、p10k 主題正常
- [ ] `git config --global user.name` / `user.email` 正確
- [ ] `claude` 可啟動、statusLine（ccstatusline）與 plugins 正常載入
- [ ] `~/bin/tmux-new.sh` 可正常建立 session
- [ ] `brew doctor` 無重大警告
