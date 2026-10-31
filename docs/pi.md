# Pi

The `pi` package stows `~/.pi/agent` configuration and extensions. Its setup hook installs Pi with `curl -fsSL https://pi.dev/install.sh | sh` when `pi` is missing; otherwise it reports that the CLI is already installed. It checks the managed npm extension packages and skips `npm install` when they are satisfied. `bootstrap.sh --reinstall --package pi` forces both the CLI installer and extension-package install.

`settings.json` leaves the startup provider/model automatic while `enabledModels` scopes startup selection and cycling to `gpt-6-luna`; it also exports `CLAUDE_CODE_USE_BEDROCK=1`, `AWS_PROFILE=claude-bedrock`, and `AWS_REGION=us-west-2` to Pi's processes. A stored provider credential can also carry its own `env` object, which takes precedence over the global environment. `pi/.pi/agent/npm/patches/pi-web-access+0.46.0.patch` removes `typebox` from `pi-web-access`'s dev dependencies so the host-provided wildcard peer is used; `scripts/setup-pi.sh` applies npm patches whenever it runs `npm install` (for missing/out-of-date extension packages or with `--reinstall`).

- **Model filter:** Configuration locations, rule precedence, and examples are documented in [`pi-model-filter`](../pi/.pi/custom_extensions/pi-model-filter/README.md).
- **tmux agent indicator:** Maps Pi lifecycle events to `tmux-agent-indicator`; inactive if that plugin is absent.
- **Working-directory footer:** `cwd-shortener.ts` keeps the current directory and its parent readable, abbreviates earlier path segments, and caps the line at 80 characters. It rebuilds the status line using Pi's public extension API.

Extension-specific setup and validation details live in each extension's documentation.
