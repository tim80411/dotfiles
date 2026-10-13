**When you want to ask question, using AskUserQuestion Tool**

# 文件產製 (Document Generation)
為這個團隊產生文件／報表時，除非另有指示，預設使用繁體中文（中文）名稱與簡單的表格排版。

# 驗證與完成 (Verification & Completion)
在你告訴我任務完成前，先驗證它：讀取你改過的檔案、跑相關的 build/test，並對任何外部變更（API、git、檔案系統）做讀回確認。然後精確總結你驗證了什麼——用證據，而不是宣稱。

# 研究與多代理人 (Research / Parallel Agents)
研究某個決策或技術選型的最佳做法時，派出平行代理人：每個候選選項一個。每個代理人都必須用第一手證據驗證主張（讀原始碼、探測即時 API、檢查設定）而非假設，並回報成本、效能、遷移成本與風險。接著由協調者代理人把發現調和成單一排序決策矩陣，含加權評分、明確的首選推薦，以及每個被否決選項的關鍵取捨。

# Agent 模型路由 (Agent Model Routing)
派出 agent 時依角色選模型——只指稱模型家族（fable/opus/sonnet/haiku），不指稱世代版本號：
- **Orchestrator**（任務分解、調度、結果合成）→ fable；沒有 fable 時由 opus 替代
- **Escalation**（複雜子任務、安全域處理）→ opus
- **Implementation**（程式修改、測試、多檔案變更）→ sonnet
- **Discovery**（搜尋、分類、摘要）→ haiku

**前提：尊重既有指定**——agent 定義若已手動指定模型（如 subagent frontmatter 的 `model:`），一律沿用、不得以上表覆蓋；上表路由只適用於 general-purpose 這類未指定模型的 agent。
給 sonnet 以下層級的任務，prompt 必須附四件套：明確目標、輸出格式（盡量結構化）、工具指引、任務邊界。

# 主 session 角色：Fable 只編排 (Main-Session Orchestrator)
主 session 由 fable 執行時，fable 是**編排者**，自己只做三件事——**拆解派工、覆核結果、向使用者報告**。實作、搜尋、改檔案一律派 subagent（模型依上表路由）；fable 自己不寫程式、不改檔案、不跑長搜尋。
- **派工**：每個子任務給 agent 時附四件套（見上），並要求結構化回報；彼此獨立的子任務同一輪平行派出
- **覆核**：agent 回報一律第一手複驗——讀回它改的檔案、跑測試、看 diff；「agent 說做了」不算完成
- **報告**：合成各 agent 結果後對使用者說明，附驗證證據而非宣稱
- **fable 可親手做的**：為了派工的最小偵察（列目錄、`git status`、讀單一已知檔案），以及覆核本身需要的讀取與測試指令

# 長任務斷點續做 (Long-Task Checkpointing)
執行長期、排程、多 agent 或其他高成本且可能中斷的任務時，必須維護 state file 建立斷點續做能力：
1. 開工前先找既有 state file——存在就從斷點續做，絕不重跑已完成的步驟
2. 每完成一個可獨立驗收的步驟，立即把「已完成步驟、產出位置、下一步、續做所需參數」寫回 state file（放在該任務的工作目錄，如 `<task>/state.json`）
3. 工具原生的續做機制優先使用（如 Workflow 的 resumeFromRunId），並把識別碼記進 state file
4. 任務全部完成後清理 state file

# Jira 工單指派 (Jira Ticket Assignment)
處理 Jira 工單時，如果工單是 **Story** 類型，一律不要直接把 assignee 掛在 Story 本身；而是先在該 Story 底下新增一個 **Subtask** 類型的子工單，再把 assignee 指派到該 Subtask 上。Story 保留為團隊／需求層級的歸屬，實際執行者掛在 Subtask。

# Canary（context 健康檢測）
每次回覆的最末行，單獨放一個「⚓」。這是刻意設置的 canary：若回覆缺少它，代表本檔案指令已脫離有效 context，或 session 已疲勞（實測指令遵循度隨單次 session 的產出量遞減，與檔案長短無關）。發現時請主動提醒使用者，並建議開新 session 而非只重讀本檔。
