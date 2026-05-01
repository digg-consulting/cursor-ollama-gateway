# Security Policy

## Supported Versions

This project is currently maintained on the default branch only.

## Reporting a Vulnerability

Please do not open public GitHub issues for potential vulnerabilities.

Instead, report security concerns privately to the maintainers through your preferred private channel (for example, direct email or private security intake).

When reporting, include:

- A description of the issue and impact.
- Reproduction steps or proof of concept.
- Any suggested mitigations.

## Secrets and Hardening Notes

- Never commit `.env` files or production tokens.
- Rotate `OLLAMA_PROXY_TOKEN` immediately if exposure is suspected.
- Rotate `NGROK_AUTHTOKEN` immediately if exposure is suspected.
- Keep Ollama bound to `127.0.0.1` only.
- Keep ngrok inspector disabled unless actively debugging.
