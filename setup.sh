#!/usr/bin/env bash
set -euo pipefail

# Hard-code to zsh (installed by setup if not present)
RC_FILE="$HOME/.zshrc"
ZSH_CONFIG_DIR="$HOME/.config/zsh.d"

# Get script directory (works in both bash and zsh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")" && pwd)"

# Install zsh configuration files
install_zsh_config() {
    # Ensure .zshrc exists
    touch "$RC_FILE"

    # Remove old marker-based snippets if they exist
    if grep -qF "# dotfiles-snippets-start" "$RC_FILE"; then
        sed -i.bak "/# dotfiles-snippets-start/,/# dotfiles-snippets-end/d" "$RC_FILE"
        rm -f "$RC_FILE.bak"
        echo "✓ Removed old marker-based snippets"
    fi

    # Check if .zshrc already sources the config directory
    if ! grep -qF "# Source all config files from ~/.config/zsh.d/" "$RC_FILE"; then
        cat >> "$RC_FILE" << 'EOF'

# Source all config files from ~/.config/zsh.d/
if [[ -d "$HOME/.config/zsh.d" ]]; then
    for config in "$HOME/.config/zsh.d"/*.zsh(N); do
        source "$config"
    done
fi
EOF
        echo "✓ Configured .zshrc to source ~/.config/zsh.d/"
    fi

    local zshd="$HOME/.config/zsh.d"

    # Copy entire zsh.d directory to ~/.config/
    if [[ -d "$SCRIPT_DIR/zsh.d" ]]; then
        mkdir -p "$HOME/.config"
        if gum confirm "rm -fr $zshd"; then
            echo "rm -fr $zshd"
            rm -fr "$zshd"
        fi
        cp -r "$SCRIPT_DIR/zsh.d" "$HOME/.config/"
        echo "✓ Copied zsh configuration files to ~/.config/zsh.d/"
    else
        echo "✗ Error: $SCRIPT_DIR/zsh.d not found"
        return 1
    fi
}

# Helper: Create .bak backup of a file (only if backup doesn't already exist)
backup_file() {
    local file="$1"
    if [[ -f "$file" ]] && [[ ! -f "$file.bak" ]]; then
        cp "$file" "$file.bak"
    fi
    return 0
}

# Install zsh and oh-my-zsh
install_zsh_and_omz() {
    # Install zsh if not present
    if ! command -v zsh >/dev/null 2>&1; then
        echo "→ Installing zsh..."
        if command -v brew >/dev/null 2>&1; then
            brew install -q zsh
        elif command -v apt-get >/dev/null 2>&1; then
            sudo apt-get install -y zsh
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y zsh
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm zsh
        else
            echo "✗ Error: Cannot install zsh (unsupported package manager)"
            exit 1
        fi
        echo "✓ Installed zsh"
    fi

    # Install oh-my-zsh (handles zsh configuration)
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        echo "→ Installing oh-my-zsh..."
        # Use unattended installation
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        echo "✓ Installed oh-my-zsh"
    fi
}

# Change default shell to zsh
change_shell_to_zsh() {
    local current_shell=$(basename "$SHELL")

    if [[ "$current_shell" != "zsh" ]]; then
        echo "→ Changing default shell to zsh..."

        local zsh_path=$(command -v zsh)

        # Add zsh to /etc/shells if not present
        if ! grep -qF "$zsh_path" /etc/shells 2>/dev/null; then
            echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
        fi

        # Change shell (requires password)
        chsh -s "$zsh_path"
        echo "✓ Changed default shell to zsh"
        echo "  Note: Log out and back in (or run 'exec zsh') for change to take effect"
    fi
}

# Install mise
install_mise() {
    if command -v mise >/dev/null 2>&1; then
        return 0
    fi

    curl https://mise.jdx.dev/install.sh | sh

    # Add to PATH for current session
    export PATH="$HOME/.local/bin:$PATH"

    # Activate mise for current session
    eval "$(mise activate bash)"
}

# Install global mise configuration
install_mise_config() {
    local mise_config_dir="$HOME/.config/mise"
    local mise_config="$mise_config_dir/config.toml"
    local source_config="$SCRIPT_DIR/configs/mise.toml"

    [[ -f "$source_config" ]] || { echo "✗ Error: $source_config not found"; return 1; }

    if ! mkdir -p "$mise_config_dir"; then
        echo "Error: failed to create directory $mise_config_dir"
        return 1
    fi

    # Backup existing config (handle both files and symlinks)
    if [[ -f "$mise_config" ]] || [[ -L "$mise_config" ]]; then
        backup_file "$mise_config"
        rm -f "$mise_config"
    fi

    # Copy config file
    cp "$source_config" "$mise_config"
}

# Uninstall tools migrated to mise
cleanup_homebrew_tools() {
    if ! command -v brew >/dev/null 2>&1; then
        return 0
    fi

    # Only proceed if mise is working
    if ! command -v mise >/dev/null 2>&1; then
        return 0
    fi

    # List of packages to uninstall (migrated to mise)
    local migrated=(yq helix go fzf zoxide ripgrep bat eza ast-grep fd direnv git-delta jq btop tldr sd glow tokei gh dust golangci-lint zig zls taplo goenv starship marksman grex zellij go-task procs)

    # Uninstall all packages at once (brew will skip packages that aren't installed)
    brew uninstall -q "${migrated[@]}" 2>/dev/null || true
}

# Ensure dependencies are installed
ensure_dependencies() {
    # Check for Homebrew first
    if ! command -v brew >/dev/null 2>&1; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add brew to PATH for this session
        if [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
    fi

    # Install gum early for interactive setup
    if ! command -v gum >/dev/null 2>&1; then
        brew install -q gum
    fi

    # Install zsh and oh-my-zsh
    install_zsh_and_omz

    # Change default shell to zsh
    change_shell_to_zsh

    # Install mise
    install_mise
    # mise handles all other tools
    mise install

    # Install remaining Homebrew dependencies (system tools only)
    local deps=(gnupg typescript-language-server bash-language-server yaml-language-server vscode-langservers-extracted)
    brew install -q "${deps[@]}"

}

# Interactive component selection
select_components() {
    # Skip if gum not available or non-interactive
    if ! command -v gum >/dev/null 2>&1 || [[ ! -t 0 ]]; then
        # Default: install everything
        INSTALL_TERMINAL_SETTINGS=true
        INSTALL_EDITOR_CONFIGS=true
        INSTALL_GIT_CONFIG=true
        INSTALL_SECRETS=true
        INSTALL_SHELL_CONFIG=true
        INSTALL_TOOLS=true
        return 0
    fi

    gum style --border rounded --padding "1 1" --margin "1 1" \
        "Dotfiles Setup" \
        "" \
        "Select components to install:"

    local selected=$(gum choose --no-limit \
        "Editor configs (Helix, Zellij)" \
        "Fonts" \
        "Git configuration (GPG signing)" \
        "Secrets management (Cloudflare Worker)" \
        "Terminal settings (iTerm2, Windows Terminal)" \
        "Tools")

    # Parse selections
    INSTALL_TOOLS=false
    INSTALL_EDITOR_CONFIGS=false
    INSTALL_FONTS=false
    INSTALL_GIT_CONFIG=false
    INSTALL_SECRETS=false
    INSTALL_SHELL_CONFIG=false
    INSTALL_TERMINAL_SETTINGS=false

    while IFS= read -r item; do
        case "$item" in
            "Editor configs"*) INSTALL_EDITOR_CONFIGS=true ;;
            "Fonts") INSTALL_FONTS=true ;;
            "Git configuration"*) INSTALL_GIT_CONFIG=true ;;
            "Secrets management"*) INSTALL_SECRETS=true ;;
            "Shell configuration"*) INSTALL_SHELL_CONFIG=true ;;
            "Terminal settings"*) INSTALL_TERMINAL_SETTINGS=true ;;
            "Tools"*) INSTALL_TOOLS=true ;;
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

    local iterm_plist="$SCRIPT_DIR/configs/com.googlecode.iterm2.plist"

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

# Install Helix config
install_helix_config() {
    local config_source="$SCRIPT_DIR/configs/helix.toml"
    local config_dest="$HOME/.config/helix/config.toml"

    [[ -f "$config_source" ]] || { echo "✗ Error: $config_source not found"; return 1; }

    mkdir -p "$(dirname "$config_dest")"
    backup_file "$config_dest"
    cp "$config_source" "$config_dest"
}

# Install Zellij config
install_zellij_config() {
    local config_source="$SCRIPT_DIR/configs/zellij.kdl"
    local config_dest="$HOME/.config/zellij/config.kdl"

    [[ -f "$config_source" ]] || { echo "✗ Error: $config_source not found"; return 1; }

    mkdir -p "$(dirname "$config_dest")"
    backup_file "$config_dest"
    cp "$config_source" "$config_dest"
    echo "✓ Installed Zellij config"
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

# Install Go tools with special requirements
install_go_tools() {
    if ! command -v go >/dev/null 2>&1; then
        echo "⊘ Skipping Go tools (Go not installed)"
        return 0
    fi

    echo "→ Installing Go tools with special requirements..."

    # usql requires build tags (not supported by mise go: backend yet)
    go_install "github.com/xo/usql" "usql" "postgres sqlite3"

    echo "✓ Installed Go tools"
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
    local source_file="$SCRIPT_DIR/configs/CLAUDE.md"

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

    # Create secrets config file directly in ~/.config/zsh.d/
    mkdir -p "$ZSH_CONFIG_DIR"
    local secrets_file="$ZSH_CONFIG_DIR/secrets.zsh"
    cat > "$secrets_file" << EOF
export SECRETS_URL="$url"
export SECRETS_PASSPHRASE="$passphrase"
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
    git config --global user.name "dane"
    git config --global user.email "dane@medieval.software"
    git config --global user.signingkey 7B5FC82E53B5ABE6
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global commit.gpgsign true

    if command -v hx >/dev/null 2>&1; then
        git config --global core.editor "hx"
        git config --global sequence.editor "hx"
    fi

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
    local gitignore_source="$SCRIPT_DIR/configs/gitignore_global"
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
    set -x

    ensure_dependencies
    cleanup_homebrew_tools
    install_mise_config
    select_components

    [[ "$INSTALL_FONTS" == true ]] && try_install_fonts

    if [[ "$INSTALL_TERMINAL_SETTINGS" == true ]]; then
        try_restore_winterm
        try_restore_iterm
    fi

    if [[ "$INSTALL_EDITOR_CONFIGS" == true ]]; then
        install_helix_config
        install_zellij_config
    fi

    [[ "$INSTALL_GIT_CONFIG" == true ]] && configure_git

    if [[ "$INSTALL_SECRETS" == true ]]; then
        configure_secrets
        install_secrets_cli
        setup_gpg_key
    fi

    # Shell configuration
    if [[ "$INSTALL_SHELL_CONFIG" == true ]]; then
        install_zsh_config
    fi

    # CLI tools installation
    if [[ "$INSTALL_TOOLS" == true ]]; then
        install_go_tools
        install_claude_cli
        configure_claude_instructions
    fi

    gum style --border rounded --padding "1 1" --margin "1 1" --foreground 2 "✓ Setup complete!"

    if [[ "$INSTALL_SHELL_CONFIG" == true ]]; then
        echo "Run: exec zsh   # Or log out and back in"
    fi
}

main
