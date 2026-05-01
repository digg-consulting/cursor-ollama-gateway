#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"
# shellcheck source=lib/service-pids.sh
source "$SCRIPT_DIR/lib/service-pids.sh"

STALE_COUNT=0

show_proc() {
	local name="$1"
	local pid_file="$RUN_DIR/$name.pid"

	local resolved
	resolved="$(resolve_service_pid "$name")"
	local from_file
	from_file="$(read_pid_file "$pid_file")"

	if [[ -n "$resolved" ]] && kill -0 "$resolved" 2>/dev/null; then
		if [[ "$from_file" != "$resolved" ]] || [[ ! -f "$pid_file" ]]; then
			echo "$resolved" >"$pid_file"
			echo "$name: running (pid $resolved; pid file synced)"
		else
			echo "$name: running (pid $resolved)"
		fi
		return 0
	fi

	if [[ -f "$pid_file" ]]; then
		echo "$name: stopped (stale pid file: ${from_file:-empty}; nothing listening / no matching process)"
		STALE_COUNT=$((STALE_COUNT + 1))
		return 0
	fi

	echo "$name: stopped (no pid file)"
}

show_proc "ollama"
show_proc "caddy-ollama"
show_proc "ngrok-ollama"

if [[ "$STALE_COUNT" -gt 0 ]]; then
	echo
	echo "Clean up stale pid files with:"
	echo "  bash \"$SCRIPT_DIR/stop-stack.sh\""
	echo "  (or: cursor-ollama-stop)"
fi

echo
echo "Log files:"
echo "  $LOG_DIR/ollama.out.log"
echo "  $LOG_DIR/ollama.err.log"
echo "  $LOG_DIR/caddy-ollama.out.log"
echo "  $LOG_DIR/caddy-ollama.err.log"
echo "  $LOG_DIR/ngrok-ollama.out.log"
echo "  $LOG_DIR/ngrok-ollama.err.log"
