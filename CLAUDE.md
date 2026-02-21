# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Personal dotfiles for macOS and Ubuntu environments. Configs are deployed via install scripts that curl files from the GitHub `master` branch, so **all changes must be committed and pushed to `master` to take effect on target machines**.

## Repository Structure

```
macOS/          # macOS-specific configs
  install.sh    # Main installer — runs steps sequentially via function array
  Brewfile      # Homebrew packages and casks
  .zshrc        # Zsh config (antigen-based plugin management)
  .tmux.conf    # tmux configuration
  .gitconfig    # Git aliases and settings
  .vimrc        # Vim settings
  .p10k.zsh     # Powerlevel10k theme config
  claude/       # Claude Code settings, plugins, hooks, scripts
  ccstatusline/ # ccstatusline settings
  tcim/         # TCIM input method auto-restart (launchd)
  tmux/         # tmux helper scripts (tmux-new.sh, tmux-pick.sh)

ubuntu/         # Ubuntu-specific configs
  install.sh    # Ubuntu installer (apt-based, Oh My Zsh direct install)
  .zshrc        # Zsh config (Oh My Zsh-based, no antigen)
  .p10k.zsh     # Powerlevel10k theme config
```

## Key Architecture Details

- **macOS install.sh** uses `try/cache` (sic — typo for `catch`) error handling and a function array (`install_step`) to run steps in order. Each step curls the config from GitHub raw URL to its target location.
- **macOS .zshrc** uses **antigen** for plugin management (installed via Homebrew). Ubuntu .zshrc uses **Oh My Zsh** directly with git-cloned plugins — they are not interchangeable.
- **Claude Code config** (`macOS/claude/`) includes: global `settings.json` with hooks (mobile notifications on Stop/Notification events), plugin list (`plugins/installed_plugins.json`), a rate-limit status script, and a notify script. The `__HOME__` placeholder in plugin JSON files is replaced with `$HOME` via `sed` during install.
- **tmux scripts** (`macOS/tmux/`) create sessions named by git project + branch + timestamp, designed for use with iTerm2 and ShellFish (remote SSH).

## Common Tasks

```bash
# Test macOS install script locally (will overwrite your configs!)
bash macOS/install.sh

# Test Ubuntu install script
bash ubuntu/install.sh
```

## Conventions

- Config files use their native dot-prefixed names (`.zshrc`, `.gitconfig`, etc.) stored without the home directory path.
- Install scripts deploy by curling from `https://raw.githubusercontent.com/tim80411/dotfiles/master/...` — file paths in the repo must match the curl URLs.
- Comments in config files are written in Traditional Chinese (zh-TW).
