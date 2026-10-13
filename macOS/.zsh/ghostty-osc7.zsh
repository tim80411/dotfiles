# 來源：搬自 ~/.zsh/cmux-mini.zsh（P1，2026-09-11 cutover 拔除 devbox/dbx 家族時抽出）
# 用途：Ghostty + tmux DCS passthrough 送 OSC 7，讓新 Tab/Split 拿得到 cwd
# ── Ghostty + tmux：DCS passthrough 送 OSC 7，讓新 Tab/Split 拿得到 cwd ──
# （tmux 會把 TERM_PROGRAM 覆蓋為 "tmux"，故改用 client_termname 偵測）
if [[ -n "$TMUX" ]] && [[ "$(tmux display-message -p '#{client_termname}' 2>/dev/null)" == *ghostty* ]]; then
  _ghostty_osc7_passthrough() {
    printf '\ePtmux;\e\e]7;file://%s%s\a\e\\' "${HOST}" "${PWD}"
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _ghostty_osc7_passthrough
  _ghostty_osc7_passthrough
fi
