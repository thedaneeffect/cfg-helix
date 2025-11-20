# Secrets Storage Worker

A Cloudflare Worker that provides secure storage for encrypted secrets with named group support.

## Features

- **Named Groups**: Organize secrets into groups (`default`, `github`, `work`, etc.)
- **Bearer Token Auth**: Simple authentication via `Authorization` header
- **KV Storage**: Uses Cloudflare KV for globally distributed storage
- **Simple API**: GET, POST, DELETE operations on secret groups

## API

### Authentication
All requests require a Bearer token:
```bash
Authorization: Bearer YOUR_SECRET_PASSPHRASE
```

### Endpoints

#### Store Secrets
```bash
POST /secrets/{group}
# Body: Binary data (usually base64-encoded tarball)

# Example
curl -X POST -H "Authorization: Bearer $PASSPHRASE" \
  --data-binary @secrets.tar.gz \
  https://your-worker.workers.dev/secrets/github
```

#### Retrieve Secrets
```bash
GET /secrets/{group}

# Example
curl -H "Authorization: Bearer $PASSPHRASE" \
  https://your-worker.workers.dev/secrets/github \
  > secrets.tar.gz
```

#### Delete Secrets
```bash
DELETE /secrets/{group}

# Example
curl -X DELETE -H "Authorization: Bearer $PASSPHRASE" \
  https://your-worker.workers.dev/secrets/github
```

#### List Groups
```bash
GET /list

# Example
curl -H "Authorization: Bearer $PASSPHRASE" \
  https://your-worker.workers.dev/list
# Returns: ["default", "github", "work"]
```

## Setup

### 1. Install Wrangler CLI
```bash
npm install -g wrangler
# or
bun install -g wrangler
```

### 2. Login to Cloudflare
```bash
wrangler login
```

### 3. Create KV Namespace
```bash
cd worker
wrangler kv:namespace create SECRETS
```

Copy the namespace ID from the output and update `wrangler.toml`:
```toml
[[kv_namespaces]]
binding = "SECRETS"
id = "abc123..." # Your actual ID here
```

### 4. Set Secret Passphrase
```bash
wrangler secret put SECRET_PASSPHRASE
# Enter your passphrase when prompted
```

### 5. Deploy
```bash
wrangler deploy
```

You'll get a URL like: `https://secrets-storage.your-subdomain.workers.dev`

### 6. Configure Your Secrets CLI
```bash
export SECRETS_URL="https://secrets-storage.your-subdomain.workers.dev"
export SECRETS_PASSPHRASE="your-passphrase"
```

## Deploy from GitHub

Cloudflare can deploy directly from GitHub:

1. Go to Cloudflare Dashboard → Workers & Pages
2. Create Application → Connect to Git
3. Select this repository
4. Set build command to: `cd worker && wrangler deploy`
5. Configure KV namespace and secrets in dashboard

## Storage Limits

- **Free Tier**: 1GB storage, 100k reads/day, 1k writes/day
- **Value Size**: 25MB max per group
- **Groups**: Unlimited

## Security Notes

- ✅ All data is encrypted in transit (HTTPS)
- ✅ Bearer token authentication prevents unauthorized access
- ✅ Store your passphrase securely (password manager, environment variable)
- ✅ Consider encrypting tarballs before uploading (defense in depth)
- ⚠️ Cloudflare can technically access your data (use client-side encryption if concerned)

## Integration with Secrets CLI

The `secrets` CLI script supports this worker as a backend. Set these environment variables:

```bash
export SECRETS_BACKEND="worker"  # or "bitwarden" for old backend
export SECRETS_URL="https://your-worker.workers.dev"
export SECRETS_PASSPHRASE="your-passphrase"
```

Then use as normal:
```bash
secrets add ~/.ssh/id_rsa
secrets push github
secrets pull github
```
