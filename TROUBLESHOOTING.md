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

## Connection errors / ngrok offline

- Confirm ngrok is running and the URL in Cursor matches the current tunnel (URLs change unless you use a **reserved domain**).
- From another machine or browser, try `GET https://<ngrok-domain>/v1/models` with the Bearer header (see above).

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
