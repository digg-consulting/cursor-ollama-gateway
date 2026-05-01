#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"

echo "Installing layout:"
echo "  config: $CONFIG_DIR"
echo "  run:    $RUN_DIR"
echo "  logs:   $LOG_DIR"
if [[ "${CURSOR_OLLAMA_GATEWAY_SYSTEM:-}" == "1" ]]; then
	echo "  mode:   system (CURSOR_OLLAMA_GATEWAY_SYSTEM=1, uses sudo)"
fi
echo

if [[ "${CURSOR_OLLAMA_GATEWAY_SYSTEM:-}" == "1" ]]; then
	sudo mkdir -p "$CONFIG_DIR" "$RUN_DIR" "$LOG_DIR"
	sudo cp "$PROJECT_ROOT/Caddyfile" "$CONFIG_DIR/Caddyfile"
	sudo cp "$PROJECT_ROOT/ngrok.yml" "$CONFIG_DIR/ngrok.yml"
	if [[ ! -f "$CONFIG_DIR/.env" ]]; then
		sudo cp "$PROJECT_ROOT/.env.example" "$CONFIG_DIR/.env"
		echo "Created $CONFIG_DIR/.env from template. Update it before startup."
	fi
	sudo chown -R "$USER":staff "$CONFIG_DIR" "$RUN_DIR" "$LOG_DIR"
else
	mkdir -p "$CONFIG_DIR" "$RUN_DIR" "$LOG_DIR"
	cp "$PROJECT_ROOT/Caddyfile" "$CONFIG_DIR/Caddyfile"
	cp "$PROJECT_ROOT/ngrok.yml" "$CONFIG_DIR/ngrok.yml"
	if [[ ! -f "$CONFIG_DIR/.env" ]]; then
		cp "$PROJECT_ROOT/.env.example" "$CONFIG_DIR/.env"
		echo "Created $CONFIG_DIR/.env from template. Update it before startup."
	fi
fi

chmod 700 "$RUN_DIR"
chmod 700 "$LOG_DIR"
chmod 600 "$CONFIG_DIR/.env"

echo "Install complete."
echo "Next:"
echo "  1) edit $CONFIG_DIR/.env"
echo "  2) ENV_FILE=$CONFIG_DIR/.env ./scripts/generate-secrets.sh"
