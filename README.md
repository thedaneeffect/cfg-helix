# Helix & Windows Terminal Configuration

My development environment configuration for WSL + Windows Terminal + Helix editor.

## Quick Start

**One-liner installation:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/thedaneeffect/cfg-helix/master/bootstrap.sh)
```

**Or clone and run manually:**

```bash
git clone https://github.com/thedaneeffect/cfg-helix.git
cd cfg-helix
./setup.sh
```

## What's Included

- **Helix Editor Config** (`config.toml`) - Custom Helix settings
- **Windows Terminal Settings** (`settings.json`) - Terminal appearance and behavior
- **Fonts** (`fonts/`) - Custom fonts for the terminal
- **Setup Script** (`setup.sh`) - Automated installation script
- **Bootstrap Script** (`bootstrap.sh`) - One-liner installer

## Selective Installation

Run specific parts only:

```bash
./setup.sh fonts     # Install fonts only
./setup.sh settings  # Apply Windows Terminal settings only
./setup.sh helix     # Install Helix config only
./setup.sh fzf       # Configure fzf only
./setup.sh go        # Configure GOPATH only
./setup.sh task      # Configure task completion only
./setup.sh all       # Everything (default)
```

## What the Script Does

- **Dependency Management**: Installs Homebrew, yq, helix, go, fzf, and task if missing
- **Fonts**: Copies custom fonts to Windows fonts directory (WSL only)
- **Windows Terminal**: Merges settings using yq (WSL only)
- **Helix Config**: Installs to `~/.config/helix/config.toml`
- **Shell Configuration**: Adds fzf, GOPATH, and task completion to `.bashrc`
- **Backups**: Creates timestamped backups before overwriting configs
- **WSL Detection**: Skips Windows-specific operations on native Linux

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
