#!/usr/bin/env bash
# Unified stack control (init-style): start | stop | status | restart
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
	cat <<'EOF'
Usage: cursor-ollama-gateway.sh <command>

Commands:
  start       Start Ollama, Caddy, and ngrok (stack expects to own Ollama — stop brew services first).
  stop        Stop stack components and sweep listeners on known ports.
  status      Show listener / pid-file status.
  url         Print the public https URL from ngrok logs (append /v1 for Cursor Base URL).
  restart     Run stop then start.
  logs-clear  Delete *.log under LOG_DIR (default: ~/.local/share/.../cursor-ollama-gateway/logs/).

Environment:
  CURSOR_OLLAMA_GATEWAY_ALLOW_BREW_OLLAMA=1  Skip the guard when Homebrew service "ollama" is started.
  CURSOR_OLLAMA_GATEWAY_QUIET=1               Omit stderr lines showing which stack script is running.

The PATH shortcuts cursor-ollama-start, cursor-ollama-stop, and cursor-ollama-status call this script.
EOF
}

abort_if_brew_ollama_supervisor() {
	[[ "${CURSOR_OLLAMA_GATEWAY_ALLOW_BREW_OLLAMA:-}" == "1" ]] && return 0
	command -v brew >/dev/null 2>&1 || return 0

	local brew_out line
	brew_out="$(brew services list 2>/dev/null || true)"
	line="$(printf '%s\n' "$brew_out" | grep -E '^ollama[[:space:]]' || true)"
	[[ -z "$line" ]] && return 0

	case "$line" in
	*started*)
		echo "ERROR: Homebrew still has the Ollama service active:" >&2
		echo "       $line" >&2
		echo "       This stack is meant to own \`ollama serve\`. Run:" >&2
		echo "         brew services stop ollama" >&2
		echo "       Or set CURSOR_OLLAMA_GATEWAY_ALLOW_BREW_OLLAMA=1 to skip this check." >&2
		exit 1
		;;
	esac
}

require_script() {
	local rel="$1"
	local path="$SCRIPT_DIR/$rel"
	if [[ ! -s "$path" ]]; then
		echo "cursor-ollama-gateway: missing or empty $path" >&2
		echo "Re-sync scripts (example): bash \"$SCRIPT_DIR/install-to-home.sh\"" >&2
		exit 1
	fi
}

gate_notify() {
	[[ "${CURSOR_OLLAMA_GATEWAY_QUIET:-}" == "1" ]] && return 0
	echo "cursor-ollama-gateway: $*" >&2
}

case "${1:-}" in
start)
	shift
	require_script start-stack.sh
	abort_if_brew_ollama_supervisor
	gate_notify "start → start-stack.sh"
	exec bash "$SCRIPT_DIR/start-stack.sh" "$@"
	;;
stop)
	shift
	require_script stop-stack.sh
	gate_notify "stop → stop-stack.sh"
	exec bash "$SCRIPT_DIR/stop-stack.sh" "$@"
	;;
status)
	shift
	require_script status-stack.sh
	gate_notify "status → status-stack.sh"
	exec bash "$SCRIPT_DIR/status-stack.sh" "$@"
	;;
url)
	shift
	require_script print-ngrok-public-url.sh
	gate_notify "url → print-ngrok-public-url.sh"
	exec bash "$SCRIPT_DIR/print-ngrok-public-url.sh" "$@"
	;;
restart)
	shift
	require_script stop-stack.sh
	require_script start-stack.sh
	gate_notify "restart (stop then start)"
	bash "$SCRIPT_DIR/stop-stack.sh"
	bash "$SCRIPT_DIR/start-stack.sh" "$@"
	;;
logs-clear)
	shift
	# shellcheck source=lib/paths.sh
	source "$SCRIPT_DIR/lib/paths.sh"
	mkdir -p "$LOG_DIR"
	find "$LOG_DIR" -maxdepth 1 -type f \( -name '*.log' -o -name '*.log.*' \) -delete 2>/dev/null || true
	echo "cursor-ollama-gateway: cleared *.log under $LOG_DIR" >&2
	exit 0
	;;
"" | -h | --help | help)
	usage
	exit 0
	;;
*)
	echo "Unknown command: ${1:-}" >&2
	echo >&2
	usage >&2
	exit 1
	;;
esac
