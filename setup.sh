#!/usr/bin/env bash
set -euo pipefail

# Uncomment for debugging: set -x
# Or run with: DEBUG=1 ./setup.sh
[[ "${DEBUG:-}" == "1" ]] && set -x

# Check if running as root
if [[ $EUID -eq 0 ]] && [[ -z "${ALLOW_ROOT:-}" ]]; then
    echo "✗ Error: This script should not be run as root"
    echo ""
    echo "Homebrew and other tools work best with a non-root user."
    echo ""
    echo "In Docker, create a user first:"
    echo "  adduser --disabled-password --gecos '' user"
    echo "  su - user"
    echo "  cd /dotfiles"
    echo "  ./setup.sh"
    echo ""
    echo "Or set ALLOW_ROOT=1 to bypass (not recommended):"
    echo "  ALLOW_ROOT=1 ./setup.sh"
    exit 1
fi

# Get script directory (works in both bash and zsh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")" && pwd)"
RC_FILE="$HOME/.zshrc"

# Install zsh configuration
install_zsh_config() {
    local source_file="$SCRIPT_DIR/.zshrc"

    if [[ ! -f "$source_file" ]]; then
        echo "✗ Error: $source_file not found"
        return 1
    fi

    # Ensure .zshrc exists
    touch "$RC_FILE"

    # Backup existing .zshrc
    backup_file "$RC_FILE"

    # Remove old dotfiles section if exists
    if grep -qF "# dotfiles-start" "$RC_FILE"; then
        sed -i.bak '/# dotfiles-start/,/# dotfiles-end/d' "$RC_FILE"
        rm -f "$RC_FILE.bak"
    fi

    # Append configuration with delimiters
    cat >> "$RC_FILE" << EOF

# dotfiles-start
$(cat "$source_file")
# dotfiles-end
EOF

    echo "✓ Configured .zshrc"
}

# Helper: Create .bak backup of a file (only if backup doesn't already exist)
backup_file() {
    local file="$1"
    if [[ -f "$file" ]] && [[ ! -f "$file.bak" ]]; then
        cp "$file" "$file.bak"
    fi
    return 0
}

# Change default shell to zsh
configure_zsh() {
    brew install -q zsh

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi

    install_zsh_config
    
    local current_shell=$(basename "$SHELL")

    if [[ "$current_shell" != "zsh" ]]; then
        echo "→ Changing default shell to zsh..."

        local zsh_path=$(command -v zsh)

        # Add zsh to /etc/shells if not present
        if ! grep -qF "$zsh_path" /etc/shells 2>/dev/null; then
            echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
        fi

        # Change shell (may require password or sudo)
        # Try sudo first (works in Docker/containers), fall back to regular chsh
        if sudo chsh -s "$zsh_path" "$USER" 2>/dev/null || chsh -s "$zsh_path" 2>/dev/null; then
            echo "✓ Changed default shell to zsh"
            echo "  Note: Will take effect on next login or run 'exec zsh' to switch now"
        else
            echo "⊘ Could not change default shell"
            echo "  You can still use zsh by running 'exec zsh'"
        fi
    fi
}

# ============================================================================
# Package Management Strategy
# ============================================================================
# We use both mise AND Homebrew for different purposes:
#
# mise:
#   - Development tools with per-project version support (go, rust, node, etc.)
#   - CLI tools with version pinning (bat, ripgrep, fzf, etc.)
#   - Defined in ~/.config/mise/config.toml globally
#   - Projects can override with local .mise.toml
#
# Homebrew:
#   - System tools and dependencies (gnupg)
#   - Tools not available in mise (language servers, btop)
#   - Tools with GitHub rate limit issues via mise (dust, grex)
#   - Always uses latest versions
# ============================================================================

# Install Homebrew if not present
install_homebrew() {
    # Less verbose, we don't need all the hints
    export HOMEBREW_NO_ENV_HINTS=1

    if command -v brew >/dev/null 2>&1; then
        echo "✓ Homebrew (already installed)"
        return 0
    fi

    echo "→ Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to PATH for this session
    if [[ -f /opt/homebrew/bin/brew ]]; then
        # macOS Apple Silicon
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        # macOS Intel
        eval "$(/usr/local/bin/brew shellenv)"
    elif [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        # Linux/WSL
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi

    echo "✓ Installed Homebrew"
}

# Install mise and configure it
install_and_configure_mise() {
    echo "→ Installing mise..."
    brew install -q mise
    echo "✓ Installed mise"

    # Copy global mise configuration
    local mise_source="$SCRIPT_DIR/.config/mise/config.toml"
    local mise_dest="$HOME/.config/mise/config.toml"

    mkdir -p "$(dirname "$mise_dest")"
    backup_file "$mise_dest"
    cp "$mise_source" "$mise_dest"
    echo "✓ Installed mise configuration"

    # Install core languages first (warnings about go: packages are expected)
    echo "→ Installing core languages (go, rust, bun, zig)..."
    mise install go rust bun zig
    echo "✓ Installed core languages"

    # Activate mise now that core languages are installed
    export PATH="$HOME/.local/bin:$PATH"
    eval "$(mise activate bash)"

    # Install all remaining mise tools
    echo "→ Installing remaining mise tools..."
    mise install
    echo "✓ Installed all mise tools"
}

# Install Homebrew packages that aren't in mise
install_homebrew_packages() {
    echo "→ Installing additional Homebrew packages..."

    local deps=(
        gum
        gnupg
        btop      # Not available via mise on some platforms
        grex      # Avoid GitHub rate limits
        tokei     # Platform asset issues
        tealdeer  # tlrc not in mise registry
    )

    brew install -q "${deps[@]}"
    echo "✓ Installed Homebrew packages"
}

# Uninstall Homebrew tools that have been migrated to mise
cleanup_homebrew_tools() {
    if ! command -v brew >/dev/null 2>&1; then
        return 0
    fi

    # Only proceed if mise is working
    if ! command -v mise >/dev/null 2>&1; then
        return 0
    fi

    echo "→ Cleaning up Homebrew packages migrated to mise..."

    # List of packages to uninstall (migrated to mise)
    # Keep in Homebrew: btop, dust, grex, tokei, tealdeer/tldr, gum
    local migrated=(yq helix go rust fzf zoxide ripgrep bat eza ast-grep fd direnv git-delta jq sd glow gh golangci-lint zig zls taplo goenv starship marksman zellij go-task procs)

    # Uninstall all packages at once (brew will skip packages that aren't installed)
    brew uninstall -q "${migrated[@]}" 2>/dev/null || true

    echo "✓ Cleaned up Homebrew packages"
}

# Install language servers
install_language_servers() {
    echo "→ Installing language servers..."

    local lsp_servers=(
        typescript-language-server
        bash-language-server
        yaml-language-server
        vscode-langservers-extracted
    )

    brew install -q "${lsp_servers[@]}"
    echo "✓ Installed language servers"
}

# Interactive component selection
select_components() {
    # Skip if gum not available or non-interactive
    if ! command -v gum >/dev/null 2>&1 || [[ ! -t 0 ]]; then
        # Default: install everything
        INSTALL_FONTS=true
        INSTALL_TERMINAL_SETTINGS=true
        INSTALL_EDITOR_CONFIGS=true
        INSTALL_GIT_CONFIG=true
        INSTALL_SECRETS=true
        INSTALL_SHELL_CONFIG=true
        INSTALL_DATABASE_TOOLS=true
        INSTALL_CLAUDE=true
        INSTALL_LANGUAGE_SERVERS=true
        return 0
    fi

    gum style --border rounded --padding "1 1" --margin "1 1" \
        "Dotfiles Setup" \
        "" \
        "Select components to install:"

    local selected=$(gum choose --no-limit \
        "Shell configuration (.zshrc)" \
        "Editor configs (Helix, Zellij)" \
        "Language servers (TypeScript, Bash, YAML, etc.)" \
        "Fonts" \
        "Git configuration (GPG signing)" \
        "Secrets management (Cloudflare Worker)" \
        "Terminal settings (iTerm2, Windows Terminal)" \
        "Database tools (usql)" \
        "Claude CLI")

    # Parse selections
    INSTALL_DATABASE_TOOLS=false
    INSTALL_CLAUDE=false
    INSTALL_EDITOR_CONFIGS=false
    INSTALL_FONTS=false
    INSTALL_GIT_CONFIG=false
    INSTALL_SECRETS=false
    INSTALL_SHELL_CONFIG=false
    INSTALL_TERMINAL_SETTINGS=false
    INSTALL_LANGUAGE_SERVERS=false

    while IFS= read -r item; do
        case "$item" in
            "Editor configs"*) INSTALL_EDITOR_CONFIGS=true ;;
            "Language servers"*) INSTALL_LANGUAGE_SERVERS=true ;;
            "Fonts") INSTALL_FONTS=true ;;
            "Git configuration"*) INSTALL_GIT_CONFIG=true ;;
            "Secrets management"*) INSTALL_SECRETS=true ;;
            "Shell configuration"*) INSTALL_SHELL_CONFIG=true ;;
            "Terminal settings"*) INSTALL_TERMINAL_SETTINGS=true ;;
            "Database tools"*) INSTALL_DATABASE_TOOLS=true ;;
            "Claude CLI"*) INSTALL_CLAUDE=true ;;
        esac
    done <<< "$selected"
}

# Check if running on macOS
is_macos() {
    [[ "$(uname)" == "Darwin" ]]
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
try_install_fonts() {
    local fonts_dir="$SCRIPT_DIR/fonts"

    # Skip if fonts directory doesn't exist or is empty
    if [[ ! -d "$fonts_dir" ]] || [[ -z "$(ls -A "$fonts_dir" 2>/dev/null)" ]]; then
        return 0
    fi

    if is_wsl; then
        # WSL: Use PowerShell script to install fonts in Windows
        powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/scripts/install_fonts.ps1")" 2>/dev/null
        echo "✓ Installed fonts (WSL)"
    elif is_macos; then
        # macOS: Copy fonts to user fonts directory
        local user_fonts="$HOME/Library/Fonts"
        mkdir -p "$user_fonts"

        local font_count=0
        shopt -s nullglob
        for font in "$fonts_dir"/*.{ttf,otf,TTF,OTF}; do
            [[ -f "$font" ]] || continue
            cp "$font" "$user_fonts/"
            ((font_count++))
        done
        shopt -u nullglob

        if [[ $font_count -gt 0 ]]; then
            echo "✓ Installed $font_count fonts (macOS)"
        fi
    fi
}

# Apply Windows Terminal settings
try_restore_winterm() {
    if ! is_wsl; then
        return 0
    fi

    local localappdata=$(get_localappdata)
    local local_patch="$SCRIPT_DIR/configs/windows-terminal.json"

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

# Restore iTerm2 settings
try_restore_iterm() {
    if ! is_macos; then
        echo "⊘ Skipping iTerm2 (not macOS)"
        return 0
    fi

    local iterm_plist="$SCRIPT_DIR/Library/Preferences/com.googlecode.iterm2.plist"

    if [[ ! -f "$iterm_plist" ]]; then
        echo "⊘ Skipping iTerm2 (settings file not found)"
        return 0
    fi

    local iterm_prefs="$HOME/Library/Preferences/com.googlecode.iterm2.plist"

    backup_file "$iterm_prefs"
    cp "$iterm_plist" "$iterm_prefs"

    # Reload iTerm2 preferences (kill cfprefsd to force reload)
    killall cfprefsd 2>/dev/null || true

    echo "✓ Restored iTerm2 settings"
    echo "  Note: Restart iTerm2 for changes to take effect"
}

# Helper: Install Go tool via go install
go_install() {
    local package="$1"
    local name="$2"
    local tags="${3:-}"

    if [[ -n "$tags" ]]; then
        go install -tags "$tags" "$package@latest"
    else
        go install "$package@latest"
    fi
}

# Install database tools with special requirements
install_database_tools() {
    if ! command -v go >/dev/null 2>&1; then
        echo "⊘ Skipping database tools (Go not installed)"
        return 0
    fi

    echo "→ Installing database tools..."

    # usql requires build tags (not supported by mise go: backend)
    go_install "github.com/xo/usql" "usql" "postgres sqlite3"

    echo "✓ Installed database tools"
}

# Install Claude CLI
install_claude_cli() {
    if command -v claude >/dev/null 2>&1; then
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
    local source_file="$SCRIPT_DIR/.claude/CLAUDE.md"

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
}

# Configure secrets (prompt for URL and passphrase)
configure_secrets() {
    # Skip if already configured via environment
    if [[ -n "${SECRETS_URL:-}" ]] && [[ -n "${SECRETS_PASSPHRASE:-}" ]]; then
        return 0
    fi

    echo "→ Configuring secrets storage..."
    echo ""
    echo "Secrets are stored in Cloudflare Workers. You'll need:"
    echo "  1. Your worker URL (e.g., https://secrets.your-subdomain.workers.dev)"
    echo "  2. Your passphrase for authentication"
    echo ""
    read -p "Enter your secrets worker URL (or press Enter to skip): " url
    
    if [[ -z "$url" ]]; then
        echo "⊘ Skipping secrets configuration"
        return 0
    fi

    read -p "Enter your secrets passphrase: " passphrase

    if [[ -z "$passphrase" ]]; then
        echo "⊘ Skipping secrets configuration (no passphrase provided)"
        return 0
    fi

    # Ensure .zshrc exists
    touch "$RC_FILE"

    # Remove old secrets section if exists
    if grep -qF "# dotfiles-secrets-start" "$RC_FILE"; then
        sed -i.bak '/# dotfiles-secrets-start/,/# dotfiles-secrets-end/d' "$RC_FILE"
        rm -f "$RC_FILE.bak"
    fi

    # Append secrets with delimiters
    cat >> "$RC_FILE" << EOF

# dotfiles-secrets-start
export SECRETS_URL="$url"
export SECRETS_PASSPHRASE="$passphrase"
# dotfiles-secrets-end
EOF

    # Export for current session so setup_gpg_key can use them
    export SECRETS_URL="$url"
    export SECRETS_PASSPHRASE="$passphrase"

    echo "✓ Configured secrets"
}

# Setup GPG key for commit signing
setup_gpg_key() {
    # Check if GPG key is already imported
    if gpg --list-keys 7B5FC82E53B5ABE6 >/dev/null 2>&1; then
        return 0
    fi

    if ! command -v secrets >/dev/null 2>&1; then
        echo "⊘ Skipping GPG key setup (secrets CLI not available)"
        return 0
    fi

    # Check if worker is configured
    if [[ -z "${SECRETS_URL:-}" ]] || [[ -z "${SECRETS_PASSPHRASE:-}" ]]; then
        echo "⊘ Skipping GPG key setup (SECRETS_URL or SECRETS_PASSPHRASE not set)"
        return 0
    fi

    if secrets pull 2>/dev/null; then
        if [[ -f "$HOME/.ssh/gpg" ]]; then
            if gpg --import "$HOME/.ssh/gpg" 2>/dev/null; then
                # Set ultimate trust for the imported key
                echo -e "5\ny\n" | gpg --command-fd 0 --expert --edit-key 7B5FC82E53B5ABE6 trust quit 2>/dev/null && \
                    echo "✓ Key trusted for signing" || \
                    echo "⊘ Key trust may already be set"
            else
                echo "⊘ GPG key may already be imported"
            fi
        else
            echo "⊘ GPG key file not found at ~/.ssh/gpg"
        fi
    else
        echo "⊘ No secrets in worker yet (use: secrets push)"
    fi
}

# Configure git
configure_git() {
    echo "→ Configuring git..."

    # Install gitconfig
    local gitconfig_source="$SCRIPT_DIR/.gitconfig"
    if [[ -f "$gitconfig_source" ]]; then
        backup_file "$HOME/.gitconfig"
        cp "$gitconfig_source" "$HOME/.gitconfig"
        echo "✓ Installed .gitconfig"
    fi

    # Install global gitignore
    local gitignore_source="$SCRIPT_DIR/.gitignore_global"
    if [[ -f "$gitignore_source" ]]; then
        backup_file "$HOME/.gitignore_global"
        cp "$gitignore_source" "$HOME/.gitignore_global"
        echo "✓ Installed .gitignore_global"
    fi

    echo "✓ Configured git"
}

# Main execution
main() {
    # Install core dependencies in correct order
    install_homebrew
    install_and_configure_mise
    install_homebrew_packages
    cleanup_homebrew_tools

    configure_zsh

    select_components

    # Install tealdeer config
    local tealdeer_source="$SCRIPT_DIR/.config/tealdeer/config.toml"
    local tealdeer_dest="$HOME/.config/tealdeer/config.toml"
    if [[ -f "$tealdeer_source" ]]; then
        mkdir -p "$(dirname "$tealdeer_dest")"
        backup_file "$tealdeer_dest"
        cp "$tealdeer_source" "$tealdeer_dest"
        echo "✓ Installed tealdeer config"
    fi

    [[ "$INSTALL_FONTS" == true ]] && try_install_fonts

    if [[ "$INSTALL_TERMINAL_SETTINGS" == true ]]; then
        try_restore_winterm
        try_restore_iterm
    fi

    if [[ "$INSTALL_EDITOR_CONFIGS" == true ]]; then
        # Helix config
        local helix_source="$SCRIPT_DIR/.config/helix/config.toml"
        local helix_dest="$HOME/.config/helix/config.toml"
        if [[ -f "$helix_source" ]]; then
            mkdir -p "$(dirname "$helix_dest")"
            backup_file "$helix_dest"
            cp "$helix_source" "$helix_dest"
            echo "✓ Installed Helix config"
        fi

        # Zellij config
        local zellij_source="$SCRIPT_DIR/.config/zellij/config.kdl"
        local zellij_dest="$HOME/.config/zellij/config.kdl"
        if [[ -f "$zellij_source" ]]; then
            mkdir -p "$(dirname "$zellij_dest")"
            backup_file "$zellij_dest"
            cp "$zellij_source" "$zellij_dest"
            echo "✓ Installed Zellij config"
        fi
    fi

    [[ "$INSTALL_GIT_CONFIG" == true ]] && configure_git

    if [[ "$INSTALL_SECRETS" == true ]]; then
        configure_secrets
        install_secrets_cli
        setup_gpg_key
    fi

    if [[ "$INSTALL_DATABASE_TOOLS" == true ]]; then
        install_database_tools
    fi

    if [[ "$INSTALL_CLAUDE" == true ]]; then
        install_claude_cli
        configure_claude_instructions
    fi

    # Language servers installation
    if [[ "$INSTALL_LANGUAGE_SERVERS" == true ]]; then
        install_language_servers
    fi

    gum style --border rounded --padding "1 1" --margin "1 1" --foreground 2 "✓ Setup complete!"

    if [[ "$INSTALL_SHELL_CONFIG" == true ]]; then
        echo "Run: exec zsh   # Or log out and back in"
    fi
}

main
