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

## File transfers over SSH

The Bash package supplies [`fdrop` and `fgrab`](bash.md#ssh-file-transfers).
The SSH client is the computer where you start the SSH connection and keep
your local files. The remote is the machine running the transfer functions.
Set up a reverse forward and dedicated key for each trusted client–remote pair.

1. Run an SSH server on the client and allow the client account that receives
   the transfers. On macOS, use **System Settings → General → Sharing →
   Remote Login**, choose **Only these users**, and add that account.
2. On both machines, create `~/.ssh/sockets` with mode `0700`. Add these
   settings within the remote machine's alias block in the client's
   `~/.ssh/config`. If the client's SSH server uses a different port, change
   the last port in `RemoteForward`.

   ```sshconfig
   ControlMaster auto
   ControlPath ~/.ssh/sockets/%C
   ControlPersist 10m
   ServerAliveInterval 60
   ExitOnForwardFailure yes
   RemoteForward 127.0.0.1:2222 127.0.0.1:22
   ```

3. On the remote, generate the key with
   `ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519_ssh_transfer`.
   Append the contents of `id_ed25519_ssh_transfer.pub` to the client account's
   `~/.ssh/authorized_keys`, prefixed with `from="127.0.0.1,::1",restrict `.
   The remote keeps the private key. This key can run file-transfer commands
   as the client account through the loopback connection.
4. Add the following to the remote's `~/.ssh/config` before broad matching
   rules, substituting the client account name. Keep the forwarded listener
   on loopback in the remote SSH server's policy.

   ```sshconfig
   Host transfer-client
     HostName 127.0.0.1
     Port 2222
     User your-client-account
     IdentityFile ~/.ssh/id_ed25519_ssh_transfer
     IdentitiesOnly yes
     IdentityAgent none
     ForwardAgent no
     BatchMode yes
     StrictHostKeyChecking accept-new
     ControlMaster auto
     ControlPath ~/.ssh/sockets/%C
     ControlPersist 10m
   ```

5. Connect using the client's alias for the remote, then run
   `ssh transfer-client true` from the remote shell to check the reverse
   connection. Try both transfer commands with a path containing spaces. If
   you use tmux, attach over SSH and keep `SSH_CONNECTION` in tmux's
   `update-environment` option so the session recognizes reattachments.
   Existing panes started before installation need to run `source ~/.bashrc`
   once.

Use port `2222` independently on separate remote machines. For multiple clients
on one remote, give each client its own reverse port, key, and SSH alias.
Select that client's alias with `SSH_TRANSFER_CLIENT`, for example
`SSH_TRANSFER_CLIENT=transfer-laptop fdrop '~/Documents/report.pdf'`.
For an existing reverse setup, add `transfer-client` to its `Host` line or
set `SSH_TRANSFER_CLIENT` to the existing alias. The initial outbound SSH
connection can require approval from the client's configured SSH agent.
