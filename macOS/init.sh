#!/bin/bash

# 獲取主機名稱
HOSTNAME=$(hostname)

# 導出環境變數
export HOSTNAME

# 運行 docker-compose
# 相容兩種 CLI:優先 compose v2 子指令,沒有再退回獨立的 docker-compose 二進位
# (某些 OrbStack 環境未掛 cli-plugins,docker compose 會噴 unknown command)
if docker compose version >/dev/null 2>&1; then
    docker compose up -d
else
    docker-compose up -d
fi
