# What are Cursor, Ollama, ngrok, and Caddy?

This page is for people who are new to this gateway project and want a plain-language picture of the moving parts. For setup steps, see the **[README](../README.md)** at the repository root. For errors and fixes, see **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)**.

---

## Cursor

**Cursor** is a code editor (based on VS Code) with built-in AI assistance. It can chat about your code, suggest edits, and call language models through various providers.

In this project, Cursor is the **client**: it sends HTTPS requests that look like the OpenAI API, but aimed at **your** machine’s gateway URL instead of OpenAI’s servers. You paste your gateway URL and a secret token into Cursor’s provider settings so traffic stays under your control.

---

## Ollama

**Ollama** is a tool that runs **large language models locally** on your Mac (Llama, Mistral, and many others). You pull model weights once, then ask questions or generate text without sending prompts to a cloud vendor—aside from whatever this gateway exposes.

Here, Ollama is the **engine** that actually answers model requests. It listens on **`127.0.0.1`** only so random machines on the internet cannot reach it directly; only trusted paths on your machine (and this gateway stack) talk to it.

---

## ngrok

**ngrok** creates a **temporary public HTTPS URL** that tunnels traffic into something running on your computer—in our case, to Caddy on localhost.

Without ngrok, Cursor on another network cannot reach “localhost” on your Mac. With ngrok, you get something like `https://your-subdomain.ngrok-free.app` that forwards securely to your local gateway. You need an ngrok account and authtoken; optional reserved domains keep the URL stable across restarts.

---

## Caddy (and the `Caddyfile`)

**Caddy** is a web server and **reverse proxy**. In this setup it listens on **localhost** over **HTTP**, enforces your rules (paths, Bearer token), and forwards allowed traffic to Ollama. **HTTPS** between the public internet and the ngrok agent is handled by **ngrok**; only your machine talks to Caddy on the loopback interface.

In this repo you configure Caddy with a **`Caddyfile`**—that’s just Caddy’s config format (like nginx has config files). Our template **`Caddyfile`** tells Caddy to require a **Bearer token** and only expose the paths we want (for example OpenAI-compatible **`/v1/*`** routes). That way even though ngrok exposes a public URL, strangers cannot freely call your models without your secret.

---

## How they fit together

Rough flow:

```text
Cursor  →  ngrok (public URL)  →  Caddy (auth + routing)  →  Ollama (localhost)
```

- **Cursor** uses your ngrok URL as the API base and sends the proxy token as authorization.
- **ngrok** carries that traffic to **Caddy** on your machine.
- **Caddy** checks the token and forwards allowed requests to **Ollama**.

Secrets such as **`NGROK_AUTHTOKEN`** and **`OLLAMA_PROXY_TOKEN`** live in **`.env`** next to **`Caddyfile`** and **`ngrok.yml`** under your config directory—see the **[README](../README.md)** paths table.
