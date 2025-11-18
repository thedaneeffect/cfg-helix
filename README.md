# Helix & Windows Terminal Configuration

My development environment configuration for WSL + Windows Terminal + Helix editor.

## What's Included

- **Helix Editor Config** (`config.toml`) - Custom Helix settings
- **Windows Terminal Settings** (`settings.json`) - Terminal appearance and behavior
- **Fonts** (`fonts/`) - Custom fonts for the terminal
- **Setup Script** (`setup.sh`) - Automated installation script

## Quick Start

Run the setup script to install everything:

```bash
./setup.sh
```

This will:
1. Install dependencies (Homebrew, yq, helix) if needed
2. Install fonts to Windows
3. Merge Windows Terminal settings
4. Install Helix config to `~/.config/helix/config.toml`

## Selective Installation

You can run individual parts:

```bash
./setup.sh fonts     # Install fonts only
./setup.sh settings  # Apply Windows Terminal settings only
./setup.sh helix     # Install Helix config only
```

## What the Script Does

- **Dependency Management**: Automatically installs Homebrew, yq, and helix if missing
- **Backup**: Creates timestamped backups before overwriting existing configs
- **Merge**: Uses yq to merge Windows Terminal settings (doesn't overwrite everything)
- **Atomic**: Safe file operations with proper error handling

## Requirements

- WSL (Windows Subsystem for Linux)
- Windows Terminal
- Internet connection (for dependency installation)

## File Structure

```
.
├── setup.sh        # Main installation script
├── config.toml     # Helix editor configuration
├── settings.json   # Windows Terminal settings
├── fonts/          # Custom fonts directory
└── README.md       # This file
```
