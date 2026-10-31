# pi-model-filter

Filter and block models from any provider in pi via declarative allow/block rules.

Hide unwanted GitHub Copilot models, enforce global allowlists, block by reasoning capability or context window size — all through a simple JSON config.

## Install

This repository deploys the extension through the `pi` Stow package. The stowed wrapper at `pi/.pi/agent/extensions/pi-model-filter.ts` re-exports `pi/pi-model-filter/src/extension.ts`.

## Configuration

Use `~/.pi/model-filter.json` for global rules and `<project>/.pi/model-filter.json` for project rules. Project rules are evaluated first; unmatched models fall through to global rules, whose `defaultAction` is retained. The tracked Stow config at `~/.pi/agent/model-filter.json` is intentionally empty and does not impose a shared model policy.

### Schema

```typescript
interface FilterRule {
  provider: string;      // "*" = any provider
  action: "allow" | "block";
  match: {
    ids?: string[];                    // exact model ID match (OR)
    patterns?: string[];               // glob patterns (OR), supports * and ?
    reasoning?: boolean;               // match reasoning capability
    contextWindow?: { min?: number; max?: number }; // match context window size
  };
}

interface FilterConfig {
  rules: FilterRule[];                 // evaluated top-to-bottom, first match wins
  defaultAction: "allow" | "block";   // default: "allow"
}
```

### Rule evaluation

- Rules are evaluated **top to bottom** — first matching rule wins.
- Within a match field, alternatives are **OR'd** (e.g., `ids: ["a", "b"]` matches either).
- Across different match fields, conditions are **AND'd** (e.g., `ids + reasoning` must both match).
- If no rule matches, `defaultAction` applies.
- Invalid or missing config fails open: all models pass through with a warning.

### Examples

Model IDs and providers available to Pi vary by machine. Put machine-specific rules in `~/.pi/model-filter.json` and project-specific rules in `<project>/.pi/model-filter.json`. For example, to show only OpenAI GPT-6-family IDs globally:

```json
{
  "rules": [
    { "provider": "openai", "action": "allow", "match": { "patterns": ["gpt-6*"] } },
    { "provider": "openai", "action": "block", "match": { "patterns": ["*"] } }
  ],
  "defaultAction": "allow"
}
```

To show only cloud-backed Ollama models in a project, leaving other providers untouched, save this as `<project>/.pi/model-filter.json`:

```json
{
  "rules": [
    { "provider": "ollama", "action": "allow", "match": { "patterns": ["*-cloud"] } },
    { "provider": "ollama", "action": "block", "match": { "patterns": ["*"] } }
  ],
  "defaultAction": "allow"
}
```

To restrict all providers, use a global block rule after the provider-specific allow rules and set `defaultAction` to `block`.

**Block non-reasoning models:**

```json
{
  "rules": [
    { "provider": "*", "action": "block", "match": { "reasoning": false } }
  ],
  "defaultAction": "allow"
}
```

**Block small context windows:**

```json
{
  "rules": [
    { "provider": "*", "action": "block", "match": { "contextWindow": { "max": 150000 } } }
  ],
  "defaultAction": "allow"
}
```

## How it works

The extension patches both `ModelRuntime.prototype` and the compatibility `ModelRegistry.prototype` at load time (before startup model resolution) so filtered models are hidden from `/model`, `--list-models`, `--model` CLI flags, and request auth resolution. It does not mutate either surface's internal model collections — filtering happens on method results. Configuration is watched and reloaded with a short debounce; invalid reloads fail open.

### Failure behavior

- **Missing or invalid config**: all models pass through, warning logged.
- **pi internals change**: extension detects missing methods and disables itself with a warning.
- **Hot reload**: edits to existing global or project `model-filter.json` files take effect without restarting pi. Start a new Pi session after creating a previously absent project config.

## Development

```sh
cd pi/pi-model-filter
npm install
npm test
npm run typecheck
npm run build
```

