# tmux CPU/MEM monitor

The `tmux-cpu-mem-monitor` package vendors a fork of `hendrikmi/tmux-cpu-mem-monitor` at `~/.tmux/plugins/tmux-cpu-mem-monitor`.

Package-scoped bootstrap selects `tmux` and `uv` with the monitor.

## Status segment

The wrapper manages the CPU/MEM/battery `status-right` segment:

- Replaces CPU, memory, disk, and battery placeholders.
- Preserves the `tmux-prefix-highlight` and agent-indicator placeholders.
- Shows the configured battery icon and percentage, ⚡ while charging, or `N/A` when no battery is available.

## Python environment

- Metrics run with Python 3.14 from `~/.local/share/tmux-cpu-mem-monitor-venv/`.
- Each run of `scripts/setup-tmux.sh` recreates the environment with `uv venv --clear` and syncs the locked `psutil==6.0.0` dependency from the plugin's `uv.lock`.
- The old plugin-local `.venv` is unused and can be removed.

The related tmux configuration is documented in [`tmux.md`](tmux.md).
