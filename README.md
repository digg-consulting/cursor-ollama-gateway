# Cursor + Ollama Secure Gateway (macOS)

Production-ready local gateway to connect Cursor to Ollama through ngrok, with Caddy enforcing auth and path restrictions.

## Architecture

`Cursor -> ngrok (public HTTPS) -> Caddy (token auth + allowlist) -> Ollama (localhost only)`

## Standard Filesystem Layout (Admin-Friendly)

This project follows common Unix admin patterns for runtime deployment:

- `/usr/local/etc/cursor-ollama-gateway`
  - `Caddyfile`
  - `ngrok.yml`
  - `.env` (secrets, mode `600`)
- `/usr/local/var/log/cursor-ollama-gateway`
  - `*.out.log`, `*.err.log`
- `/usr/local/var/run/cursor-ollama-gateway`
  - `*.pid`

The repository checkout is treated as source code and installer scripts.

## Why this is secure

- Ollama is bound to `127.0.0.1` only.
- Caddy is bound to `127.0.0.1` only.
- ngrok is the only internet-facing entrypoint.
- Caddy requires a bearer token and only allows `/v1/*`.
- Unneeded paths and methods are denied.
- ngrok inspector is disabled.
- Secrets are stored in `.env` outside the repo runtime flow.

## Prerequisites

- macOS with Homebrew
- Installed tools:
  - `ollama`
  - `caddy`
  - `ngrok`

Install example:

```bash
brew install caddy ngrok
# ollama can be installed from https://ollama.com/download
```

## ngrok Account Setup

1. Create an account at [https://dashboard.ngrok.com/signup](https://dashboard.ngrok.com/signup).
2. Verify email and sign in.
3. Copy your personal authtoken from [https://dashboard.ngrok.com/get-started/your-authtoken](https://dashboard.ngrok.com/get-started/your-authtoken).
4. Put the token in `/usr/local/etc/cursor-ollama-gateway/.env`:

```bash
NGROK_AUTHTOKEN=YOUR_NGROK_AUTHTOKEN
```

Optional but recommended for stable endpoint URLs:

5. Reserve a domain/subdomain in ngrok dashboard.
6. Set it in `ngrok.yml` under the tunnel as `domain: your-reserved-domain`.

## Quick Deploy (No Clone Required)

You can run the standalone installer directly from the repository:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/digg-consulting/cursor-ollama-gateway/main/deploy.sh)
```

It prompts for:

- `NGROK_AUTHTOKEN` (required)
- `domain` (optional reserved ngrok domain)
- `OLLAMA_HOST` (defaults to `127.0.0.1:11434`)

It then creates:

- `/usr/local/etc/cursor-ollama-gateway/.env`
- `/usr/local/etc/cursor-ollama-gateway/Caddyfile`
- `/usr/local/etc/cursor-ollama-gateway/ngrok.yml`

## Install to Standard Paths

From project root:

```bash
REPO_ROOT="$(pwd)"
cd "$REPO_ROOT"
./scripts/install-standard-layout.sh
```

Then set/rotate secrets:

```bash
ENV_FILE=/usr/local/etc/cursor-ollama-gateway/.env ./scripts/generate-secrets.sh
chmod 600 /usr/local/etc/cursor-ollama-gateway/.env
```

Validate config:

```bash
caddy validate --config /usr/local/etc/cursor-ollama-gateway/Caddyfile
```

## Startup Script Option (No plist Required)

Start:

```bash
./scripts/start-stack.sh
```

Status:

```bash
./scripts/status-stack.sh
```

Stop:

```bash
./scripts/stop-stack.sh
```

These scripts run the stack in the background, write PID files under `/usr/local/var/run/cursor-ollama-gateway`, and logs under `/usr/local/var/log/cursor-ollama-gateway`.

## Optional: Add to Login Startup Without plist

If you want script-based startup on login, add this line to your shell profile:

```bash
"$REPO_ROOT"/scripts/start-stack.sh >/dev/null 2>&1
```

For cleaner behavior, prefer a dedicated scheduler or service manager; profile startup is best for user-session usage.

## Optional launchd (Sanitized Example)

Template launch agents are provided in `launchd/` with generic labels:

- `com.cursor-ollama-gateway.ollama.plist`
- `com.cursor-ollama-gateway.caddy.plist`
- `com.cursor-ollama-gateway.ngrok.plist`

Install example:

```bash
mkdir -p "$HOME/Library/LaunchAgents"
cp "$REPO_ROOT"/launchd/com.cursor-ollama-gateway.*.plist "$HOME/Library/LaunchAgents/"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.cursor-ollama-gateway.ollama.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.cursor-ollama-gateway.caddy.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.cursor-ollama-gateway.ngrok.plist"
```

## Verify Endpoint

```bash
# should fail (missing token)
curl -i https://<your-ngrok-domain>/v1/models

# should work
source /usr/local/etc/cursor-ollama-gateway/.env
curl -sS https://<your-ngrok-domain>/v1/models \
  -H "Authorization: Bearer $OLLAMA_PROXY_TOKEN"
```

## Cursor Configuration

- Provider type: OpenAI-compatible
- Base URL: `https://<your-ngrok-domain>/v1`
- API key: value of `OLLAMA_PROXY_TOKEN`
- Model: a model available in Ollama (e.g. `llama3.1:8b`)

## Token Rotation

1. `ENV_FILE=/usr/local/etc/cursor-ollama-gateway/.env ./scripts/generate-secrets.sh`
2. Restart Caddy: `./scripts/stop-stack.sh && ./scripts/start-stack.sh`
3. Update Cursor API key.

## Incident Response (token leak)

1. Rotate token immediately.
2. Restart stack.
3. Revoke/rotate ngrok token if suspected exposed.
4. Review logs in `/usr/local/var/log/cursor-ollama-gateway`.
