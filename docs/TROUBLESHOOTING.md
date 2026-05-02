# Troubleshooting

## Cursor: “AI Model Not Found” / “Model name is not valid”

Cursor checks the model id against what your **OpenAI-compatible** endpoint reports (typically **`GET /v1/models`**). The string you pick in the UI must match an **`id`** Ollama exposes through that API **exactly** (including tag).

### 1. Install the model in Ollama

Pull the tag you want locally:

```bash
ollama pull qwen3:14b
```

Check what you actually have:

```bash
ollama list
```

If `qwen3:14b` never finishes downloading or errors out, Cursor cannot use it. Pick a tag that exists on [ollama.com/library](https://ollama.com/library) (for example `qwen3:8b`, `qwen3:14b`, `qwen2.5:14b`) and pull again.

### 2. Confirm the gateway sees the same models

Load your `.env` and call **`/v1/models`** through the **same base URL** you configured in Cursor (ngrok URL):

```bash
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/cursor-ollama-gateway"
source "$CFG/.env"
curl -sS "https://<your-ngrok-domain>/v1/models" \
  -H "Authorization: Bearer $OLLAMA_PROXY_TOKEN" | jq '.data[].id'
```

You should see a line **`qwen3:14b`** (or whatever you typed). If it is missing:

- Ollama may not be running or may be a **different** daemon/user than the one you pulled into.
- Restart the stack after pulling: `cursor-ollama-stop` then `cursor-ollama-start` (or equivalent).

### 3. Match Cursor’s model field to the API id

In Cursor’s model dropdown / settings, use the **exact** id from `/v1/models` (e.g. `qwen3:14b`, not `Qwen3 14B` or a shortened name).

### 4. Typos and naming

Library names change over time. If `qwen3:14b` is invalid for **your** install, compare with:

- Tags listed for [qwen3](https://ollama.com/library/qwen3/tags) or [qwen2.5](https://ollama.com/library/qwen2.5/tags).
- Output of `ollama list` (that list is authoritative for **your** machine).

---

## HTTP 401 “missing authorization” or 403 “forbidden”

- **401**: Cursor did not send `Authorization: Bearer ...`. Set the provider **API key** to **`OLLAMA_PROXY_TOKEN`** from your gateway `.env` (see main README).
- **403**: Bearer token does not match what Caddy expects. Regenerate with `cursor-ollama-generate-secrets`, restart the stack, update Cursor’s API key.

---

## Cursor: **“Access to private networks is forbidden”** (localhost / **127.0.0.1** base URL)

Cursor does **not** let you use **`http://127.0.0.1`** or **`http://localhost`** as the OpenAI-compatible **override base URL**. Requests are validated in a way that **blocks RFC1918 / loopback** targets (**SSRF protection**).

Use a **public HTTPS URL** from your tunnel (**ngrok**, **`cloudflared tunnel --url http://127.0.0.1:8443`**, Tailscale Funnel, …) ending in **`/v1`**, plus **`OLLAMA_PROXY_TOKEN`** as the API key. Keep testing the gateway with **`curl http://127.0.0.1:8443`** locally.

---

## Connection errors / ngrok offline

### **`cursor-ollama-gateway url`** shows another machine’s hostname

The **`url`** command scans **`ngrok-ollama.{out,err}.log`**. Older releases read the **whole** file; the **last** `https://…` anywhere in that history could be a **stale** tunnel from another laptop or an old **`ERR_NGROK_334`** line — not what ngrok is using **now**.

Current scripts only scan the **last ~400 lines** per log (override with **`PRINT_NGROK_LOG_TAIL`**). If it still looks wrong: **`cursor-ollama-gateway logs-clear`**, **`restart`**, then **`url`** again. Confirm **`NGROK_AUTHTOKEN`** and any **`domain:`** in **`ngrok.yml`** on **this** Mac match ngrok account 1 only.

---

### **`ERR_NGROK_334`** — endpoint already online

Ngrok says the public URL is **already bound** by another agent (another Terminal tab, older **`cursor-ollama-start`**, or a stray **`ngrok http`**).

1. **`cursor-ollama-gateway stop`** (or **`cursor-ollama-stop`**).
2. **`pgrep -fl ngrok`** — quit extra ngrok processes you do not want.
3. **`cursor-ollama-gateway start`** again.

**`cursor-ollama-gateway url`** reads **`ngrok-ollama.out.log`** and **`ngrok-ollama.err.log`**; if you still see **`334`**, the hostname in the error line is usually still the URL Cursor should use once only **one** tunnel owns it.

---

- Confirm ngrok is running and the URL in Cursor matches the current tunnel (URLs change unless you use a **reserved domain**).
- From another machine or browser, try `GET https://<ngrok-domain>/v1/models` with the Bearer header (see above).

### **`curl` returns `400`** on **`*.ngrok-free.dev`** / **`*.ngrok-free.app`**

Ngrok’s **free** endpoints often intercept requests that don’t identify as your API client. Retry with:

```bash
curl -sS -i "https://<your-ngrok-host>/v1/models" \
  -H "Authorization: Bearer $OLLAMA_PROXY_TOKEN" \
  -H "ngrok-skip-browser-warning: 1"
```

If that returns **200** but plain **`curl` without that header returns 400**, **Cursor must send the same header**—many OpenAI-compatible clients don’t. Options: use **ngrok paid** (no warning behavior), put a tiny **local reverse proxy** in front that adds **`ngrok-skip-browser-warning`**, or check whether Cursor’s provider settings allow **custom HTTP headers**. Ngrok also documents using a **non-default User-Agent** as an alternative bypass on some plans—your **`curl -v`** response body usually states which rule triggered.

### **Still `400` after `ngrok-skip-browser-warning`**

Split **where** it fails:

**A — Bypass ngrok (proves Caddy + token + Ollama)**

```bash
source "${XDG_CONFIG_HOME:-$HOME/.config}/cursor-ollama-gateway/.env"
curl -sS -i --http1.1 "http://127.0.0.1:8443/v1/models" \
  -H "Authorization: Bearer $OLLAMA_PROXY_TOKEN"
```

- **`401` / `403`** → wrong/missing **`OLLAMA_PROXY_TOKEN`** vs **`Caddyfile`** (not ngrok).
- **`200`** → stack is fine locally; problem is **only** on the public URL.

**B — Same URL ngrok uses, with headers ngrok expects**

```bash
curl -sS -i --http1.1 "https://YOUR-SUBDOMAIN.ngrok-free.dev/v1/models" \
  -H "Authorization: Bearer $OLLAMA_PROXY_TOKEN" \
  -H "ngrok-skip-browser-warning: 1" \
  -H "User-Agent: Mozilla/5.0"
```

Read the **response body**: ngrok often returns HTML or JSON with an **`ERR_NGROK_*`** code explaining the **`400`**.

**C — Tunnel **`host_header`**

Current **[`ngrok.yml`](../ngrok.yml)** sets **`host_header: rewrite`** so the **`Host`** header matches **`127.0.0.1:8443`**. Merge that into **`~/.config/cursor-ollama-gateway/ngrok.yml`** and **`cursor-ollama-gateway restart`**.

---

## Caddy or ngrok exits immediately (WARNING in `start-stack.sh`)

Check the files it names (**`caddy-ollama.err.log`**, **`ngrok-ollama.err.log`**).

Common causes:

1. **`command not found`** for **`caddy`** or **`ngrok`** — often a **PATH** mismatch when the stack used a different login shell. Current **`start-stack.sh`** launches services with **`bash -c`** so they inherit the same environment as the script; refresh **`scripts/start-stack.sh`** via **`install-to-home.sh`** / **`deploy.sh`**.

2. **Ngrok → Caddy TLS verification** — older templates pointed **`ngrok.yml`** at **`https://127.0.0.1:8443`** while **`Caddyfile`** used **`tls internal`** (self-signed). The ngrok agent often refuses that backend certificate and exits. **Current templates use plain HTTP on loopback** (**no `tls internal`** in **`Caddyfile`**, **`addr: http://127.0.0.1:8443`** in **`ngrok.yml`**). Copy those changes into **`~/.config/cursor-ollama-gateway/`** (or merge by hand), then **`cursor-ollama-gateway restart`**.

3. Invalid **`Caddyfile`** / **`ngrok.yml`** — run **`caddy validate --config "$CFG/Caddyfile"`** with **`CFG`** set to your config directory.

4. **`Error: adapting config ... unrecognized servers option 'read_timeout'`** — your **`caddy`** build is older than the directive set we used briefly in templates. Copy the current **[`Caddyfile`](../Caddyfile)** from this repo (global block should only include **`admin`** / **`auto_https`**), or **`brew upgrade caddy`**.

5. **`bash: line 0: exec: : not found`** in **`caddy-ollama.err.log`** — **`PATH`** exported from **`~/.config/cursor-ollama-gateway/.env`** overwrote or emptied **`PATH`**, so **`command -v caddy`** returned nothing inside the stack subprocess. Current **`start-stack.sh`** prepends **`/opt/homebrew/bin`** and **`/usr/local/bin`** after sourcing **`.env`**; refresh scripts via **`install-to-home.sh`**. Prefer **not** setting **`PATH`** in **`.env`** unless you mean to.

6. **`ERR_NGROK_105`** / **`Your authtoken: ${NGROK_AUTHTOKEN}`** — **`ngrok.yml`** contained **`authtoken: ${NGROK_AUTHTOKEN}`**. Ngrok does **not** expand shell syntax. Put your real token only in **`NGROK_AUTHTOKEN=…`** in **`~/.config/cursor-ollama-gateway/.env`**, delete any **`authtoken:`** line from **`ngrok.yml`** (or copy **[`ngrok.yml`](../ngrok.yml)** from this repo), then **`cursor-ollama-gateway restart`**. Current **`start-stack.sh`** refuses **`start`** if **`ngrok.yml`** still contains that placeholder **`authtoken:`** line.

---

## Clearing old stack logs

```bash
cursor-ollama-gateway logs-clear
```

Removes **`*.log`** (and **`*.log.*`**) directly under **`LOG_DIR`** (default **`~/.local/share/cursor-ollama-gateway/logs/`**). Stop or restart the stack first if you want a perfectly quiet startup log after clearing.

---

## **`Client sent an HTTP request to an HTTPS server`** (curl to **`http://127.0.0.1:8443`**)

**Caddy enables automatic HTTPS for bare loopback addresses** like **`127.0.0.1:8443`** (self-signed), even when there is **no** **`tls internal`** line — so **`curl http://…`** speaks plain HTTP while Caddy expects TLS.

**Fix:** use an explicit **`http://`** site address in **`Caddyfile`**:

```caddyfile
http://127.0.0.1:8443 {
```

Match **[`Caddyfile`](../Caddyfile)** from this repo, then **`caddy validate`**, **`cursor-ollama-gateway restart`**.

If you previously used **`tls internal`**, remove it. **`curl https://127.0.0.1:8443`** against local TLS needs **`curl -k`** unless you trust Caddy’s CA — with **`http://`** in the site address you should use **`curl http://`** only.

---

## **`HTTP/1.0 400 Bad Request`** from **`http://127.0.0.1:8443/v1/models`**

Older **`Caddyfile`** templates put **`request_body { max_size … }`** on the whole site. That makes **`reverse_proxy`** interact badly with **GET** requests (no body), often yielding **`400 Bad Request`**. Newer templates removed **site-wide** **`request_body`**; do not reintroduce **`request_body`** on **`/v1/*`** with **`reverse_proxy`** — see **chat completions empty body** below.

---

## **`/v1/chat/completions`** returns **`200`** with **`Content-Length: 0`** (Cursor: “Empty provider response”)

Having **`request_body { max_size … }`** (even with **`@post`**) in the same **`handle`** as **`reverse_proxy`** to Ollama can **drop the POST body** so the upstream never runs a real completion; clients see an empty successful response.

Current **[`Caddyfile`](../Caddyfile)** omits **`request_body`** on the proxy route. Sync **`~/.config/cursor-ollama-gateway/Caddyfile`**, **`caddy validate`**, **`cursor-ollama-gateway restart`**, then:

```bash
curl -sS -i "http://127.0.0.1:8443/v1/chat/completions" \
  -H "Authorization: Bearer $OLLAMA_PROXY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.1:8b","messages":[{"role":"user","content":"hi"}],"stream":false}'
```

You should see a **non-zero** JSON body with **`choices`**.

### **`POST /v1/chat/completions`** works on **`127.0.0.1:8443`** but **`Content-Length: 0`** through **`https://….ngrok-free.dev`**

Typical pattern: **`curl`** shows **`HTTP/2 200`** and **`server: Caddy`** but **no JSON body**. **`GET /v1/models`** through ngrok can still look fine — some clients only break on **`POST`**.

**Try forcing HTTP/1.1 to the public URL:**

```bash
curl --http1.1 -sS -i "$BASE/v1/chat/completions" \
  -H "Authorization: Bearer $OLLAMA_PROXY_TOKEN" \
  -H "Content-Type: application/json" \
  -H "ngrok-skip-browser-warning: 1" \
  -d '{"model":"llama3.1:8b","messages":[{"role":"user","content":"hi"}],"stream":false}'
```

If **`--http1.1`** restores a JSON body, the failure is on the **HTTP/2 path between your client and ngrok’s edge** (Cursor may still use HTTP/2 and hit the same bug).

**Practical mitigations:**

1. **`brew upgrade ngrok`** (agent + edge behavior changes occasionally fix tunnel quirks).
2. **Paid ngrok** (removes free-tier interstitial / header friction Cursor cannot easily send) or **Cloudflare Tunnel** / **Tailscale Funnel** if ngrok keeps mangling **`POST`** bodies or **`HTTP/2`**.
3. Cursor **cannot** use **`http://127.0.0.1:8443/v1`** as the provider Base URL (**SSRF block**) — loopback is only for **`curl`** on your Mac.

---

## Empty model list or Ollama errors behind the gateway

- Verify **Ollama** is up: `curl -sS http://127.0.0.1:11434/api/tags`.
- Verify **Caddy** is bound and proxying: check logs under `${XDG_DATA_HOME:-$HOME/.local/share}/cursor-ollama-gateway/logs/` (see main README).
- Ensure **`OLLAMA_HOST`** in `.env` matches where Ollama listens (default `127.0.0.1:11434`).

---

## `stop-stack` / stale pid files

If processes already exited, **`stop-stack` always deletes** the matching `.pid` files under:

`${XDG_STATE_HOME:-$HOME/.local/state}/cursor-ollama-gateway/run/`

You should see a line like **`removed pid file …`** for each service. If your output still says **`pid file existed but process not running`** with no **removed** line, your **`~/.local/share/.../scripts/`** copy is outdated—re-sync from the repo:

```bash
bash /path/to/cursor-ollama-gateway/scripts/install-to-home.sh
```

Start again with `cursor-ollama-start` (or `bash …/start-stack.sh`).

### `status-stack` shows “stale pid file” for every service

Same situation: **nothing is listening** under those PIDs anymore (often after a crash or reboot). The log paths printed (`$LOG_DIR/*.log`) are normal—they match `scripts/lib/paths.sh` (`~/.local/share/cursor-ollama-gateway/logs` by default).

Clear the pid files with **`stop-stack`** / **`cursor-ollama-stop`**, then **`start`** again if you want the gateway up.

### Status showed stale right after `start-stack` (fixed in current scripts)

Older scripts stored the **shell launcher PID** from `$!`, which could exit before the **real server PID** was stable. Current `start-stack.sh` re-resolves PIDs using **`lsof`** on **TCP 11434** (Ollama) and **8443** (default Caddy bind) and **`pgrep`** for ngrok, then writes that PID to the pid file.

If you changed **ports** in `Caddyfile` or `OLLAMA_HOST`, update `scripts/lib/service-pids.sh` to match or status/start may disagree with your layout.

---

## `cursor-ollama-stop` ran but Ollama / ngrok still appears running

Common causes:

1. **Another `ollama serve` already running** (second Terminal tab, IDE task, tmux pane). Only one listener can bind **127.0.0.1:11434**. Check `ps aux | grep '[o]llama serve'` and stop the extra session.

2. **Homebrew services** (`brew services`) supervising **Ollama** or related tools (**`mlx-lm`**, etc.). Those jobs **restart** after exit and **keep TCP 11434** (or other ports) busy even when `cursor-ollama-stop` runs.

   ```bash
   brew services list
   brew services stop ollama
   # stop other ML-related services if they conflict with your workflow, e.g.
   brew services stop mlx-lm
   ```

   Pick **one** supervisor for Ollama: either **brew services** *or* **`cursor-ollama-gateway start`** / **`cursor-ollama-start`** (which runs `ollama serve` from the stack). Running both typically means brew always wins.

3. **launchd** job. Check `launchctl list | grep -i ollama`.

4. **Ollama desktop app (menu bar)** — same idea: it supervises an API process.

5. **Stale scripts**: older `stop-stack.sh` only trusted pid files. Current scripts kill listeners found via **`lsof` / pgrep**, run a short **SIGKILL sweep** if needed, then warn if something **still** binds the port.

After stop you should see either silence or a **WARNING** block naming what is still bound.

---

## `command not found: caddy` (or `ngrok`, `ollama`)

Those binaries usually come from **Homebrew**. If **`PATH`** does not include Brew’s prefix, interactive **`zsh`** (including Cursor’s terminal) won’t find them.

**Apple Silicon:** Homebrew lives under **`/opt/homebrew/bin`**. One-session fix:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

**Intel Mac:** often **`/usr/local/bin`**:

```bash
eval "$(/usr/local/bin/brew shellenv)"
```

Then **`hash -r`** (optional) and retry **`caddy validate …`**.

Permanent fix: ensure **`brew shellenv`** runs from **`~/.zprofile`** (Homebrew prints exact lines when you run **`brew shellenv`** once).

You can always bypass **`PATH`**:

```bash
/opt/homebrew/bin/caddy validate --config ~/.config/cursor-ollama-gateway/Caddyfile
# or
/usr/local/bin/caddy validate --config ~/.config/cursor-ollama-gateway/Caddyfile
```

---

## PATH commands finish instantly with **no output** (no processes started)

**What’s going on:** the launcher runs `bash` on **`cursor-ollama-gateway.sh`** under **`~/.local/share/cursor-ollama-gateway/scripts/`**. If that file is **missing or zero-byte**, Bash exits successfully and prints nothing — so **`cursor-ollama-start`** and **`cursor-ollama-status`** both look like no-ops.

**Check:**

```bash
wc -l ~/.local/share/cursor-ollama-gateway/scripts/cursor-ollama-gateway.sh
type cursor-ollama-start
head -5 ~/.local/bin/cursor-ollama-start
```

You should see a non-zero line count and a wrapper that references **`cursor-ollama-gateway.sh`**.

**Fix:** refresh installed scripts from this repo (adjust path to your clone):

```bash
bash /path/to/cursor-ollama-gateway/scripts/install-to-home.sh
```

Then open a new terminal and try **`cursor-ollama-gateway start`** again.

---

## Only **`cursor-ollama-gateway: start → …`** (or **`status → …`**) then the shell prompt — no stack output

Fixed in current **`scripts/lib/service-pids.sh`**: with **`set -o pipefail`**, **`lsof`** exits non‑zero when nothing is listening on **11434** / **8443**, which used to abort **`start-stack.sh`** and **`status-stack.sh`** immediately. Refresh installed scripts (**`install-to-home.sh`** / **`deploy.sh`**) so **`~/.local/share/.../scripts/lib/service-pids.sh`** matches the repo.

---

## PATH commands not found (`cursor-ollama-start`, etc.)

- Run `bash scripts/install-to-home.sh` from a clone, or complete **quick deploy**, then **open a new terminal** (or `source` the RC file that was updated).
- Confirm `~/.local/bin` appears in `echo $PATH`.

---

## Still stuck?

Collect:

1. Output of `ollama list`
2. Redacted output of `/v1/models` through ngrok (no secrets—Bearer token redacted in logs if you paste publicly)
3. Relevant lines from `caddy-ollama.err.log` and `ollama.err.log` under your gateway log directory

Opening an issue with that context makes reproduction much easier.
