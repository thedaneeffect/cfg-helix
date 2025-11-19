# Helix & Windows Terminal Configuration

My development environment configuration for WSL + Windows Terminal + Helix editor.

## Quick Start

**One-liner installation:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/thedaneeffect/env-wsl/master/bootstrap.sh)
```

**Or clone and run manually:**

```bash
git clone https://github.com/thedaneeffect/env-wsl.git
cd env-wsl
./setup.sh
```

## What's Included

- **Helix Editor Config** (`config.toml`) - Custom Helix settings
- **Windows Terminal Settings** (`settings.json`) - Terminal appearance and behavior
- **Fonts** (`fonts/`) - Custom fonts for the terminal
- **Claude CLI** - AI-powered command line assistant
- **Setup Script** (`setup.sh`) - Automated installation script
- **Bootstrap Script** (`bootstrap.sh`) - One-liner installer

## Selective Installation

Run specific parts only:

```bash
./setup.sh fonts     # Install fonts only
./setup.sh settings  # Apply Windows Terminal settings only
./setup.sh helix     # Install Helix config only
./setup.sh fzf       # Configure fzf only
./setup.sh zoxide    # Configure zoxide only
./setup.sh go        # Configure GOPATH only
./setup.sh task      # Configure task completion only
./setup.sh claude    # Install Claude CLI and configure PATH only
./setup.sh ps1       # Configure PS1 prompt only
./setup.sh eza       # Configure eza aliases (ls, ll, la) only
./setup.sh git       # Configure git settings only
./setup.sh bash      # Configure bash quality of life improvements only
./setup.sh all       # Everything (default)
```

## What the Script Does

- **Dependency Management**: Installs Homebrew, yq, helix, go, fzf, zoxide, task, ripgrep, ast-grep, bat, and eza if missing
- **Fonts**: Copies custom fonts to Windows fonts directory (WSL only)
- **Windows Terminal**: Merges settings using yq (WSL only)
- **Helix Config**: Installs to `~/.config/helix/config.toml`
- **Claude CLI**: Installs Claude AI assistant and adds `~/.local/bin` to PATH
- **Git Configuration**: Sets user name, email, default branch, and useful aliases (st, co, br, lg)
- **Shell Configuration**: Adds fzf, zoxide, GOPATH, task completion, PS1 prompt, eza aliases, bash history improvements, and useful aliases
- **Backups**: Creates timestamped backups before overwriting configs
- **WSL Detection**: Skips Windows-specific operations on native Linux

## Key Features

### Zoxide - Smart Directory Navigation
After installation, use these commands to navigate:
- `z <partial-name>` - Jump to a directory matching the name (based on frecency)
- `zi` - Interactive fuzzy finder (via fzf) to select from all your directories
- Works across all terminal sessions - remembers your most-used paths

Examples:
```bash
z proj          # Jump to ~/projects/env-wsl
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
- **bat** - Cat with syntax highlighting and git integration
- **eza** - Modern ls replacement with colors and git status
  - `ls` - List files
  - `ll` - List with details
  - `la` - List all including hidden files

### Git Configuration
Pre-configured with:
- User: Dane <dane@medieval.software>
- Default branch: main
- Pull strategy: merge (not rebase)
- Aliases: `git st`, `git co`, `git br`, `git lg`

### Bash Improvements
- Extended history (10000 commands)
- No duplicate entries
- Useful aliases: `..`, `...`, colored grep

## Requirements

- WSL (Windows Subsystem for Linux)
- Windows Terminal
- Internet connection (for dependency installation)

## File Structure

```
.
├── bootstrap.sh    # One-liner installer
├── setup.sh        # Main installation script
├── config.toml     # Helix editor configuration
├── settings.json   # Windows Terminal settings
├── fonts/          # Custom fonts directory (9 ProggyClean variants)
└── README.md       # This file
```
