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
| **Starship** | Cross-shell prompt with git integration |
| **Claude CLI** | AI assistant for command line |
| **Secrets CLI** | AES-256 encrypted secrets sync via Cloudflare Workers |
| **Modern Tools** | ripgrep, fd, bat, eza, delta, jq, sd, glow, tokei, gh, procs, dust |
| **Development** | Go, goenv, air, bun, direnv, task |
| **Language Servers** | gopls, typescript-language-server, zls, yaml-language-server |

Automatically configures git, GPG signing, shell aliases, and syncs settings across machines.

## Modern CLI Tools

| Tool | Replaces | Purpose |
|------|----------|---------|
| **ripgrep (rg)** | grep | Fast search, respects .gitignore |
| **fd** | find | Simple file finding |
| **bat** | cat | Syntax highlighting |
| **eza** | ls | Colors and git status |
| **delta** | diff | Beautiful git diffs |
| **sd** | sed | Simple find and replace |
| **procs** | ps | Process viewer |
| **dust** | du | Disk usage tree |
| **zoxide** | cd | Smart directory jumping |
| **fzf** | - | Fuzzy finder for everything |

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
├── bootstrap.sh      # One-liner installer
├── setup.sh          # Main installation script
├── secrets           # Secrets management CLI
├── config.toml       # Helix editor configuration
├── worker/           # Cloudflare Worker
│   ├── index.js
│   ├── wrangler.toml
│   └── README.md
└── snippets/         # Shell configurations
    ├── fzf.sh
    ├── zoxide.sh
    ├── git_aliases.sh
    └── ...
```
