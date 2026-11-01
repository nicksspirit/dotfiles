# btop

The `btop` bootstrap package installs btop from apt and stows `btop/.config/btop/btop.conf` to `~/.config/btop/btop.conf`. The tracked configuration was adopted from the existing home config (btop 1.3.2, `Default` theme), so it preserves those settings.

Preview installation and Stow changes with `./bootstrap.sh --dry-run --package btop`. Before deploying manually, follow the [Stow safety guide](agents/stow.md) and inspect any existing target in `$HOME` before replacing it.
