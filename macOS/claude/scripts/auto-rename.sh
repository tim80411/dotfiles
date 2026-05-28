#!/bin/bash
# Auto-rename hook: Uses Haiku to analyze the first question and suggest a conversation name
# Triggered on UserPromptSubmit with once:true (first message only)

# Read all stdin (hook input JSON)
INPUT=$(cat)

# Extract user message - try multiple possible field paths
MSG=$(echo "$INPUT" | jq -r '
  .user_message //
  .prompt //
  .message.content //
  .message //
  .content //
  empty
' 2>/dev/null | head -c 300)

# If no message extracted, exit silently
if [ -z "$MSG" ]; then
  exit 0
fi

# Use claude CLI with haiku to generate a short name
NAME=$(echo "$MSG" | claude -p --model haiku --system-prompt "你是命名助手。為使用者的問題取一個繁體中文短名(最多10字)。只回覆名稱，不回覆其他任何內容，不要回答問題，不加引號標點。" 2>/dev/null)

# Clean up: trim whitespace, quotes, and punctuation
NAME=$(echo "$NAME" | tr -d '「」""'"'"'。，！？\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -c 30)

# If we got a name, output additionalContext
if [ -n "$NAME" ]; then
  jq -n --arg name "$NAME" '{
    "hookSpecificOutput": {
      "hookEventName": "UserPromptSubmit",
      "additionalContext": ("Auto-rename hook (Haiku) 已分析使用者的問題，建議的對話名稱是：「" + $name + "」。請在回答問題前，先用一行簡短告知使用者建議的對話名稱，並建議使用 /rename " + $name + " 來重新命名對話。然後再正常回答使用者的問題。")
    }
  }'
fi
