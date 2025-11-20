# Development Environment Setup

Automated development environment for macOS and WSL with GPG commit signing and encrypted secrets management.

## Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/thedaneeffect/dotfiles/main/bootstrap.sh)
```

Or clone and run:

```bash
git clone https://github.com/thedaneeffect/dotfiles.git
cd dotfiles
./setup.sh
```

Setup prompts for optional secrets storage configuration (Cloudflare Worker URL + passphrase).

## What Gets Installed

| Component | Purpose |
|-----------|---------|
| **Helix** | Modern terminal editor |
| **Zellij** | Terminal multiplexer |
| **Starship** | Cross-shell prompt with git integration |
| **Claude CLI** | AI assistant for command line |
| **Secrets CLI** | AES-256 encrypted secrets sync via Cloudflare Workers |
| **Modern Tools** | ripgrep, fd, bat, eza, delta, jq, sd, glow, tokei, gh, procs, dust, btop, tldr, grex, yq |
| **Development** | Go, Zig, goenv, air, bun, direnv, task |
| **Language Servers** | gopls, typescript-language-server, bash-language-server, zls, yaml-language-server, marksman, taplo |

Automatically configures git, GPG signing, shell aliases, and syncs settings across machines.

## Modern CLI Tools

| Tool | Replaces | Purpose |
|------|----------|---------|
| **ripgrep (rg)** | grep | Fast search, respects .gitignore |
| **ast-grep** | - | Structural code search |
| **fd** | find | Simple file finding |
| **bat** | cat | Syntax highlighting |
| **eza** | ls | Colors and git status |
| **delta** | diff | Beautiful git diffs |
| **sd** | sed | Simple find and replace |
| **procs** | ps | Process viewer |
| **dust** | du | Disk usage tree |
| **btop** | top/htop | System monitor |
| **zoxide** | cd | Smart directory jumping |
| **fzf** | - | Fuzzy finder |
| **zellij** | tmux/screen | Terminal multiplexer |
| **jq** | - | JSON processor |
| **yq** | - | YAML processor |
| **glow** | - | Markdown renderer |
| **grex** | - | Regex generator from examples |
| **tldr** | man | Simplified command examples |
| **gh** | - | GitHub CLI |

## Secrets Management

AES-256 encrypted storage via Cloudflare Workers. Data is encrypted client-side before upload.

### Commands

| Command | Purpose |
|---------|---------|
| `secrets add <file>` | Track a file |
| `secrets push` | Encrypt and upload |
| `secrets pull` | Download and decrypt |
| `secrets list` | Show local and remote files |
| `secrets groups` | List all groups |
| `secrets delete <group>` | Remove a group |

### Named Groups

```bash
secrets add ~/.ssh/github_key -g github
secrets push github
secrets pull github
```

### Security Model

1. Client-side AES-256-CBC encryption before upload
2. PBKDF2 key derivation from passphrase
3. Encrypted storage in Cloudflare KV
4. HTTPS transport security
5. Bearer token authentication

Data remains encrypted even with full Cloudflare account access.

### Worker Deployment

```bash
npm install -g wrangler
cd worker
wrangler login
wrangler kv:namespace create SECRETS
# Update wrangler.toml with KV namespace ID
wrangler secret put SECRET_PASSPHRASE
wrangler deploy
```

## iTerm2 Settings (macOS)

Automatically restores iTerm2 preferences on macOS.

### Backup Current Settings

```bash
./backup-iterm.sh
```

This exports your current iTerm2 preferences to `com.googlecode.iterm2.plist`.

### Restore on New Machine

Settings are automatically restored when running `./setup.sh` on macOS. The script will:
1. Backup existing preferences to `.bak` file
2. Copy stored settings to `~/Library/Preferences/`
3. Reload preferences

Restart iTerm2 after setup completes.

## Font Management

Fonts are automatically installed from the `fonts/` directory on both macOS and WSL.

### Backup Fonts (macOS)

```bash
./backup-fonts.sh
```

This exports all Input fonts from `~/Library/Fonts` to the `fonts/` directory.

### Restore Fonts

Fonts are automatically installed when running `./setup.sh`:
- **macOS**: Copied to `~/Library/Fonts`
- **WSL**: Installed in Windows via PowerShell script

## Zellij Configuration

Custom Zellij configuration is automatically installed to `~/.config/zellij/config.kdl`.

### Features

- **Theme**: gruvbox-dark
- **Default mode**: locked (requires Ctrl+g to unlock)
- **Default layout**: compact
- **Pane frames**: disabled
- **Startup tips**: disabled

The configuration includes custom keybindings and tmux-compatible shortcuts.

## Git Configuration

| Setting | Value |
|---------|-------|
| User | dane <dane@medieval.software> |
| Default branch | main |
| Commit signing | GPG (auto-imported from secrets) |
| Pager | delta |

### Git Aliases

| Alias | Command |
|-------|---------|
| `git st` | status |
| `git co` | checkout |
| `git br` | branch |
| `git lg` | log --graph --oneline --decorate |
| `git cm` | commit -m |
| `git amend` | commit --amend --no-edit |

### Shell Aliases

| Alias | Command |
|-------|---------|
| `gst` | git status |
| `gc` | git commit |
| `gl` | git log |
| `gd` | git diff |
| `gds` | git diff --staged |
| `ga` | git add |

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Ctrl+R` | Search command history (fzf) |
| `Ctrl+T` | Fuzzy find files |
| `Alt+C` | Fuzzy find directories |

## Zoxide

Smart directory navigation based on frecency:

```bash
z proj          # Jump to ~/projects/dotfiles
zi              # Interactive fuzzy finder
```

## Requirements

| Requirement | Notes |
|-------------|-------|
| macOS or WSL | - |
| bash or zsh | Auto-detected |
| Internet | For dependencies |
| Windows Terminal | WSL only |
| Cloudflare account | Optional, for secrets storage |

## Snippet System

Shell configurations live in `snippets/`:
- Modular, version-controlled files
- Wrapped with delimiters for clean updates
- Shell-specific snippets load conditionally
- Re-running setup replaces all snippets cleanly

## Updates

```bash
bootstrap  # Re-download and run latest setup
```

This updates all snippets and reloads your shell configuration.

## File Structure

```
.
├── bootstrap.sh                    # One-liner installer
├── setup.sh                        # Main installation script
├── backup-iterm.sh                 # Backup iTerm2 settings (macOS)
├── backup-fonts.sh                 # Backup fonts (macOS)
├── secrets                         # Secrets management CLI
├── config.toml                     # Helix editor configuration
├── zellij-config.kdl               # Zellij configuration
├── com.googlecode.iterm2.plist     # iTerm2 settings (created by backup-iterm.sh)
├── fonts/                          # Font files (auto-installed)
│   └── *.ttf                       # TrueType fonts
├── worker/                         # Cloudflare Worker
│   ├── index.js
│   ├── wrangler.toml
│   └── README.md
└── snippets/                       # Shell configurations
    ├── fzf.sh
    ├── zoxide.sh
    ├── git_aliases.sh
    └── ...
```
