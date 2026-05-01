# Contributing

Thanks for contributing.

## Development Workflow

1. Fork or branch from the default branch.
2. Make focused changes with clear commit messages.
3. Update documentation for behavior or operations changes (including **`docs/`** when relevant).
4. Validate scripts/config changes locally before opening a PR.

## Local Validation Checklist

From the repository root, after **`bash scripts/install-standard-layout.sh`**, validate Caddy against your effective config path:

```bash
caddy validate --config "${XDG_CONFIG_HOME:-$HOME/.config}/cursor-ollama-gateway/Caddyfile"
```

If **`caddy`** is not found, ensure Homebrew is on **`PATH`** (`eval "$(/opt/homebrew/bin/brew shellenv)"` or Intel **`/usr/local/bin/brew`**) or invoke **`/opt/homebrew/bin/caddy`** / **`/usr/local/bin/caddy`** explicitly.

- Verify `start-stack.sh`, `status-stack.sh`, and `stop-stack.sh` behavior.
- Confirm no secrets are added to tracked files.

## Pull Request Guidelines

- Keep PRs small and focused.
- Explain operational impact in the PR description.
- Add rollback notes if changing runtime paths or startup behavior.

## Security

If your change touches authentication, token handling, or network exposure, include threat considerations in the PR notes.
