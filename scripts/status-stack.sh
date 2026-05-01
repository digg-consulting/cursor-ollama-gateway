#!/usr/bin/env bash
set -euo pipefail

RUN_DIR="${RUN_DIR:-/usr/local/var/run/cursor-ollama-gateway}"
LOG_DIR="${LOG_DIR:-/usr/local/var/log/cursor-ollama-gateway}"

show_proc() {
  local name="$1"
  local pid_file="$RUN_DIR/$name.pid"

  if [[ -f "$pid_file" ]]; then
    local pid
    pid="$(cat "$pid_file")"
    if kill -0 "$pid" 2>/dev/null; then
      echo "$name: running (pid $pid)"
      return
    fi
    echo "$name: stale pid file ($pid)"
    return
  fi
  echo "$name: stopped"
}

show_proc "ollama"
show_proc "caddy-ollama"
show_proc "ngrok-ollama"

echo
echo "Log files:"
echo "  $LOG_DIR/ollama.out.log"
echo "  $LOG_DIR/ollama.err.log"
echo "  $LOG_DIR/caddy-ollama.out.log"
echo "  $LOG_DIR/caddy-ollama.err.log"
echo "  $LOG_DIR/ngrok-ollama.out.log"
echo "  $LOG_DIR/ngrok-ollama.err.log"
