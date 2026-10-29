# Treemux sidebar

The `treemux` package stows `~/.config/treemux/treemux_init.lua`. Keep this
configuration outside `~/.tmux/plugins/treemux/`, which TPM owns and updates.

Treemux runs a separate Neovim sidebar process, independent of the main LazyVim editor. It uses `nvim-tree`, `nvim-tree-remote.nvim`, filesystem watchers, and reload-on-buffer-enter. The main editor does not load a tree plugin.

Package-scoped bootstrap selects `tmux`, `nvim`, and `uv` with Treemux.

`~/.tmux.conf` selects `nvim-tree` and the Python 3.14 environment created by `scripts/setup-treemux.sh` at `~/.local/share/treemux-venv/`. Each setup run recreates this environment with `uv venv --clear` before installing `neovim`, so reruns do not prompt before replacing an existing environment.

If TPM reports a Treemux download failure, check `~/.tmux/plugins/treemux` for
a dangling symlink; remove the link itself before retrying the install.

See the [Treemux keybindings](keybindings/treemux.md) for the sidebar,
nvim-tree, and file-explorer shortcuts.
