# Local binaries

The `local-bin` package stows user-owned helpers under `~/.local/bin/`.

All command entry points in `local-bin/.local/bin/` are executable scripts.

- `difft` wraps difftastic with inline display.
- `browser` opens URLs for commands such as `gh auth login` and can also be called directly. When `~/.opener.sock` is present, it sends HTTP or HTTPS URLs to the forwarded opener service using `socat`; otherwise it uses the available WSL or desktop opener. The `local-bin` bootstrap unit installs `socat`.
- `mwt` manages sparse worktrees from a backend repository's `wt.yaml`; it requires `git` and `yq`.
- `show-keybindings` opens the package keybinding guides in Neovim.
- `skillx` safely reconciles globally installed agent skills with `~/.agents/.skill-lock.json`. It requires Python 3.12 or newer and `npx`; it has no third-party Python runtime dependencies and does not require `jq`.

## skillx

Use `npx skills` for discovery and individual additions, updates, or removals. Use `skillx` to restore and maintain the skills declared in a lockfile.

| Command | Purpose |
| --- | --- |
| `skillx check` | Check that declared skills are available from their sources; does not check installed versions. |
| `skillx sync` | Install or update declared skills and record ownership, including existing installations it updates. |
| `skillx repair` | Preview removal of confirmed-invalid lockfile entries; `--yes` applies with a backup. |
| `skillx adopt --from-lock` | Preview ownership of existing declared skills without reinstalling; `--yes` records it. |
| `skillx prune` | Preview cleanup of managed skills absent from the lockfile; `--yes` applies. |

The default lockfile is `~/.agents/.skill-lock.json`; override it with `--lockfile` or `LOCKFILE`. Ownership is recorded in `~/.agents/.skillx-managed.json`; sync, adopt, and prune accept `--ledger` to select another file.

To retire a managed skill, remove its lockfile entry, preview `skillx prune`, then run `skillx prune --yes`. Direct upstream removal may leave an ownership record that prune can clean up. Keep any separate lockfile in agreement with intentional removals, or sync will reinstall the skill.

Uncertain source failures never justify automatic deletion. Prune leaves unmanaged and ambiguously matched installations alone. Sync and prune attempt rollback if a mutation or ownership update fails; check the reported recovery status after a failure.

Use `--dry-run` to preview changes, `--json` for machine-readable reports, `-v` for diagnostics, and `-vv` for tracebacks. See `skillx <command> --help` for options. Exit codes are `0` for success, `1` for drift, blocked operations, or unapplied repair/prune plans, and `2` for usage, configuration, or runtime failures.

Source: [`local-bin/skillx-cli`](../local-bin/skillx-cli); [ownership rules](../local-bin/skillx-cli/src/skillx/reconcile.py).

Run its tests from the repository root with `PYTHONPATH=local-bin/skillx-cli/src python3 -m unittest discover -s local-bin/skillx-cli/tests`.
