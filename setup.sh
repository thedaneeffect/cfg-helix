#!/usr/bin/env bash
set -euo pipefail

# Detect user's login shell (not the shell running this script)
detect_shell() {
    # Use $SHELL to detect the user's default shell
    case "$(basename "$SHELL")" in
        zsh)
            echo "zsh"
            ;;
        bash)
            echo "bash"
            ;;
        *)
            # Fallback to bash if unknown
            echo "bash"
            ;;
    esac
}

SHELL_TYPE=$(detect_shell)
RC_FILE="$HOME/.${SHELL_TYPE}rc"

# Get script directory (works in both bash and zsh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")" && pwd)"

# Helper: Add content to shell rc file if not already present
add_to_rc() {
    local search_string="$1"
    local content="$2"
    local description="$3"

    touch "$RC_FILE"
    if ! grep -qF "$search_string" "$RC_FILE"; then
        echo -e "\n$content" >> "$RC_FILE"
        echo "✓ Configured $description"
    else
        echo "✓ $description (already configured)"
    fi
}

# Helper: Initialize snippet section (called once at start)
init_snippets() {
    touch "$RC_FILE"

    # Remove old snippets section if exists
    if grep -qF "# dotfiles-snippets-start" "$RC_FILE"; then
        sed -i.bak "/# dotfiles-snippets-start/,/# dotfiles-snippets-end/d" "$RC_FILE"
        rm -f "$RC_FILE.bak"
    fi

    # Add snippets start marker
    echo "# dotfiles-snippets-start" >> "$RC_FILE"
}

# Helper: Finalize snippet section (called once at end)
finalize_snippets() {
    echo "# dotfiles-snippets-end" >> "$RC_FILE"
}

# Helper: Add snippet (no individual deletion needed)
add_snippet() {
    local snippet_name="$1"
    local description="$2"
    local snippet_file="$SCRIPT_DIR/snippets/${snippet_name}.sh"

    # Check if snippet file exists
    [[ -f "$snippet_file" ]] || { echo "✗ Error: $snippet_file not found"; return 1; }

    # Add snippet with delimiters, substituting SHELL_TYPE placeholder
    {
        echo "# snippet:${snippet_name}.sh"
        sed "s/SHELL_TYPE/${SHELL_TYPE}/g" "$snippet_file"
        echo "# end:${snippet_name}.sh"
        echo ""
    } >> "$RC_FILE"

    echo "✓ Configured $description"
}

# Helper: Create .bak backup of a file (only if backup doesn't already exist)
backup_file() {
    local file="$1"
    if [[ -f "$file" ]] && [[ ! -f "$file.bak" ]]; then
        cp "$file" "$file.bak"
    fi
    return 0
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

    # Install dependencies (brew skips already installed packages)
    local deps=(yq helix go fzf zoxide ripgrep bat eza ast-grep fd direnv git-delta jq btop tldr sd glow tokei gh procs dust typescript-language-server bash-language-server golangci-lint zig zls taplo yaml-language-server goenv starship marksman vscode-langservers-extracted grex zellij bitwarden-cli)

    brew install -q "${deps[@]}"
    brew install -q go-task/tap/go-task
}

# Install bun
install_bun() {
    command -v bun >/dev/null 2>&1 && return 0
    curl -fsSL https://bun.sh/install | bash
}

# Check if running in WSL
is_wsl() {
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
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

# Helper: Install Go tool via go install
go_install() {
    local package="$1"
    local name="$2"
    local tags="${3:-}"

    if [[ -n "$tags" ]]; then
        go install -tags "$tags" "$package@latest" && echo "✓ Installed $name"
    else
        go install "$package@latest" && echo "✓ Installed $name"
    fi
}

# Install Go tools
install_go_tools() {
    if ! command -v go >/dev/null 2>&1; then
        echo "⊘ Skipping Go tools (Go not installed)"
        return 0
    fi

    echo "→ Installing Go tools..."

    go_install "golang.org/x/tools/gopls" "gopls"
    go_install "github.com/nametake/golangci-lint-langserver" "golangci-lint-langserver"
    go_install "github.com/segmentio/golines" "golines"
    go_install "mvdan.cc/gofumpt" "gofumpt"
    go_install "github.com/go-delve/delve/cmd/dlv" "delve"
    go_install "github.com/air-verse/air" "air"
    go_install "github.com/xo/usql" "usql" "postgres sqlite3"
    go_install "github.com/docker/docker-language-server/cmd/docker-language-server" "docker-language-server"

    echo "✓ Installed Go tools"
}

# Install Claude CLI
install_claude_cli() {
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
    local source_file="$SCRIPT_DIR/CLAUDE.md"

    [[ -f "$source_file" ]] || { echo "✗ Error: $source_file not found"; return 1; }

    mkdir -p "$HOME/.claude"

    # Create CLAUDE.md if it doesn't exist
    if [[ ! -f "$claude_file" ]]; then
        touch "$claude_file"
    else
        backup_file "$claude_file"
    fi

    # Remove old section if exists
    if grep -qF "<!-- dotfiles-start -->" "$claude_file"; then
        sed -i.bak '/<!-- dotfiles-start -->/,/<!-- dotfiles-end -->/d' "$claude_file"
        rm -f "$claude_file.bak"
    fi

    # Append our instructions with delimiters
    cat >> "$claude_file" << EOF
<!-- dotfiles-start -->
$(cat "$source_file")
<!-- dotfiles-end -->
EOF

    echo "✓ Configured Claude custom instructions"
}

# Install secrets management CLI
install_secrets_cli() {
    local secrets_script="$SCRIPT_DIR/secrets"
    local secrets_dest="$HOME/.local/bin/secrets"

    if [[ ! -f "$secrets_script" ]]; then
        echo "⊘ Skipping secrets CLI (script not found)"
        return 0
    fi

    mkdir -p "$HOME/.local/bin"
    cp "$secrets_script" "$secrets_dest"
    chmod +x "$secrets_dest"
    echo "✓ Installed secrets CLI"

    # Try to pull secrets if Bitwarden is available and unlocked
    if command -v bw >/dev/null 2>&1 && bw login --check &>/dev/null && [[ -n "${BW_SESSION:-}" ]]; then
        echo "→ Pulling secrets from Bitwarden..."
        if "$secrets_dest" pull 2>/dev/null; then
            echo "✓ Pulled secrets from Bitwarden"
        else
            echo "⊘ No secrets in Bitwarden yet (use: secrets push)"
        fi
    fi
}

# Configure git
configure_git() {
    echo "→ Configuring git..."
    git config --global user.name "Dane"
    git config --global user.email "dane@medieval.software"
    git config --global init.defaultBranch main
    git config --global pull.rebase false

    # Use Helix as editor
    git config --global core.editor "hx"
    git config --global sequence.editor "hx"

    # Git aliases
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.lg "log --graph --oneline --decorate"
    git config --global alias.cm "commit -m"
    git config --global alias.amend "commit --amend --no-edit"
    git config --global alias.uncommit "reset --soft HEAD~1"
    git config --global alias.unstage "reset HEAD --"
    git config --global alias.last "log -1 HEAD"
    git config --global alias.branches "branch -a"
    git config --global alias.remotes "remote -v"
    git config --global alias.contributors "shortlog -sn"

    # Better diff algorithm
    git config --global diff.algorithm histogram

    # Prune on fetch
    git config --global fetch.prune true

    # Reuse recorded resolution (helps with repetitive merge conflicts)
    git config --global rerere.enabled true

    # Configure delta as pager if available
    if command -v delta >/dev/null 2>&1; then
        git config --global core.pager delta
        git config --global interactive.diffFilter "delta --color-only"
        git config --global delta.navigate true
        git config --global merge.conflictStyle zdiff3
    fi

    # Install global gitignore
    local gitignore_source="$SCRIPT_DIR/.gitignore_global"
    local gitignore_dest="$HOME/.gitignore_global"

    if [[ -f "$gitignore_source" ]]; then
        backup_file "$gitignore_dest"
        cp "$gitignore_source" "$gitignore_dest"
        git config --global core.excludesFile "$gitignore_dest"
        echo "✓ Installed global gitignore"
    fi

    echo "✓ Configured git"
}

# Main execution
main() {
    # Ensure dependencies are installed first
    ensure_dependencies
    install_bun

    # Run all configurations
    install_fonts
    apply_settings
    install_helix_config
    configure_git

    # Initialize snippet section
    init_snippets

    # Add all snippets
    add_snippet "fzf" "fzf"
    add_snippet "zoxide" "zoxide"
    add_snippet "direnv" "direnv"
    add_snippet "goenv" "goenv"
    add_snippet "gopath" "GOPATH"
    add_snippet "task" "task completion"
    add_snippet "bun" "bun"
    add_snippet "local_bin" "~/.local/bin in PATH"
    add_snippet "starship" "Starship prompt"
    add_snippet "eza_aliases" "eza aliases"
    add_snippet "git_aliases" "git aliases"
    add_snippet "fzf_git" "fzf + git integration"
    add_snippet "dev" "development utilities"
    add_snippet "xdg" "XDG directories"
    add_snippet "qol" "shell quality of life"

    # Shell-specific snippets
    if [ "$SHELL_TYPE" = "zsh" ]; then
        [[ "$(uname)" = "Darwin" ]] && add_snippet "macos_bindkeys" "macOS bindkeys"
        add_snippet "zsh_dirstack" "zsh features"
        add_snippet "zsh_qol" "zsh history config"
    else
        add_snippet "bash_qol" "bash history config"
    fi

    add_snippet "bootstrap" "bootstrap alias"

    # Finalize snippet section
    finalize_snippets

    # Non-snippet configurations
    install_go_tools
    install_claude_cli
    configure_claude_instructions
    install_secrets_cli

    echo ""
    echo "✓ Setup complete!"
    echo ""
    echo "Run: source ~/.${SHELL_TYPE}rc"
    echo ""
    echo "After sourcing, you can re-run setup anytime with: bootstrap"
    echo ""
    echo "Manage secrets with: secrets add <file>, secrets push, secrets pull"
}

main
