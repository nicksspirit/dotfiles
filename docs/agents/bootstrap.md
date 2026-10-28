# Bootstrap scripts

`scripts/package-registry.sh` is the authoritative Bash-only registry. `REGISTRY_UNIT_IDS` is its only enumeration list, and each unit has one self-contained `registry_load_unit` case stanza with explicitly named fields. Canonical IDs are separate from command names, distribution names, and Stow package directories; aliases include `npiperelay.exe` (for `npiperelay`) and `cortex` (for `snowflake`). The registry contains apt, GitHub, Snap, installer, Stow ownership, per-package Stow options, and setup-hook names. Setup phases use `registry_hook_selected` so hook metadata controls package-scoped post-install work instead of serving as a descriptive dead field. The registry intentionally has no jq/yq/Python dependency.

Package mode validates IDs before running setup, then installs and stows only matching registry records. Pass multiple `--package` options to select multiple records; omitting them selects the full registry. Unknown IDs fail before mutation.

After cloning the repository, choose the package IDs that fit the host and pass one `--package` option for each. IDs and their installation metadata are defined in `scripts/package-registry.sh`; include any prerequisite units required by the selected packages.

```sh
./bootstrap.sh --dry-run --package PACKAGE_ID --package ANOTHER_ID
./bootstrap.sh --package PACKAGE_ID --package ANOTHER_ID
```

Review the dry-run and any Stow conflicts before applying. Package mode installs and stows only selected units and runs setup hooks owned by those units. Use `./bootstrap.sh --dry-run` to preview a full bootstrap.

Keep host-specific shell settings in the local override described in [`bash.md`](../bash.md), not in repo-managed configuration.

`bootstrap.sh` manages generated and plugin content that cannot be stowed. Setup scripts accept `-n`/`--dry-run` when audited independently and reject unknown options instead of silently running normal-mode actions.

Bootstrap scripts source `scripts/lib.sh` (which loads the registry) and call `enable_error_trap`. Use `log` for top-level sections, `sublog` for nested work, and `status` for indented outcomes; multiline `status` messages align continuation lines beneath the message. `run` makes ordinary commands dry-run aware; use `run_sh` only for pipelines or compound shell commands. Do not print bootstrap actions with ad hoc `printf` or `echo`. `NO_COLOR=1` disables color output.

Postinstall SSH reminders derive candidates from `ssh -G github.com` and only name a key when exactly one configured identity file exists. With no candidate or multiple candidates, print generic guidance and do not guess which key to load.

Use `clone_if_missing` for idempotent clones and `make_temp_dir` for temporary directories so the shared `EXIT` trap cleans them up. Keep expected failures in explicit conditionals and preserve the shared cleanup and error traps.
