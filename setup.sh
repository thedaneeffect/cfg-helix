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
    local deps=(yq helix go fzf go-task zoxide ripgrep bat eza ast-grep fd direnv git-delta jq btop tlrc sd glow tokei gh procs dust typescript-language-server bash-language-server golangci-lint zig zls taplo yaml-language-server goenv starship bun)
    local cmds=(yq hx go fzf task zoxide rg bat eza ast-grep fd direnv delta jq btop tldr sd glow tokei gh procs dust typescript-language-server bash-language-server golangci-lint zig zls taplo yaml-language-server goenv starship bun)

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

# Configure fzf in shell rc
configure_fzf() {
    add_snippet "fzf" "fzf"
}

# Configure zoxide in shell rc
configure_zoxide() {
    add_snippet "zoxide" "zoxide"
}

# Configure direnv in shell rc
configure_direnv() {
    add_snippet "direnv" "direnv"
}

# Configure goenv in shell rc
configure_goenv() {
    add_snippet "goenv" "goenv"
}

# Configure GOPATH in shell rc
configure_gopath() {
    add_snippet "gopath" "GOPATH"
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

    echo "✓ Installed Go tools"
}

# Configure task completion in shell rc
configure_task() {
    add_snippet "task" "task completion"
}

# Configure bun
configure_bun() {
    add_snippet "bun" "bun"
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
    fi

    # Append our instructions with delimiters
    cat >> "$claude_file" << EOF
<!-- dotfiles-start -->
$(cat "$source_file")
<!-- dotfiles-end -->
EOF

    echo "✓ Configured Claude custom instructions"
}

# Configure ~/.local/bin in PATH
configure_local_bin_path() {
    add_snippet "local_bin" "~/.local/bin in PATH"
}

# Configure Starship prompt
configure_starship() {
    add_snippet "starship" "Starship prompt"
}

# Configure eza aliases
configure_eza_aliases() {
    add_snippet "eza_aliases" "eza aliases"
}

# Configure git shell aliases
configure_git_aliases() {
    add_snippet "git_aliases" "git aliases"
}

# Configure macOS bindkeys for zsh
configure_macos_bindkeys() {
    if [[ "$(uname)" != "Darwin" ]] || [[ "$SHELL_TYPE" != "zsh" ]]; then
        return 0
    fi

    add_snippet "macos_bindkeys" "macOS bindkeys"
}

# Configure XDG Base Directory specification
configure_xdg() {
    add_snippet "xdg" "XDG directories"
}

# Configure zsh-specific features
configure_zsh() {
    if [[ "$SHELL_TYPE" != "zsh" ]]; then
        return 0
    fi

    add_snippet "zsh_dirstack" "zsh features"
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

# Configure shell quality of life improvements
configure_bash_qol() {
    add_snippet "qol" "shell quality of life"

    if [ "$SHELL_TYPE" = "zsh" ]; then
        add_snippet "zsh_qol" "zsh history config"
    else
        add_snippet "bash_qol" "bash history config"
    fi
}

# Configure bootstrap alias
configure_bootstrap_alias() {
    add_snippet "bootstrap" "bootstrap alias"
}

# Main execution
main() {
    # Ensure dependencies are installed first
    ensure_dependencies

    # Run all configurations
    install_fonts
    apply_settings
    install_helix_config
    configure_git

    # Initialize snippet section
    init_snippets

    configure_fzf
    configure_zoxide
    configure_direnv
    configure_goenv
    configure_gopath
    configure_task
    configure_bun
    configure_local_bin_path
    configure_starship
    configure_eza_aliases
    configure_git_aliases
    configure_macos_bindkeys
    configure_xdg
    configure_zsh
    configure_bash_qol
    configure_bootstrap_alias

    # Finalize snippet section
    finalize_snippets

    # Non-snippet configurations
    install_go_tools
    install_claude_cli
    configure_claude_instructions

    echo ""
    echo "✓ Setup complete!"
    echo ""
    echo "Run: source ~/.${SHELL_TYPE}rc"
    echo ""
    echo "After sourcing, you can re-run setup anytime with: bootstrap"
}

main
