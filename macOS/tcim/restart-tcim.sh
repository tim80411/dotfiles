#!/bin/bash
# 重啟 macOS 繁體中文輸入法 (TCIM) 進程
# 用途：解決輸入法卡頓、只出注音符號、彩虹游標等問題

pkill -9 -f TCIM_Extension 2>/dev/null
pkill -9 -f SCIM_Extension 2>/dev/null

echo "$(date): TCIM/SCIM 已重啟" >> ~/Library/Logs/restart-tcim.log
