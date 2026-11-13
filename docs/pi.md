# Pi

The `pi` package stows `~/.pi/agent` configuration and extensions, including the `pi-cli-guard` npm package declared in `settings.json`. Its setup hook installs Pi with `curl -fsSL https://pi.dev/install.sh | sh` when `pi` is missing; otherwise it reports that the CLI is already installed. `pi-cli-guard` is third-party code; review its package source before loading it. It checks the managed npm extension packages and skips `npm install` when they are satisfied. `bootstrap.sh --reinstall --package pi` forces both the CLI installer and extension-package install.

`settings.json` leaves the startup provider/model automatic while `enabledModels` scopes startup selection and cycling to `gpt-6-luna`; it also exports `CLAUDE_CODE_USE_BEDROCK=1`, `AWS_PROFILE=claude-bedrock`, and `AWS_REGION=us-west-2` to Pi's processes. A stored provider credential can also carry its own `env` object, which takes precedence over the global environment. `pi/.pi/agent/npm/patches/pi-web-access+0.46.0.patch` removes `typebox` from `pi-web-access`'s dev dependencies so the host-provided wildcard peer is used; `scripts/setup-pi.sh` applies npm patches whenever it runs `npm install` (for missing/out-of-date extension packages or with `--reinstall`).

- **Model filter:** Configuration locations, rule precedence, and examples are documented in [`pi-model-filter`](../pi/.pi/custom_extensions/pi-model-filter/README.md).
- **tmux agent indicator:** Maps Pi lifecycle events to `tmux-agent-indicator`; inactive if that plugin is absent.
- **Split ledger statusline:** `pi-minimal-statusline.ts` loads the local extension that places directory/branch and model identity above the editor, native usage below it, and third-party status entries on additional rows.

## Split ledger statusline

The statusline requires Pi and `@earendil-works/pi-tui` 1.5.0 or newer. Its default two core rows follow the Split ledger prototype. The shelf above the editor places directory, branch, and optional session name on the left and provider/model/thinking effort on the right. Below the editor, token/cache counters sit on the left with cost and context usage aligned right. It uses Pi's current theme and leaves tmux's Nord configuration unchanged.

Pi's native `↑`, `↓`, `R`, `W`, `CH`, `$`, `(sub)`, `%/window`, `(auto)`, and model/effort notation are retained. Subscription markers use OAuth and provider subscription metadata, with Pi's explicit Kimi Coding exception. Compaction state comes from Pi's effective settings. Usage totals include assistant messages, tool usage, summaries, compactions, and explicit usage entries across the whole session.

Extension statuses are read from Pi's live status map on every render and sorted by key. A dim `  │  ` separates entries on the same row. Each entry keeps its own text and ANSI colors. Extmgr's package/scheduler summary remains one entry, and ponytail's activity circle stays with its mode. New keys appear automatically, updates replace values, and empty or cleared entries leave no separator. Whole entries move to a new row when they do not fit. Oversized entries wrap with Pi's ANSI-aware helpers.

- `--statusline-lines 1|2|3` selects the core row count at launch and defaults to `2`.
- `/statusline 1`, `/statusline 2`, and `/statusline 3` change it until reload or exit. The row count includes the shelf above the editor. Extension rows are additional.
- One core row combines usage/model/context below the editor and includes location when space permits. Three core rows separate location, model, and usage.
- `/statusline details` opens the complete values in a full-width, scrollable overlay. Scroll with arrows, Page Up/Down, or Home/End, then press Escape or Enter to close.

Narrow panes remove the optional provider prefix, abbreviate the path, and show explicit ellipses for omitted core fields. Context and model identity take precedence in compact mode. The details view retains the full values. The shelf is attached to the editor so todo lists and other above-editor widgets stay above it as they grow or republish. An existing custom editor factory is preserved, and native editing, autocomplete, and app keybindings pass through. Disposal restores the earlier editor factory when this extension still owns the slot. A later editor replacement controls its own rendering. Another extension that calls `setFooter()` replaces this footer. Ordinary `setStatus()` publishers coexist.

Validate from `pi/.pi/custom_extensions/pi-minimal-statusline` with `npm run typecheck`, `npm test`, and `npm run build`. The focused tests compare usage output against Pi's stock footer and cover live status-map changes, Unicode/ANSI wrapping, widths, row counts, lifecycle cleanup, and the details view. After changing dependency selection, also run `bash tests/test_bootstrap.sh` from the repository root. Verify the candidate in a separate tmux session before deploying it; inspect existing home-directory targets and preview Stow changes first.

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

For a one-run model override, put `model=provider/model` in brackets immediately after the agent name, and include a task: `/run scout[model=openai/gpt-6.1-terra:low] Find the authentication flow --bg`. The optional `:low` suffix selects the thinking level. This changes neither the agent definition nor the parent model; the chosen provider and model must be available on that machine. Check the run result for the resolved model.

For machine-specific configuration, `PI_CODING_AGENT_DIR` changes the entire Pi configuration directory, not just its agents; ensure the alternate directory also has the needed settings, packages, and credentials. Agent definitions can omit `model` to use the configured subagent default or parent model; `model: inherit` explicitly selects the parent unless a stronger per-agent or per-run override applies. Model resolution and availability depend on each machine's providers and settings; inspect the resolved model before relying on it.

Extension-specific setup and validation details live in each extension's documentation.
