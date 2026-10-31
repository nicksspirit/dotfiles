# Pi

The `pi` package stows `~/.pi/agent` configuration and extensions. Its setup hook installs Pi with `curl -fsSL https://pi.dev/install.sh | sh` when `pi` is missing; otherwise it reports that the CLI is already installed. It checks the managed npm extension packages and skips `npm install` when they are satisfied. `bootstrap.sh --reinstall --package pi` forces both the CLI installer and extension-package install.

Pi's Amazon Bedrock credential is stored in `pi/.pi/agent/auth.json`; its `AWS_PROFILE` must be `claude-bedrock`, which chains the `claude` SSO profile into `SuOps-BedrockInvokeRole`. The global `settings.json` environment is not authoritative when a provider credential already has a stored `env` object. `pi/.pi/agent/npm/patches/pi-web-access+0.46.0.patch` removes `typebox` from `pi-web-access`'s dev dependencies so the host-provided wildcard peer is used; `scripts/setup-pi.sh` applies npm patches whenever it runs `npm install` (for missing/out-of-date extension packages or with `--reinstall`).

- **Model filter:** Configuration locations, rule precedence, and examples are documented in [`pi-model-filter`](../pi/.pi/custom_extensions/pi-model-filter/README.md).
- **tmux agent indicator:** Maps Pi lifecycle events to `tmux-agent-indicator`; inactive if that plugin is absent.
- **Working-directory footer:** `cwd-shortener.ts` keeps the current directory and its parent readable, abbreviates earlier path segments, and caps the line at 80 characters. It rebuilds the status line using Pi's public extension API.

Extension-specific setup and validation details live in each extension's documentation.
