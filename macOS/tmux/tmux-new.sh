#!/bin/bash
# ~/bin/tmux-new.sh - 每次呼叫都建立新的 tmux session

# 基礎名稱：時間戳，保證不重複
SESSION_NAME="s-$(date +%H%M%S)"

# 如果在 git 專案內，用專案名+分支
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    PROJECT=$(basename "$(git rev-parse --show-toplevel)")
    BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null | tr '/' '-')
    SESSION_NAME="${PROJECT}_${BRANCH:-detached}_$(date +%H%M%S)"
fi

exec tmux new-session -s "$SESSION_NAME"
