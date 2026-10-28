# Neovim keybindings

## General

| Key | Modes | Action |
| --- | --- | --- |
| `<leader>p` | Normal, insert, visual | Open the Legendary command palette. |
| `<C-s>` | Normal, insert, visual | Save the current file. |
| `<C-z>` | Normal, insert, visual | Undo; the visual mapping returns to normal mode first. |
| `u` | Normal | Undo. |
| `<C-r>` | Normal | Redo. |

## Rambo

These shortcuts apply in Insert and Select modes. Modified keys, particularly Alt and Ctrl+arrow, depend on terminal support.

| Key | Action |
| --- | --- |
| `Ctrl` + Left/Right | Move by word. |
| `Ctrl` + Up/Down | Move by paragraph. |
| `Ctrl` + Home/End | Move to the start/end of the file. |
| `Shift` + movement | Select text; add `Ctrl` for larger jumps. |
| `Ctrl` + A | Select all. |
| `Shift` + Space | Toggle characterwise and linewise selection. |
| `Insert` | Switch between Select and Visual modes. |
| `Alt` + Up/Down | Move the current line or selected lines. |
| Left/Right | Dedent/indent selected lines. |
| `Alt` + `Shift` + Up/Down | Scroll the window. |
| Wrapping character, such as `)` | Wrap the selected text. |
| `Ctrl` + C/X/V | Copy/cut/paste. |
| `Ctrl` + S | Save. |
| `Ctrl` + Z/Y | Undo/redo. |
| `Ctrl` + F | Search; use selected text as the query when selected. |
| `F2` / `F3` | Navigate search results. |
| `F4` | Clear search highlighting. |

## Folds

| Key | Action |
| --- | --- |
| `zM` | Close all folds. |
| `zR` | Open all folds. |
| `za` | Toggle the fold under the cursor. |
| `zc` | Close the fold under the cursor. |
| `zo` | Open the fold under the cursor. |
