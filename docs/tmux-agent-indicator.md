# tmux-agent-indicator

`tmux-agent-indicator` is configured in this repository:

- `tmux/.tmux.conf` configures the plugin through TPM, appends its placeholders after the CPU/MEM wrapper, uses numbered icons (`➊`–`➎`) for idle sessions, and configures Pi (`π`), Cortex, Coco, and Copilot process fallback. `scripts/setup-tmux.sh` installs TPM and its plugins.
- `tmux/patches/tmux-agent-indicator-session-dots.patch` extends the upstream session-dot script with numbered idle-session markers and worker states, handles stale seen-session markers without blanking the segment, and clears `needs-input` once its source pane is focused; `scripts/setup-tmux.sh` applies it after TPM installation.
- `tmux-cpu-mem-monitor/.tmux/plugins/tmux-cpu-mem-monitor/tmux_cpu_mem_monitor.tmux` preserves the Nord CPU/MEM segment while carrying the indicator placeholders to the final interpolation step.
- `pi/pi-tmux-agent-indicator/` contains the Stow-managed Pi extension.
- `pi/.pi/agent/extensions/pi-tmux-agent-indicator.ts` is the deployed extension entrypoint.

The extension is silent when the plugin is absent and does not block Pi while
calling `agent-state.sh`.

## Window tab styling

`tmux/.tmux.conf` overrides Nord's window formats after TPM loads the theme.
The label inherits `window-status-style` or `window-status-current-style`;
the arrow separators extract the same style's background color. This lets the
plugin color the whole tab yellow for `needs-input` or red for `done`, instead
of leaving Nord's hard-coded grey label inside a colored edge. Pane background
coloring remains disabled by default.

The plugin restores the window styles when attention is acknowledged or a new
turn starts. Ordinary inactive tabs use white on grey; the current tab uses
black on cyan. `bash tests/test_tmux_window_status.sh` checks both tab formats
for ordinary, attention, and restored styles in an isolated tmux server.

## Add more numbered idle icons

Numbered icons are assigned by tmux session order. To add more:

1. Add the new glyph to `@agent-indicator-session-dots-idle` in `tmux/.tmux.conf`.
2. Add the same glyph to the default `IDLE_SYMBOLS` list in `tmux/patches/tmux-agent-indicator-session-dots.patch`.
3. Run `./scripts/setup-tmux.sh` to install the patched script.
4. Reload tmux with `tmux source-file ~/.tmux.conf`.

For example, add `➏` after `➎` in both files. Idle sessions without a matching
glyph use the inactive fallback symbol (`○`). Running, done, and needs-input
markers still take priority over idle numbers.
