# Migrating from Homebrew to mise

This guide covers the migration from Homebrew-based tool management to mise.

## For Existing Users

If you've already run `setup.sh` with Homebrew:

1. **Backup current setup:**
   ```bash
   brew list > ~/brew-backup.txt
   cp ~/.bashrc ~/.bashrc.backup  # or ~/.zshrc
   ```

2. **Pull latest dotfiles:**
   ```bash
   cd ~/projects/dotfiles
   git pull
   ```

3. **Run updated setup:**
   ```bash
   ./setup.sh
   ```

4. **Reload shell:**
   ```bash
   source ~/.bashrc  # or ~/.zshrc
   ```

5. **Verify mise installation:**
   ```bash
   mise doctor
   mise list --installed
   ```

6. **Homebrew cleanup (automatic):**
   The setup script automatically removes Homebrew packages that have been migrated to mise. The following tools remain in Homebrew:
   - gnupg (system integration)
   - typescript-language-server
   - bash-language-server
   - yaml-language-server
   - vscode-langservers-extracted

## Troubleshooting

### Tools not found after migration

1. Check mise activation:
   ```bash
   echo $MISE_SHELL
   ```

2. Manually activate mise:
   ```bash
   eval "$(mise activate bash)"  # or zsh
   ```

3. Check tool installation:
   ```bash
   mise list --installed
   mise install  # Install missing tools
   ```

### Conflicts between Homebrew and mise

mise tools take precedence if mise is activated in shell. Check PATH:
```bash
echo $PATH
```

mise paths should appear before Homebrew paths (`/opt/homebrew/bin` or `/usr/local/bin`).

### Rolling back to Homebrew

If you experience issues:

1. **Restore shell configuration:**
   ```bash
   cp ~/.bashrc.backup ~/.bashrc  # or ~/.zshrc
   source ~/.bashrc  # or ~/.zshrc
   ```

2. **Reinstall Homebrew packages:**
   ```bash
   brew install $(cat ~/brew-backup.txt)
   ```

3. **Reinstall goenv if needed:**
   ```bash
   brew install goenv
   export GOENV_ROOT="$HOME/.goenv"
   export PATH="$GOENV_ROOT/bin:$PATH"
   eval "$(goenv init -)"
   goenv install 1.23.3  # Or your preferred version
   goenv global 1.23.3
   ```

4. **Reinstall Go tools:**
   ```bash
   go install golang.org/x/tools/gopls@latest
   go install github.com/air-verse/air@latest
   go install -tags "postgres sqlite3" github.com/xo/usql@latest
   # ... other Go tools as needed
   ```

## Benefits of mise

- **Unified management**: One tool for all languages and CLIs
- **Version pinning**: `.mise.toml` commits versions to git
- **Per-project versions**: Different tool versions per directory
- **Faster**: Rust-based, faster than Homebrew
- **Auto-install**: Tools install automatically when entering directory
- **Task running**: Built-in task runner (replaces go-task)
- **Environment variables**: Replaces direnv functionality

## What Changed

### Tools Migrated to mise

The following tools are now managed by mise (see `.mise.toml`):

**Core Languages & Runtimes:**
- bun, go, zig

**CLI Utilities (22 tools):**
- bat, btop, delta, dust, eza, fd, fzf, gh, glow, grex, jq, ripgrep, sd, starship, tldr, tokei, yq, zellij, zoxide, direnv, ast-grep

**Development Tools:**
- helix, golangci-lint, marksman, taplo, zls

**Go Tools:**
- air, gofumpt, golines, gopls, delve, golangci-lint-langserver, docker-language-server

### Tools Kept in Homebrew

These remain in Homebrew for system integration:
- gnupg
- typescript-language-server
- bash-language-server
- yaml-language-server
- vscode-langservers-extracted

### Replaced Tools

- **goenv** → mise (Go version management)
- **go-task** → mise tasks (task runner)
- **direnv** → mise env vars (environment management, though direnv tool is still installed)

## Using mise

### Basic Commands

```bash
# Install all tools from .mise.toml
mise install

# Update all tools
mise upgrade --bump

# Check for outdated tools
mise outdated

# List installed tools
mise list --installed

# Run a task
mise run setup
mise run update-tools

# Check mise health
mise doctor
```

### Per-Project Tool Versions

mise supports per-project tool versions. In any project, create a `.mise.toml`:

```toml
[tools]
go = "1.21.0"  # Project-specific Go version
node = "20.0.0"
```

When you `cd` into that directory, mise automatically activates those versions.

### Updating Tool Versions

Edit `.mise.toml` and change version numbers:

```toml
[tools]
go = "1.23.3"  # Change from "latest" to pin version
```

Then run:
```bash
mise install
```

## FAQ

**Q: Can I use both Homebrew and mise?**
A: Yes. mise-managed tools take precedence in PATH when mise is activated.

**Q: What if a tool isn't in mise registry?**
A: mise supports multiple backends (ubi for GitHub releases, go for Go tools, npm for Node packages). Check the `.mise.toml` for examples.

**Q: How do I switch Go versions?**
A: Use `mise use go@<version>` or edit `.mise.toml` and run `mise install`.

**Q: Do I need to reinstall tools on every machine?**
A: No. Clone dotfiles, run `./setup.sh`, and mise installs everything from `.mise.toml`.

**Q: Can I rollback if something breaks?**
A: Yes. See "Rolling back to Homebrew" section above.

## Support

If you encounter issues:

1. Run `mise doctor` to diagnose problems
2. Check `mise list --installed` to verify tool installation
3. Review shell RC file for mise activation
4. Restore from backup if needed (see Troubleshooting section)
