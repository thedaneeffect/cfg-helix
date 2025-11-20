#!/usr/bin/env bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONTS_DIR="$SCRIPT_DIR/fonts"

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: This script only works on macOS"
    exit 1
fi

# Create fonts directory
mkdir -p "$FONTS_DIR"

# Find and copy Input fonts
echo "→ Backing up Input fonts..."

# Use array to avoid subshell scope issues
mapfile -t fonts < <(find ~/Library/Fonts /Library/Fonts -name "Input*.ttf" 2>/dev/null)

if [[ ${#fonts[@]} -eq 0 ]]; then
    echo "✗ No Input fonts found in ~/Library/Fonts or /Library/Fonts"
    exit 1
fi

for font in "${fonts[@]}"; do
    cp "$font" "$FONTS_DIR/"
    echo "  ✓ $(basename "$font")"
done

echo ""
echo "✓ Backed up ${#fonts[@]} Input font files to: $FONTS_DIR"
echo ""
echo "To restore these fonts on another machine, run:"
echo "  ./setup.sh"
