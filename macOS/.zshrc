
# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh"


# p10k config source
if [[ -n "$CURSOR_AGENT" ]]; then
  # Skip theme initialization for better compatibility
else
  [[ -r ~/.p10k.zsh ]] && source ~/.p10k.zsh
fi

# Terminal 中的 Report terminal type 改為 xterm-256color
export TERM='xterm-256color'

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
export PATH="$PATH":/opt/homebrew/opt/dotnet@6/libexec
export GOPATH=$(go env GOPATH)
export PATH="$PATH":$GOPATH/bin
export PATH="$HOME/.local/bin:$PATH"
export DOTNET_ROOT=/opt/homebrew/opt/dotnet@6/libexec

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



# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"
