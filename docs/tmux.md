# tmux

The `tmux` package manages `~/.tmux.conf` and configures TPM plugins.

## Current configuration

- tmux uses `tmux-256color`, truecolor terminal features, CSI-u extended keys, `Ctrl-A` prefix, one-based pane/window numbering, mouse mode, and a bottom status bar.
- `update-environment` carries the D-Bus, GNOME keyring, and runtime-directory variables from attaching clients into tmux.
- The Nord styled status bar shows prefix highlighting, CPU/MEM metrics, the battery icon and percentage (⚡ while charging), and tmux-agent-indicator session markers; numbered icons mark idle sessions.
- `tmux-menus` provides popup menus; `tmux-fzf` provides interactive selectors.
- Package-scoped bootstrap of `tmux` selects `fzf` and `local-bin`, and installs Git and `patch` for plugin setup.

Reload a running server with `tmux source-file ~/.tmux.conf`; never run `tmux kill-server` inside a session.

See the [tmux keybindings](keybindings/tmux.md), [Treemux overview](treemux.md),
and [`tmux-cpu-mem-monitor.md`](tmux-cpu-mem-monitor.md) for the vendored
metric wrapper. Package-scoped bootstrap of `tmux` also deploys the
`local-bin` helpers it calls.
