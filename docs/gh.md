# GitHub CLI setup

## Important configuration paths

- `~/.bashrc`
- `~/.bash_aliases`
- `~/.config/gh/` if you later authenticate or add CLI config

## Installed state

- `scripts/setup-tools.sh` installs `gh`, which is available on `PATH`.
- Browser opening support comes from `browser` in `~/.local/bin`

## Current state

- There is no `gh`-specific shell init in `~/.bashrc` or `~/.bash_aliases`
- `~/.config/gh/` holds user-level GitHub CLI configuration after authentication
- `gh auth login` relies on the shell's `BROWSER` setting, which is exported from `~/.bashrc` when `browser` is available
- Package-scoped bootstrap of `gh` also deploys `browser` from the `local-bin` package.

## Caveats

- Authentication state and CLI preferences appear after commands such as `gh auth login`.
- Shell completions or aliases for `gh` are not currently configured in the documented Bash setup; browser launching is handled by `browser`

## Opening links over SSH

For a remote Debian machine, install and start [opener](https://github.com/superbrothers/opener#setup) on the local computer. Configure the local SSH client with a `RemoteForward` from the remote home directory's `.opener.sock` to the local home directory's `.opener.sock`, using absolute paths. For example:

```sshconfig
Host debian-host
    RemoteForward /home/REMOTE_USER/.opener.sock /Users/LOCAL_USER/.opener.sock
    ExitOnForwardFailure yes
```

Bootstrap the remote `bash` and `local-bin` packages, reconnect, and check that `command -v browser` finds the helper and `BROWSER` is set to `browser`. Run `browser https://github.com/` to test the connection. The local `opener` service opens the link in the local browser; no remote `xdg-open` shim is required. Other shells must set `BROWSER=browser` themselves.

The forwarded socket is a capability to open links on the local computer. Use only trusted remote accounts. The opt-in [`ssh-server` bootstrap unit](ssh-server.md) installs and configures the remote OpenSSH server with:

```sshdconfig
StreamLocalBindMask 0177
StreamLocalBindUnlink yes
```

For an existing server, `scripts/setup-ssh-server.sh` applies these settings, validates them, and reloads the active Debian `ssh` service. These settings belong in the remote server's `sshd_config` or an included configuration file. Setting `StreamLocalBindUnlink` in the local SSH client does not fix a remote listen-path conflict. The server setting removes an existing socket path before binding, including one used by another session; the most recent successful forward receives new browser requests.

### Recovering a stale socket

`Error: remote port forwarding failed for listen path .../.opener.sock` can occur because OpenSSH leaves the socket file after a forwarding session ends. Connect without requesting the forward:

```sh
ssh -o ClearAllForwardings=yes debian-host
```

On the remote host, inspect the socket and its listener:

```sh
ls -l "$HOME/.opener.sock"
ss -xlpn | grep -F -- "$HOME/.opener.sock"
```

If the path is a socket and there is no listener, remove the stale socket with `test -S "$HOME/.opener.sock" && rm -- "$HOME/.opener.sock"`, then reconnect normally. If a listener exists, use the session that owns it or close that forwarding session before cleanup. Enable the server setting above to prevent stale sockets from blocking subsequent connections. `ExitOnForwardFailure yes` keeps forwarding failures visible.

A forwarded socket that exists but cannot connect causes `browser` to fail instead of falling back to a different opener. The local browser resolves `localhost` locally; a remote web server needs a separate SSH port forward.
