#!/usr/bin/env bash
# Unified stack control (init-style): start | stop | status | restart
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
	cat <<'EOF'
Usage: cursor-ollama-gateway.sh <command>

Commands:
  start    Start Ollama, Caddy, and ngrok (stack expects to own Ollama — stop brew services first).
  stop     Stop stack components and sweep listeners on known ports.
  status   Show listener / pid-file status.
  restart  Run stop then start.

Environment:
  CURSOR_OLLAMA_GATEWAY_ALLOW_BREW_OLLAMA=1  Skip the guard when Homebrew service "ollama" is started.

The PATH shortcuts cursor-ollama-start, cursor-ollama-stop, and cursor-ollama-status call this script.
EOF
}

abort_if_brew_ollama_supervisor() {
	[[ "${CURSOR_OLLAMA_GATEWAY_ALLOW_BREW_OLLAMA:-}" == "1" ]] && return 0
	command -v brew >/dev/null 2>&1 || return 0

	local line
	line="$(brew services list 2>/dev/null | grep -E '^ollama[[:space:]]' || true)"
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

case "${1:-}" in
start)
	shift
	abort_if_brew_ollama_supervisor
	exec bash "$SCRIPT_DIR/start-stack.sh" "$@"
	;;
stop)
	shift
	exec bash "$SCRIPT_DIR/stop-stack.sh" "$@"
	;;
status)
	shift
	exec bash "$SCRIPT_DIR/status-stack.sh" "$@"
	;;
restart)
	shift
	bash "$SCRIPT_DIR/stop-stack.sh"
	bash "$SCRIPT_DIR/start-stack.sh" "$@"
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
