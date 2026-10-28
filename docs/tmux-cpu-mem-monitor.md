# tmux CPU/MEM monitor

The `tmux-cpu-mem-monitor` package vendors a fork of `hendrikmi/tmux-cpu-mem-monitor` at `~/.tmux/plugins/tmux-cpu-mem-monitor`.

Its wrapper owns the CPU/MEM `status-right` segment. It runs metrics with the Python interpreter in `~/.local/share/tmux-cpu-mem-monitor-venv/`, rewrites CPU, memory, disk, and battery placeholders in tmux status formats, and preserves the `tmux-prefix-highlight` and agent-indicator placeholders. `scripts/setup-tmux.sh` creates that environment when needed and syncs its `psutil==6.0.0` dependency from the plugin's `uv.lock`. Any old plugin-local `.venv` is no longer used and can be removed manually.

The related tmux configuration is documented in [`tmux.md`](tmux.md).
