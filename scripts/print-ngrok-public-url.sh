#!/usr/bin/env bash
# Extract the tunnel's public https URL from ngrok agent output (ngrok-ollama.{out,err}.log under LOG_DIR).
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"

out_log="$LOG_DIR/ngrok-ollama.out.log"
err_log="$LOG_DIR/ngrok-ollama.err.log"

combined_ngrok_logs() {
	local f
	for f in "$out_log" "$err_log"; do
		[[ -f "$f" ]] || continue
		[[ -s "$f" ]] || continue
		cat "$f"
	done
}

# Drop documentation, loopback, and other non-tunnel URLs ngrok sometimes prints.
filter_tunnel_candidate() {
	grep -Ev '(127\.0\.0\.1|localhost|dashboard\.ngrok\.com|ngrok\.com/)' || true
}

extract_from_forwarding_line() {
	combined_ngrok_logs | grep -Fi forwarding | grep -oE 'https://[^[:space:]]+' | filter_tunnel_candidate | tail -1
}

# ERR_NGROK_334: "The endpoint 'https://….' is already online" — still gives the hostname Cursor needs.
extract_from_endpoint_busy_message() {
	combined_ngrok_logs | grep -oE "The endpoint 'https://[^']+'" | sed -e "s/^The endpoint '//" -e "s/'$//" | tail -1
}

extract_fallback_last_https() {
	combined_ngrok_logs | grep -oE 'https://[^[:space:]]+' | filter_tunnel_candidate | tail -1
}

detect_ngrok_334() {
	combined_ngrok_logs | grep -q 'ERR_NGROK_334' 2>/dev/null
}

wait_loop=0
if [[ "${1:-}" == "--wait" ]]; then
	wait_loop=15
fi

url=""
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
	exit 1
fi

echo "Ngrok public URL:     $url"
echo "Cursor OpenAI Base URL: ${url}/v1"
if detect_ngrok_334; then
	echo >&2
	echo "Note: Log shows ERR_NGROK_334 (this tunnel URL may already be bound by another ngrok process)." >&2
	echo "If requests fail, stop every ngrok using the same domain, then restart the stack." >&2
fi
exit 0
