#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"
# shellcheck source=lib/service-pids.sh
source "$SCRIPT_DIR/lib/service-pids.sh"

ENV_FILE="${ENV_FILE:-$CONFIG_DIR/.env}"
CADDYFILE="${CADDYFILE:-$CONFIG_DIR/Caddyfile}"
NGROK_CONFIG="${NGROK_CONFIG:-$CONFIG_DIR/ngrok.yml}"

mkdir -p "$CONFIG_DIR" "$RUN_DIR" "$LOG_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
	echo "Missing env file: $ENV_FILE" >&2
	exit 1
fi
if [[ ! -f "$CADDYFILE" ]]; then
	echo "Missing Caddyfile: $CADDYFILE" >&2
	exit 1
fi
if [[ ! -f "$NGROK_CONFIG" ]]; then
	echo "Missing ngrok config: $NGROK_CONFIG" >&2
	exit 1
fi

if grep -qE '^[[:space:]]*authtoken:[[:space:]].*\$\{NGROK_AUTHTOKEN\}' "$NGROK_CONFIG" 2>/dev/null; then
	echo "ERROR: $NGROK_CONFIG lists authtoken: \${NGROK_AUTHTOKEN} — ngrok does not expand shell syntax (ERR_NGROK_105)." >&2
	echo "Remove the entire authtoken: line. Put your real token only in NGROK_AUTHTOKEN=... inside $ENV_FILE" >&2
	echo "Or copy ngrok.yml from this repo (no authtoken key)." >&2
	exit 1
fi

# Save PATH before sourcing .env — `set -a` exports every assignment in .env. If .env sets PATH to
# something narrow or empty, `command -v caddy` / `ngrok` inside spawned jobs becomes empty →
# `exec: : not found`. Always put Homebrew prefixes back on PATH afterward.
_gw_saved_path="$PATH"
set -a
source "$ENV_FILE"
set +a
PATH="${PATH:-$_gw_saved_path}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
unset _gw_saved_path

start_proc() {
	local name="$1"
	local cmd="$2"
	local pid_file="$RUN_DIR/$name.pid"
	local out_file="$LOG_DIR/$name.out.log"
	local err_file="$LOG_DIR/$name.err.log"

	local existing
	existing="$(resolve_service_pid "$name")"
	if [[ -n "$existing" ]] && kill -0 "$existing" 2>/dev/null; then
		echo "$existing" >"$pid_file"
		echo "$name already running (pid $existing)"
		if [[ "$name" == "ollama" ]]; then
			echo "  Note: Something else is already listening on 11434 — often another terminal's \`ollama serve\`, brew services," >&2
			echo "  launchd, or the menu-bar app. Stop that before expecting this stack to own the port." >&2
		fi
		return 0
	fi

	if [[ -f "$pid_file" ]]; then
		local oldpid
		oldpid="$(read_pid_file "$pid_file")"
		if [[ -n "$oldpid" ]] && kill -0 "$oldpid" 2>/dev/null; then
			echo "$name already running (pid $oldpid)"
			return 0
		fi
		rm -f "$pid_file"
		echo "$name: removed stale pid file before start"
	fi

	# bash -c inherits this script's exported env + PATH (from ~/.env via set -a).
	# zsh -lc often diverges from non-login bash PATH and can miss Homebrew binaries.
	# Ngrok prints session status (including the public https URL) to stderr — keep it in *.out.log
	# so print-ngrok-public-url.sh and log tailers see Forwarding lines in one place.
	if [[ "$name" == "ngrok-ollama" ]]; then
		nohup bash -c "$cmd" >>"$out_file" 2>&1 &
	else
		nohup bash -c "$cmd" >>"$out_file" 2>>"$err_file" &
	fi
	local launcher_pid=$!

	sleep 1
	local real_pid=""
	local _attempt
	for _attempt in 1 2 3 4 5 6; do
		real_pid="$(resolve_service_pid "$name")"
		[[ -n "$real_pid" ]] && break
		sleep 0.5
	done

	if [[ -n "$real_pid" ]] && [[ "$real_pid" =~ ^[0-9]+$ ]] && kill -0 "$real_pid" 2>/dev/null; then
		echo "$real_pid" >"$pid_file"
		echo "started $name (pid $real_pid)"
		return 0
	fi

	if kill -0 "$launcher_pid" 2>/dev/null; then
		echo "$launcher_pid" >"$pid_file"
		echo "started $name (pid $launcher_pid — could not confirm via port/pgrep; check status/logs)"
		return 0
	fi

	echo "$launcher_pid" >"$pid_file"
	local diag="$err_file"
	[[ "$name" == "ngrok-ollama" ]] && diag="$out_file"
	echo "WARNING: $name exited immediately (launcher pid $launcher_pid). See $diag" >&2
	if [[ -s "$diag" ]]; then
		echo "Last lines from $(basename "$diag"):" >&2
		tail -n 20 "$diag" | sed 's/^/  /' >&2
	fi
	return 0
}

start_proc "ollama" 'export OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"; exec "$(command -v ollama)" serve'
sleep 1
start_proc "caddy-ollama" 'exec "$(command -v caddy)" run --config "'"$CADDYFILE"'"'
sleep 1
start_proc "ngrok-ollama" 'exec "$(command -v ngrok)" start --config "'"$NGROK_CONFIG"'" cursor-ollama'

echo "Stack start requested. Check status with: bash \"$SCRIPT_DIR/status-stack.sh\""
echo
if bash "$SCRIPT_DIR/print-ngrok-public-url.sh" --wait 2>/dev/null; then
	:
else
	echo "(Tunnel URL will appear here once ngrok writes to $LOG_DIR/ngrok-ollama.out.log — run: cursor-ollama-gateway url)" >&2
fi
