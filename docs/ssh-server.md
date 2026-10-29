# SSH server

The opt-in `ssh-server` bootstrap unit installs Debian's `openssh-server` through
`scripts/setup-tools.sh`. Its `scripts/setup-ssh-server.sh` hook manages
`/etc/ssh/sshd_config.d/00-dotfiles-opener.conf` outside GNU Stow.

Select `--package ssh-server` when bootstrapping a remote host. To configure an
already installed server, run `bash scripts/setup-ssh-server.sh` on that host.
Both entry points support `--dry-run` and require sudo for real changes.

The drop-in sets `StreamLocalBindUnlink yes` so stale Unix sockets do not block
later forwarding sessions, and `StreamLocalBindMask 0177` so newly created
sockets are accessible only to their owner. The settings apply server-wide.
The latest successful forward to a given socket path receives new connections,
even if a previous forwarding session remains connected.

Setup checks the existing SSH configuration before writing, then validates both
syntax and effective global socket settings. If validation fails, it restores the
previous drop-in (or removes the new one) without reloading SSH. The server must
include `/etc/ssh/sshd_config.d/*.conf`; conflicting earlier settings cause setup
to fail. Host-specific `Match` blocks can override the global settings.

Setup reloads the Debian `ssh` service only when active. An inactive service uses
the settings on its next start. Authentication and TCP forwarding policies are
not configured by this unit. See [GitHub CLI setup](gh.md#opening-links-over-ssh)
for the matching client forward and stale-socket recovery.

Validate changes with `bash tests/test_bootstrap.sh` and
`bash tests/test_ssh_server.sh`. The latter exercises setup with isolated
privileged commands, including repeat runs, rollback, and inactive services.
Each SSH setup test uses its own fixture and separates Arrange, Act, and Assert,
following the [AAA pattern](https://semaphore.io/blog/aaa-pattern-test-automation).
