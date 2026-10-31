# tmux CPU/MEM monitor

The `tmux-cpu-mem-monitor` package vendors a fork of `hendrikmi/tmux-cpu-mem-monitor` at `~/.tmux/plugins/tmux-cpu-mem-monitor`.

Package-scoped bootstrap selects `tmux` and `uv` with the monitor.

## Deployment

The package registry passes `--no-folding` to Stow. This keeps `~/.tmux`
and `~/.tmux/plugins` as real directories, so TPM downloads stay outside
the repository. The monitor's files remain managed by Stow.

Older deployments can have `~/.tmux` or `~/.tmux/plugins` linked into this
package. `scripts/setup-tmux.sh` refuses to run TPM when the plugin directory
resolves inside the checkout. It preserves the existing links and files.
Before retrying, preserve and move the generated TPM plugin directories to
a real `~/.tmux/plugins` directory outside the checkout, remove only the
verified parent symlinks, and deploy the monitor through bootstrap. Keep
the vendored monitor source in this package. Do not commit downloaded
plugins or discard them while a running tmux session uses them.

Validate deployment changes with `bash tests/test_bootstrap.sh` and
`bash tests/test_tmux_setup.sh`. The latter exercises the unsafe existing
layouts and uses real Stow when available to check fresh and repeat
deployments without touching the user's home directory.

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
