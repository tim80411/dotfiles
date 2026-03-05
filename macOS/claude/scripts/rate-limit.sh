#!/bin/bash
# Rate limit utilization display for ccstatusline
# Dual-source: /api/oauth/usage (primary) + Messages API headers (fallback)

CACHE_DIR="$HOME/.cache/claude"
CACHE_FILE="$CACHE_DIR/rate-limit.json"
CACHE_TTL=120
CACHE_MAX_AGE=1800

# Consume stdin (ccstatusline pipes input)
cat > /dev/null

get_token() {
  security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
    | grep -o '"accessToken":"[^"]*"' | head -1 | sed 's/"accessToken":"//;s/"$//'
}

# Primary: /api/oauth/usage
fetch_usage_api() {
  local token="$1"
  local http_code
  http_code=$(curl -s --max-time 5 -w "%{http_code}" \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "https://api.anthropic.com/api/oauth/usage" -o "$CACHE_FILE.tmp" 2>/dev/null)
  if [ "$http_code" = "200" ] && jq -e '.five_hour' "$CACHE_FILE.tmp" >/dev/null 2>&1; then
    mv "$CACHE_FILE.tmp" "$CACHE_FILE"
    return 0
  fi
  rm -f "$CACHE_FILE.tmp"
  return 1
}

# Fallback: extract rate limit info from Messages API response headers
fetch_from_headers() {
  local token="$1"
  local headers
  headers=$(curl -s -D - -o /dev/null --max-time 10 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-version: 2023-06-01" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "Content-Type: application/json" \
    "https://api.anthropic.com/v1/messages" \
    -d '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"x"}]}' 2>/dev/null)

  local five_util five_reset seven_util seven_reset
  five_util=$(echo "$headers" | grep -i "anthropic-ratelimit-unified-5h-utilization" | awk '{print $2}' | tr -d '\r')
  five_reset=$(echo "$headers" | grep -i "anthropic-ratelimit-unified-5h-reset" | awk '{print $2}' | tr -d '\r')
  seven_util=$(echo "$headers" | grep -i "anthropic-ratelimit-unified-7d-utilization" | awk '{print $2}' | tr -d '\r')
  seven_reset=$(echo "$headers" | grep -i "anthropic-ratelimit-unified-7d-reset" | awk '{print $2}' | tr -d '\r')

  if [ -n "$five_util" ]; then
    # Convert header format to match /api/oauth/usage JSON structure
    # Reset timestamps are epoch seconds; convert to ISO 8601 for consistency
    local five_reset_iso seven_reset_iso
    five_reset_iso=$(date -u -r "$five_reset" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
    seven_reset_iso=$(date -u -r "$seven_reset" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
    # Utilization from headers is 0.0-1.0; convert to percentage
    local five_pct seven_pct
    five_pct=$(echo "$five_util" | awk '{printf "%.1f", $1 * 100}')
    seven_pct=$(echo "$seven_util" | awk '{printf "%.1f", $1 * 100}')
    cat > "$CACHE_FILE.tmp" <<EOF
{"five_hour":{"utilization":${five_pct},"resets_at":"${five_reset_iso}"},"seven_day":{"utilization":${seven_pct},"resets_at":"${seven_reset_iso}"},"_source":"headers"}
EOF
    mv "$CACHE_FILE.tmp" "$CACHE_FILE"
    return 0
  fi
  return 1
}

fetch_rate_limit() {
  mkdir -p "$CACHE_DIR"
  local token
  token=$(get_token)
  [ -z "$token" ] && return 1
  fetch_usage_api "$token" && return 0
  fetch_from_headers "$token" && return 0
  return 1
}

# Cache logic: fresh -> use cache / stale -> background refresh / no cache -> sync fetch
if [ -f "$CACHE_FILE" ]; then
  file_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
  if [ "$file_age" -gt "$CACHE_TTL" ]; then
    (fetch_rate_limit &) 2>/dev/null
  fi
else
  fetch_rate_limit 2>/dev/null || true
fi

# Show stale data up to CACHE_MAX_AGE; only show loading if no cache at all
if [ ! -f "$CACHE_FILE" ]; then
  echo "rate limit: loading..."
  exit 0
fi

file_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
if [ "$file_age" -gt "$CACHE_MAX_AGE" ]; then
  echo "rate limit: stale"
  exit 0
fi

data=$(cat "$CACHE_FILE")

# Check if data is an error response
if echo "$data" | jq -e '.error' >/dev/null 2>&1; then
  echo "rate limit: unavailable"
  exit 0
fi

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
  if [ "$v" -gt 80 ]; then printf '\033[91m'     # red (>80)
  elif [ "$v" -ge 50 ]; then printf '\033[38;5;208m' # orange (50-80)
  else printf '\033[92m'; fi                      # green (<50)
}
RST='\033[0m'
WHT='\033[97m'

output=""
[ -n "$five_h" ] && output+="$(color $five_h)5h: ${five_h}%${RST}${WHT}${five_reset_str}${RST}"
[ -n "$seven_d" ] && output+=" | $(color $seven_d)7d: ${seven_d}%${RST}${WHT}${seven_reset_str}${RST}"

printf "%b\n" "$output"
