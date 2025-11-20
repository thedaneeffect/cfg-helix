#!/usr/bin/env bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: This script only works on macOS"
    exit 1
fi

# Check if iTerm2 preferences exist
ITERM_PREFS="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
if [[ ! -f "$ITERM_PREFS" ]]; then
    echo "Error: iTerm2 preferences not found at $ITERM_PREFS"
    echo "Make sure iTerm2 is installed and has been run at least once"
    exit 1
fi

# Backup the plist file
BACKUP_FILE="$SCRIPT_DIR/com.googlecode.iterm2.plist"
cp "$ITERM_PREFS" "$BACKUP_FILE"

echo "✓ Backed up iTerm2 settings to: $BACKUP_FILE"
echo ""
echo "To restore these settings on another machine, run:"
echo "  ./setup.sh"
