#!/usr/bin/env bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper: Add content to bashrc if not already present
add_to_bashrc() {
    local search_string="$1"
    local content="$2"
    local description="$3"
    local bashrc="$HOME/.bashrc"

    touch "$bashrc"
    if ! grep -qF "$search_string" "$bashrc"; then
        echo -e "\n$content" >> "$bashrc"
        echo "✓ Configured $description"
    else
        echo "✓ $description (already configured)"
    fi
}

# Helper: Create timestamped backup of a file
backup_file() {
    local file="$1"
    [[ -f "$file" ]] && cp "$file" "$file.backup.$(date +%s)"
}

# Ensure dependencies are installed
ensure_dependencies() {
    # Check for Homebrew
    if ! command -v brew >/dev/null 2>&1; then
        echo "→ Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add brew to PATH for this session
        if [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
        echo "✓ Installed Homebrew"
    fi

    # Install missing dependencies
    local deps=(yq helix go fzf go-task zoxide ripgrep bat eza ast-grep fd direnv git-delta jq btop tlrc sd glow tokei gh procs dust)
    local cmds=(yq hx go fzf task zoxide rg bat eza ast-grep fd direnv delta jq btop tldr sd glow tokei gh procs dust)

    for i in "${!deps[@]}"; do
        if ! command -v "${cmds[$i]}" >/dev/null 2>&1; then
            echo "→ Installing ${deps[$i]}..."
            brew install "${deps[$i]}" && echo "✓ Installed ${deps[$i]}"
        else
            echo "✓ ${deps[$i]} (already installed)"
        fi
    done
}

# Check if running in WSL
is_wsl() {
    if [[ -n "${WSL_DISTRO_NAME}" ]] || grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
        return 0
    fi
    return 1
}

# Get Windows LocalAppData path (shared by both operations)
get_localappdata() {
    wslpath "$(cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')"
}

# Install fonts from fonts/ directory
install_fonts() {
    if ! is_wsl; then
        echo "⊘ Skipping fonts (not WSL)"
        return 0
    fi

    local fonts_dir="$SCRIPT_DIR/fonts"
    [[ -d "$fonts_dir" ]] || { echo "✗ Error: $fonts_dir not found"; return 1; }

    # Run PowerShell script to copy and register fonts
    powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/install_fonts.ps1")" 2>/dev/null
    echo "✓ Installed fonts"
}

# Apply Windows Terminal settings
apply_settings() {
    if ! is_wsl; then
        echo "⊘ Skipping Windows Terminal (not WSL)"
        return 0
    fi

    local localappdata=$(get_localappdata)
    local local_patch="$SCRIPT_DIR/settings.json"

    [[ -f "$local_patch" ]] || { echo "✗ Error: $local_patch not found"; return 1; }

    local wt_package=$(find "$localappdata/Packages" -maxdepth 1 -name "Microsoft.WindowsTerminal_*" -type d 2>/dev/null | head -n 1)
    [[ -n "$wt_package" ]] || { echo "✗ Error: Windows Terminal not found"; return 1; }

    local wt_settings="$wt_package/LocalState/settings.json"
    [[ -f "$wt_settings" ]] || { echo "✗ Error: settings.json not found"; return 1; }

    backup_file "$wt_settings"

    local temp_file=$(mktemp)
    trap "rm -f '$temp_file'" EXIT

    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
      "$wt_settings" "$local_patch" > "$temp_file"
    cat "$temp_file" > "$wt_settings"
    echo "✓ Applied Windows Terminal settings"
}

# Install Helix config
install_helix_config() {
    local config_source="$SCRIPT_DIR/config.toml"
    local config_dest="$HOME/.config/helix/config.toml"

    [[ -f "$config_source" ]] || { echo "✗ Error: $config_source not found"; return 1; }

    mkdir -p "$(dirname "$config_dest")"
    backup_file "$config_dest"
    cp "$config_source" "$config_dest"
    echo "✓ Installed Helix config"
}

# Configure fzf in bashrc
configure_fzf() {
    add_to_bashrc 'fzf --bash' 'eval "$(fzf --bash)"' 'fzf'
}

# Configure zoxide in bashrc
configure_zoxide() {
    add_to_bashrc 'zoxide init bash' '# Initialize zoxide (smart cd)\neval "$(zoxide init bash)"' 'zoxide'
}

# Configure direnv in bashrc
configure_direnv() {
    add_to_bashrc 'direnv hook bash' '# Initialize direnv (auto-load .envrc)\neval "$(direnv hook bash)"' 'direnv'
}

# Configure GOPATH in bashrc
configure_gopath() {
    add_to_bashrc 'go env GOPATH' '# Add Go binaries to PATH\nexport PATH="$PATH:$(go env GOPATH)/bin"' 'GOPATH'
}

# Install Go tools
install_go_tools() {
    if ! command -v go >/dev/null 2>&1; then
        echo "⊘ Skipping Go tools (Go not installed)"
        return 0
    fi

    echo "→ Installing Go tools..."

    # Install gopls (Go language server)
    go install golang.org/x/tools/gopls@latest && echo "✓ Installed gopls"

    # Install golangci-lint
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest && echo "✓ Installed golangci-lint"

    # Install delve (Go debugger)
    go install github.com/go-delve/delve/cmd/dlv@latest && echo "✓ Installed delve"

    # Install air (live reload)
    go install github.com/cosmtrek/air@latest && echo "✓ Installed air"

    echo "✓ Installed Go tools"
}

# Configure task completion in bashrc
configure_task() {
    add_to_bashrc 'task --completion bash' '# task completion\neval "$(task --completion bash)"' 'task completion'
}

# Install Claude CLI
install_claude_cli() {
    # Ensure ~/.local/bin is in PATH before installing
    configure_local_bin_path

    if command -v claude >/dev/null 2>&1; then
        echo "✓ Claude CLI (already installed)"
        return 0
    fi

    # Add ~/.local/bin to current session PATH
    export PATH="$HOME/.local/bin:$PATH"

    echo "→ Installing Claude CLI..."
    curl -fsSL https://claude.ai/install.sh | bash
    echo "✓ Installed Claude CLI"
}

# Configure Claude CLI custom instructions
configure_claude_instructions() {
    if ! command -v claude >/dev/null 2>&1; then
        echo "⊘ Skipping Claude instructions (Claude CLI not installed)"
        return 0
    fi

    local claude_file="$HOME/.claude/CLAUDE.md"
    local source_file="$SCRIPT_DIR/.claude/custom_instructions.md"

    [[ -f "$source_file" ]] || { echo "✗ Error: $source_file not found"; return 1; }

    mkdir -p "$HOME/.claude"

    # Create CLAUDE.md if it doesn't exist
    if [[ ! -f "$claude_file" ]]; then
        touch "$claude_file"
    else
        backup_file "$claude_file"
    fi

    # Remove old section if exists
    if grep -qF "<!-- env-wsl-start -->" "$claude_file"; then
        sed -i '/<!-- env-wsl-start -->/,/<!-- env-wsl-end -->/d' "$claude_file"
    fi

    # Append our instructions with delimiters
    cat >> "$claude_file" << EOF

<!-- env-wsl-start -->
$(cat "$source_file")
<!-- env-wsl-end -->
EOF

    echo "✓ Configured Claude custom instructions"
}

# Configure ~/.local/bin in PATH
configure_local_bin_path() {
    add_to_bashrc '.local/bin' '# Add ~/.local/bin to PATH\nexport PATH="$HOME/.local/bin:$PATH"' '~/.local/bin in PATH'
}

# Configure PS1 prompt
configure_ps1() {
    add_to_bashrc '# Custom PS1 prompt' '# Custom PS1 prompt (bright green username, cyan directory)\nexport PS1="\\[\\e[92m\\]\\u\\[\\e[0m\\]:\\[\\e[96m\\]\\W\\[\\e[0m\\]\\$ "' 'PS1 prompt'
}

# Configure eza aliases
configure_eza_aliases() {
    add_to_bashrc "alias ls='eza'" "# eza aliases (modern ls replacement)\nalias ls='eza'\nalias ll='eza -l'\nalias la='eza -la'" 'eza aliases'
}

# Configure git
configure_git() {
    echo "→ Configuring git..."
    git config --global user.name "Dane"
    git config --global user.email "dane@medieval.software"
    git config --global init.defaultBranch main
    git config --global pull.rebase false

    # Git aliases
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.lg "log --graph --oneline --decorate"

    # Configure delta as pager if available
    if command -v delta >/dev/null 2>&1; then
        git config --global core.pager delta
        git config --global interactive.diffFilter "delta --color-only"
        git config --global delta.navigate true
        git config --global merge.conflictStyle zdiff3
    fi

    echo "✓ Configured git"
}

# Configure bash quality of life improvements
configure_bash_qol() {
    local bashrc="$HOME/.bashrc"
    touch "$bashrc"

    if ! grep -qF 'HISTSIZE=10000' "$bashrc"; then
        cat >> "$bashrc" << 'EOF'

# Bash history improvements
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# Useful aliases
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
EOF
        echo "✓ Configured bash quality of life"
    else
        echo "✓ bash quality of life (already configured)"
    fi
}

# Configure bootstrap alias
configure_bootstrap_alias() {
    add_to_bashrc "alias bootstrap=" "# Bootstrap alias - re-run setup and reload bashrc\nalias bootstrap='bash <(curl -fsSL https://raw.githubusercontent.com/thedaneeffect/env-wsl/master/bootstrap.sh) && source ~/.bashrc'" 'bootstrap alias'
}

# Main execution
main() {
    # Ensure dependencies are installed first
    ensure_dependencies

    case "${1:-all}" in
        fonts)
            install_fonts
            ;;
        settings)
            apply_settings
            ;;
        helix)
            install_helix_config
            ;;
        fzf)
            configure_fzf
            ;;
        zoxide)
            configure_zoxide
            ;;
        direnv)
            configure_direnv
            ;;
        go)
            configure_gopath
            install_go_tools
            ;;
        task)
            configure_task
            ;;
        claude)
            install_claude_cli
            configure_claude_instructions
            ;;
        ps1)
            configure_ps1
            ;;
        eza)
            configure_eza_aliases
            ;;
        git)
            configure_git
            ;;
        bash)
            configure_bash_qol
            ;;
        bootstrap)
            configure_bootstrap_alias
            ;;
        all)
            install_fonts
            apply_settings
            install_helix_config
            configure_fzf
            configure_zoxide
            configure_direnv
            configure_gopath
            install_go_tools
            configure_task
            install_claude_cli
            configure_claude_instructions
            configure_ps1
            configure_eza_aliases
            configure_git
            configure_bash_qol
            configure_bootstrap_alias
            ;;
        *)
            echo "Usage: $0 [fonts|settings|helix|fzf|zoxide|direnv|go|task|claude|ps1|eza|git|bash|bootstrap|all]"
            echo "  fonts    - Install fonts only"
            echo "  settings - Apply Windows Terminal settings only"
            echo "  helix    - Install Helix config only"
            echo "  fzf      - Configure fzf in .bashrc only"
            echo "  zoxide   - Configure zoxide in .bashrc only"
            echo "  direnv   - Configure direnv in .bashrc only"
            echo "  go       - Configure GOPATH and install Go tools (gopls, golangci-lint, delve, air)"
            echo "  task     - Configure task completion in .bashrc only"
            echo "  claude   - Install Claude CLI and configure instructions"
            echo "  ps1      - Configure PS1 prompt in .bashrc only"
            echo "  eza      - Configure eza aliases (ls, ll, la) only"
            echo "  git      - Configure git settings only"
            echo "  bash     - Configure bash quality of life improvements only"
            echo "  bootstrap - Configure bootstrap alias only"
            echo "  all      - Do everything (default)"
            exit 1
            ;;
    esac

    echo ""
    echo "✓ Setup complete!"
    echo ""
    echo "Run: source ~/.bashrc"
    echo ""
    echo "After sourcing, you can re-run setup anytime with: bootstrap"
}

main "$@"
