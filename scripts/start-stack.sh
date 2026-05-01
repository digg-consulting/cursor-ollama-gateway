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

set -a
source "$ENV_FILE"
set +a

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

	nohup /bin/zsh -lc "$cmd" >>"$out_file" 2>>"$err_file" &
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
	echo "WARNING: $name exited immediately (launcher pid $launcher_pid). See $err_file" >&2
	return 0
}

start_proc "ollama" 'export OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"; exec "$(command -v ollama)" serve'
sleep 1
start_proc "caddy-ollama" 'exec "$(command -v caddy)" run --config "'"$CADDYFILE"'"'
sleep 1
start_proc "ngrok-ollama" 'exec "$(command -v ngrok)" start --config "'"$NGROK_CONFIG"'" cursor-ollama'

echo "Stack start requested. Check status with: bash \"$SCRIPT_DIR/status-stack.sh\""
