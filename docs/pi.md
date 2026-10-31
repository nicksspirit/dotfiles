# Pi

The `pi` package stows `~/.pi/agent` configuration and extensions. Its setup hook installs Pi with `curl -fsSL https://pi.dev/install.sh | sh` when `pi` is missing; otherwise it reports that the CLI is already installed. It checks the managed npm extension packages and skips `npm install` when they are satisfied. `bootstrap.sh --reinstall --package pi` forces both the CLI installer and extension-package install.

Pi's Amazon Bedrock credential is stored in `pi/.pi/agent/auth.json`; its `AWS_PROFILE` must be `claude-bedrock`, which chains the `claude` SSO profile into `SuOps-BedrockInvokeRole`. The global `settings.json` environment is not authoritative when a provider credential already has a stored `env` object. `pi/.pi/agent/npm/patches/pi-web-access+0.46.0.patch` removes `typebox` from `pi-web-access`'s dev dependencies so the host-provided wildcard peer is used; `scripts/setup-pi.sh` applies npm patches whenever it runs `npm install` (for missing/out-of-date extension packages or with `--reinstall`).

- `pi-model-filter` loads global rules from `~/.pi/model-filter.json` and gives project rules in `<project>/.pi/model-filter.json` first-match priority; the tracked `~/.pi/agent/model-filter.json` has no rules. Model IDs/providers vary by machine; examples are in `pi/pi-model-filter/README.md`.
- `pi-tmux-agent-indicator` maps Pi lifecycle events to `tmux-agent-indicator` states and does nothing when the plugin is absent.
- `pi/.pi/agent/extensions/cwd-shortener.ts` replaces the interactive footer via `ctx.ui.setFooter` to shorten the working-directory line: the leaf and its immediate parent stay full, every earlier segment collapses to its first character (two characters if that first character isn't a letter/digit, e.g. `_SketchUp` -> `_S`), and the whole line is capped at 80 characters. It rebuilds the stats/cost/context%/model/effort line from public `ExtensionContext` data since Pi's own formatting helpers for that line aren't exported by the package. Single-file extension, no build step, auto-discovered like the others.

Each extension subproject contains its own validation commands and runtime documentation.
