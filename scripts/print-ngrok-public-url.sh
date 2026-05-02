#!/usr/bin/env bash
# Print public https URL for Cursor: prefers ngrok.yml `domain:` when set; else parses ngrok logs.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"

NGROK_CONFIG="${NGROK_CONFIG:-$CONFIG_DIR/ngrok.yml}"
out_log="$LOG_DIR/ngrok-ollama.out.log"
err_log="$LOG_DIR/ngrok-ollama.err.log"

# Stable hostname reserved in dashboard — authoritative for Base URL even if logs mention older tunnels.
pinned_https_url_from_ngrok_yml() {
	local cfg="$NGROK_CONFIG"
	[[ -f "$cfg" ]] || return 1
	local raw host
	raw="$(grep -E '^[[:space:]]*domain:[[:space:]]+[[:alnum:]._-]+' "$cfg" | tail -1)" || true
	[[ -z "${raw:-}" ]] && return 1
	host="${raw#*:}"
	host="$(echo "$host" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' )"
	[[ -z "$host" ]] && return 1
	case "$host" in
	http://* | https://*) echo "${host%/}" ;;
	*) echo "https://${host}" ;;
	esac
}

# Only scan recent lines — full logs accumulate URLs from older sessions (another laptop's domain,
# stale ERR_NGROK_334 text, etc.) and `tail -1` on all https matches would lie about "current" URL.
_recent_tail_lines() {
	# shellcheck disable=SC2155
	local n="${PRINT_NGROK_LOG_TAIL:-400}"
	case "$n" in
	'' | *[!0-9]*) n=400 ;;
	esac
	echo "$n"
}

combined_ngrok_logs_recent() {
	local n
	n="$(_recent_tail_lines)"
	local f
	for f in "$out_log" "$err_log"; do
		[[ -f "$f" ]] || continue
		tail -n "$n" "$f" 2>/dev/null || true
	done
}

# Drop documentation, loopback, and other non-tunnel URLs ngrok sometimes prints.
filter_tunnel_candidate() {
	grep -Ev '(127\.0\.0\.1|localhost|dashboard\.ngrok\.com|ngrok\.com/)' || true
}

extract_from_forwarding_line() {
	combined_ngrok_logs_recent | grep -Fi forwarding | grep -oE 'https://[^[:space:]]+' | filter_tunnel_candidate | tail -1
}

# ERR_NGROK_334: "The endpoint 'https://….' is already online" — still gives the hostname Cursor needs.
extract_from_endpoint_busy_message() {
	combined_ngrok_logs_recent | grep -oE "The endpoint 'https://[^']+'" | sed -e "s/^The endpoint '//" -e "s/'$//" | tail -1
}

extract_fallback_last_https() {
	combined_ngrok_logs_recent | grep -oE 'https://[^[:space:]]+' | filter_tunnel_candidate | tail -1
}

detect_ngrok_334() {
	combined_ngrok_logs_recent | grep -q 'ERR_NGROK_334' 2>/dev/null
}

wait_loop=0
if [[ "${1:-}" == "--wait" ]]; then
	wait_loop=15
fi

url=""
pinned="$(pinned_https_url_from_ngrok_yml || true)"
if [[ -n "${pinned:-}" ]]; then
	url="$pinned"
else
	if [[ "$wait_loop" -gt 0 ]]; then
		local i
		for ((i = 0; i < wait_loop; i++)); do
			url="$(extract_from_forwarding_line || true)"
			[[ -n "$url" ]] && break
			url="$(extract_from_endpoint_busy_message || true)"
			[[ -n "$url" ]] && break
			url="$(extract_fallback_last_https || true)"
			[[ -n "$url" ]] && break
			sleep 1
		done
	else
		url="$(extract_from_forwarding_line || true)"
		[[ -z "$url" ]] && url="$(extract_from_endpoint_busy_message || true)"
		[[ -z "$url" ]] && url="$(extract_fallback_last_https || true)"
	fi
fi

if [[ -z "$url" ]]; then
	echo "Could not find a public tunnel https URL in:" >&2
	echo "  $out_log" >&2
	echo "  $err_log" >&2
	echo >&2
	if [[ -s "$err_log" ]]; then
		echo "Last lines from ngrok-ollama.err.log:" >&2
		tail -n 12 "$err_log" | sed 's/^/  /' >&2
	elif [[ -s "$out_log" ]]; then
		echo "Last lines from ngrok-ollama.out.log:" >&2
		tail -n 12 "$out_log" | sed 's/^/  /' >&2
	fi
	echo >&2
	echo "Fix: cursor-ollama-gateway stop; ensure no other \`ngrok\` is using this domain; cursor-ollama-gateway start" >&2
	echo "Then: cursor-ollama-gateway url" >&2
	echo "Or set domain: under tunnels.cursor-ollama in $NGROK_CONFIG (reserved in ngrok dashboard)." >&2
	exit 1
fi

echo "Ngrok public URL:     $url"
echo "Cursor OpenAI Base URL: ${url}/v1"
# Pinned domain: don't warn from stale 334 lines in old log history.
if [[ -z "${pinned:-}" ]] && detect_ngrok_334; then
	echo >&2
	echo "Note: Log shows ERR_NGROK_334 (this tunnel URL may already be bound by another ngrok process)." >&2
	echo "If requests fail, stop every ngrok using the same domain, then restart the stack." >&2
fi
exit 0
