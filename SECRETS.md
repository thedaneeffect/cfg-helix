# Secrets Management

This dotfiles setup includes a custom `secrets` CLI tool for managing sensitive files using Bitwarden.

**✅ Works with free Bitwarden tier** - splits data into 8KB chunks across multiple secure notes (10k limit per note).

## Quick Start

### First Time Setup

```bash
# 1. Add your sensitive files to the registry
secrets add ~/.ssh/id_rsa
secrets add ~/.ssh/id_rsa.pub
secrets add ~/.ssh/config
secrets add ~/.env
secrets add ~/.aws/credentials

# 2. View what's tracked
secrets list

# 3. Push secrets (will prompt for Bitwarden login/password)
secrets push

# The command will:
# - Prompt for Bitwarden email and password
# - Export BW_SESSION automatically
# - Upload your secrets

# Done! Your secrets are encrypted and uploaded to Bitwarden
```

### On a New Machine

```bash
# 1. Run setup (installs Bitwarden CLI and secrets tool)
./setup.sh

# 2. Pull your secrets (will prompt for Bitwarden login/password)
secrets pull

# The command will:
# - Prompt for Bitwarden email and password
# - Export BW_SESSION automatically
# - Download and restore all your secrets

# All your secrets are restored!
```

## Commands

### `secrets add <path>`
Add a file or directory to the secrets registry.

```bash
secrets add ~/.ssh/id_rsa
secrets add ~/.gitconfig.local
secrets add ~/.aws/credentials
```

Paths can be:
- Absolute: `/Users/dane/.ssh/id_rsa`
- Relative to home: `~/.ssh/id_rsa`
- Relative to current dir: `.ssh/id_rsa`

### `secrets remove <path>`
Remove a file from the registry.

```bash
secrets remove ~/.env
```

### `secrets list`
Show all tracked files and their status.

```bash
$ secrets list
Tracked secrets:
  ✓ .ssh/id_rsa
  ✓ .ssh/config
  ✓ .env
  ✗ .aws/credentials (missing)
```

### `secrets status`
Check which tracked files exist.

```bash
$ secrets status
✗ Missing: .aws/credentials

✓ 3 files exist
✗ 1 files missing
```

### `secrets push`
Package all tracked files and upload to Bitwarden.

```bash
$ secrets push
→ Please login to Bitwarden:
  Email: you@example.com
? Master password: [hidden]
✓ Session key exported (valid for this session)
  To persist in your shell, run:
  export BW_SESSION="..."
→ Creating tarball...
→ Uploading to Bitwarden...
✓ Secrets pushed to Bitwarden
  Files: 4
  Size: 12K
```

The command will:
- Prompt for Bitwarden login if not logged in
- Prompt for master password to unlock vault
- Automatically export BW_SESSION for the command
- Upload encrypted tarball to Bitwarden

Requirements:
- All tracked files must exist

### `secrets pull`
Download and restore secrets from Bitwarden.

```bash
$ secrets pull
→ Please login to Bitwarden:
  Email: you@example.com
? Master password: [hidden]
✓ Session key exported (valid for this session)
  To persist in your shell, run:
  export BW_SESSION="..."
→ Downloading from Bitwarden...
→ Extracting secrets...
✓ Secrets pulled from Bitwarden
  Files restored: 4
```

The command will:
- Prompt for Bitwarden login if not logged in
- Prompt for master password to unlock vault
- Automatically export BW_SESSION for the command
- Download and restore all secrets to their original locations

Files are extracted to their original locations relative to `~/`.

## How It Works

### Registry File: `~/.secrets`
A simple text file listing paths to track (relative to home):

```
.ssh/id_rsa
.ssh/id_rsa.pub
.ssh/config
.env
.aws/credentials
```

You can edit this file manually or use `secrets add`/`secrets remove`.

### Storage: Bitwarden Items
- **Metadata**: "Dotfiles Secrets - Metadata" (stores chunk count)
- **Chunks**: "Dotfiles Secrets - Chunk 0", "Chunk 1", etc.
- **Type**: Secure Notes
- **Chunk size**: 8000 characters (under 10k limit)
- **✅ Works with free Bitwarden tier!**

### Workflow
1. `secrets add` → Adds path to `~/.secrets`
2. `secrets push`:
   - Creates tarball of tracked files
   - Base64 encodes the tarball
   - Splits into 8KB chunks
   - Stores each chunk as a separate Bitwarden note
   - Creates metadata note with chunk count
3. `secrets pull`:
   - Reads metadata to get chunk count
   - Downloads all chunks from Bitwarden
   - Concatenates chunks
   - Base64 decodes and extracts to home

## Common Use Cases

### SSH Keys
```bash
secrets add ~/.ssh/id_rsa
secrets add ~/.ssh/id_rsa.pub
secrets add ~/.ssh/config
secrets push
```

### Environment Variables
```bash
secrets add ~/.env
secrets add ~/.envrc  # if using direnv
secrets push
```

### Cloud Credentials
```bash
secrets add ~/.aws/credentials
secrets add ~/.config/gcloud/
secrets push
```

### Git Configuration
```bash
secrets add ~/.gitconfig.local
secrets push
```

## Security Notes

✅ **Encrypted at Rest**: Bitwarden encrypts all data with AES-256
✅ **Password Protected**: Requires master password to unlock
✅ **2FA Support**: Enable 2FA on Bitwarden account
✅ **Zero-Knowledge**: Bitwarden cannot decrypt your data
✅ **Never in Git**: Secrets never touch your dotfiles repo
✅ **Free Tier Compatible**: No premium subscription required
✅ **No Size Limit**: Automatically chunks data across multiple notes

⚠️ **Important**:
- Keep your Bitwarden master password secure
- Enable 2FA on your Bitwarden account
- Lock vault when done: `bw lock`
- Don't share your `BW_SESSION` token
- Each push creates new chunks (old ones are automatically deleted)

## Troubleshooting

### "Bitwarden CLI not installed"
```bash
brew install bitwarden-cli
```

### "No secrets found in Bitwarden"
You haven't pushed yet. Run:
```bash
secrets add ~/.ssh/id_rsa  # Add your files first
secrets push               # Then push
```

### "Failed to extract secrets"
- Check that you entered the correct master password
- Verify item exists in Bitwarden web vault
- Try logging out and back in: `bw logout && secrets push`

### Multiple Password Prompts
If you're being prompted for your password multiple times:
- The session might not be persisting - copy the export command shown
- Run it in your shell: `export BW_SESSION="..."`
- Then retry your command

### Session Expired
If you see "Session expired" errors:
```bash
# Manually unlock and export session
export BW_SESSION="$(bw unlock --raw)"

# Or just run your command again - it will prompt for password
secrets pull
```

## Advanced Usage

### Manual Registry Editing
Edit `~/.secrets` directly:
```bash
hx ~/.secrets
```

### Check Before Pushing
```bash
secrets status  # See what exists
secrets list    # See what's tracked
secrets push    # Upload
```

### Partial Restore
Currently not supported - pull restores all files. To restore selectively:
```bash
bw get attachment secrets.tar.gz --itemid <id> --raw | tar tzf -  # List contents
bw get attachment secrets.tar.gz --itemid <id> --raw | tar xzf - .ssh/id_rsa  # Extract one file
```

### Updating Secrets
Just push again - old version is replaced:
```bash
# Edit your secret file
echo "NEW_KEY=value" >> ~/.env

# Push update
secrets push
```

## Integration with Setup Script

The setup script automatically:
1. Installs Bitwarden CLI (`brew install bitwarden-cli`)
2. Installs `secrets` command to `~/.local/bin/secrets`
3. Attempts to pull secrets if Bitwarden is unlocked

If you want secrets on first setup:
```bash
# Before running setup
bw login your-email@example.com
export BW_SESSION="$(bw unlock --raw)"

# Now run setup - secrets will be pulled automatically
./setup.sh
```
