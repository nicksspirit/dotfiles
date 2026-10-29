# Bootstrap scripts

`scripts/package-registry.sh` is the authoritative Bash-only registry. `REGISTRY_UNIT_IDS` is its only enumeration list, and each unit has one self-contained `registry_load_unit` case stanza with explicitly named fields. Canonical IDs are separate from command names, distribution names, and Stow package directories; aliases include `npiperelay.exe` (for `npiperelay`) and `cortex` (for `snowflake`). The registry contains apt, GitHub, Snap, installer, Stow ownership, per-package Stow options, and setup-hook names. Setup phases use `registry_hook_selected` so hook metadata controls package-scoped post-install work instead of serving as a descriptive dead field. The registry intentionally has no jq/yq/Python dependency.

Bootstrap validates IDs before running setup, then installs and stows the selected registry records and their transitive `REGISTRY_PACKAGE_DEPENDENCIES`. For example, `tmux`, `gh`, and `difftastic` require `local-bin` for their configured helper commands. Every run selects `__core__` (alias `core`): `ca-certificates`, `curl`, `stow`, and Fastfetch from apt. With no package options, only this baseline is selected. Fastfetch must be available in the host's configured apt repositories. The host must already have Bash, standard shell utilities, apt/dpkg, and sudo access. Pass multiple `--package` options to add records. Unknown IDs fail before mutation.

After cloning the repository, choose the package IDs that fit the host and pass one `--package` option for each. IDs, dependencies, and installation metadata are defined in `scripts/package-registry.sh`.

```sh
./bootstrap.sh --dry-run --package PACKAGE_ID --package ANOTHER_ID
./bootstrap.sh --package PACKAGE_ID --package ANOTHER_ID
```

Review the dry-run and any Stow conflicts before applying. Bootstrap installs and stows selected units and their dependencies and runs their setup hooks. Use `./bootstrap.sh --dry-run` to preview the baseline. Select `wsl` explicitly to run `setup-wsl.sh`; on WSL this writes the repository's host-specific `/etc/wsl.conf`. The former `bootstrap-prerequisites` ID is no longer accepted; remove it from saved commands.

A registry package is a selectable unit that can install a tool, deploy Stow configuration, run setup, or combine these. A tool is an installed program. Use `./bootstrap.sh --dry-run --reinstall --package jq` to preview reinstalling jq, or use `-r -p jq`. `--reinstall` requires at least one explicit package and forces only explicitly selected tools to reinstall or refresh. Missing baseline and dependencies are installed normally; existing ones are not forced to reinstall unless explicitly selected. Stow and setup phases still run normally for selected packages and dependencies. Configuration-only packages have no tool to reinstall. The former `--reinstall-tools` option is no longer accepted.

After changing the package registry or dependency selection, run `bash tests/test_bootstrap.sh`. The test checks setup script permissions, dependency selection, and the automatic baseline using dry runs with a temporary home. Keep `scripts/setup-*.sh` executable in Git so bootstrap can run them in fresh checkouts and dry runs.

Keep host-specific shell settings in the local override described in [`bash.md`](../bash.md), not in repo-managed configuration.

`bootstrap.sh` manages generated and plugin content that cannot be stowed. Setup scripts accept `-n`/`--dry-run` when audited independently and reject unknown options instead of silently running normal-mode actions.

`setup-postinstall.sh` is not run automatically; run it separately for its checks and skill synchronization when needed.

Select `ssh-server` explicitly on remote Debian hosts to install OpenSSH and run
`setup-ssh-server.sh` after tool installation. It manages the server socket-forwarding
drop-in, validates syntax and effective settings with rollback on validation failure,
and reloads an active `ssh` service. See [`ssh-server.md`](../ssh-server.md).

Select `linux-laptop` explicitly for Linux laptops used as always-on servers.
Its `setup-linux-laptop.sh` hook ignores lid and idle sleep in logind and masks
systemd sleep targets. It supports standalone dry runs and does not reboot or
restart logind. See [`linux-laptop.md`](../linux-laptop.md).

Bootstrap scripts source `scripts/lib.sh` (which loads the registry) and call `enable_error_trap`. Use `log` for top-level sections, `sublog` for nested work, and `status` for indented outcomes; multiline `status` messages align continuation lines beneath the message. `run` makes ordinary commands dry-run aware; use `run_sh` only for pipelines or compound shell commands. Do not print bootstrap actions with ad hoc `printf` or `echo`. `NO_COLOR=1` disables color output.

Postinstall SSH reminders derive candidates from `ssh -G github.com` and only name a key when exactly one configured identity file exists. With no candidate or multiple candidates, print generic guidance and do not guess which key to load.

Use `clone_if_missing` for idempotent clones and `make_temp_dir` for temporary directories so the shared `EXIT` trap cleans them up. Keep expected failures in explicit conditionals and preserve the shared cleanup and error traps.
