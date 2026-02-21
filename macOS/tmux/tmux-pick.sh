#!/bin/bash
# ~/bin/tmux-pick.sh - 互動式選擇或建立 session (適合 ShellFish 使用)

SESSIONS=$(tmux ls -F "#{session_name}" 2>/dev/null)

if [ -z "$SESSIONS" ]; then
    echo "No sessions. Creating new one..."
    exec ~/bin/tmux-new.sh
fi

echo "Available sessions:"
echo "$SESSIONS" | nl
echo ""
read -p "Enter number to attach (or 'n' for new): " CHOICE

if [ "$CHOICE" = "n" ]; then
    exec ~/bin/tmux-new.sh
fi

TARGET=$(echo "$SESSIONS" | sed -n "${CHOICE}p")
if [ -n "$TARGET" ]; then
    exec tmux attach -t "$TARGET"
else
    echo "Invalid. Creating new session..."
    exec ~/bin/tmux-new.sh
fi
