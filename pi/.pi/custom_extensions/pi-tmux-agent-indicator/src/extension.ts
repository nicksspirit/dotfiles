import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { spawn } from "node:child_process";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** States accepted by agent-state.sh. */
export type AgentState = "running" | "needs-input" | "done" | "off";

/** Minimal interface for the spawn function, replaceable in tests. */
export type SpawnFn = (
  cmd: string,
  args: string[],
  opts: { stdio: "ignore"; detached: boolean },
) => { unref(): void };

// ---------------------------------------------------------------------------
// Plugin path resolution
// ---------------------------------------------------------------------------

const PLUGIN_RELATIVE =
  ".tmux/plugins/tmux-agent-indicator/scripts/agent-state.sh";

/**
 * Returns the absolute path to agent-state.sh, or undefined when the plugin
 * is not installed.
 */
export function resolveAgentStatePath(
  home?: string,
  exists: (path: string) => boolean = existsSync,
): string | undefined {
  const h = home ?? homedir();
  const candidate = join(h, PLUGIN_RELATIVE);
  return exists(candidate) ? candidate : undefined;
}

// ---------------------------------------------------------------------------
// State dispatch
// ---------------------------------------------------------------------------

/**
 * Fire-and-forget call to agent-state.sh.
 *
 * Errors (script not found, tmux not running, etc.) are swallowed so the
 * extension never interrupts Pi. The script is spawned detached and
 * immediately unreffed, so it does not block the Node.js event loop.
 */
export function sendState(
  state: AgentState,
  scriptPath: string,
  spawnFn: SpawnFn = spawn,
): void {
  try {
    const child = spawnFn(scriptPath, ["--agent", "pi", "--state", state], {
      stdio: "ignore",
      detached: true,
    });
    child.unref();
  } catch {
    // Intentionally silent: plugin may not be running or tmux may be absent.
  }
}

// ---------------------------------------------------------------------------
// Extension entry point
// ---------------------------------------------------------------------------

export default function piTmuxAgentIndicator(
  pi: any,
  scriptPath: string | undefined = resolveAgentStatePath(),
  spawnFn: SpawnFn = spawn,
): void {
  if (!scriptPath) {
    // Plugin not installed; extension is a no-op but does not error.
    return;
  }

  let state: AgentState = "done";
  let promptDepth = 0;
  let stateBeforePrompt: AgentState = "done";
  const setState = (next: AgentState) => {
    state = next;
    sendState(next, scriptPath, spawnFn);
  };

  // before_agent_start: user submitted a prompt; agent loop is about to start.
  pi.on("before_agent_start", () => {
    setState("running");
  });

  // tool_execution_start: a tool invocation begins inside a running agent turn.
  pi.on("tool_execution_start", () => {
    setState("running");
  });

  // Pi emits these for blocking extension UI; restore the prior state when it closes.
  pi.on("ui_prompt_start", () => {
    if (promptDepth++ === 0) stateBeforePrompt = state;
    setState("needs-input");
  });
  pi.on("ui_prompt_end", () => {
    if (promptDepth > 0 && --promptDepth === 0) setState(stateBeforePrompt);
  });

  // agent_settled: Pi will not continue running automatically; agent is idle.
  pi.on("agent_settled", () => {
    promptDepth = 0;
    setState("done");
  });

  // session_shutdown: session is ending; clear indicator.
  pi.on("session_shutdown", () => {
    promptDepth = 0;
    setState("off");
  });
}
