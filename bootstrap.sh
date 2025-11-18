#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/thedaneeffect/cfg-helix.git"
TEMP_DIR=$(mktemp -d)

echo "→ Cloning configuration repository..."
git clone --quiet "$REPO_URL" "$TEMP_DIR"

echo "→ Running setup..."
cd "$TEMP_DIR"
bash setup.sh "$@"

echo "→ Cleaning up..."
rm -rf "$TEMP_DIR"

echo ""
echo "✓ Bootstrap complete!"
