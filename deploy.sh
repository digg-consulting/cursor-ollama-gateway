#!/usr/bin/env bash
set -euo pipefail

if [[ "${CURSOR_OLLAMA_GATEWAY_SYSTEM:-}" == "1" ]]; then
	CONFIG_DIR="${CONFIG_DIR:-/usr/local/etc/cursor-ollama-gateway}"
	RUN_DIR="${RUN_DIR:-/usr/local/var/run/cursor-ollama-gateway}"
	LOG_DIR="${LOG_DIR:-/usr/local/var/log/cursor-ollama-gateway}"
else
	XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
	XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
	XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
	CONFIG_DIR="${CONFIG_DIR:-$XDG_CONFIG_HOME/cursor-ollama-gateway}"
	RUN_DIR="${RUN_DIR:-$XDG_STATE_HOME/cursor-ollama-gateway/run}"
	LOG_DIR="${LOG_DIR:-$XDG_DATA_HOME/cursor-ollama-gateway/logs}"
fi

ENV_FILE="$CONFIG_DIR/.env"
CADDYFILE="$CONFIG_DIR/Caddyfile"
NGROK_CONFIG="$CONFIG_DIR/ngrok.yml"

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Missing required command: $1" >&2
		exit 1
	fi
}

prompt_required() {
	local var_name="$1"
	local prompt_text="$2"
	local value=""
	while [[ -z "$value" ]]; do
		read -r -p "$prompt_text: " value
	done
	printf -v "$var_name" "%s" "$value"
}

echo "== Cursor Ollama Gateway Deploy =="
echo "This script writes config under:"
echo "  $CONFIG_DIR"
echo "Runtime dirs:"
echo "  run: $RUN_DIR"
echo "  log: $LOG_DIR"
if [[ "${CURSOR_OLLAMA_GATEWAY_SYSTEM:-}" == "1" ]]; then
	echo "Mode: system (CURSOR_OLLAMA_GATEWAY_SYSTEM=1, uses sudo)"
fi
echo

require_cmd openssl

if [[ "${CURSOR_OLLAMA_GATEWAY_SYSTEM:-}" == "1" ]]; then
	require_cmd sudo
fi

prompt_required NGROK_AUTHTOKEN "Enter NGROK_AUTHTOKEN"
read -r -p "Enter reserved ngrok domain (optional, press enter to skip): " NGROK_DOMAIN
read -r -p "Enter Ollama host [127.0.0.1:11434]: " OLLAMA_HOST
OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"

OLLAMA_PROXY_TOKEN="$(openssl rand -base64 72 | tr -d '\n' | tr '/+' '_-')"

echo
echo "Creating directories..."
if [[ "${CURSOR_OLLAMA_GATEWAY_SYSTEM:-}" == "1" ]]; then
	sudo mkdir -p "$CONFIG_DIR" "$RUN_DIR" "$LOG_DIR"
	sudo chown -R "$USER":staff "$CONFIG_DIR" "$RUN_DIR" "$LOG_DIR"
else
	mkdir -p "$CONFIG_DIR" "$RUN_DIR" "$LOG_DIR"
fi
chmod 700 "$RUN_DIR" "$LOG_DIR"

cat >"$ENV_FILE" <<EOF
OLLAMA_PROXY_TOKEN=$OLLAMA_PROXY_TOKEN
NGROK_AUTHTOKEN=$NGROK_AUTHTOKEN
OLLAMA_HOST=$OLLAMA_HOST
EOF
chmod 600 "$ENV_FILE"

cat >"$CADDYFILE" <<'EOF'
{
	admin off
	auto_https off
	servers {
		read_timeout 15s
		write_timeout 120s
		idle_timeout 120s
	}
}

127.0.0.1:8443 {
	tls internal

	request_body {
		max_size 10MB
	}

	@v1 path /v1/*
	handle @v1 {
		@missing_auth not header Authorization *
		respond @missing_auth "missing authorization" 401

		@bad_auth not header Authorization "Bearer {$OLLAMA_PROXY_TOKEN}"
		respond @bad_auth "forbidden" 403

		@bad_method not method GET POST
		respond @bad_method "method not allowed" 405

		header {
			-Server
			X-Content-Type-Options "nosniff"
			X-Frame-Options "DENY"
			Referrer-Policy "no-referrer"
			Cache-Control "no-store"
		}

		reverse_proxy 127.0.0.1:11434
	}

	respond "not found" 404
}
EOF

cat >"$NGROK_CONFIG" <<EOF
version: "2"
authtoken: \${NGROK_AUTHTOKEN}

tunnels:
  cursor-ollama:
    proto: http
    addr: https://127.0.0.1:8443
    inspect: false
EOF

if [[ -n "${NGROK_DOMAIN:-}" ]]; then
	cat >>"$NGROK_CONFIG" <<EOF
    domain: $NGROK_DOMAIN
EOF
fi

echo
echo "Deployment files created:"
echo "  $ENV_FILE"
echo "  $CADDYFILE"
echo "  $NGROK_CONFIG"
echo
echo "Next:"
echo "  1) source $ENV_FILE"
echo "  2) run ollama serve with OLLAMA_HOST=$OLLAMA_HOST"
echo "  3) run: caddy run --config $CADDYFILE"
echo "  4) run: ngrok start --config $NGROK_CONFIG cursor-ollama"
echo
echo "Or from a clone: ./scripts/start-stack.sh"
echo
echo "Use this token as Cursor API key:"
echo "  $OLLAMA_PROXY_TOKEN"
