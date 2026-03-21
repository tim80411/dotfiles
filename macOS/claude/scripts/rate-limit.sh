#!/bin/bash
# Rate limit display — reads from Claude Code's built-in rate_limits field (stdin JSON)

input=$(cat)

five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

[ -z "$five_pct" ] && [ -z "$seven_pct" ] && exit 0

fmt_remaining() {
  local diff=$(( $1 - $(date +%s) ))
  [ "$diff" -le 0 ] && return
  local d=$((diff / 86400)) h=$(( (diff % 86400) / 3600 )) m=$(( (diff % 3600) / 60 ))
  if [ "$d" -gt 0 ]; then echo "(${d}d${h}h)"
  else echo "(${h}h${m}m)"; fi
}

color() {
  local v=${1%.*}
  if [ "$v" -gt 80 ]; then printf '\033[91m'
  elif [ "$v" -ge 50 ]; then printf '\033[38;5;208m'
  else printf '\033[92m'; fi
}
RST='\033[0m'
WHT='\033[97m'

output=""
if [ -n "$five_pct" ]; then
  five_rem=""; [ -n "$five_reset" ] && five_rem=" $(fmt_remaining "$five_reset")"
  output+="$(color "$five_pct")5h:$(printf '%.0f' "$five_pct")%${RST}${WHT}${five_rem}${RST}"
fi
if [ -n "$seven_pct" ]; then
  seven_rem=""; [ -n "$seven_reset" ] && seven_rem=" $(fmt_remaining "$seven_reset")"
  output+=" | $(color "$seven_pct")7d:$(printf '%.0f' "$seven_pct")%${RST}${WHT}${seven_rem}${RST}"
fi

printf "%b\n" "$output"
