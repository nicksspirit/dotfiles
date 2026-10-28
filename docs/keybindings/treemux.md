# Treemux keybindings

The tmux prefix is `Ctrl-a`. Press `prefix + K` from any tmux pane to open
the keybindings folder in Neovim. In the file browser, use `j` and `k` to
choose a guide, `Enter` to open it, and `-` to return to the folder. Use `:q`
to close the popup. The sidebar is a separate Neovim window: use the tree keys
only after focusing it.

## Sidebar controls

| Key | Action |
| --- | --- |
| `prefix + Tab` | Toggle the sidebar. |
| `prefix + Backspace` | Toggle the sidebar and focus it. |

## nvim-tree navigation and opening

Treemux installs the nvim-tree defaults, then replaces some mappings to open
the selected path in Treemux, the main pane, or a tmux split.

| Key | Action |
| --- | --- |
| `R` | Refresh the tree. |
| `u` | Change the tree root to the selected directory. |
| `h` | Close the current directory node. |
| `Enter`, `l`, `Ctrl-t`, or double-click | Open the selected path in Treemux. |
| `Tab` | Open the selected file in an 85% × 85% tmux popup running Neovim. |
| `o` | Open the selected path in the main pane without creating a tmux split. |
| `v` or `Ctrl-v` | Open the selected path in a vertical tmux split. |
| `Ctrl-x` | Open the selected path in a horizontal tmux split. |
| `F1` | Show information about the selected node. |

## File operations

Use normal Neovim motions such as `j` and `k` to select an entry. The
following nvim-tree defaults remain available:

| Task | Key | Notes |
| --- | --- | --- |
| Open or expand the selection | `Enter` or `l` | Files open in the main Treemux editor; directories open locally in the tree. |
| Close a directory | `h` or `Backspace` | Closes the selected directory node. |
| Make the selected directory the root | `u` or `Ctrl-]` | `u` is configured; `Ctrl-]` is the nvim-tree default. |
| Create a file or directory | `a` | End the name with `/` to create a directory. |
| Rename | `r` | `e` renames only the basename. |
| Copy / cut / paste | `c` / `x` / `p` | Select a destination directory before pasting. |
| Delete / move to trash | `d` / `D` | Confirm the prompted operation. |
| Copy filename / relative path / absolute path | `y` / `Y` / `gy` | Copies to the nvim-tree clipboard. |
| Show or hide dotfiles | `H` | |
| Expand or collapse the entire tree | `E` / `W` | |
| Filter entries | `f` / `F` | Start / clear the live filter. |
| Show the live keymap | `g?` | Shows mappings for the installed nvim-tree version. |

## File-explorer switching

| Key | Action |
| --- | --- |
| `Space o` | Toggle between nvim-tree and Oil, preserving the selected path. |
| `Space nn` | Toggle Neo-tree. |

In the Neo-tree window, `Space o` opens the selected location in Oil.

The nvim-tree mappings `-`, `Ctrl-k`, `O`, and `q` are intentionally disabled
in Treemux. `F1` replaces the node-information shortcut, and `Tab` opens a
tmux popup instead of the usual nvim-tree preview.
