# Cursor + Ollama Secure Gateway (macOS)

Production-ready local gateway: **Caddy** enforces bearer-token auth and path rules in front of **Ollama**. **Terminal tools** (`curl`, scripts) can use **`http://127.0.0.1:8443`** directly. **Cursor’s custom OpenAI-compatible provider does not:** Cursor validates base URLs server-side and returns **“Access to private networks is forbidden”** for **`localhost` / `127.0.0.1` / RFC1918** (SSRF protection). So **Cursor still needs a public HTTPS URL** into your gateway — typically **ngrok**, **[Cloudflare Quick Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/run-tunnel/trycloudflare/)**, Tailscale Funnel, etc. Ngrok remains optional only for non-Cursor clients that truly hit loopback.

## Documentation

Extra guides live under **[docs/](docs/)**. Highlights:

- **[Components](docs/COMPONENTS.md)** — plain-language intro to Cursor, Ollama, ngrok, Caddy (read first if you’re new)
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** — model names, auth, ngrok, brew conflicts
- **[Contributing](docs/CONTRIBUTING.md)**
- **[Security](docs/SECURITY.md)** — vulnerability reporting

## Architecture

**Local-only tools:** `curl/scripts -> http://127.0.0.1:8443 -> Caddy -> Ollama`

**Cursor IDE (custom OpenAI-compatible URL):** requests are checked against Cursor’s servers, which **block private IPs** — use a **public HTTPS tunnel** into Caddy:

`Cursor -> https://your-tunnel-host/… -> (tunnel agent on your Mac) -> Caddy -> Ollama`

Ngrok is one tunnel option; Cloudflare **`cloudflared tunnel --url http://127.0.0.1:8443`**, Tailscale Funnel, etc. work conceptually the same (must terminate TLS at the edge with a **public** hostname).

## Where files live (default: per-user, XDG-style)

By default everything stays under your home directory so each user has an isolated setup (no sudo, no shared `/usr/local/etc`):

| Purpose | Path |
|--------|------|
| Config (`Caddyfile`, `ngrok.yml`, `.env`) | `${XDG_CONFIG_HOME:-$HOME/.config}/cursor-ollama-gateway/` |
| PID files | `${XDG_STATE_HOME:-$HOME/.local/state}/cursor-ollama-gateway/run/` |
| Logs (`start-stack.sh` **and** optional launchd) | `${XDG_DATA_HOME:-$HOME/.local/share}/cursor-ollama-gateway/logs/` |
| Operator scripts (`paths.sh`, stack scripts, `generate-secrets`) | `${XDG_DATA_HOME:-$HOME/.local/share}/cursor-ollama-gateway/scripts/` |
| PATH wrappers (quick deploy / `install-standard-layout`) | `~/.local/bin/` → **`cursor-ollama-gateway`** (`start` \| `stop` \| `status` \| **`url`** \| `restart` \| **`logs-clear`**), shortcuts **`cursor-ollama-start`** / **`cursor-ollama-stop`** / **`cursor-ollama-status`**, plus **`cursor-ollama-generate-secrets`** |

Optional overrides:

- `CONFIG_DIR`, `RUN_DIR`, `LOG_DIR` — force explicit paths.
- `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, `XDG_DATA_HOME` — standard XDG relocation.

**Optional system-wide layout** (classic Unix, requires `sudo` for install/deploy):

```bash
export CURSOR_OLLAMA_GATEWAY_SYSTEM=1
```

Then defaults become `/usr/local/etc/cursor-ollama-gateway`, `/usr/local/var/run/...`, `/usr/local/var/log/...`.

Shared resolution logic lives in `scripts/lib/paths.sh`.

The repository checkout is source templates + scripts only; runtime config is not tied to the clone location.

### Logging (single directory, same filenames)

We intentionally use **one `LOG_DIR`** for both interactive stack scripts and optional **launchd** agents:

- **Why**: easier tailing and incident review—you do not need to remember different paths depending on startup method.
- **How**: `scripts/start-stack.sh` resolves `LOG_DIR` via `scripts/lib/paths.sh`. The `launchd/*.plist` jobs run the same path formula in an inline `zsh -lc` string (`CFG` / `LOGROOT` mirror `CONFIG_DIR` / `LOG_DIR`), because launchd cannot source `paths.sh`.
- **Filenames**: `ollama.out.log`, `caddy-ollama.out.log`, `ngrok-ollama.out.log` (same as the stack script). Stderr is merged into the same file as stdout (`2>&1`).
- **Do not double-run**: pick either launchd **or** `start-stack.sh` for a given component; two supervisors fighting the same ports will misbehave.

For **`CURSOR_OLLAMA_GATEWAY_SYSTEM=1`**, logs default to `/usr/local/var/log/cursor-ollama-gateway/`; operator scripts install under `/usr/local/libexec/cursor-ollama-gateway/scripts/` and wrappers under `/usr/local/bin/`. The bundled launchd templates target the user XDG layout—customize plists if you run system-wide.

## Why this is secure

- Ollama is bound to `127.0.0.1` only.
- Caddy listens on **`127.0.0.1` only** (HTTP to the tunnel agent; HTTPS to the world is terminated at **ngrok**).
- ngrok is the only internet-facing entrypoint.
- Caddy requires a bearer token and only allows `/v1/*`.
- Unneeded paths and methods are denied.
- ngrok inspector is disabled.
- Secrets live in `.env` under your config directory (default `~/.config/...`), not in the repo.

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
4. Put the token in your gateway `.env` (after install or deploy), for example:

```bash
# Default path:
"${XDG_CONFIG_HOME:-$HOME/.config}/cursor-ollama-gateway/.env"
```

```bash
NGROK_AUTHTOKEN=YOUR_NGROK_AUTHTOKEN
```

The **`ngrok.yml`** shipped with this project does **not** embed the token (ngrok reads **`NGROK_AUTHTOKEN`** from the environment after **`start-stack.sh`** sources **`.env`**). Never put a literal **`${NGROK_AUTHTOKEN}`** string in **`ngrok.yml`** — ngrok does not expand shell syntax and will fail with **ERR_NGROK_105**.

**Free `ngrok-free.dev` URLs:** programmatic clients often need an extra request header (**`ngrok-skip-browser-warning`**) or you may see **`400`** / network errors from tools that can’t send it (see **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**).

Optional but recommended for stable endpoint URLs:

5. Reserve a domain/subdomain in ngrok dashboard.
6. Set it in `ngrok.yml` under the tunnel as `domain: your-reserved-domain`.

## Ngrok + Cursor (minimal checklist)

This is the shortest path to a **working ngrok setup** with this gateway:

1. **Templates** — Your config dir needs **`Caddyfile`**, **`ngrok.yml`**, and **`.env`** matching this repo (deploy script, **`install-standard-layout.sh`**, or copy by hand).
2. **`.env`** — Set **`NGROK_AUTHTOKEN`** (real token string) and **`OLLAMA_PROXY_TOKEN`** (long secret used as Cursor’s API key). Do **not** add **`authtoken:`** to **`ngrok.yml`**.
3. **Start** — `cursor-ollama-start` (or **`cursor-ollama-gateway start`**).
4. **Public URL** — After ngrok connects, the start output prints **`Ngrok public URL`** and **`Cursor OpenAI Base URL`**. Any time later: **`cursor-ollama-gateway url`**.
5. **Cursor** — OpenAI-compatible provider: **Base URL** = that value (ends with **`/v1`**), **API key** = **`OLLAMA_PROXY_TOKEN`**, **model** = an Ollama id from **`ollama list`** (e.g. **`llama3.1:8b`**).

**Free `*.ngrok-free.*` URLs:** Ngrok may apply rules that expect **`ngrok-skip-browser-warning`** or a non-default **`User-Agent`**; Cursor usually cannot send those. If **`curl`** to **`127.0.0.1:8443`** works but Cursor fails through ngrok with **`400`** or empty responses, move to **paid ngrok** or another tunnel — see **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**.

## Quick Deploy (No Clone Required)

Run the standalone installer from the repository:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/digg-consulting/cursor-ollama-gateway/main/deploy.sh)
```

It prompts for:

- `NGROK_AUTHTOKEN` (required)
- `domain` (optional reserved ngrok domain)
- `OLLAMA_HOST` (defaults to `127.0.0.1:11434`)

**Default output paths** (same as table above): config under `~/.config/cursor-ollama-gateway/`, plus run/log dirs under `~/.local/...`.

It also **downloads** the same operator scripts as this repo into `~/.local/share/cursor-ollama-gateway/scripts/` (override with `SCRIPT_INSTALL`), installs **PATH wrappers** into `~/.local/bin/`, and **prepends `~/.local/bin` to your PATH** in `~/.zprofile`, `~/.zshrc`, or `~/.bash_profile` when needed (idempotent snippet). Open a new terminal afterward.

**Operator scripts are not auto-updated:** Quick deploy copies those scripts from GitHub **`main` only while `deploy.sh` runs**. When **`main`** later adds fixes or features, your existing install under **`~/.local/share/.../scripts/`** stays on the old revision until you refresh it. To pull the latest scripts **without** touching **`~/.config/cursor-ollama-gateway/`** (your **`.env`**, **`ngrok.yml`**, **`Caddyfile`**), use a checkout of this repo at the revision you want and run **`bash scripts/install-to-home.sh`**—see **[Install from clone](#install-from-clone)**. Re-running **`deploy.sh`** also re-downloads scripts but repeats the full interactive flow (back up **`.env`** first if you customized it).

Commands available globally:

- **`cursor-ollama-gateway <start|stop|status|restart|logs-clear>`** — single entrypoint (like an init script); **`start`** refuses to run while **`brew services`** has **ollama** marked started unless **`CURSOR_OLLAMA_GATEWAY_ALLOW_BREW_OLLAMA=1`** (stop **`brew services stop ollama`** first so this stack owns **`ollama serve`**). **`logs-clear`** deletes **`*.log`** under **`LOG_DIR`** (see paths table).
- **`cursor-ollama-start`**, **`cursor-ollama-stop`**, **`cursor-ollama-status`** — thin wrappers that call **`cursor-ollama-gateway`** with the matching subcommand.
- **`cursor-ollama-generate-secrets`**

Use a different GitHub raw base (fork / branch) via:

```bash
export CURSOR_OLLAMA_GATEWAY_REPO_RAW="https://raw.githubusercontent.com/you/cursor-ollama-gateway/my-branch"
bash <(curl -fsSL "${CURSOR_OLLAMA_GATEWAY_REPO_RAW}/deploy.sh")
```

For system-wide install instead:

```bash
CURSOR_OLLAMA_GATEWAY_SYSTEM=1 bash <(curl -fsSL https://raw.githubusercontent.com/digg-consulting/cursor-ollama-gateway/main/deploy.sh)
```

## Install from clone

From the repository root:

```bash
REPO_ROOT="$(pwd)"
cd "$REPO_ROOT"
bash scripts/install-standard-layout.sh
```

To copy **only** the operator scripts and PATH wrappers (no config redeploy), after you already have config under `~/.config/cursor-ollama-gateway/`:

```bash
bash scripts/install-to-home.sh
```

System-wide:

```bash
CURSOR_OLLAMA_GATEWAY_SYSTEM=1 bash scripts/install-standard-layout.sh
```

Then generate or rotate the proxy token:

```bash
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/cursor-ollama-gateway"
ENV_FILE="$CFG/.env" bash scripts/generate-secrets.sh
chmod 600 "$CFG/.env"
```

Validate config:

```bash
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/cursor-ollama-gateway"
caddy validate --config "$CFG/Caddyfile"
```

If **`zsh: command not found: caddy`**, Homebrew’s bin dir is probably not on **`PATH`** in that terminal (common in Cursor’s integrated terminal until **`brew`** is wired into **`~/.zprofile`**). Either load Homebrew into the shell (`eval "$(/opt/homebrew/bin/brew shellenv)"` on Apple Silicon, or **`eval "$(/usr/local/bin/brew shellenv)"`** on Intel), open a new terminal after fixing **`~/.zprofile`**, or call **`caddy`** by full path — **`/opt/homebrew/bin/caddy`** or **`/usr/local/bin/caddy`** — before **`validate`**.

Scripts are intentionally **not** marked executable in git; invoke with `bash scripts/...`, or use **quick deploy** / **`install-standard-layout`** so copy-on-disk wrappers (`cursor-ollama-*`) exist under `~/.local/bin`.

## Startup scripts (no plist required)

Preferred control path (runs **`brew services`** guard on **`start`**):

```bash
bash scripts/cursor-ollama-gateway.sh start   # stop | status | restart | logs-clear
# or, after quick deploy / install-standard-layout:
cursor-ollama-gateway start
cursor-ollama-start    # same as: cursor-ollama-gateway start
```

Direct stack scripts (same processes; **`start`** skips the brew guard):

```bash
bash scripts/start-stack.sh
bash scripts/status-stack.sh
bash scripts/stop-stack.sh
```

PID files and process logs use `RUN_DIR` / `LOG_DIR` from `scripts/lib/paths.sh`.

To wipe rotated/stack logs under **`LOG_DIR`** (does not stop services):

```bash
cursor-ollama-gateway logs-clear
```

## Optional: login startup without plist

Add to your shell profile (adjust if you keep the repo elsewhere):

```bash
bash /path/to/cursor-ollama-gateway/scripts/cursor-ollama-gateway.sh start >/dev/null 2>&1
```

## Optional launchd

Templates in `launchd/` resolve config via `${XDG_CONFIG_HOME:-$HOME/.config}/cursor-ollama-gateway` and write logs under **`${XDG_DATA_HOME:-$HOME/.local/share}/cursor-ollama-gateway/logs/`**, using the **same filenames** as `start-stack.sh` (see [Logging](#logging-single-directory-same-filenames)).

Install:

```bash
REPO_ROOT="$(pwd)"
mkdir -p "$HOME/Library/LaunchAgents"
cp "$REPO_ROOT"/launchd/com.cursor-ollama-gateway.*.plist "$HOME/Library/LaunchAgents/"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.cursor-ollama-gateway.ollama.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.cursor-ollama-gateway.caddy.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.cursor-ollama-gateway.ngrok.plist"
```

## Verify endpoint

```bash
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/cursor-ollama-gateway"

# should fail (missing token)
curl -i https://<your-ngrok-domain>/v1/models

# should work
source "$CFG/.env"
curl -sS https://<your-ngrok-domain>/v1/models \
  -H "Authorization: Bearer $OLLAMA_PROXY_TOKEN"
```

## Cursor configuration

In Cursor, add an **OpenAI-compatible** (or **OpenAI API**) provider that talks to your gateway—not to OpenAI’s servers.

- **Provider type:** OpenAI-compatible
- **Base URL:** **`https://<your-public-tunnel-host>/v1`** (ngrok, **`*.trycloudflare.com`**, etc.). **Do not use `http://127.0.0.1` here** — Cursor will reject it (**private network forbidden**). Use **`http://127.0.0.1:8443`** only from your own terminal (`curl`, tests). If your tunnel strips **`POST`** bodies (seen with some free ngrok paths), try **`cloudflared`**, ngrok paid, or another tunnel — see **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**.
- **API key:** paste the **`OLLAMA_PROXY_TOKEN`** value from your gateway `.env`  
  (typically `~/.config/cursor-ollama-gateway/.env`, or under `$XDG_CONFIG_HOME` if set).  
  Caddy checks this as the `Bearer` token; it is **only** your local gateway secret.

**Do not** put **`NGROK_AUTHTOKEN`** or a real **OpenAI API key** in Cursor for this setup. Ngrok’s token stays in `.env` for the ngrok process only.

- **Model:** an Ollama model id (e.g. `llama3.1:8b`)

## Token rotation

1. `cursor-ollama-generate-secrets`  
   (or: `ENV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/cursor-ollama-gateway/.env" bash scripts/generate-secrets.sh`)
2. `cursor-ollama-gateway restart` (or `cursor-ollama-stop && cursor-ollama-start`, or `bash scripts/cursor-ollama-gateway.sh restart`)
3. Update Cursor API key.

## Incident response (token leak)

1. Rotate tokens immediately.
2. Restart stack.
3. Revoke/rotate ngrok token if suspected exposed.
4. Review logs under `${XDG_DATA_HOME:-$HOME/.local/share}/cursor-ollama-gateway/logs/` (or `LOG_DIR` if overridden).
