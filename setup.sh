#!/usr/bin/env bash
set -euo pipefail

# Ensure dependencies are installed
ensure_dependencies() {
    echo "==> Checking dependencies..."

    # Check for Homebrew
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add brew to PATH for this session
        if [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
    else
        echo "✓ Homebrew installed"
    fi

    # Check for yq
    if ! command -v yq >/dev/null 2>&1; then
        echo "yq not found. Installing..."
        brew install yq
    else
        echo "✓ yq installed"
    fi

    # Check for helix
    if ! command -v hx >/dev/null 2>&1; then
        echo "helix not found. Installing..."
        brew install helix
    else
        echo "✓ helix installed"
    fi

    # Check for go
    if ! command -v go >/dev/null 2>&1; then
        echo "go not found. Installing..."
        brew install go
    else
        echo "✓ go installed"
    fi

    # Check for fzf
    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf not found. Installing..."
        brew install fzf
    else
        echo "✓ fzf installed"
    fi
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
    wslpath "$(cmd.exe /c 'echo %LOCALAPPDATA%' | tr -d '\r')"
}

# Install fonts from fonts/ directory
install_fonts() {
    echo "==> Installing fonts..."

    if ! is_wsl; then
        echo "⚠ Skipping font installation (not in WSL environment)"
        return 0
    fi

    local fonts_dir="./fonts"
    [[ -d "$fonts_dir" ]] || { echo "Error: $fonts_dir directory not found"; return 1; }

    local localappdata=$(get_localappdata)
    local user_fonts="$localappdata/Microsoft/Windows/Fonts"
    mkdir -p "$user_fonts"

    # Copy font files to Windows fonts directory
    local count=0
    for font in "$fonts_dir"/*.{ttf,otf,TTF,OTF}; do
        [[ -f "$font" ]] || continue
        cp "$font" "$user_fonts/"
        ((count++))
    done

    if [[ $count -eq 0 ]]; then
        echo "⚠ No font files found in $fonts_dir"
        return 1
    fi

    echo "✓ Installed $count font files"
}

# Apply Windows Terminal settings
apply_settings() {
    echo "==> Applying Windows Terminal settings..."

    if ! is_wsl; then
        echo "⚠ Skipping Windows Terminal settings (not in WSL environment)"
        return 0
    fi

    local localappdata=$(get_localappdata)
    local local_patch="./settings.json"

    # Validate source file
    [[ -f "$local_patch" ]] || { echo "Error: $local_patch not found"; return 1; }

    # Find Windows Terminal package directory
    local wt_package=$(find "$localappdata/Packages" -maxdepth 1 -name "Microsoft.WindowsTerminal_*" -type d 2>/dev/null | head -n 1)
    [[ -n "$wt_package" ]] || { echo "Error: Windows Terminal package not found in $localappdata/Packages"; return 1; }

    local wt_settings="$wt_package/LocalState/settings.json"
    [[ -f "$wt_settings" ]] || { echo "Error: Windows Terminal settings not found at $wt_settings"; return 1; }

    # Backup
    local backup="$wt_settings.backup.$(date +%s)"
    cp "$wt_settings" "$backup"
    echo "Backed up to: $backup"

    # Merge: local patch overwrites WT settings
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
      "$wt_settings" "$local_patch" > /tmp/merged.json

    # Atomic write
    mv /tmp/merged.json "$wt_settings"
    echo "✓ Settings applied"
}

# Install Helix config
install_helix_config() {
    echo "==> Installing Helix config..."
    local config_source="./config.toml"
    local config_dest="$HOME/.config/helix/config.toml"

    # Validate source exists
    [[ -f "$config_source" ]] || { echo "Error: $config_source not found"; return 1; }

    # Create config directory if needed
    mkdir -p "$(dirname "$config_dest")"

    # Backup existing config if present
    if [[ -f "$config_dest" ]]; then
        local backup="$config_dest.backup.$(date +%s)"
        cp "$config_dest" "$backup"
        echo "Backed up existing config to: $backup"
    fi

    # Copy config
    cp "$config_source" "$config_dest"
    echo "✓ Helix config installed to $config_dest"
}

# Configure fzf in bashrc
configure_fzf() {
    echo "==> Configuring fzf in .bashrc..."
    local bashrc="$HOME/.bashrc"
    local fzf_line='eval "$(fzf --bash)"'

    # Create .bashrc if it doesn't exist
    touch "$bashrc"

    # Check if fzf is already configured
    if grep -qF "$fzf_line" "$bashrc"; then
        echo "✓ fzf already configured in .bashrc"
    else
        echo "" >> "$bashrc"
        echo "$fzf_line" >> "$bashrc"
        echo "✓ Added fzf configuration to .bashrc"
    fi
}

# Configure GOPATH in bashrc
configure_gopath() {
    echo "==> Configuring GOPATH in .bashrc..."
    local bashrc="$HOME/.bashrc"
    local gopath_export='export PATH="$PATH:$(go env GOPATH)/bin"'

    # Create .bashrc if it doesn't exist
    touch "$bashrc"

    # Check if GOPATH is already in PATH
    if grep -qF 'go env GOPATH' "$bashrc"; then
        echo "✓ GOPATH already configured in .bashrc"
    else
        echo "" >> "$bashrc"
        echo "# Add Go binaries to PATH" >> "$bashrc"
        echo "$gopath_export" >> "$bashrc"
        echo "✓ Added GOPATH to .bashrc"
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
        go)
            configure_gopath
            ;;
        all)
            install_fonts
            apply_settings
            install_helix_config
            configure_fzf
            configure_gopath
            ;;
        *)
            echo "Usage: $0 [fonts|settings|helix|fzf|go|all]"
            echo "  fonts    - Install fonts only"
            echo "  settings - Apply Windows Terminal settings only"
            echo "  helix    - Install Helix config only"
            echo "  fzf      - Configure fzf in .bashrc only"
            echo "  go       - Configure GOPATH in .bashrc only"
            echo "  all      - Do everything (default)"
            exit 1
            ;;
    esac

    echo ""
    echo "============================================"
    echo "✓ Setup complete!"
    echo ""
    echo "To apply changes to your current shell, run:"
    echo "  source ~/.bashrc"
    echo ""
    echo "Or simply restart your terminal."
    echo "============================================"
}

main "$@"
