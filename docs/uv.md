# uv

Python package and runtime manager.

`scripts/setup-tools.sh` installs uv with its official installer at
`~/.local/bin/uv`.

## Important configuration paths

- `~/.local/bin/uv` — uv binary installed by bootstrap
- `~/.local/share/uv/python/` — uv-managed Python installations

## Managed Python

`scripts/setup-postinstall.sh` prints this follow-up command when `uv` is
available, and marks it `done` when the Python is already installed:

```sh
uv python install 3.14
python3.14 --version
```

The `3.14` request lets uv install the latest available Python 3.14 patch for
the current uv release metadata instead of pinning a patch version in this repo.

## Key commands

```sh
uv python list          # list available and installed Python versions
uv python install 3.14  # install the latest available Python 3.14 patch
uv python dir           # show uv's managed Python install directory
uv python find 3.14     # show the resolved Python 3.14 executable
```
