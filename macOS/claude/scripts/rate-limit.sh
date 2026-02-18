#!/bin/bash
# Rate limit utilization display for ccstatusline
# Queries Anthropic OAuth Usage API and shows 5h/7d utilization percentages

CACHE_DIR="$HOME/.cache/claude"
CACHE_FILE="$CACHE_DIR/rate-limit.json"
CACHE_TTL=60

# Consume stdin (ccstatusline pipes input)
cat > /dev/null

fetch_rate_limit() {
  mkdir -p "$CACHE_DIR"
  local token
  token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
    | jq -r '.claudeAiOauth.accessToken // empty')
  [ -z "$token" ] && return 1
  curl -s --max-time 5 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "https://api.anthropic.com/api/oauth/usage" > "$CACHE_FILE.tmp" 2>/dev/null \
    && mv "$CACHE_FILE.tmp" "$CACHE_FILE"
}

# Cache logic: fresh -> use cache / stale -> use cache + background refresh / no cache -> sync fetch
if [ -f "$CACHE_FILE" ]; then
  file_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
  if [ "$file_age" -gt "$CACHE_TTL" ]; then
    (fetch_rate_limit &) 2>/dev/null
  fi
else
  fetch_rate_limit 2>/dev/null || true
fi

if [ ! -f "$CACHE_FILE" ]; then
  echo "rate limit: loading..."
  exit 0
fi

data=$(cat "$CACHE_FILE")
five_h=$(echo "$data" | jq -r '.five_hour.utilization // empty')
five_reset=$(echo "$data" | jq -r '.five_hour.resets_at // empty')
seven_d=$(echo "$data" | jq -r '.seven_day.utilization // empty')

# Calculate time until reset
reset_str=""
if [ -n "$five_reset" ] && [ "$five_reset" != "null" ]; then
  reset_ts=$(date -jf "%Y-%m-%dT%H:%M:%S" \
    "$(echo "$five_reset" | sed 's/\..*//' | sed 's/+.*//')" +%s 2>/dev/null || echo "")
  if [ -n "$reset_ts" ]; then
    diff=$(( reset_ts - $(date +%s) ))
    if [ "$diff" -gt 0 ]; then
      reset_str=" (reset $((diff/3600))h$(( (diff%3600)/60 ))m)"
    fi
  fi
fi

# ANSI colors based on utilization level
color() {
  local v=${1%%.*}
  if [ "$v" -ge 80 ]; then printf '\033[91m'    # red
  elif [ "$v" -ge 50 ]; then printf '\033[93m'   # yellow
  else printf '\033[92m'; fi                      # green
}
RST='\033[0m'
DIM='\033[2m'

output=""
[ -n "$five_h" ] && output+="$(color $five_h)5h: ${five_h}%${RST}${DIM}${reset_str}${RST}"
[ -n "$seven_d" ] && output+=" | $(color $seven_d)7d: ${seven_d}%${RST}"

printf "%b\n" "$output"
