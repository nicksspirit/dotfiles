# Bash

The `bash` package manages `~/.bashrc` and `~/.bash_aliases`.

## Current configuration

- Interactive Bash uses `LANG=C.UTF-8`, enables completion when system files are present, and prepends `~/.local/bin` to `PATH`.
- `MICRO_TRUECOLOR=1` is exported.
- `~/.bash_aliases` defines `bat`, `bathelp`, and a `help()` function that formats command help with `batcat`.
- `claude-usage` runs the current Claude usage tracker; tracker options such as `--today`, `--month current`, and `--budget` are passed through to the script.
- Starship, fzf, zoxide, and fnm initialize only when their commands or startup files are available.
- `gh-browser` supplies the `BROWSER` command used by `gh auth login`.
- Optional integrations initialize only when their commands or files exist; no host-specific home, Windows, or temporary-directory paths are assumed.
- The keychain startup block is disabled. A 1Password SSH agent bridge is sourced only when `~/.1password/agent-bridge.sh` exists.
- Machine-local environment and `PATH` changes belong in `~/.bashrc.local`, which is sourced after the shared configuration.

See [`starship.md`](starship.md), [`fzf.md`](fzf.md), [`fnm.md`](fnm.md), [`zoxide.md`](zoxide.md), [`gh.md`](gh.md), [`bat.md`](bat.md), and [`1password.md`](1password.md) for tool-specific details.
