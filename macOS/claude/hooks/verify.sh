#!/usr/bin/env bash
# ~/.claude/hooks/verify.sh — "verify before done" Stop-hook dispatcher.
#
# Detects the nearest project type and runs its typecheck/lint. If no manifest
# is found (or no checker is installed), it exits 0 silently, so it never blocks
# work in unrelated projects. Walking stops at $HOME so a stray manifest in your
# home dir can't trigger checks everywhere.
#
# Default = ADVISORY: on failure it surfaces a warning to you (systemMessage)
# but lets Claude stop. Set CLAUDE_VERIFY_BLOCK=1 to instead send Claude back to
# fix it (loop-guarded via stop_hook_active, so it nudges at most once per turn).

set -u
BLOCK_ON_FAIL="${CLAUDE_VERIFY_BLOCK:-0}"

# --- read hook input (JSON on stdin) ---------------------------------------
input="$(cat 2>/dev/null || true)"
cwd=""
stop_active="false"
if [ -n "$input" ] && command -v jq >/dev/null 2>&1; then
  cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
  stop_active="$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)"
fi
[ -n "$cwd" ] || cwd="$PWD"
cd "$cwd" 2>/dev/null || exit 0

# already nudged once this turn -> don't loop
if [ "$BLOCK_ON_FAIL" = "1" ] && [ "$stop_active" = "true" ]; then
  exit 0
fi

# --- find nearest manifest, never climbing above $HOME ---------------------
find_up() {
  local d="$PWD"
  while :; do
    [ -e "$d/$1" ] && { printf '%s' "$d"; return 0; }
    [ "$d" = "$HOME" ] && return 1
    [ "$d" = "/" ] && return 1
    d="$(dirname "$d")"
  done
}

fail=0
ran=0
skipped=0
report=""
skip_report=""
root=""

run() { # run "<label>" <cmd...>
  local label="$1"; shift
  local o
  if ! o="$("$@" 2>&1)"; then
    fail=1
    report="${report}
— ${label} 失敗 —
$(printf '%s' "$o" | tail -n 25)
"
  fi
}

has_script() { jq -e --arg s "$1" '.scripts[$s] // empty' package.json >/dev/null 2>&1; }

# ---- JS / TS --------------------------------------------------------------
if r="$(find_up package.json)" && [ "$r" != "$HOME" ]; then
  root="$r"; cd "$root"
  pm=npm
  [ -f yarn.lock ] && pm=yarn
  [ -f pnpm-lock.yaml ] && pm=pnpm
  [ -f bun.lockb ] && pm=bun
  if [ ! -d node_modules ]; then
    skipped=1
    skip_report="${skip_report}
— node 相依檢查 skipped（${root}）—
node_modules 缺失，請先 pnpm install（或對應套件管理器安裝）後再驗證。
"
  elif command -v "$pm" >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    for s in typecheck type-check tsc; do
      if has_script "$s"; then ran=1; run "$pm run $s" "$pm" run "$s"; break; fi
    done
    if has_script lint; then ran=1; run "$pm run lint" "$pm" run lint; fi
  fi
# ---- Python ---------------------------------------------------------------
elif r="$(find_up pyproject.toml)" && [ "$r" != "$HOME" ]; then
  root="$r"; cd "$root"
  if command -v ruff >/dev/null 2>&1; then ran=1; run "ruff check" ruff check .; fi
  if command -v mypy >/dev/null 2>&1 && grep -q '\[tool.mypy\]' pyproject.toml 2>/dev/null; then
    ran=1; run "mypy" mypy .
  fi
# ---- Go -------------------------------------------------------------------
elif r="$(find_up go.mod)" && [ "$r" != "$HOME" ]; then
  root="$r"; cd "$root"
  if command -v go >/dev/null 2>&1; then ran=1; run "go vet" go vet ./...; fi
# ---- Rust -----------------------------------------------------------------
elif r="$(find_up Cargo.toml)" && [ "$r" != "$HOME" ]; then
  root="$r"; cd "$root"
  if command -v cargo >/dev/null 2>&1; then ran=1; run "cargo check" cargo check -q; fi
fi

# nothing detected / nothing runnable, and nothing skipped -> silent pass
{ [ "$ran" = "1" ] || [ "$skipped" = "1" ]; } || exit 0
if [ "$fail" = "0" ]; then
  # skip-only path: advisory notice, never blocks (not a failure)
  if [ "$skipped" = "1" ]; then
    skip_msg="ℹ️ 驗證已 skip：${skip_report}"
    if command -v jq >/dev/null 2>&1; then
      jq -cn --arg m "$skip_msg" '{systemMessage:$m, suppressOutput:true}'
    else
      printf '%s\n' "$skip_msg" 1>&2
    fi
  fi
  exit 0
fi

# --- failure path ----------------------------------------------------------
msg="⚠️ 完成前驗證發現問題（${root}）：${report}${skip_report}"
if [ "$BLOCK_ON_FAIL" = "1" ]; then
  printf '%s' "$msg" 1>&2   # exit 2 => block stop, feed reason back to Claude
  exit 2
else
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg m "$msg" '{systemMessage:$m, suppressOutput:true}'
  else
    printf '%s\n' "$msg" 1>&2
  fi
  exit 0
fi
