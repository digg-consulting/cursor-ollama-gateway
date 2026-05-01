#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-/usr/local/etc/cursor-ollama-gateway}"
RUN_DIR="${RUN_DIR:-/usr/local/var/run/cursor-ollama-gateway}"
LOG_DIR="${LOG_DIR:-/usr/local/var/log/cursor-ollama-gateway}"

ENV_FILE="${ENV_FILE:-$CONFIG_DIR/.env}"
CADDYFILE="${CADDYFILE:-$CONFIG_DIR/Caddyfile}"
NGROK_CONFIG="${NGROK_CONFIG:-$CONFIG_DIR/ngrok.yml}"

mkdir -p "$RUN_DIR" "$LOG_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi
if [[ ! -f "$CADDYFILE" ]]; then
  echo "Missing Caddyfile: $CADDYFILE" >&2
  exit 1
fi
if [[ ! -f "$NGROK_CONFIG" ]]; then
  echo "Missing ngrok config: $NGROK_CONFIG" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

start_proc() {
  local name="$1"
  local cmd="$2"
  local pid_file="$RUN_DIR/$name.pid"
  local out_file="$LOG_DIR/$name.out.log"
  local err_file="$LOG_DIR/$name.err.log"

  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "$name already running (pid $(cat "$pid_file"))"
    return
  fi

  nohup /bin/zsh -lc "$cmd" >>"$out_file" 2>>"$err_file" &
  local pid=$!
  echo "$pid" >"$pid_file"
  echo "started $name (pid $pid)"
}

start_proc "ollama" 'export OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"; exec "$(command -v ollama)" serve'
sleep 1
start_proc "caddy-ollama" 'exec "$(command -v caddy)" run --config "'"$CADDYFILE"'"'
sleep 1
start_proc "ngrok-ollama" 'exec "$(command -v ngrok)" start --config "'"$NGROK_CONFIG"'" cursor-ollama'

echo "Stack start requested. Check status with: ./scripts/status-stack.sh"
