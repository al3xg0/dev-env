export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
export PATH="$PATH:$HOME/.local/bin"
export CDPATH=.:$HOME/github-repos:$HOME/github-repos/work:$HOME/github-repos/personal:$HOME/github-repos/learning

# Prompt
eval "$(starship init zsh)"

# Docker
export PATH="$HOME/.docker/bin:$PATH"

# Google Cloud SDK
source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"

export PATH="$HOME/.bedrock/bin:$PATH"
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

export PATH="$PATH:$HOME/flutter/bin"
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
export PATH="$PATH:$HOME/.pub-cache/bin"
export GOPRIVATE=github.com/e-flux-platform

export LANG=en_US.UTF-8
export LC_MESSAGES=en_US.UTF-8

# Aliases
alias k='kubectl'
alias mongo-up="brew services start mongodb-community@7.0"
alias mongo-down="brew services stop mongodb-community@7.0"
alias mongo-restart="brew services restart mongodb-community@7.0"

# Plugins
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
