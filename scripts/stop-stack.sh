#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"

stop_proc() {
	local name="$1"
	local pid_file="$RUN_DIR/$name.pid"

	if [[ ! -f "$pid_file" ]]; then
		echo "$name not running (no pid file)"
		return
	fi

	local pid
	pid="$(cat "$pid_file")"

	if kill -0 "$pid" 2>/dev/null; then
		kill "$pid"
		sleep 1
		if kill -0 "$pid" 2>/dev/null; then
			kill -9 "$pid" 2>/dev/null || true
		fi
		echo "stopped $name (pid $pid)"
	else
		echo "$name pid file existed but process not running"
	fi

	rm -f "$pid_file"
}

# stop in reverse dependency order
stop_proc "ngrok-ollama"
stop_proc "caddy-ollama"
stop_proc "ollama"
