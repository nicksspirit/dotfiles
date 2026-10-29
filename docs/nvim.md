# Neovim

The `nvim` package manages the LazyVim-style configuration under `~/.config/nvim/`. Lazy.nvim stores its machine-local plugin lockfile under Neovim's state directory, outside the Stow package.

`scripts/setup-tools.sh` installs Neovim from the official release tarball in `~/.local/opt/nvim-linux-x86_64/` and links `~/.local/bin/nvim`. After stowing, `scripts/setup-nvim.sh` runs `nvim --headless "+Lazy! sync" +qa`.

## Current configuration

- LazyVim imports local plugins; the configured colorscheme is Nord with a local transparent-background override.
- Options enable truecolor, relative line numbers, two-space indentation, wrapping, mouse support, and clipboard integration. The `nvim` bootstrap unit installs `xclip` for the `unnamedplus` clipboard provider, Git for plugins, build tools for parsers, and ripgrep for search.
- Folding uses Tree-sitter-based `foldexpr`, starts fully unfolded (`foldlevelstart = 99`), and exposes quick fold-level/fold-method commands through the Legendary command palette.
- `legendary.nvim` provides the `<leader>p` command palette and `render-markdown.nvim` provides Markdown rendering.
- `rambo.nvim` provides editor-style movement, selection, and editing in Insert and Select modes. Lazy.nvim installs and configures it during the Neovim bootstrap.
- Plugin versions are locked locally at `stdpath("state")/lazy-lock.json`; separate machines can update plugins without changing this repository.

`nvim-tree` is used only by the separate Treemux sidebar process; the main
LazyVim editor uses Telescope for file navigation. See the [Neovim
keybindings](keybindings/nvim.md), [Treemux overview](treemux.md), and
[Treemux keybindings](keybindings/treemux.md).
