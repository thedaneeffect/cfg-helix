# Cross-Platform Development Environment Setup

My development environment configuration for macOS and WSL, with automatic shell detection (bash/zsh).

## Quick Start

**One-liner installation:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/thedaneeffect/dotfiles/master/bootstrap.sh)
```

**Or clone and run manually:**

```bash
git clone https://github.com/thedaneeffect/dotfiles.git
cd dotfiles
./setup.sh
```

## What's Included

- **Shell Configurations** (`snippets/`) - Modular, version-controlled shell configs
- **Helix Editor Config** (`config.toml`) - Custom Helix settings
- **Windows Terminal Settings** (`settings.json`) - Terminal appearance and behavior (WSL only)
- **Fonts** (`fonts/`) - Custom fonts for the terminal (WSL only)
- **Starship Prompt** - Fast, customizable cross-shell prompt
- **Claude CLI** - AI-powered command line assistant
- **Setup Script** (`setup.sh`) - Automated installation script
- **Bootstrap Script** (`bootstrap.sh`) - One-liner installer

## What the Script Does

- **Shell Detection**: Automatically detects your default shell (bash or zsh) and configures appropriately
- **Dependency Management**: Installs Homebrew, yq, helix, go, fzf, zoxide, direnv, task, ripgrep, ast-grep, fd, bat, eza, delta, jq, btop, tldr, sd, glow, tokei, gh, procs, dust, typescript-language-server, golangci-lint, zig, zls, taplo, yaml-language-server, goenv, and starship if missing
- **Fonts**: Copies custom fonts to Windows fonts directory (WSL only)
- **Windows Terminal**: Merges settings using yq (WSL only)
- **Helix Config**: Installs to `~/.config/helix/config.toml`
- **Starship Prompt**: Configures fast, cross-shell prompt with git integration
- **Claude CLI**: Installs Claude AI assistant and adds `~/.local/bin` to PATH
- **Git Configuration**: Sets user name, email, default branch, useful aliases (st, co, br, lg), and delta as pager
- **Go Tools**: Installs gopls (language server), golangci-lint-langserver (linter langserver), golines (formatter for long lines), gofumpt (stricter gofmt), delve (debugger), air (live reload), and usql (universal SQL client) via go install
- **TypeScript Support**: Installs typescript-language-server for JavaScript/TypeScript development in Helix
- **Snippet-Based Configs**: Modular shell configurations that update cleanly on re-run
- **XDG Base Directories**: Configures clean home directory structure
- **Shell Aliases**: Git shortcuts (gst, gc, gl, gd, gds, ga), eza aliases, and navigation shortcuts
- **Zsh Features**: Directory stack management, optimized history (zsh only)
- **macOS Support**: Home/End key bindings for zsh on macOS
- **Backups**: Creates timestamped backups before overwriting configs
- **Platform Detection**: Automatically handles macOS vs WSL differences

## Key Features

### Zoxide - Smart Directory Navigation
After installation, use these commands to navigate:
- `z <partial-name>` - Jump to a directory matching the name (based on frecency)
- `zi` - Interactive fuzzy finder (via fzf) to select from all your directories
- Works across all terminal sessions - remembers your most-used paths

Examples:
```bash
z proj          # Jump to ~/projects/dotfiles
zi              # Open fzf to select from your directory history
z doc down      # Jump to ~/Documents/Downloads
```

### fzf - Fuzzy Finding
- **`Ctrl+R`** - Search command history
- **`Ctrl+T`** - Fuzzy find files in current directory
- **`Alt+C`** - Fuzzy find and cd into subdirectories

### Modern CLI Tools
- **ripgrep (rg)** - Blazing fast grep that respects .gitignore
- **ast-grep** - Structural search and replace for code
- **fd** - Modern find alternative with simpler syntax
- **bat** - Cat with syntax highlighting and git integration
- **eza** - Modern ls replacement with colors and git status
  - `ls` - List files
  - `ll` - List with details
  - `la` - List all including hidden files
  - `tree` - Show directory tree
- **delta** - Beautiful git diffs with syntax highlighting
- **jq** - JSON processor for parsing and filtering
- **sd** - Modern sed replacement with simpler syntax
- **glow** - Render markdown beautifully in terminal
- **tokei** - Code statistics and line counting
- **gh** - GitHub CLI for managing repos, PRs, and issues
- **procs** - Modern ps replacement for process viewing
- **dust** - Modern du replacement showing disk usage as tree
- **usql** - Universal SQL client (PostgreSQL and SQLite)
- **direnv** - Auto-loads `.envrc` files per directory
- **goenv** - Go version manager for managing multiple Go installations
- **btop** - Beautiful system monitor with resource usage
- **tldr** - Simplified man pages with practical examples

### Git Configuration
Pre-configured with:
- User: Dane <dane@medieval.software>
- Default branch: main
- Pull strategy: merge (not rebase)
- Delta pager for beautiful diffs
- Git command aliases: `git st`, `git co`, `git br`, `git lg`
- Shell aliases: `gst`, `gc`, `gl`, `gd`, `gds`, `ga` (no need to type `git`!)

### Shell Improvements
- Extended history (10000 commands)
- No duplicate entries (bash/zsh)
- Default editor set to Helix (`EDITOR=hx`)
- Useful aliases: `..`, `...`, colored grep
- Zsh: directory stack with auto-pushd, shared history
- Starship prompt with git integration

## Requirements

- **macOS** or **WSL (Windows Subsystem for Linux)**
- **bash** or **zsh** shell
- Internet connection (for dependency installation)
- Windows Terminal (WSL only)

## File Structure

```
.
├── bootstrap.sh      # One-liner installer
├── setup.sh          # Main installation script
├── CLAUDE.md         # Claude Code custom instructions
├── config.toml       # Helix editor configuration
├── settings.json     # Windows Terminal settings (WSL only)
├── fonts/            # Custom fonts directory (9 ProggyClean variants, WSL only)
├── snippets/         # Modular shell configuration snippets
│   ├── bash_qol.sh   # Bash-specific history config
│   ├── bootstrap.sh  # Bootstrap alias
│   ├── direnv.sh     # direnv hook
│   ├── eza_aliases.sh # Modern ls aliases
│   ├── fzf.sh        # Fuzzy finder
│   ├── git_aliases.sh # Git shortcuts (gst, gc, gl, etc.)
│   ├── goenv.sh      # Go version manager
│   ├── gopath.sh     # Go binary PATH
│   ├── local_bin.sh  # ~/.local/bin PATH
│   ├── macos_bindkeys.sh # macOS Home/End keys (zsh only)
│   ├── qol.sh        # Common quality-of-life configs
│   ├── starship.sh   # Starship prompt
│   ├── task.sh       # Task completion
│   ├── xdg.sh        # XDG Base Directory specification
│   ├── zoxide.sh     # Smart directory navigation
│   ├── zsh_dirstack.sh # Zsh directory stack management
│   └── zsh_qol.sh    # Zsh-specific history config
└── README.md         # This file
```

## How Snippets Work

Shell configurations are managed through modular snippets:
- Each snippet is a separate file in `snippets/`
- Snippets are wrapped with delimiters (`# snippet:name.sh` ... `# end:name.sh`)
- Running setup again cleanly replaces all snippets (no duplicates!)
- Easy to edit and version control
- Shell-specific snippets only load for the appropriate shell

## Re-running Setup

After initial installation, use the `bootstrap` alias to update:

```bash
bootstrap
```

This will:
1. Re-download and run the latest setup script
2. Update all snippets with any changes
3. Reload your shell configuration

Perfect for keeping your environment in sync across machines!
