# p10k config source
[[! -f ~/.p10k.zsh]] || source ~/.p10k.zsh

# Terminal 中的 Report terminal type 改為 xterm-256color 
export TERM='xterm-256color'

# 載入 antigen
# zsh 的插件管理工具
source /opt/homebrew/opt/antigen/share/antigen/antigen.zsh 

# Disable Homebrew Auto update
export HOMEBREW_NO_AUTO_UPDATE=1

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
alias ls="exa --icons"

# open browser
alias chrome='open -a "Google Chrome"'
alias chromeDev='chrome http://localhost:3000/'
alias defaultBrowserOpen='open -a $DEFAULT_BROWSER'
# ------- END -------


#  ---------------
# | other setting |
#  ---------------


# ------- END -------
