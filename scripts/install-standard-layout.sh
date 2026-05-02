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

if [[ "${CURSOR_OLLAMA_GATEWAY_SYSTEM:-}" == "1" ]]; then
	SCRIPT_INSTALL="/usr/local/libexec/cursor-ollama-gateway/scripts"
	WRAPPER_BIN="/usr/local/bin"
	MAYBE_SUDO="sudo"
else
	SCRIPT_INSTALL="${XDG_DATA_HOME}/cursor-ollama-gateway/scripts"
	WRAPPER_BIN="$HOME/.local/bin"
	MAYBE_SUDO=""
fi

echo "Installing operator scripts to:"
echo "  $SCRIPT_INSTALL"
if [[ -n "$MAYBE_SUDO" ]]; then
	sudo mkdir -p "$SCRIPT_INSTALL/lib"
	sudo cp "$PROJECT_ROOT/scripts/lib/paths.sh" "$SCRIPT_INSTALL/lib/paths.sh"
	sudo cp "$PROJECT_ROOT/scripts/lib/install-wrappers.sh" "$SCRIPT_INSTALL/lib/install-wrappers.sh"
	sudo cp "$PROJECT_ROOT/scripts/lib/service-pids.sh" "$SCRIPT_INSTALL/lib/service-pids.sh"
	sudo cp "$PROJECT_ROOT/scripts/cursor-ollama-gateway.sh" "$SCRIPT_INSTALL/cursor-ollama-gateway.sh"
	for f in start-stack.sh stop-stack.sh status-stack.sh generate-secrets.sh print-ngrok-public-url.sh; do
		sudo cp "$PROJECT_ROOT/scripts/$f" "$SCRIPT_INSTALL/$f"
	done
	sudo chmod -R a+rX "$SCRIPT_INSTALL"
else
	mkdir -p "$SCRIPT_INSTALL/lib"
	cp "$PROJECT_ROOT/scripts/lib/paths.sh" "$SCRIPT_INSTALL/lib/paths.sh"
	cp "$PROJECT_ROOT/scripts/lib/install-wrappers.sh" "$SCRIPT_INSTALL/lib/install-wrappers.sh"
	cp "$PROJECT_ROOT/scripts/lib/service-pids.sh" "$SCRIPT_INSTALL/lib/service-pids.sh"
	cp "$PROJECT_ROOT/scripts/cursor-ollama-gateway.sh" "$SCRIPT_INSTALL/cursor-ollama-gateway.sh"
	for f in start-stack.sh stop-stack.sh status-stack.sh generate-secrets.sh print-ngrok-public-url.sh; do
		cp "$PROJECT_ROOT/scripts/$f" "$SCRIPT_INSTALL/$f"
	done
	chmod -R a+rX "$SCRIPT_INSTALL"
fi

# shellcheck source=lib/install-wrappers.sh
source "$SCRIPT_DIR/lib/install-wrappers.sh"
install_cursor_ollama_gateway_wrappers "$SCRIPT_INSTALL" "$WRAPPER_BIN" "$MAYBE_SUDO"
ensure_cursor_ollama_local_bin_on_path "$WRAPPER_BIN"

echo "Install complete."
echo "Next:"
echo "  1) edit $CONFIG_DIR/.env"
echo "  2) cursor-ollama-generate-secrets"
echo "     (or: ENV_FILE=$CONFIG_DIR/.env bash \"$SCRIPT_INSTALL/generate-secrets.sh\")"
echo "  3) cursor-ollama-gateway start   (or: cursor-ollama-start)"
