#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/thedaneeffect/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

# Clone or update dotfiles repository
if [[ -d "$DOTFILES_DIR/.git" ]]; then
    echo "→ Updating dotfiles repository..."
    cd "$DOTFILES_DIR"
    git pull --quiet
else
    echo "→ Cloning dotfiles repository..."
    git clone --quiet "$REPO_URL" "$DOTFILES_DIR"
    cd "$DOTFILES_DIR"
fi

echo "→ Running setup..."
bash setup.sh "$@"

echo ""
echo "✓ Bootstrap complete!"
echo "  Dotfiles repository: $DOTFILES_DIR"
