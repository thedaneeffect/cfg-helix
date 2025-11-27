#!/usr/bin/env bash
set -euo pipefail

echo "→ Rolling back from mise to Homebrew..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Detect shell
SHELL_TYPE=$(basename "$SHELL")
RC_FILE="$HOME/.${SHELL_TYPE}rc"

# 1. Restore shell rc
if [[ -f "$RC_FILE.pre-mise" ]]; then
    cp "$RC_FILE.pre-mise" "$RC_FILE"
    echo "✓ Restored shell rc from backup"
else
    echo "⊘ No shell rc backup found at $RC_FILE.pre-mise"
fi

# 2. Uninstall mise tools (optional - doesn't conflict)
if command -v mise >/dev/null 2>&1; then
    echo "→ Uninstalling mise tools..."
    mise uninstall --all || echo "⊘ Could not uninstall mise tools"
fi

# 3. Reinstall Homebrew packages
if [[ -f "$REPO_ROOT/.brew-backup.txt" ]]; then
    echo "→ Reinstalling Homebrew packages..."
    # Filter out mise-only tools and reinstall
    while IFS= read -r pkg; do
        # Skip empty lines and comments
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue

        # Skip packages that might have dependencies issues
        if brew list "$pkg" &>/dev/null; then
            echo "  ✓ $pkg (already installed)"
        else
            echo "  → Installing $pkg..."
            brew install "$pkg" || echo "  ⊘ Could not install $pkg"
        fi
    done < "$REPO_ROOT/.brew-backup.txt"
    echo "✓ Reinstalled Homebrew packages"
else
    echo "✗ Error: .brew-backup.txt not found"
    echo "  Manual install required. Key packages:"
    echo "  brew install yq helix go fzf zoxide ripgrep bat eza ast-grep fd direnv git-delta jq btop tldr sd glow tokei gh dust golangci-lint zig zls taplo goenv starship marksman grex zellij gnupg"
fi

# 4. Restore goenv
if command -v goenv >/dev/null 2>&1; then
    export GOENV_ROOT="$HOME/.goenv"
    export PATH="$GOENV_ROOT/bin:$PATH"
    eval "$(goenv init -)"
    echo "✓ Restored goenv"
    echo "  Note: You may need to run 'goenv install <version>' and 'goenv global <version>'"
fi

# 5. Reinstall Go tools
if command -v go >/dev/null 2>&1; then
    echo "→ Reinstalling Go tools..."
    go install golang.org/x/tools/gopls@latest
    go install github.com/nametake/golangci-lint-langserver@latest
    go install github.com/segmentio/golines@latest
    go install mvdan.cc/gofumpt@latest
    go install github.com/go-delve/delve/cmd/dlv@latest
    go install github.com/air-verse/air@latest
    go install -tags "postgres sqlite3" github.com/xo/usql@latest
    go install github.com/docker/docker-language-server/cmd/docker-language-server@latest
    echo "✓ Reinstalled Go tools"
fi

echo "✓ Rollback complete!"
echo ""
echo "Next steps:"
echo "  1. Run: source ~/.${SHELL_TYPE}rc"
echo "  2. Verify tools: go version, bun --version, etc."
echo "  3. If issues persist, check .brew-versions-backup.txt for specific versions"
echo ""
echo "To completely remove mise:"
echo "  rm -rf ~/.local/share/mise ~/.local/bin/mise ~/.config/mise"
