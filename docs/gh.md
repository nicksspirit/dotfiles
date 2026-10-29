# GitHub CLI setup

## Important configuration paths

- `~/.bashrc`
- `~/.bash_aliases`
- `~/.config/gh/` if you later authenticate or add CLI config

## Installed state

- `scripts/setup-tools.sh` installs `gh`, which is available on `PATH`.
- Browser opening support comes from `browser.sh` in `~/.local/bin`

## Current state

- There is no `gh`-specific shell init in `~/.bashrc` or `~/.bash_aliases`
- `~/.config/gh/` holds user-level GitHub CLI configuration after authentication
- `gh auth login` relies on the shell's `BROWSER` setting, which is exported from `~/.bashrc` when `browser.sh` is available
- Package-scoped bootstrap of `gh` also deploys `browser.sh` from the `local-bin` package.

## Caveats

- Authentication state and CLI preferences appear after commands such as `gh auth login`.
- Shell completions or aliases for `gh` are not currently configured in the documented Bash setup; browser launching is handled by `browser.sh`

## Opening links over SSH

For a remote Debian machine, install and start [opener](https://github.com/superbrothers/opener#setup) on the local computer. Configure the local SSH client with a `RemoteForward` from the remote home directory's `.opener.sock` to the local home directory's `.opener.sock`, using absolute paths. For example:

```sshconfig
Host debian-host
    RemoteForward /home/REMOTE_USER/.opener.sock /Users/LOCAL_USER/.opener.sock
    ExitOnForwardFailure yes
```

Bootstrap the remote `bash` and `local-bin` packages, reconnect, and check that `command -v browser.sh` finds the helper and `BROWSER` is set to `browser.sh`. Run `browser.sh https://github.com/` to test the connection. The local `opener` service opens the link in the local browser; no remote `xdg-open` shim is required. Other shells must set `BROWSER=browser.sh` themselves.

The forwarded socket is a capability to open links on the local computer. Restrict its access on the remote host (for OpenSSH, `StreamLocalBindMask 0177` in the server configuration), and use only trusted remote accounts. A stale socket or another SSH session using the same path can prevent forwarding; inspect the socket and active sessions before removing it. `ExitOnForwardFailure` makes such failures visible. A forwarded socket that exists but cannot connect causes `browser.sh` to fail instead of falling back to a different opener. The local browser resolves `localhost` locally; a remote web server needs a separate SSH port forward.
