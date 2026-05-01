#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: env file not found at $ENV_FILE" >&2
  exit 1
fi

new_token="$(openssl rand -base64 72 | tr -d '\n' | tr '/+' '_-')"

if rg -q '^OLLAMA_PROXY_TOKEN=REPLACE_WITH_LONG_RANDOM_SECRET$' "$ENV_FILE"; then
  sed -i '' "s|^OLLAMA_PROXY_TOKEN=.*$|OLLAMA_PROXY_TOKEN=${new_token}|" "$ENV_FILE"
  echo "Updated OLLAMA_PROXY_TOKEN in $ENV_FILE"
else
  echo "Generated token (paste manually into $ENV_FILE):"
  echo "${new_token}"
fi

chmod 600 "$ENV_FILE"
echo "Done."
