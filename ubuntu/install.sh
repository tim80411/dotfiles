#!/bin/bash

# Ubuntu 24.04+ Dotfiles Installation Script
# Usage: curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/ubuntu/install.sh | bash

set -e

echo "=========================================="
echo "  Ubuntu 24.04+ Dotfiles Installation"
echo "=========================================="

# Update system
echo "[1/8] Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
echo "[2/8] Installing essential packages..."
sudo apt install -y \
    git \
    curl \
    wget \
    zsh \
    vim \
    build-essential \
    fontconfig \
    unzip \
    software-properties-common

# Set Zsh as default shell (using usermod to avoid interactive password prompt)
echo "[3/8] Setting Zsh as default shell..."
if [ "$SHELL" != "$(which zsh)" ]; then
    sudo usermod -s $(which zsh) $USER
fi

# Install Oh My Zsh
echo "[4/8] Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install Powerlevel10k theme
echo "[5/8] Installing Powerlevel10k theme..."
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

# Install Zsh plugins
echo "[6/8] Installing Zsh plugins..."
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# Install Nerd Fonts (Hack)
echo "[7/8] Installing Hack Nerd Font..."
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

if [ ! -f "$FONT_DIR/HackNerdFont-Regular.ttf" ]; then
    cd /tmp
    wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
    unzip -o Hack.zip -d "$FONT_DIR"
    rm Hack.zip
    fc-cache -fv
fi

# Copy configuration files
echo "[8/8] Copying configuration files..."
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If running from curl, download configs
if [ ! -f "$DOTFILES_DIR/.p10k.zsh" ]; then
    DOTFILES_DIR="/tmp/dotfiles-ubuntu"
    mkdir -p "$DOTFILES_DIR"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/ubuntu/.p10k.zsh -o "$DOTFILES_DIR/.p10k.zsh"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/ubuntu/.zshrc -o "$DOTFILES_DIR/.zshrc"
    curl -fsSL https://raw.githubusercontent.com/tim80411/dotfiles/master/ubuntu/sshConfig -o "$DOTFILES_DIR/sshConfig"
fi

# Backup existing configs
[ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d%H%M%S)"
[ -f "$HOME/.p10k.zsh" ] && cp "$HOME/.p10k.zsh" "$HOME/.p10k.zsh.backup.$(date +%Y%m%d%H%M%S)"

# Copy new configs
cp "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
cp "$DOTFILES_DIR/.p10k.zsh" "$HOME/.p10k.zsh"

# Setup SSH config
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/config" ]; then
    cp "$DOTFILES_DIR/sshConfig" "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
fi

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Log out and log back in (or run: exec zsh)"
echo "2. Configure your terminal to use 'Hack Nerd Font'"
echo "3. Run 'p10k configure' to customize your prompt"
echo ""
