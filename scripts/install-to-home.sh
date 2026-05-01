#!/usr/bin/env bash
# Copy operator scripts into ~/.local/share and install ~/.local/bin wrappers + PATH snippet.
# Run from anywhere:  bash /path/to/repo/scripts/install-to-home.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/cursor-ollama-gateway/scripts"

mkdir -p "$DEST/lib"
cp "$SCRIPT_DIR/lib/paths.sh" "$DEST/lib/paths.sh"
cp "$SCRIPT_DIR/lib/install-wrappers.sh" "$DEST/lib/install-wrappers.sh"
cp "$SCRIPT_DIR/lib/service-pids.sh" "$DEST/lib/service-pids.sh"
cp "$SCRIPT_DIR/cursor-ollama-gateway.sh" "$DEST/cursor-ollama-gateway.sh"
for f in start-stack.sh stop-stack.sh status-stack.sh generate-secrets.sh; do
	cp "$SCRIPT_DIR/$f" "$DEST/$f"
done
chmod -R a+rX "$DEST"

# shellcheck source=lib/install-wrappers.sh
source "$DEST/lib/install-wrappers.sh"
install_cursor_ollama_gateway_wrappers "$DEST" "$HOME/.local/bin" ""
ensure_cursor_ollama_local_bin_on_path "$HOME/.local/bin"

echo "Installed:"
echo "  Scripts: $DEST"
echo "  Wrappers: $HOME/.local/bin/cursor-ollama-gateway, cursor-ollama-{start,stop,status}, cursor-ollama-generate-secrets"
echo "Open a new terminal or: source ~/.zprofile (or the RC file named above)."
