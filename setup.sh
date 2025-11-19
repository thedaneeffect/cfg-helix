#!/usr/bin/env bash
set -euo pipefail

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

    local fonts_dir="./fonts"
    [[ -d "$fonts_dir" ]] || { echo "✗ Error: $fonts_dir not found"; return 1; }

    # Run PowerShell script to copy and register fonts
    powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ./install_fonts.ps1)" 2>/dev/null
    echo "✓ Installed fonts"
}

# Apply Windows Terminal settings
apply_settings() {
    if ! is_wsl; then
        echo "⊘ Skipping Windows Terminal (not WSL)"
        return 0
    fi

    local localappdata=$(get_localappdata)
    local local_patch="./settings.json"

    [[ -f "$local_patch" ]] || { echo "✗ Error: $local_patch not found"; return 1; }

    local wt_package=$(find "$localappdata/Packages" -maxdepth 1 -name "Microsoft.WindowsTerminal_*" -type d 2>/dev/null | head -n 1)
    [[ -n "$wt_package" ]] || { echo "✗ Error: Windows Terminal not found"; return 1; }

    local wt_settings="$wt_package/LocalState/settings.json"
    [[ -f "$wt_settings" ]] || { echo "✗ Error: settings.json not found"; return 1; }

    cp "$wt_settings" "$wt_settings.backup.$(date +%s)"
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
      "$wt_settings" "$local_patch" > /tmp/merged.json
    cat /tmp/merged.json > "$wt_settings"
    rm /tmp/merged.json
    echo "✓ Applied Windows Terminal settings"
}

# Install Helix config
install_helix_config() {
    local config_source="./config.toml"
    local config_dest="$HOME/.config/helix/config.toml"

    [[ -f "$config_source" ]] || { echo "✗ Error: $config_source not found"; return 1; }

    mkdir -p "$(dirname "$config_dest")"
    [[ -f "$config_dest" ]] && cp "$config_dest" "$config_dest.backup.$(date +%s)"
    cp "$config_source" "$config_dest"
    echo "✓ Installed Helix config"
}

# Configure fzf in bashrc
configure_fzf() {
    local bashrc="$HOME/.bashrc"
    touch "$bashrc"

    if ! grep -qF 'fzf --bash' "$bashrc"; then
        echo -e '\neval "$(fzf --bash)"' >> "$bashrc"
        echo "✓ Configured fzf"
    else
        echo "✓ fzf (already configured)"
    fi
}

# Configure zoxide in bashrc
configure_zoxide() {
    local bashrc="$HOME/.bashrc"
    touch "$bashrc"

    if ! grep -qF 'zoxide init bash' "$bashrc"; then
        echo -e '\n# Initialize zoxide (smart cd)\neval "$(zoxide init bash)"' >> "$bashrc"
        echo "✓ Configured zoxide"
    else
        echo "✓ zoxide (already configured)"
    fi
}

# Configure GOPATH in bashrc
configure_gopath() {
    local bashrc="$HOME/.bashrc"
    touch "$bashrc"

    if ! grep -qF 'go env GOPATH' "$bashrc"; then
        echo -e '\n# Add Go binaries to PATH\nexport PATH="$PATH:$(go env GOPATH)/bin"' >> "$bashrc"
        echo "✓ Configured GOPATH"
    else
        echo "✓ GOPATH (already configured)"
    fi
}

# Configure task completion in bashrc
configure_task() {
    local bashrc="$HOME/.bashrc"
    touch "$bashrc"

    if ! grep -qF 'task --completion bash' "$bashrc"; then
        echo -e '\n# task completion\neval "$(task --completion bash)"' >> "$bashrc"
        echo "✓ Configured task completion"
    else
        echo "✓ task completion (already configured)"
    fi
}

# Install Claude CLI
install_claude_cli() {
    if command -v claude >/dev/null 2>&1; then
        echo "✓ Claude CLI (already installed)"
        return 0
    fi

    echo "→ Installing Claude CLI..."
    curl -fsSL https://claude.ai/install.sh | bash
    echo "✓ Installed Claude CLI"
}

# Configure ~/.local/bin in PATH
configure_local_bin_path() {
    local bashrc="$HOME/.bashrc"
    touch "$bashrc"

    if ! grep -qF '.local/bin' "$bashrc"; then
        echo -e '\n# Add ~/.local/bin to PATH\nexport PATH="$HOME/.local/bin:$PATH"' >> "$bashrc"
        echo "✓ Configured ~/.local/bin in PATH"
    else
        echo "✓ ~/.local/bin (already configured)"
    fi
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
            configure_local_bin_path
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
            configure_local_bin_path
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
