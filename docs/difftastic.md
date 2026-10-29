# difftastic

Structural diff tool that understands syntax. Used as the primary git diff driver.

`scripts/setup-tools.sh` downloads the latest amd64 or arm64 Debian package from
the [difftastic-debian GitHub releases](https://github.com/dariogriffo/difftastic-debian/releases)
and installs it with `dpkg`. This free release-download route does not require
Snap or the project's subscription-based apt repository. The package installs
`/usr/bin/difft`.

## Local wrapper (`difft`)

A wrapper script at `~/.local/bin/difft` (managed by the `local-bin` stow package)
calls `/usr/bin/difft --display inline "$@"`. This ensures `--display inline` is
always active without needing to embed flags in git config (git passes positional
args directly to `diff.external`, so flags can't be added there).

Package-scoped bootstrap of `difftastic` also deploys the `local-bin` wrapper.

Git config and aliases reference `difft` (the wrapper), not `difftastic` directly.

## Git integration

Configured in the `git` stow package (`~/.gitconfig`).

The recommended integration is `[diff "difftastic"] command = difft`, combined
with `~/.git-attributes` to route `*.ipynb` to the nbdime diff and merge
drivers. `core.attributesFile` points Git at that tracked file. This keeps
difftastic as the default for normal files while notebooks use nbdime. The
difftool definition is kept as a fallback for explicit `git difftool` use.

### Aliases

| Alias | Expands to |
|---|---|
| `git dlog` | `git log -p` with difftastic diffs (inline display) |
| `git dshow` | `git show` (most recent commit) with difftastic (inline display) |
| `git difft` | `git diff` with difftastic (inline display) |

### One-off without aliases

```sh
git -c diff.external=difft diff
git -c diff.external=difft show --ext-diff
git -c diff.external=difft log -p --ext-diff
```

### Opt out for a single command

```sh
git diff --no-ext-diff
```

## Lazygit

Lazygit uses the `difft` wrapper from `PATH` for structural diffs.
