#!/usr/bin/env bash
# Resolve the real listening/working PID for stack services.
# Uses lsof on fixed local ports (matches default Caddyfile / Ollama bind).
#
# Callers use `set -o pipefail`: when nothing is listening, `lsof` exits non-zero,
# which would fail `lsof | head` and abort the script. Wrap probe commands so an
# empty result still yields pipeline status 0.

resolve_service_pid() {
	local svc="$1"
	case "$svc" in
	ollama)
		# Default OLLAMA_HOST 127.0.0.1:11434
		if command -v lsof >/dev/null 2>&1; then
			( lsof -nP -iTCP:11434 -sTCP:LISTEN -t 2>/dev/null || true ) | head -n1
		else
			( pgrep -f '[o]llama serve' 2>/dev/null || true ) | head -n1
		fi
		;;
	caddy-ollama)
		# Default site bind 127.0.0.1:8443 in repo Caddyfile
		if command -v lsof >/dev/null 2>&1; then
			( lsof -nP -iTCP:8443 -sTCP:LISTEN -t 2>/dev/null || true ) | head -n1
		else
			( pgrep -f '[c]addy run' 2>/dev/null || true ) | head -n1
		fi
		;;
	ngrok-ollama)
		( pgrep -f '[n]grok start' 2>/dev/null || true ) | head -n1
		;;
	*)
		echo ""
		;;
	esac
}

read_pid_file() {
	local f="$1"
	if [[ ! -f "$f" ]]; then
		echo ""
		return
	fi
	tr -d '[:space:]' <"$f"
}
