#!/usr/bin/env bash

# =========== color variables =========
COLOR_GRAY="\033[1;38;5;243m"
COLOR_BLUE="\033[1;34m"
COLOR_GREEN="\033[1;32m"
COLOR_RED="\033[1;31m"
COLOR_PURPLE="\033[1;35m"
COLOR_YELLOW="\033[1;33m"
COLOR_NONE="\033[0m"

# ========= utility functions ===========

function print_out {
    printf "\n${COLOR_BLUE}info ${COLOR_NONE}cancelled\n"
    exit
}

# step_rc:目前階段是否發生錯誤(0=無,1=有)。由主迴圈的 ERR trap 與 fail_here 設定。
# 這是「讓失敗看得見」的核心:success 會依它決定印綠色 success 還是紅色 FAILED。
step_rc=0

function success {
    if [ "${step_rc:-0}" -ne 0 ]; then
        printf "\n ${COLOR_RED}FAILED ${COLOR_NONE}$1${COLOR_GRAY} (見上方錯誤)${COLOR_NONE}\n"
    else
        printf "\n ${COLOR_GREEN}success ${COLOR_NONE}$1\n"
    fi
}

function warn {
    printf "\n ${COLOR_YELLOW}warn ${COLOR_NONE}$1\n"
}

# 標記目前階段為失敗(結尾總結會列出),但不中斷後續階段
function fail_here {
    step_rc=1
}

function error {
    printf "\n${COLOR_RED}error ${COLOR_NONE}$1\n"
    exit
}


function print_step {
    printf "\n${COLOR_PURPLE}step %s/%s  ${COLOR_YELLOW}%s" "$1" "$len" "$2"
    printf "\n${COLOR_GRAY}=====================================${COLOR_NONE}\n"
}

trap print_out SIGTERM SIGINT SIGHUP

# ========= install step function ===================

# Install homebrew
function install_homebrew {
    title="Install Homebrew"
    print_step "$1" "$title"
    # 已安裝就不必重跑官方安裝器(否則每次都會空轉:重新 fetch brew repo、重設權限,又慢又吵)
    if command -v brew >/dev/null 2>&1; then
        warn "$title: Homebrew 已安裝,略過安裝"
    else
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    # 非互動 shell 不讀 .zshrc,手動載入 brew 環境讓後續 brew bundle 找得到;
    # shellenv 會正確 prepend(勝過原本 append 的 export,避免系統同名工具蓋過 brew 版)
    eval "$(/opt/homebrew/bin/brew shellenv)"
    success "$title"
}

# Install APP by homebrew
function install_homebrew_dependencies {
    title="Install Homebrew dependencies"
    print_step "$1" "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/Brewfile > /tmp/Brewfile
    # brew 6.x 預設並行下載,~100 個套件裡偶發 1-2 個暫時性 CDN 失敗很常見。
    # brew bundle 具冪等性(已裝的會略過),因此重試最多 3 次讓暫時性失敗自我修復。
    local ok=0 attempt
    for attempt in 1 2 3; do
        if brew bundle --file /tmp/Brewfile; then
            ok=1
            break
        fi
        warn "brew bundle 第 ${attempt} 次未全數成功,3 秒後重試…"
        sleep 3
    done
    [ "$ok" -eq 1 ] || { warn "brew bundle 重試 3 次後仍有套件未安裝,請查看上方輸出"; fail_here; }
    rm /tmp/Brewfile

    success "$title"
}

# Setting zsh
function configure_zsh {
    title="configure zsh"
    print_step "$1" "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/.zshrc > ~/.zshrc
    mkdir -p ~/.zsh
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/.zsh/wifi-helpers.zsh > ~/.zsh/wifi-helpers.zsh
    success "$title"
}

# Setting zsh theme by powerlevel10k
function configure_powerlevel10k {
    title="configure powerlevel10k"
    print_step "$1" "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/.p10k.zsh > ~/.p10k.zsh

    success "$title"
}

# Setup zsh as default shell
function setup_default_use_zsh {
    title="setup default use zsh"
    print_step "$1" "$title"
    # chsh 在「已是 zsh」時會回傳非零並印 no changes made,屬正常情況,不算失敗
    chsh -s /bin/zsh || warn "$title: 預設 shell 未變更(可能已是 zsh)"

    success "$title"
}

# setting git
function configure_git {
    title="configure git"
    print_step "$1" "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/.gitconfig > ~/.gitconfig
    success "$title"
}

# setting docker-compose
function configure_docker_compose {
    title="configure docker-compose basic"
    print_step "$1" "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/docker-compose.yml > ~/docker-compose.yml
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/mongo_setup.sh > ~/mongo_setup.sh
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/init.sh > ~/init.sh
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/redis.conf > ~/redis.conf
    success "$title"
}

# setting ssh config
function configure_ssh_config {
    title="configure ssh config"
    print_step "$1" "$title"
    # 修正:寫檔前先建立 ~/.ssh(否則新機器上 curl 會因目錄不存在而失敗);ssh 要求該目錄權限 700
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    # 既有 config 先備份,避免無備份覆蓋個人設定
    [ -f ~/.ssh/config ] && cp ~/.ssh/config ~/.ssh/config.bak
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/sshConfig > ~/.ssh/config
    success "$title"
}

# setting vim config
function configure_vim_config {
    title="configure vim config"
    print_step "$1" "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/.vimrc > ~/.vimrc
    success "$title"
}

# install and configure ccstatusline
function configure_ccstatusline {
    title="configure ccstatusline"
    print_step "$1" "$title"
    # 修正:npm 由 nvm 管理,非互動 shell 不會自動載入 nvm,需手動 source 才找得到 npm。
    # source nvm.sh 時暫時卸下 ERR trap,避免 nvm 內部的非零指令誤觸發本階段失敗。
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        trap - ERR
        . "$NVM_DIR/nvm.sh"
        trap 'step_rc=1' ERR
    fi
    if command -v npm >/dev/null 2>&1; then
        npm install -g ccstatusline
    else
        warn "$title: 找不到 npm(需先用 nvm 安裝 node),略過 ccstatusline 本體安裝"
        fail_here
    fi
    mkdir -p ~/.config/ccstatusline
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/ccstatusline/settings.json > ~/.config/ccstatusline/settings.json

    success "$title"
}

# setting claude rate-limit script
function configure_claude_scripts {
    title="configure claude scripts"
    print_step "$1" "$title"
    mkdir -p ~/.claude/scripts
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/claude/scripts/rate-limit.sh > ~/.claude/scripts/rate-limit.sh
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/claude/scripts/auto-rename.sh > ~/.claude/scripts/auto-rename.sh
    chmod +x ~/.claude/scripts/rate-limit.sh ~/.claude/scripts/auto-rename.sh

    success "$title"
}

# configure ghostty
function configure_ghostty {
    title="configure ghostty"
    print_step "$1" "$title"
    mkdir -p ~/.config/ghostty
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/ghostty/config > ~/.config/ghostty/config
    success "$title"
}

# configure tmux
function configure_tmux {
    title="configure tmux"
    print_step "$1" "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/.tmux.conf > ~/.tmux.conf
    mkdir -p ~/bin
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/tmux/tmux-new.sh > ~/bin/tmux-new.sh
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/tmux/tmux-pick.sh > ~/bin/tmux-pick.sh
    chmod +x ~/bin/tmux-new.sh ~/bin/tmux-pick.sh
    success "$title"
}

# configure claude settings
function configure_claude_settings {
    title="configure claude settings"
    print_step "$1" "$title"
    mkdir -p ~/.claude
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/claude/settings.json > ~/.claude/settings.json

    success "$title"
}

# configure claude plugins
function configure_claude_plugins {
    title="configure claude plugins"
    print_step "$1" "$title"
    mkdir -p ~/.claude/plugins
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/claude/plugins/installed_plugins.json | sed "s|__HOME__|$HOME|g" > ~/.claude/plugins/installed_plugins.json
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/claude/plugins/known_marketplaces.json | sed "s|__HOME__|$HOME|g" > ~/.claude/plugins/known_marketplaces.json

    success "$title"
}

# configure claude notify script
function configure_claude_notify {
    title="configure claude notify script"
    print_step "$1" "$title"
    mkdir -p ~/.claude
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/claude/notify_mobile.sh > ~/.claude/notify_mobile.sh
    chmod +x ~/.claude/notify_mobile.sh
    success "$title"
}

# configure claude hooks (verify-before-done Stop hook)
function configure_claude_hooks {
    title="configure claude hooks"
    print_step "$1" "$title"
    mkdir -p ~/.claude/hooks
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/claude/hooks/verify.sh > ~/.claude/hooks/verify.sh
    chmod +x ~/.claude/hooks/verify.sh
    success "$title"
}

# configure TCIM auto-restart (fix input method freeze)
function configure_tcim_restart {
    title="configure tcim auto-restart"
    print_step "$1" "$title"
    mkdir -p ~/bin
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/tcim/restart-tcim.sh > ~/bin/restart-tcim.sh
    chmod +x ~/bin/restart-tcim.sh
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/tcim/com.local.restart-tcim.plist | sed "s|__HOME__|$HOME|g" > ~/Library/LaunchAgents/com.local.restart-tcim.plist
    # unload 在「尚未載入」時會回傳非零,屬正常情況,以 || true 吸收避免誤判失敗
    launchctl unload ~/Library/LaunchAgents/com.local.restart-tcim.plist 2>/dev/null || true
    launchctl load ~/Library/LaunchAgents/com.local.restart-tcim.plist

    success "$title"
}

function init_service {
    title="init service"
    print_step "$1" "$title"
    # 修正:docker 由 OrbStack 提供,非互動 shell 的 PATH 不含其 CLI 路徑,先補上
    export PATH="$PATH:/usr/local/bin:$HOME/.orbstack/bin"
    if command -v docker >/dev/null 2>&1; then
        # OrbStack「已安裝」不代表「已啟動」;daemon 沒起來 docker compose 也起不來,先確保它就緒
        if ! docker info >/dev/null 2>&1; then
            open -a OrbStack 2>/dev/null || true
            for i in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
        fi
        if docker info >/dev/null 2>&1; then
            chmod +x ~/init.sh
            ~/init.sh
        else
            warn "$title: docker daemon 未就緒,略過 docker compose up"
            fail_here
        fi
    else
        warn "$title: 找不到 docker(OrbStack 未安裝或未啟動),略過服務初始化"
        fail_here
    fi
    success "$title"
}

install_step=("install_homebrew" "install_homebrew_dependencies" "configure_git" "configure_zsh" "configure_powerlevel10k" "configure_docker_compose" "configure_ssh_config" "configure_vim_config" "configure_claude_scripts" "configure_claude_hooks" "configure_ghostty" "configure_tmux" "configure_claude_notify" "configure_claude_settings" "configure_claude_plugins" "configure_ccstatusline" "configure_tcim_restart" "init_service" "setup_default_use_zsh")

len=${#install_step[*]}


# ================= main function ========================
# set -E 讓 ERR trap 被 function 繼承;ERR trap 只「記錄」不 exit,所以單一階段失敗
# 不會中斷整個安裝,而是在結尾統一列出。這解決了「每個階段都必定回報 success」的問題。
set -E
trap 'step_rc=1' ERR

failed_steps=()
for step in "${!install_step[@]}"; do
    step_rc=0
    "${install_step[$step]}" "$(( step + 1 ))"
    [ "$step_rc" -eq 0 ] || failed_steps+=("${install_step[$step]}")
done

trap - ERR

if [ "${#failed_steps[@]}" -gt 0 ]; then
    printf "\n${COLOR_RED}==== 完成,但有 %s 個階段發生問題 ====${COLOR_NONE}\n" "${#failed_steps[@]}"
    for s in "${failed_steps[@]}"; do
        printf "  ${COLOR_RED}✘${COLOR_NONE} %s\n" "$s"
    done
    printf "${COLOR_GRAY}(其餘階段成功。請往上捲動查看各失敗階段的細節)${COLOR_NONE}\n"
    exit 1
fi

printf "\n${COLOR_GREEN}==== 全部 %s 個階段完成 ====${COLOR_NONE}\n" "$len"
