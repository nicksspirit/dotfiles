# Git

The `git` package stows `~/.gitconfig` and `~/.git-attributes`.

Create an untracked `~/.gitconfig.local` on each machine for `[user]` name and email. It can also hold optional SSH commit-signing configuration.

Machine-specific identity, SSH signing, credential helpers, and maintenance repositories belong in the untracked `~/.gitconfig.local`. Keep host-dependent paths out of the shared configuration; for example, configure the WSL 1Password signer only on WSL hosts. See [`1password.md`](1password.md) for bridge requirements.

[`difftastic.md`](difftastic.md) is the canonical reference for the configured diff driver and aliases.
