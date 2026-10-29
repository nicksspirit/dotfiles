# Agents

The `agents` package stows `~/.agents/`.

## Managed files

- `~/.agents/.skill-lock.json` pins skills used by `npx skills`.
- `~/.agents/.skillx-managed.json` is the versioned ownership ledger written by successful `skillx sync` or explicitly confirmed `skillx adopt --from-lock --yes` operations.
- `~/.agents/skills/in-ste/SKILL.md` is a local technical-writing skill.

The lockfile is desired state for `skillx`. `skillx sync` validates every declared source and skill before installing or updating anything, and post-install setup invokes that command after the lockfile and Node tooling are available. Indeterminate remote state blocks sync without changing installed skills or desired state.

The ownership ledger records custody. Sync manages every declared skill it successfully installs or updates, including pre-existing installations; `skillx adopt --from-lock --yes` records custody without reinstalling. Both preserve earlier records so deleting a desired entry does not erase the information needed by prune. `skillx prune --yes` can remove an installation only when its ledger record and installed inventory agree on one exact path, skill name, and source. If both the recorded name and path are already absent, prune only removes the stale ledger record. Installations outside the ledger and ambiguous matches remain untouched. Sync retains installation rollback state until inventory verification and the atomic ledger update succeed.
