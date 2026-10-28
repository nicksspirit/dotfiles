# tmux CPU/MEM monitor

The `tmux-cpu-mem-monitor` package vendors a fork of `hendrikmi/tmux-cpu-mem-monitor` at `~/.tmux/plugins/tmux-cpu-mem-monitor`.

Its wrapper owns the CPU/MEM/battery `status-right` segment. It runs metrics with the Python 3.14 interpreter in `~/.local/share/tmux-cpu-mem-monitor-venv/`, rewrites CPU, memory, disk, and battery placeholders in tmux status formats, and preserves the `tmux-prefix-highlight` and agent-indicator placeholders. The status line shows battery percentage or charging state (`N/A` when no battery is available). Each `scripts/setup-tmux.sh` run recreates this environment with `uv venv --clear` and syncs its locked `psutil==6.0.0` dependency from the plugin's `uv.lock`. Any old plugin-local `.venv` is no longer used and can be removed manually.

The related tmux configuration is documented in [`tmux.md`](tmux.md).
