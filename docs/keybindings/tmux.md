# tmux keybindings

The tmux prefix is `Ctrl-a`.

## Prefix bindings

| Key | Action |
| --- | --- |
| `prefix + \` | Open the tmux-menus popup. |
| `prefix + Ctrl-y` | Open Lazygit in a popup. |
| `prefix + Ctrl-t` | Open a shell in a popup. |
| `prefix + K` | Browse the keybindings guides in a Neovim popup. |
| `prefix + f` | Open the tmux-fzf selector. |
| `prefix + Ctrl-w` | Enter the layout table. |

## Layout table

Press `Ctrl-w` directly or `prefix + Ctrl-w` to enter this table.

| Key | Action |
| --- | --- |
| `h` / `j` / `k` / `l` | Move focus left / down / up / right. |
| `H` / `J` / `K` / `L` | Swap the current pane with the pane left / below / above / right. |
| `\|` | Split the current pane horizontally. |
| `-` | Split the current pane vertically. |
| `z` | Toggle pane zoom. |
| `x` | Close the current pane. |
| `1` / `2` / `3` / `4` | Select even-horizontal / even-vertical / main-vertical / tiled layout. |

## Copy mode

| Key | Action |
| --- | --- |
| `Space` | Start selection. |
| `y` | Copy selection and exit copy mode. |
| `q` | Exit copy mode. |

## tmux-fzf selector

| Key | Action |
| --- | --- |
| `Tab` / `Shift-Tab` | Mark selector items where multi-selection is supported. |
