#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"
# shellcheck source=lib/service-pids.sh
source "$SCRIPT_DIR/lib/service-pids.sh"

remove_pid_file() {
	local name="$1"
	local pid_file="$2"

	if [[ ! -f "$pid_file" ]]; then
		echo "$name: pid file already absent ($pid_file)"
		return 0
	fi
	if rm -f "$pid_file"; then
		echo "$name: removed pid file $pid_file"
	else
		echo "$name: ERROR failed to remove $pid_file (check permissions)" >&2
	fi
	return 0
}

kill_pid_if_live() {
	local name="$1"
	local pid="$2"
	[[ -z "$pid" ]] && return 1
	kill -0 "$pid" 2>/dev/null || return 1
	kill "$pid" 2>/dev/null || true
	sleep 1
	if kill -0 "$pid" 2>/dev/null; then
		kill -9 "$pid" 2>/dev/null || true
	fi
	echo "$name: stopped pid $pid"
	return 0
}

# Kill whatever still owns this service's port/pgrep slot (handles respawns / missed PIDs).
sweep_listener_until_clear() {
	local name="$1"
	local attempt p
	for attempt in 1 2 3 4 5 6 7 8 9 10; do
		p="$(resolve_service_pid "$name")"
		[[ -z "$p" ]] && return 0
		kill -9 "$p" 2>/dev/null || true
		sleep 0.3
	done
}

stop_proc() {
	local name="$1"
	local pid_file="$RUN_DIR/$name.pid"

	local from_file
	from_file="$(read_pid_file "$pid_file")"
	local resolved
	resolved="$(resolve_service_pid "$name")"

	local stopped_any=false
	if kill_pid_if_live "$name" "$from_file"; then
		stopped_any=true
	fi
	if [[ -n "$resolved" ]] && [[ "$resolved" != "$from_file" ]]; then
		if kill_pid_if_live "$name" "$resolved"; then
			stopped_any=true
		fi
	fi

	if [[ "$stopped_any" == false ]]; then
		if [[ -n "$from_file" ]] || [[ -n "$resolved" ]]; then
			echo "$name: no live process for pid file or port probe"
		else
			echo "$name: not running"
		fi
	fi

	sweep_listener_until_clear "$name"

	remove_pid_file "$name" "$pid_file"
}

# stop in reverse dependency order
stop_proc "ngrok-ollama"
stop_proc "caddy-ollama"
stop_proc "ollama"

sleep 1

warn_if_still_up() {
	local svc="$1"
	local human="$2"
	local still
	still="$(resolve_service_pid "$svc")"
	[[ -z "$still" ]] && return 0
	echo "" >&2
	echo "WARNING: $human still looks active (pid $still)." >&2
	echo "  This stack only sends signals to processes it finds on known ports / pgrep." >&2
	echo "  Another supervisor may restart them (another terminal running \`ollama serve\`, brew services, launchd, or Ollama desktop)." >&2
	echo "  Quit from the menu bar or unload that agent if you need them fully stopped." >&2
}

warn_if_still_up "ollama" "Ollama (TCP 11434)"
warn_if_still_up "caddy-ollama" "Caddy (TCP 8443)"
warn_if_still_up "ngrok-ollama" "ngrok"
