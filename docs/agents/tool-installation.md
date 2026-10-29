# Tool installation

Register every new tool in `scripts/package-registry.sh` so new machines receive it. Keep the installation implementations in `scripts/setup-tools.sh`; the setup script materializes selected registry records into its method loops.

- apt, GitHub release, Snap, and installer metadata belong in the registry.
- The automatic `__core__` unit contains the shared bootstrap baseline. Put other apt prerequisites in the requiring unit's `REGISTRY_APT_DEPENDENCIES`, and use `REGISTRY_PACKAGE_DEPENDENCIES` when the complete registry unit, including its Stow files and setup, is needed.
- Keep canonical bootstrap IDs distinct from command/distribution names; add aliases there.
- Stow ownership and per-package options also belong in the registry.
- Git clones and generated plugin content belong in `bootstrap.sh` or the relevant setup phase.

Install single binaries and `.pyz` files in `~/.local/bin/`. Extract tarballs to `~/.local/opt/<name>/` and link their binary from `~/.local/bin/`.

Setup scripts add `~/.local/bin` to their process `PATH`, so freshly installed tools are available to later setup phases and repeat runs detect them. Downloads use curl's silent progress mode while preserving transfer errors.

After changing the tool setup, run `./bootstrap.sh --dry-run`.
