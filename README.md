# Shell setup

Personal Linux/WSL shell, editor, and AI-tool configuration managed with
[GNU Stow](https://www.gnu.org/software/stow/) and shell bootstrap scripts.

## Bootstrap

Preview, then install the bootstrap baseline:

```sh
./bootstrap.sh --dry-run
./bootstrap.sh
```

Run `./bootstrap.sh --help` for additional options.

To add configuration or tools, pass one `--package ID` option per registry ID.
Preview the selection with `--dry-run` before applying it. See
[`docs/agents/bootstrap.md`](docs/agents/bootstrap.md) for the pattern.

## Repository layout

- `docs/` contains the canonical human-readable documentation.
- `docs/agents/` contains focused task guides for coding agents.
- Root package directories contain configuration deployed under `$HOME`.
- `scripts/` and `bootstrap.sh` install tools and generated content.

## Documentation

Browse [`docs/`](docs/) for package setup, configuration, and usage notes.

AI agents must follow [`AGENTS.md`](AGENTS.md).
