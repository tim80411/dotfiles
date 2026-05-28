
# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh"

# Fast-path: 跳過重量級初始化 (手動用 env FAST_SHELL=1 zsh)
if [[ -n "$FAST_SHELL" ]]; then
  export PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/opt/openjdk/bin:$PATH"
  export PATH="$PATH:$(go env GOPATH 2>/dev/null)/bin"
  [[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"
  return
fi

# p10k config source
if [[ -n "$CURSOR_AGENT" ]]; then
  # Skip theme initialization for better compatibility
else
  [[ -r ~/.p10k.zsh ]] && source ~/.p10k.zsh
fi

# Terminal 中的 Report terminal type 改為 xterm-256color
# Ghostty 需要保留 xterm-ghostty 以啟用 shell integration
if [[ "$TERM_PROGRAM" != "ghostty" ]]; then
  export TERM='xterm-256color'
fi

# 載入 antigen
# zsh 的插件管理工具
source /opt/homebrew/opt/antigen/share/antigen/antigen.zsh

# Disable Homebrew Auto update
export HOMEBREW_NO_AUTO_UPDATE=1

# SVN
export SVN_EDITOR=vim

#  -----------------
# | antigen setting |
#  -----------------

# oh my zsh
antigen use oh-my-zsh

# zsh theme
antigen theme romkatv/powerlevel10k

# nvm
antigen bundle lukechilds/zsh-nvm

# zsh auto suggestions
antigen bundle zsh-users/zsh-autosuggestions

# zsh syntax highlight
antigen bundle zsh-users/zsh-syntax-highlighting

# zsh vim
# sourcing mode: 在 source 階段初始化 keymap，避免 zle-line-init 時清掉 typeahead buffer
# 這修復了 tmux send-keys 送出的指令被 vi-mode 吃掉的問題
ZVM_INIT_MODE=sourcing
antigen bundle jeffreytse/zsh-vi-mode

# zsh z
antigen bundle agkozak/zsh-z

# 套用 antigen 設定
antigen apply

# ------- END -------


#  ---------------
# | theme setting |
#  ---------------

ZSH_THEME="powerlevel10k/powerlevel10k"

# ------- END -------

#  ---------------
# |   variables   |
#  ---------------
DEFAULT_BROWSER="Google Chrome"

# ------- END -------

#  ---------------
# | alias setting |
#  ---------------

# alias to vscode
# terminal 下 "code ./xxx" 可以直接用 vscode 開啟檔案
alias code='/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code'

# Change Directory
alias cdw="cd ~/downloads"

# edit configs
alias ezsh="vim ~/.zshrc"
alias egit="vim ~/.gitconfig"
alias evim="vim ~/.vimrc"
alias essh="vim ~/.ssh/config"
alias ehost="vim /etc/hosts"
alias ecompose="vim ~/docker-compose.yml"
alias ls="lsd"

# open browser
alias chrome='open -a "Google Chrome"'
alias chromeDev='chrome http://localhost:3000/'
alias defaultBrowserOpen='open -a $DEFAULT_BROWSER'

# script
alias update-branches="~/.local/bin/update-branches.sh"
alias claude-monitor='cd ~/Claude-Code-Usage-Monitor && source venv/bin/activate && ./ccusage_monitor.py'

# OCI Terraform (uses OCI S3-compatible credentials for remote state)
alias tf-oci='AWS_PROFILE=oci terraform'

# ------- END -------


#  ---------------
# | other setting |
#  ---------------
export PATH="$PATH":/opt/homebrew/bin:$GOROOT/bin:~/.composer/vendor/bin
export PATH="$PATH":/usr/local/share/dotnet
export GOPATH=$(go env GOPATH)
export PATH="$PATH":$GOPATH/bin
export PATH="$HOME/.local/bin:$PATH"
export DOTNET_ROOT=/usr/local/share/dotnet

# ------- END -------

# Q post block. Keep at the bottom of this file.
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# [[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
#if [[ $TERM_PROGRAM == "kiro" ]]; then
#  source "$(kiro --locate-shell-integration-path zsh)"
#else
#  :   # Placeholder empty command, maintain exit status as 0.
#fi


export GPG_TTY=$(tty)


# Added by Antigravity
export PATH="/Users/tim80411/.antigravity/antigravity/bin:$PATH"

# bun completions
[ -s "/Users/tim80411/.bun/_bun" ] && source "/Users/tim80411/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX=YES
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# cmux: 自動根據 git project/branch 命名 workspace
if [[ -n "$CMUX_WORKSPACE_ID" ]]; then
  _cmux_auto_name() {
    local name
    if git rev-parse --is-inside-work-tree &>/dev/null; then
      local project=$(basename "$(git rev-parse --show-toplevel)")
      local branch=$(git symbolic-ref --short HEAD 2>/dev/null | tr '/' '-')
      name="${project}/${branch:-detached}"
    else
      name="${PWD##*/}"
    fi
    cmux workspace-action --action rename --title "$name" &>/dev/null &
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _cmux_auto_name
  _cmux_auto_name  # 新 workspace 開啟時也命名一次
fi

# cmux: 開新 workspace 並自動命名
cw() {
  local dir="${1:-.}"
  dir="$(cd "$dir" 2>/dev/null && pwd)" || return 1
  local name
  if git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
    local project=$(basename "$(git -C "$dir" rev-parse --show-toplevel)")
    local branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null | tr '/' '-')
    name="${project}/${branch:-detached}"
  else
    name="${dir##*/}"
  fi
  cmux new-workspace --cwd "$dir" --command "cmux workspace-action --action rename --title '${name}'"
}

# Ghostty + tmux: 透過 DCS passthrough 送 OSC 7 讓 Ghostty 知道當前目錄
# 解決新開 Tab/Split 時 working-directory=inherit 無法取得 cwd 的問題
# 注意：tmux 會把 TERM_PROGRAM 覆蓋為 "tmux"，所以改用 client_termname 偵測
if [[ -n "$TMUX" ]] && [[ "$(tmux display-message -p '#{client_termname}' 2>/dev/null)" == *ghostty* ]]; then
  _ghostty_osc7_passthrough() {
    printf '\ePtmux;\e\e]7;file://%s%s\a\e\\' "${HOST}" "${PWD}"
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _ghostty_osc7_passthrough
  _ghostty_osc7_passthrough  # 初始化時也送一次
fi


# Claude Code: Agent Teams (experimental)
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Wi-Fi password helpers (繞開 macOS 拷貝密碼 bug)
[[ -f "${HOME}/.zsh/wifi-helpers.zsh" ]] && source "${HOME}/.zsh/wifi-helpers.zsh"

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"
