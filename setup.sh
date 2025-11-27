#!/usr/bin/env bash
set -euo pipefail

# Detect user's login shell
detect_shell() {
    local shell_path=""

    # Try to get login shell from system passwd database
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS: use dscl
        shell_path=$(dscl . -read ~/ UserShell 2>/dev/null | awk '{print $2}')
    else
        # Linux/WSL: use getent
        shell_path=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)
    fi

    # Fallback to $SHELL environment variable
    if [[ -z "$shell_path" ]]; then
        shell_path="$SHELL"
    fi

    # Extract shell name and normalize
    case "$(basename "$shell_path")" in
        zsh)
            echo "zsh"
            ;;
        bash)
            echo "bash"
            ;;
        *)
            # Check which rc file exists as final fallback
            if [[ -f "$HOME/.zshrc" ]]; then
                echo "zsh"
            elif [[ -f "$HOME/.bashrc" ]]; then
                echo "bash"
            else
                # Ultimate fallback to bash
                echo "bash"
            fi
            ;;
    esac
}

SHELL_TYPE=$(detect_shell)
RC_FILE="$HOME/.${SHELL_TYPE}rc"

# Get script directory (works in both bash and zsh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")" && pwd)"

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

# Install mise
install_mise() {
    if command -v mise >/dev/null 2>&1; then
        echo "✓ mise (already installed)"
        return 0
    fi

    echo "→ Installing mise..."
    curl https://mise.jdx.dev/install.sh | sh

    # Add to PATH for current session
    export PATH="$HOME/.local/bin:$PATH"

    # Activate mise for current session
    eval "$(mise activate bash)"

    echo "✓ Installed mise"
}

# Install global mise configuration
install_mise_config() {
    local mise_config_dir="$HOME/.config/mise"
    local mise_config="$mise_config_dir/config.toml"
    local source_config="$SCRIPT_DIR/.mise.toml"

    [[ -f "$source_config" ]] || { echo "✗ Error: $source_config not found"; return 1; }

    mkdir -p "$mise_config_dir"

    # Backup existing config if not a symlink
    if [[ -f "$mise_config" ]] && [[ ! -L "$mise_config" ]]; then
        backup_file "$mise_config"
    fi

    # Remove existing symlink or file
    rm -f "$mise_config"

    # Create symlink
    ln -s "$source_config" "$mise_config"
    echo "✓ Installed global mise configuration"
}

# Uninstall tools migrated to mise
cleanup_homebrew_tools() {
    if ! command -v brew >/dev/null 2>&1; then
        echo "⊘ Skipping Homebrew cleanup (brew not installed)"
        return 0
    fi

    # Only proceed if mise is working
    if ! command -v mise >/dev/null 2>&1; then
        echo "⊘ Skipping Homebrew cleanup (mise not installed)"
        return 0
    fi

    echo "→ Cleaning up Homebrew packages (migrated to mise)..."

    # List of packages to uninstall (migrated to mise)
    local migrated=(yq helix go fzf zoxide ripgrep bat eza ast-grep fd direnv git-delta jq btop tldr sd glow tokei gh dust golangci-lint zig zls taplo goenv starship marksman grex zellij go-task procs)

    # Uninstall all packages at once (brew will skip packages that aren't installed)
    brew uninstall -q "${migrated[@]}" 2>/dev/null || true

    echo "✓ Cleaned up Homebrew packages"
    echo "  Note: Some packages may remain if other tools depend on them"
}

# Ensure dependencies are installed
ensure_dependencies() {
    # Check for Homebrew first
    if ! command -v brew >/dev/null 2>&1; then
        echo "→ Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add brew to PATH for this session
        if [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
        echo "✓ Installed Homebrew"
    fi

    # Install gum early for interactive setup
    if ! command -v gum >/dev/null 2>&1; then
        echo "→ Installing gum (for interactive setup)..."
        brew install -q gum
        echo "✓ Installed gum"
    fi

    # Install mise
    install_mise

    # Install remaining Homebrew dependencies (system tools only)
    local deps=(gnupg typescript-language-server bash-language-server yaml-language-server vscode-langservers-extracted)

    brew install -q "${deps[@]}"

    # mise handles all other tools
    echo "→ Installing mise tools..."
    mise install
    echo "✓ Installed mise tools"
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
        INSTALL_CLI_TOOLS=true
        return 0
    fi

    gum style --border double --padding "1 2" --margin "1 0" \
        "Dotfiles Setup" \
        "" \
        "Select components to install:"

    local selected=$(gum choose --no-limit \
        "Fonts" \
        "Terminal settings (iTerm2/Windows Terminal)" \
        "Editor configs (Helix/Zellij)" \
        "Git configuration" \
        "Secrets management" \
        "Shell configuration (.bashrc/.zshrc)" \
        "CLI tools (Go tools, Claude CLI)")

    # Parse selections
    INSTALL_FONTS=false
    INSTALL_TERMINAL_SETTINGS=false
    INSTALL_EDITOR_CONFIGS=false
    INSTALL_GIT_CONFIG=false
    INSTALL_SECRETS=false
    INSTALL_SHELL_CONFIG=false
    INSTALL_CLI_TOOLS=false

    while IFS= read -r item; do
        case "$item" in
            "Fonts") INSTALL_FONTS=true ;;
            "Terminal settings"*) INSTALL_TERMINAL_SETTINGS=true ;;
            "Editor configs"*) INSTALL_EDITOR_CONFIGS=true ;;
            "Git configuration") INSTALL_GIT_CONFIG=true ;;
            "Secrets management") INSTALL_SECRETS=true ;;
            "Shell configuration"*) INSTALL_SHELL_CONFIG=true ;;
            "CLI tools"*) INSTALL_CLI_TOOLS=true ;;
        esac
    done <<< "$selected"
}

# Install bun
install_bun() {
    # mise handles bun installation
    if command -v mise >/dev/null 2>&1; then
        echo "✓ bun (installed via mise)"
        return 0
    fi

    # Fallback: direct installation if mise not available
    command -v bun >/dev/null 2>&1 && return 0
    curl -fsSL https://bun.sh/install | bash
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
        echo "⊘ Skipping fonts (no fonts to install)"
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
        else
            echo "⊘ No fonts found to install"
        fi
    else
        echo "⊘ Skipping fonts (unsupported platform)"
    fi
}

# Apply Windows Terminal settings
try_restore_winterm() {
    if ! is_wsl; then
        echo "⊘ Skipping Windows Terminal (not WSL)"
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
    echo "✓ Installed Helix config"
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
}

# Configure secrets (prompt for URL and passphrase)
configure_secrets() {
    # Skip if already configured via environment
    if [[ -n "${SECRETS_URL:-}" ]] && [[ -n "${SECRETS_PASSPHRASE:-}" ]]; then
        echo "⊘ Secrets already configured via environment"
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

    # Create secrets snippet with actual values
    local secrets_snippet="$SCRIPT_DIR/snippets/secrets.sh"
    cat > "$secrets_snippet" << EOF
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
    if [[ "${SKIP_SECRETS_PULL:-}" == "true" ]]; then
        echo "⊘ Skipping secrets pull (SKIP_SECRETS_PULL=true)"
        return 0
    fi

    # Check if GPG key is already imported
    if gpg --list-keys 7B5FC82E53B5ABE6 >/dev/null 2>&1; then
        echo "✓ GPG key already imported"
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

    echo "→ Pulling secrets from worker..."
    if secrets pull 2>/dev/null; then
        echo "✓ Pulled secrets from worker"

        if [[ -f "$HOME/.ssh/gpg" ]]; then
            echo "→ Importing GPG key..."
            if gpg --import "$HOME/.ssh/gpg" 2>/dev/null; then
                echo "✓ Imported GPG key to keychain"

                # Set ultimate trust for the imported key
                echo "→ Setting key trust level..."
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

    # Install global mise configuration
    install_mise_config

    # Cleanup Homebrew packages migrated to mise
    cleanup_homebrew_tools

    install_bun

    # Interactive component selection
    select_components

    # Run configurations based on selections
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

    [[ "$INSTALL_SECRETS" == true ]] && configure_secrets

    # Shell configuration
    if [[ "$INSTALL_SHELL_CONFIG" == true ]]; then
        # Initialize snippet section
        init_snippets

        # Add mise snippet FIRST (must load before tools)
        add_snippet "mise" "mise (tool version manager)"

        # Add all snippets
        add_snippet "fzf" "fzf"
        add_snippet "zoxide" "zoxide"
        add_snippet "gopath" "GOPATH"
        add_snippet "bun" "bun"
        add_snippet "local_bin" "~/.local/bin in PATH"
        add_snippet "starship" "Starship prompt"
        add_snippet "eza_aliases" "eza aliases"
        add_snippet "git_aliases" "git aliases"
        add_snippet "fzf_git" "fzf + git integration"
        add_snippet "dev" "development utilities"
        add_snippet "xdg" "XDG directories"
        add_snippet "qol" "shell quality of life"

        # Add secrets snippet only if it was created
        local secrets_snippet="$SCRIPT_DIR/snippets/secrets.sh"
        if [[ -f "$secrets_snippet" ]]; then
            add_snippet "secrets" "secrets configuration"
            # Delete secrets snippet file after it's been added (contains sensitive data)
            rm -f "$secrets_snippet"
        fi

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
    fi

    # CLI tools installation
    if [[ "$INSTALL_CLI_TOOLS" == true ]]; then
        install_go_tools
        install_claude_cli
        configure_claude_instructions
        [[ "$INSTALL_SECRETS" == true ]] && install_secrets_cli
        [[ "$INSTALL_SECRETS" == true ]] && setup_gpg_key
    fi

    echo ""
    gum style --border rounded --padding "1 2" --foreground 2 "✓ Setup complete!"
    echo ""
    [[ "$INSTALL_SHELL_CONFIG" == true ]] && echo "Run: source ~/.${SHELL_TYPE}rc"
}

main
