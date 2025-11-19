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
    local deps=(yq helix go fzf go-task zoxide)
    local cmds=(yq hx go fzf task zoxide)

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

# Configure GOPATH in bashrc
configure_gopath() {
    add_to_bashrc 'go env GOPATH' '# Add Go binaries to PATH\nexport PATH="$PATH:$(go env GOPATH)/bin"' 'GOPATH'
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

# Configure ~/.local/bin in PATH
configure_local_bin_path() {
    add_to_bashrc '.local/bin' '# Add ~/.local/bin to PATH\nexport PATH="$HOME/.local/bin:$PATH"' '~/.local/bin in PATH'
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
        go)
            configure_gopath
            ;;
        task)
            configure_task
            ;;
        claude)
            install_claude_cli
            ;;
        all)
            install_fonts
            apply_settings
            install_helix_config
            configure_fzf
            configure_zoxide
            configure_gopath
            configure_task
            install_claude_cli
            ;;
        *)
            echo "Usage: $0 [fonts|settings|helix|fzf|zoxide|go|task|claude|all]"
            echo "  fonts    - Install fonts only"
            echo "  settings - Apply Windows Terminal settings only"
            echo "  helix    - Install Helix config only"
            echo "  fzf      - Configure fzf in .bashrc only"
            echo "  zoxide   - Configure zoxide in .bashrc only"
            echo "  go       - Configure GOPATH in .bashrc only"
            echo "  task     - Configure task completion in .bashrc only"
            echo "  claude   - Install Claude CLI and configure PATH only"
            echo "  all      - Do everything (default)"
            exit 1
            ;;
    esac

    echo ""
    echo "✓ Setup complete. Run 'source ~/.bashrc' to apply changes."
}

main "$@"
