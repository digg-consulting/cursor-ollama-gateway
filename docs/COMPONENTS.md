# What are Cursor, Ollama, ngrok, and Caddy?

This page is for people who are new to this gateway project and want a plain-language picture of the moving parts. For setup steps, see the **[README](../README.md)** at the repository root. For errors and fixes, see **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)**.

---

## Cursor

**Cursor** is a code editor (based on VS Code) with built-in AI assistance. It can chat about your code, suggest edits, and call language models through various providers.

In this project, Cursor is configured like an OpenAI-compatible client. **Important:** Cursor does **not** allow **`localhost` / `127.0.0.1` / private IPs** as the override base URL — its backend enforces **SSRF protection**, so you’ll see errors like **“Access to private networks is forbidden.”** Even on the **same Mac**, Cursor needs a **public HTTPS hostname** that tunnels into **Caddy** (ngrok, Cloudflare Quick Tunnel, Tailscale Funnel, …). Your **`OLLAMA_PROXY_TOKEN`** goes in the API key field; only **`curl`** and similar tools should hit **`http://127.0.0.1:8443`** directly.

---

## Ollama

**Ollama** is a tool that runs **large language models locally** on your Mac (Llama, Mistral, and many others). You pull model weights once, then ask questions or generate text without sending prompts to a cloud vendor—aside from whatever this gateway exposes.

Here, Ollama is the **engine** that actually answers model requests. It listens on **`127.0.0.1`** only so random machines on the internet cannot reach it directly; only trusted paths on your machine (and this gateway stack) talk to it.

---

## ngrok

**ngrok** creates a **temporary public HTTPS URL** that tunnels traffic into something running on your computer—in our case, to Caddy on localhost.

**A tunnel (ngrok, cloudflared, …) is required for Cursor’s UI**, because Cursor won’t call loopback. **Ngrok** is optional only if you never use Cursor against this gateway—in that case **`curl`** to **`127.0.0.1:8443`** is enough. For ngrok itself you need an account and **`NGROK_AUTHTOKEN`** in **`.env`**; optional reserved domains stabilize URLs across restarts.

---

## Caddy (and the `Caddyfile`)

**Caddy** is a web server and **reverse proxy**. In this setup it listens on **localhost** over **HTTP**, enforces your rules (paths, Bearer token), and forwards allowed traffic to Ollama. **HTTPS** at the internet edge is handled by **ngrok** only when you use it; **Caddy on loopback is plain HTTP**, which is fine because nothing off-machine touches it unless you expose it via ngrok or similar.

In this repo you configure Caddy with a **`Caddyfile`**—that’s just Caddy’s config format (like nginx has config files). Our template **`Caddyfile`** tells Caddy to require a **Bearer token** and only expose the paths we want (for example OpenAI-compatible **`/v1/*`** routes). That way, if you **do** expose the gateway publicly (ngrok, etc.), strangers still cannot call your models without your secret.

---

## How they fit together

**Terminal / scripts on your Mac:**

```text
curl  →  http://127.0.0.1:8443  →  Caddy  →  Ollama
```

**Cursor IDE** (cannot use loopback base URL):

```text
Cursor  →  https://public-tunnel-host/…  →  tunnel agent  →  Caddy  →  Ollama
```

- **Cursor:** **`https://…/v1`** from your tunnel + **`OLLAMA_PROXY_TOKEN`** as API key.
- **Caddy:** validates Bearer token and proxies **`/v1/*`** to **Ollama**.

Secrets such as **`NGROK_AUTHTOKEN`** and **`OLLAMA_PROXY_TOKEN`** live in **`.env`** next to **`Caddyfile`** and **`ngrok.yml`** under your config directory—see the **[README](../README.md)** paths table.
