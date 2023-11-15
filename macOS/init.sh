#!/bin/bash

# 獲取主機名稱
HOSTNAME=$(hostname -s)

# 導出環境變數
export HOSTNAME

# 運行 docker-compose
docker-compose up -d
