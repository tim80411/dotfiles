#!/usr/bin/env bash

# =========== colro variables =========
COLOR_GRAY="\033[1;38;5;243m"
COLOR_BLUE="\033[1;34m"
COLOR_GREEN="\033[1;32m"
COLOR_RED="\033[1;31m"
COLOR_PURPLE="\033[1;35m"
COLOR_YELLOW="\033[1;33m"
COLOR_NONE="\033[0m"

# ========= utilites function ===========

function print_out {
    printf "\n${COLOR_BLUE}info ${COLOR_NONE}canel\n"
    exit
}

function success {
    printf "\n ${COLOR_GREEN}success ${COLOR_NONE}$1\n"
}

function error {
    printf "\n${COLOR_RED}error ${COLOR_NONE}$1\n"
    exit
}


function print_step {
    printf "\n${COLOR_PURPLE}step $1/$len  ${COLOR_YELLOW}$2"
    printf "\n${COLOR_GRAY}=====================================${COLOR_NONE}\n"
}

trap print_out SIGTERM SIGINT SIGHUP

# ========= install step function ===================

# Install homebrew
function install_homebrew {
    title="Install Homebrew"
    print_step $1 "$title"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    export PATH=$PATH:/opt/homebrew/bin

    success "$title"
}

# Install APP by homebrew
function install_homebrew_dependencies {
    title="Install Homebrew dependencies"
    print_step $1 "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/Brewfile > /tmp/Brewfile  
    brew bundle --file /tmp/Brewfile  
    rm /tmp/Brewfile

    success "$title"
}

# Setting zsh 
function configuare_zsh {
    title="configuare zsh"
    print_step $1 "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/.zshrc > ~/.zshrc
    success "$title"
}

# Setting zsh theme by powerlevel10k
function configuare_powerlevel10k {
    title="configuare powerlevel10k"
    print_step $1 "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/.p10k.zsh > ~/.p10k.zsh

    success "$title"
}

# Setup zsh to deafault shell
function setup_default_use_zsh {
    title="setup default use zsh"
    print_step $1 "$title"
    chsh -s /bin/zsh
    zsh

    success "$title"
}

# setting git
function configure_git {
    title="configure git"
    print_step $1 "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/.gitconfig > ~/.gitconfig
}

# setting docker-compose
function configure_docker_compose {
    title="configure docker-compose basic"
    print_step $1 "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/docker-compose.yml > ~/docker-compose.yml
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/mongo_setup.sh > ~/mongo_setup.sh
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/init.sh > ~/init.sh
}

# setting ssh config
function configure_ssh_config {
    title="configure ssh config"
    print_step $1 "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/sshConfig > ~/.ssh/config
}

# setting vim config
function configure_vim_config {
    title="configure vim config"
    print_step $1 "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/.vimrc > ~/.vimrc
}

# setting redis config
function configure_redis_config {
    title="configure redis config"
    print_step $1 "$title"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/redis.conf > ~/redis.conf
}

# install and configure ccstatusline
function configure_ccstatusline {
    title="configure ccstatusline"
    print_step $1 "$title"
    npm install -g ccstatusline
    mkdir -p ~/.config/ccstatusline
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/ccstatusline/settings.json > ~/.config/ccstatusline/settings.json

    success "$title"
}

# setting claude rate-limit script
function configure_claude_scripts {
    title="configure claude scripts"
    print_step $1 "$title"
    mkdir -p ~/.claude/scripts
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/claude/scripts/rate-limit.sh > ~/.claude/scripts/rate-limit.sh
    chmod +x ~/.claude/scripts/rate-limit.sh

    success "$title"
}

# configure tmux
function configure_tmux {
    title="configure tmux"
    print_step $1 "$title"
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
    print_step $1 "$title"
    mkdir -p ~/.claude
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/claude/settings.json > ~/.claude/settings.json

    success "$title"
}

# configure claude plugins
function configure_claude_plugins {
    title="configure claude plugins"
    print_step $1 "$title"
    mkdir -p ~/.claude/plugins
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/claude/plugins/installed_plugins.json | sed "s|__HOME__|$HOME|g" > ~/.claude/plugins/installed_plugins.json
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/claude/plugins/known_marketplaces.json | sed "s|__HOME__|$HOME|g" > ~/.claude/plugins/known_marketplaces.json

    success "$title"
}

# configure claude notify script
function configure_claude_notify {
    title="configure claude notify script"
    print_step $1 "$title"
    mkdir -p ~/.claude
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/claude/notify_mobile.sh > ~/.claude/notify_mobile.sh
    chmod +x ~/.claude/notify_mobile.sh
    success "$title"
}

# configure TCIM auto-restart (fix input method freeze)
function configure_tcim_restart {
    title="configure tcim auto-restart"
    print_step $1 "$title"
    mkdir -p ~/bin
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/tcim/restart-tcim.sh > ~/bin/restart-tcim.sh
    chmod +x ~/bin/restart-tcim.sh
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/macOS/tcim/com.local.restart-tcim.plist | sed "s|__HOME__|$HOME|g" > ~/Library/LaunchAgents/com.local.restart-tcim.plist
    launchctl unload ~/Library/LaunchAgents/com.local.restart-tcim.plist 2>/dev/null
    launchctl load ~/Library/LaunchAgents/com.local.restart-tcim.plist

    success "$title"
}

function init_service {
    title="init service"
    print_step $1 "$title"
    chmod +x ~/init.sh
    ~/init.sh
}

install_step=("install_homebrew" "install_homebrew_dependencies" "configure_git" "configuare_zsh" "configuare_powerlevel10k" "configure_docker_compose" "configure_ssh_config" "configure_vim_config" "configure_claude_scripts" "configure_tmux" "configure_claude_notify" "configure_claude_settings" "configure_claude_plugins" "configure_ccstatusline" "configure_tcim_restart" "init_service" "setup_default_use_zsh")

len=${#install_step[*]}


# ================= main function ========================
try
(
    for step in ${!install_step[@]}; do
    
        ${install_step[$step]} `expr $step + 1`
   
    
    done
)
cache || {
    error "Error" SIGTERM SIGINT SIGHUP
}
