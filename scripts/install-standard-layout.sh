#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="${CONFIG_DIR:-/usr/local/etc/cursor-ollama-gateway}"
RUN_DIR="${RUN_DIR:-/usr/local/var/run/cursor-ollama-gateway}"
LOG_DIR="${LOG_DIR:-/usr/local/var/log/cursor-ollama-gateway}"

echo "Installing standard layout:"
echo "  config: $CONFIG_DIR"
echo "  run:    $RUN_DIR"
echo "  logs:   $LOG_DIR"

sudo mkdir -p "$CONFIG_DIR" "$RUN_DIR" "$LOG_DIR"
sudo cp "$PROJECT_ROOT/Caddyfile" "$CONFIG_DIR/Caddyfile"
sudo cp "$PROJECT_ROOT/ngrok.yml" "$CONFIG_DIR/ngrok.yml"

if [[ ! -f "$CONFIG_DIR/.env" ]]; then
  sudo cp "$PROJECT_ROOT/.env.example" "$CONFIG_DIR/.env"
  echo "Created $CONFIG_DIR/.env from template. Update it before startup."
fi

sudo chown -R "$USER":staff "$CONFIG_DIR" "$RUN_DIR" "$LOG_DIR"
chmod 700 "$RUN_DIR"
chmod 700 "$LOG_DIR"
chmod 600 "$CONFIG_DIR/.env"

echo "Install complete."
echo "Next:"
echo "  1) edit $CONFIG_DIR/.env"
echo "  2) run ./scripts/generate-secrets.sh with ENV_FILE override if needed"
