# Subagent delegation

When delegation is appropriate, send read-only investigation to `scout` in the background and implementation work to `delegate`. Run at most four subagents in parallel unless the user overrides this limit in the session. Give each child a self-contained task; use forked context when conversation history is needed. Use `rg` and `fd` for shell searches when available; read-only agents should use their available search tools.
