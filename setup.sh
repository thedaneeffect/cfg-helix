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
}

# Get Windows LocalAppData path (shared by both operations)
get_localappdata() {
    wslpath "$(cmd.exe /c 'echo %LOCALAPPDATA%' | tr -d '\r')"
}

# Install fonts from fonts.zip
install_fonts() {
    echo "==> Installing fonts..."
    local fonts_zip="fonts.zip"
    [[ -f "$fonts_zip" ]] || { echo "Error: $fonts_zip not found"; return 1; }

    local localappdata=$(get_localappdata)
    local user_fonts="$localappdata/Microsoft/Windows/Fonts"
    mkdir -p "$user_fonts"

    # Extract fonts directly to user fonts dir
    unzip -o -j "$fonts_zip" '*' -d "$user_fonts" || true
    echo "✓ Fonts installed"
}

# Apply Windows Terminal settings
apply_settings() {
    echo "==> Applying Windows Terminal settings..."
    local localappdata=$(get_localappdata)
    local wt_settings="$localappdata/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
    local local_patch="./settings.json"

    # Validate
    [[ -f "$local_patch" ]] || { echo "Error: $local_patch not found"; return 1; }
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
        all)
            install_fonts
            apply_settings
            install_helix_config
            ;;
        *)
            echo "Usage: $0 [fonts|settings|helix|all]"
            echo "  fonts    - Install fonts only"
            echo "  settings - Apply Windows Terminal settings only"
            echo "  helix    - Install Helix config only"
            echo "  all      - Do everything (default)"
            exit 1
            ;;
    esac
}

main "$@"
