#!/usr/bin/env bash
# Install small launcher scripts onto PATH and optionally prepend ~/.local/bin to shell RC files.
# Designed to be sourced from install-standard-layout.sh or curl+sourced from deploy.sh.
#
# Third argument: optional "sudo" — used when installing wrappers under /usr/local/bin.

_write_gateway_wrapper() {
	local maybe_sudo="$1"
	local dest="$2"
	local script_path="$3"
	local tmp
	tmp="$(mktemp)"
	cat >"$tmp" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec bash "$script_path" "\$@"
EOF
	if [[ -n "$maybe_sudo" ]]; then
		sudo install -m 0755 "$tmp" "$dest"
	else
		install -m 0755 "$tmp" "$dest"
	fi
	rm -f "$tmp"
}

_write_cursor_ollama_gateway_invoker() {
	local maybe_sudo="$1"
	local dest="$2"
	local script_root="$3"
	local subcommand="$4"
	local tmp
	tmp="$(mktemp)"
	cat >"$tmp" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec bash "$script_root/cursor-ollama-gateway.sh" $subcommand "\$@"
EOF
	if [[ -n "$maybe_sudo" ]]; then
		sudo install -m 0755 "$tmp" "$dest"
	else
		install -m 0755 "$tmp" "$dest"
	fi
	rm -f "$tmp"
}

install_cursor_ollama_gateway_wrappers() {
	local script_root="$1"
	local wrapper_bin="$2"
	local maybe_sudo="${3:-}"

	if [[ -n "$maybe_sudo" ]]; then
		sudo mkdir -p "$wrapper_bin"
	else
		mkdir -p "$wrapper_bin"
	fi

	_write_gateway_wrapper "$maybe_sudo" "$wrapper_bin/cursor-ollama-gateway" "$script_root/cursor-ollama-gateway.sh"
	_write_cursor_ollama_gateway_invoker "$maybe_sudo" "$wrapper_bin/cursor-ollama-start" "$script_root" start
	_write_cursor_ollama_gateway_invoker "$maybe_sudo" "$wrapper_bin/cursor-ollama-stop" "$script_root" stop
	_write_cursor_ollama_gateway_invoker "$maybe_sudo" "$wrapper_bin/cursor-ollama-status" "$script_root" status
	_write_gateway_wrapper "$maybe_sudo" "$wrapper_bin/cursor-ollama-generate-secrets" "$script_root/generate-secrets.sh"
}

# Prepend ~/.local/bin to PATH in the user's shell RC when wrappers live there.
ensure_cursor_ollama_local_bin_on_path() {
	local wrapper_bin="$1"
	local marker="cursor-ollama-gateway PATH"

	[[ "$wrapper_bin" == "$HOME/.local/bin" ]] || return 0

	local bin="$HOME/.local/bin"
	local path_token=":${PATH:-}:"

	if [[ "$path_token" == *":${bin}:"* ]]; then
		echo "Note: ~/.local/bin is already on PATH in this shell session."
	fi

	local rc=""
	for candidate in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc"; do
		if [[ -f "$candidate" ]] && grep -q "$marker" "$candidate" 2>/dev/null; then
			echo "PATH snippet already installed ($candidate)."
			return 0
		fi
	done

	for candidate in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc"; do
		if [[ -f "$candidate" ]]; then
			rc="$candidate"
			break
		fi
	done

	rc="${rc:-$HOME/.zprofile}"

	if [[ -f "$rc" ]] && grep -q "$marker" "$rc" 2>/dev/null; then
		return 0
	fi

	{
		echo ""
		echo "# >>> ${marker} (cursor-ollama-gateway)"
		echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
		echo "# <<< ${marker}"
	} >>"$rc"

	echo "Prepended ~/.local/bin to PATH via $rc (open a new terminal or: source \"$rc\")."
}
