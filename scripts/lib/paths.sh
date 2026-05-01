#!/usr/bin/env bash
# Shared config/state/log locations for cursor-ollama-gateway.
# Source this file from other scripts in this repo (do not execute directly).
#
# Logging convention:
#   LOG_DIR is the single place for gateway logs in the default (per-user) layout.
#   Stack scripts (start-stack.sh) and the optional launchd plists use the same
#   directory and the same filenames (ollama.out.log, caddy-ollama.out.log,
#   ngrok-ollama.out.log) so troubleshooting does not depend on how you started
#   the processes. Plists duplicate this path with inline shell because launchd
#   cannot source this file; keep the formulas in sync when changing defaults.

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
