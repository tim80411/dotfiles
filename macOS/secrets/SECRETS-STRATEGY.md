# 機密管理策略(Secrets Strategy)

## 核心決策

**設定進 git(這個 public repo),機密進 Bitwarden。兩者不混。**

- 📁 **設定**(`.zshrc`、Brewfile、`install.sh`…)→ 留在這個公開 dotfiles repo,普通 git,`git push` 就好。
- 🔑 **機密**(SSH/GPG 金鑰、雲端 token…)→ **完全不進任何 git repo**,打包成一個 tar 存進自架 **Bitwarden** 的附件。根信任 = 你腦中的 Bitwarden 主密碼。

為什麼這樣分:機密是「寫一次、讀很少」的資料(一把 key 用好幾年,只在換機時才需要)。所以把罕見的機密操作留在 Bitwarden,把高頻的設定操作留在純 git,兩者互不拖累。機密永不碰 git = 零 git 外洩風險,也不必學 git-crypt/SOPS。

> 曾評估過的替代方案與否決理由:
> - **git-crypt / SOPS+age(機密進 git)**:雖可「編輯即推」,但機密就得放 private repo(否則 `.gitattributes` 一漏配就公開外洩);且 SOPS 對二進位金鑰群不友善。此 repo 想維持公開,故不採用。
> - **age 封存包(檔案)**:機制簡單,但 all-or-nothing、改一點就要重打包,日常摩擦大。Bitwarden 路線省掉「檔案該放哪、bootstrap 憑證怎麼來」的循環依賴,且已在用。

## 日常長怎樣

| 情境 | 頻率 | 你做的事 | 碰 Bitwarden? |
|---|---|---|---|
| 改設定 | 幾乎每天 | `git commit && git push` | ❌ |
| 換 key / 輪替 token | 一年幾次 | `pack-secrets.sh`(順手刷新備份) | ✅ 一次 |
| 換新機 | 一年幾次 | `install.sh` + `bootstrap-secrets.sh` | ✅ 一次 |

95% 的動作是純 git,碰不到 Bitwarden。

## 三個檔

- `secret-paths.sh` — 機密路徑清單(唯一真相,pack/bootstrap 共用)。列的是整個目錄,所以新增 key 不用改清單。
- `pack-secrets.sh` — 打包機密 → 上傳 Bitwarden 附件。item 不存在會自動建立;更新採「先刪舊附件再上傳」。
- `bootstrap-secrets.sh` — 新機從 Bitwarden 拉回 → 解開 → 修權限(600/700)。

`install.sh` 會把這三支佈署到 `~/bin/`,但**不會自動跑** bootstrap(因為 `bw unlock` 是刻意保留的互動步驟,不該被自動化)。

## 新機 bootstrap 步驟

```bash
# 1) 裝環境(含 bitwarden-cli、jq)
bash <(curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/install.sh)

# 2) 登入自架 Bitwarden(手機/另一台讀主密碼)
bw config server <你的 vault URL>
bw login

# 3) 拉回機密
~/bin/bootstrap-secrets.sh

# 4) 驗證
ssh -T git@github.com ; gh auth status ; aws sts get-caller-identity
```

## 更新機密(勤勞派 / 佛系派)

同一支 `pack-secrets.sh`,差別只在跑的頻率:

- **勤勞派**:每次改完機密順手 `~/bin/pack-secrets.sh` → Bitwarden 永遠最新,舊機隨時可死。
- **佛系派**:平常不管,換機時直接從舊機打包(舊機通常還活著)。Bitwarden 當「偶爾刷新的保險」。

方便的話,在 `.zshrc` 加個 alias:`alias packsecrets="$HOME/bin/pack-secrets.sh"`。

## 安全備註

- Bitwarden 是機密的單一存放點:自架 vault 務必自己備份(sqlite/attachment),並開 2FA。建議額外把 vault 主密碼離線留一份(保險箱/紙本)當最終備援。
- 機密包內是全部機密的超集,能解密者拿到全部;若懷疑外洩,做法是「輪替裡面所有機密」。
- `pack-secrets.sh` / `bootstrap-secrets.sh` / `secret-paths.sh` 本身不含任何機密,放 public repo 安全。
