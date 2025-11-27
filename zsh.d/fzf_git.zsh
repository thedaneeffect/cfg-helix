# FZF + Git integration
alias gcob='git branch | fzf | xargs git checkout'
alias glf='git log --oneline | fzf --preview "git show {1}"'
