# mise - unified tool version management

# mise activation
eval "$(mise activate zsh 2>/dev/null)"
eval "$(mise completion zsh)"

# Aliases for convenience
alias mi='mise'
alias mii='mise install'
alias miu='mise upgrade'
alias mis='mise use'
alias mil='mise list'
alias mio='mise outdated'

# mise doctor for troubleshooting
alias mise-doctor='mise doctor'

# Quick tool version check
alias mise-versions='mise list --installed'
