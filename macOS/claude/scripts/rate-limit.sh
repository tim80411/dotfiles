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
seven_reset=$(echo "$data" | jq -r '.seven_day.resets_at // empty')

# Parse ISO 8601 UTC timestamp to epoch seconds
parse_utc_ts() {
  local iso="$1"
  local stripped
  stripped=$(echo "$iso" | sed 's/\..*//' | sed 's/+.*//' | sed 's/Z$//')
  # Parse as UTC by using -u flag
  date -ju -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null || echo ""
}

# Format remaining time from seconds
fmt_remaining() {
  local diff=$1
  if [ "$diff" -le 0 ]; then echo ""; return; fi
  local d=$((diff / 86400))
  local h=$(( (diff % 86400) / 3600 ))
  local m=$(( (diff % 3600) / 60 ))
  if [ "$d" -gt 0 ]; then
    echo " (reset ${d}d${h}h)"
  else
    echo " (reset ${h}h${m}m)"
  fi
}

now=$(date +%s)

# Calculate time until 5h reset
five_reset_str=""
if [ -n "$five_reset" ] && [ "$five_reset" != "null" ]; then
  five_reset_ts=$(parse_utc_ts "$five_reset")
  [ -n "$five_reset_ts" ] && five_reset_str=$(fmt_remaining $(( five_reset_ts - now )))
fi

# Calculate time until 7d reset
seven_reset_str=""
if [ -n "$seven_reset" ] && [ "$seven_reset" != "null" ]; then
  seven_reset_ts=$(parse_utc_ts "$seven_reset")
  [ -n "$seven_reset_ts" ] && seven_reset_str=$(fmt_remaining $(( seven_reset_ts - now )))
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
[ -n "$five_h" ] && output+="$(color $five_h)5h: ${five_h}%${RST}${DIM}${five_reset_str}${RST}"
[ -n "$seven_d" ] && output+=" | $(color $seven_d)7d: ${seven_d}%${RST}${DIM}${seven_reset_str}${RST}"

printf "%b\n" "$output"
