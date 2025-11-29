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

# Helper: Create .bak backup of a file (only if backup doesn't already exist)
backup_file() {
    local file="$1"
    if [[ -f "$file" ]] && [[ ! -f "$file.bak" ]]; then
        cp "$file" "$file.bak"
    fi
    return 0
}

# Helper: Symlink config file from repo to target location
# Re-runnable: skips if symlink already points to source
symlink_config() {
    local source="$1"
    local target="$2"

    # Expand tilde in paths
    target="${target/#\~/$HOME}"

    # Check source exists
    if [[ ! -e "$source" ]]; then
        echo "✗ Error: $source not found"
        return 1
    fi

    # Create parent directory
    mkdir -p "$(dirname "$target")"

    # If target is already a symlink to our source, we're done
    if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
        return 0
    fi

    # If something exists at target (file or different symlink), back it up and remove
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        backup_file "$target"
        rm -f "$target"
    fi

    # Create symlink
    ln -s "$source" "$target"

    return 0
}

# Change default shell to zsh
configure_zsh() {
    brew install -q zsh

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi

    # Symlink .zshrc
    if symlink_config "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"; then
        echo "✓ Symlinked .zshrc"
    fi
    
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

    # Symlink global mise configuration
    if symlink_config "$SCRIPT_DIR/.config/mise/config.toml" "$HOME/.config/mise/config.toml"; then
        echo "✓ Symlinked mise configuration"
    fi

    # Install core languages first (warnings about go: packages are expected)
    echo "→ Installing core languages (go, rust, bun, zig)..."
    mise use -g go rust bun zig
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
        tokei     # Platform asset issues
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

# Interactive component selection
select_components() {
    # Skip if gum not available or non-interactive
    if ! command -v gum >/dev/null 2>&1 || [[ ! -t 0 ]]; then
        # Default: install everything
        INSTALL_SHELL_CONFIG=true
        INSTALL_EDITOR_CONFIGS=true
        INSTALL_FONTS=true
        INSTALL_GIT_CONFIG=true
        INSTALL_SECRETS=true
        INSTALL_TERMINAL_SETTINGS=true
        INSTALL_CLAUDE=true
        return 0
    fi

    gum style --border rounded --padding "1 1" --margin "1 1" \
        "Dotfiles Setup" \
        "" \
        "Select components to install:"

    # Component mapping: parallel arrays for display prefixes and variable names
    local component_prefixes=("Shell configuration" "Editor configs" "Fonts" "Git configuration" "Secrets management" "Terminal settings" "Claude CLI")
    local component_vars=(INSTALL_SHELL_CONFIG INSTALL_EDITOR_CONFIGS INSTALL_FONTS INSTALL_GIT_CONFIG INSTALL_SECRETS INSTALL_TERMINAL_SETTINGS INSTALL_CLAUDE)

    # Initialize all to false
    for var in "${component_vars[@]}"; do
        eval "$var=false"
    done

    # Get user selections
    local selected=$(gum choose --no-limit \
        "Shell configuration (.zshrc)" \
        "Editor configs (Helix, Zellij)" \
        "Fonts" \
        "Git configuration (GPG signing)" \
        "Secrets management (Cloudflare Worker)" \
        "Terminal settings (iTerm2, Windows Terminal)" \
        "Claude CLI")

    # Parse selections
    while IFS= read -r item; do
        for i in "${!component_prefixes[@]}"; do
            if [[ "$item" == "${component_prefixes[$i]}"* ]]; then
                eval "${component_vars[$i]}=true"
                break
            fi
        done
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

    # Symlink CLAUDE.md
    if symlink_config "$SCRIPT_DIR/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"; then
        echo "✓ Symlinked Claude custom instructions"
    fi

    # Symlink settings.json
    if symlink_config "$SCRIPT_DIR/.claude/settings.json" "$HOME/.claude/settings.json"; then
        echo "✓ Symlinked Claude settings"
    fi
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

    # Symlink gitconfig
    if symlink_config "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig"; then
        echo "✓ Symlinked .gitconfig"
    fi

    # Symlink global gitignore
    if symlink_config "$SCRIPT_DIR/.gitignore_global" "$HOME/.gitignore_global"; then
        echo "✓ Symlinked .gitignore_global"
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

    # Symlink tealdeer config
    if symlink_config "$SCRIPT_DIR/.config/tealdeer/config.toml" "$HOME/.config/tealdeer/config.toml"; then
        echo "✓ Symlinked tealdeer config"
    fi

    [[ "$INSTALL_FONTS" == true ]] && try_install_fonts

    if [[ "$INSTALL_TERMINAL_SETTINGS" == true ]]; then
        try_restore_winterm
        try_restore_iterm
    fi

    if [[ "$INSTALL_EDITOR_CONFIGS" == true ]]; then
        # Symlink Helix config
        if symlink_config "$SCRIPT_DIR/.config/helix/config.toml" "$HOME/.config/helix/config.toml"; then
            echo "✓ Symlinked Helix config"
        fi

        # Symlink Zellij config
        if symlink_config "$SCRIPT_DIR/.config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"; then
            echo "✓ Symlinked Zellij config"
        fi
    fi

    [[ "$INSTALL_GIT_CONFIG" == true ]] && configure_git

    if [[ "$INSTALL_SECRETS" == true ]]; then
        configure_secrets
        install_secrets_cli
        setup_gpg_key
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
