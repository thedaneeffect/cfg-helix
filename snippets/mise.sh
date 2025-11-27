# mise - unified tool version management
# Replaces: goenv, direnv (partially), task

# mise activation
eval "$(mise activate bash 2>/dev/null || mise activate zsh 2>/dev/null)"

# Optional: mise completions
# Detect shell type for completions
if [ -n "$BASH_VERSION" ]; then
    eval "$(mise completion bash)"
elif [ -n "$ZSH_VERSION" ]; then
    eval "$(mise completion zsh)"
fi

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
