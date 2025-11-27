export SAVEHIST=20000
export HISTFILE=~/.zsh_history

setopt AUTO_PUSHD           # Automatically push directories onto stack
setopt PUSHD_MINUS          # Swap meaning of cd +1 and cd -1
setopt CDABLE_VARS          # Allow cd to variable names
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS

autoload -Uz compinit
compinit

zstyle ':completion:*:directory-stack' list-colors '=(#b) #([0-9]#)*( *)==95=38;5;12'

