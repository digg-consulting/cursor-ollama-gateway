#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/paths.sh
source "$SCRIPT_DIR/lib/paths.sh"

ENV_FILE="${ENV_FILE:-$CONFIG_DIR/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
	echo "ERROR: env file not found at $ENV_FILE" >&2
	echo "Run ./scripts/install-standard-layout.sh or deploy.sh first." >&2
	exit 1
fi

new_token="$(openssl rand -base64 72 | tr -d '\n' | tr '/+' '_-')"

if grep -q '^OLLAMA_PROXY_TOKEN=REPLACE_WITH_LONG_RANDOM_SECRET$' "$ENV_FILE"; then
	sed -i '' "s|^OLLAMA_PROXY_TOKEN=.*$|OLLAMA_PROXY_TOKEN=${new_token}|" "$ENV_FILE"
	echo "Updated OLLAMA_PROXY_TOKEN in $ENV_FILE"
else
	echo "Generated token (paste manually into $ENV_FILE):"
	echo "${new_token}"
fi

chmod 600 "$ENV_FILE"
echo "Done."
