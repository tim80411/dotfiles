<!-- 共用規則（AskUserQuestion、文件產製、驗證與完成、研究與多代理人、Agent 模型路由、長任務斷點續做、Jira、Canary）在 ~/AGENTS.md。Claude Code 不會自動讀 AGENTS.md，靠下一行 import 載入。本檔只放 Claude 專屬補充。 -->
@~/AGENTS.md

# 報告與解釋的形狀 (Report & Explanation Shape)
收工報告、長解釋適用（指令型訊息維持行動優先）：
1. 先一段話講「這整件事在幹嘛」再進細節
2. session 代號（工單號、方案代號、腳本名）首次出現就括號白話
3. 每個抽象項配一個真實例子（真標題/真 log 行/實測結果）
4. 結尾收斂成單一決定＋2-4 個現成回覆選項；使用者若附帶自己的理解，先重述對齊他的模型再回答

# Codex 委派 (Codex Delegation)
已安裝 `codex@openai-codex` plugin。主 agent 可用 Agent tool 呼叫 `codex:codex-rescue` subagent 把工作交給 Codex，目的是減少 Claude 主 context 的 token 壓力。由 Claude 自行判斷，不必等使用者點名 Codex。

**門檻（中度）**——符合任一才委派：
- 預估要讀 5 個以上檔案才能搞懂問題
- 跨多檔的實作或重構
- 同一個 bug Claude 已試 2 輪未解
- 需要第二意見（設計挑戰、上線前 review）→ 改用 `/codex:review` 或 `/codex:adversarial-review`
小任務、單檔修改、對話式問答一律自己做，不委派。

**寫入權限（混合）**：
- 調查／診斷／研究類：prompt 內明寫「read-only, do not edit files」，subagent 就不會加 `--write`
- 實作／修 bug 類：允許 Codex 直接寫檔
- Codex 寫檔後，Claude 必須 `git diff --stat` 讀回改動並跑相關測試，才可宣告完成

**執行方式**：
- 預估超過 1 分鐘的任務用 background，先做其他不相依的事，再以 `/codex:result` 收結果
- 委派時在回覆裡明說「已委派 Codex：<任務一句話>」，方便日後審核委派效果
- Codex 失敗或未回應：回報原因並問使用者是否改由 Claude 自己做，不要默默在主 context 重做一遍

# 簡報預設走 open-slide (Slides Default)
**前提：本機有 `~/.claude/skills/my-slides/` 才適用**（目前只有 mini 有；沒有就照一般簡報流程）。凡是做簡報／投影片／deck／presentation，一律先載入使用者層級的 `my-slides` skill（`~/.claude/skills/my-slides/SKILL.md`），預設在 `~/self/products/slides` 這個 open-slide 工作區產出並 push 上線；只有使用者明確要 `.pptx` 檔才改走 pptx skill。工作區內 open-slide 自帶的 skill（create-slide、slide-authoring 等）要用絕對路徑直接讀來照做。

# 寫作 A/B 實驗：Claude vs Gemini (Writing A/B Experiment)
**狀態：ON**（要關閉就把這整段刪掉，或把 ON 改成 OFF）。
**觸發範圍**：以「產出型態」判定——凡是最終產出是一份以文字為主的文件就觸發，不論格式（.md、.docx、.pdf、Confluence／Notion 頁、Claude Docs…）與種類（文章、報告、spec、計畫、筆記、README、release note、簡報文案、摘要、提案、翻譯、潤稿…）。新寫整份或重寫／潤飾一個段落以上才算；單句小修不觸發。A/B 只比文字內容，格式轉換（docx／pdf／發佈）在選出勝者後才做。
**做法**：一律先載入 `writing-ab` skill（tim-private-skills plugin，即 `/writing-ab:writing-ab`）照做：同一份 brief 平行派 Claude subagent 與 `agy`（Antigravity CLI）的 Gemini，盲測 A/B，用 AskUserQuestion 讓使用者選，結果記錄到 log。
**排除**：
- 程式碼、設定檔（yaml／json／env）、commit message
- agent 指令檔（CLAUDE.md／SKILL.md／AGENTS.md／hooks）與記憶檔
- 固定套版表單（如 nani-office 需求單／採購單）
- write-me skill 範圍的訊息（以使用者本人口吻發給別人）
- 使用者說「不用 A/B」「只要 Claude」「只要 Gemini」
**前提**：plugin `writing-ab@tim-private-skills` 已安裝；`agy` 須已登入；未登入就提示使用者先在終端機執行 `agy` 登入，這次只跑 Claude 側且不記 log。
