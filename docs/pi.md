# Pi

The `pi` package stows `~/.pi/agent` configuration and extensions. Its setup hook installs Pi with `curl -fsSL https://pi.dev/install.sh | sh` when `pi` is missing; otherwise it reports that the CLI is already installed. It checks the managed npm extension packages and skips `npm install` when they are satisfied. `bootstrap.sh --reinstall --package pi` forces both the CLI installer and extension-package install.

`settings.json` leaves the startup provider/model automatic while `enabledModels` scopes startup selection and cycling to `gpt-6-luna`; it also exports `CLAUDE_CODE_USE_BEDROCK=1`, `AWS_PROFILE=claude-bedrock`, and `AWS_REGION=us-west-2` to Pi's processes. A stored provider credential can also carry its own `env` object, which takes precedence over the global environment. `pi/.pi/agent/npm/patches/pi-web-access+0.46.0.patch` removes `typebox` from `pi-web-access`'s dev dependencies so the host-provided wildcard peer is used; `scripts/setup-pi.sh` applies npm patches whenever it runs `npm install` (for missing/out-of-date extension packages or with `--reinstall`).

- **Model filter:** Configuration locations, rule precedence, and examples are documented in [`pi-model-filter`](../pi/.pi/custom_extensions/pi-model-filter/README.md).
- **tmux agent indicator:** Maps Pi lifecycle events to `tmux-agent-indicator`; inactive if that plugin is absent.
- **Working-directory footer:** `cwd-shortener.ts` keeps the current directory and its parent readable, abbreviates earlier path segments, and caps the line at 80 characters. It rebuilds the status line using Pi's public extension API.

## Background subagents

`pi-subagents` discovers user agent definitions under `$PI_CODING_AGENT_DIR/agents/` (default `~/.pi/agent/agents/`). The stowed `delegate` and `scout` override the built-ins by name; installed package agents also precede built-ins, and trusted project definitions in `.pi/agents/` take precedence over user definitions. User and project settings can override individual agent fields. These files must be deployed on each machine.

Ask Pi to delegate implementation to `delegate` or read-only investigation to `scout` in the background. Both inherit the parent model and discovered skills by default, and inherit project instructions. `scout` is restricted to `read`, `grep`, `find`, and `ls`; it cannot run `rg` or `fd` without shell access. The four-agent parallel limit in the global `AGENTS.md` is advisory and the user may override it in a session. Give children self-contained tasks, or request forked context when they need conversation history. Background defaults can be overridden at launch. Turn budgets are per-run, not persistent per-agent limits.

### Invoking a subagent

- **Normal message:** Ask Pi, for example, “Ask scout in the background to investigate this, then use its result to answer me.” The main assistant launches the child and can incorporate its completion into its answer.
- **Direct command:** Use `/run scout Investigate the authentication flow --bg` or `/run delegate Add a test for login validation --bg`. The command selects and launches the child directly; its result is displayed, but the main assistant does not necessarily act on it. Ask a follow-up if you want the assistant to use the result.

Put `/run` flags at the **end** of the command, after the task:

- `--bg` explicitly runs in the background. These two agent definitions already default to background, so the flag is optional for them.
- `--fork` passes the current conversation context. Without it, these agents normally start fresh and need a self-contained task. A fork includes the parent's system prompt, instructions, and skills, so share context deliberately.
- Combine them as `/run scout Investigate the issue --bg --fork`. Use `/subagents` or `/subagents-fleet` to inspect runs.

For machine-specific configuration, `PI_CODING_AGENT_DIR` changes the entire Pi configuration directory, not just its agents; ensure the alternate directory also has the needed settings, packages, and credentials. Agent definitions can omit `model` to use the configured subagent default or parent model; `model: inherit` explicitly selects the parent unless a stronger per-agent or per-run override applies. Model resolution and availability depend on each machine's providers and settings; inspect the resolved model before relying on it.

Extension-specific setup and validation details live in each extension's documentation.
