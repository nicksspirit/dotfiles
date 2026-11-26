# Bash

The `bash` package manages `~/.bashrc`, `~/.bash_aliases`, and
`~/.config/ssh-transfer/functions.sh`.

## Current configuration

- Interactive Bash uses `LANG=C.UTF-8`, enables completion when system files are present, and prepends `~/.local/bin` to `PATH`.
- `MICRO_TRUECOLOR=1` is exported.
- `~/.bash_aliases` defines `bat`, `bathelp`, and a `help()` function that formats command help with `batcat`.
- `claude-usage` runs the current Claude usage tracker; tracker options such as `--today`, `--month current`, and `--budget` are passed through to the script.
- Starship, fzf, zoxide, and fnm initialize only when their commands or startup files are available.
- Bash autosuggestions loads from `~/.local/lib/bash-autosuggestions` when installed. Select `bash-autosuggestions` in bootstrap to build the pinned plugin with its Bash and Readline development dependencies; `scripts/setup-tools.sh` owns installation. Suggestions come from command history and can be accepted with the right arrow.
- `browser` supplies the `BROWSER` command for applications that open URLs, including `gh auth login`.
- Optional integrations initialize only when their commands or files exist; no host-specific home, Windows, or temporary-directory paths are assumed.
- The keychain startup block is disabled. A 1Password SSH agent bridge is sourced only when `~/.1password/agent-bridge.sh` exists.
- Machine-local environment and `PATH` changes belong in `~/.bashrc.local`, which is sourced after the shared configuration.

## SSH file transfers

On a host with the Bash package already stowed, pull the checkout and open a
new Bash shell. Existing Bash panes can run `source ~/.bashrc`.

Run both commands in the remote shell after connecting from your client
computer over SSH. You can also run them in a remote tmux session attached
over SSH.

- `fdrop` copies files or folders from the client into your current directory
  on the remote machine. Type or paste the client's paths at the remote
  prompt. Use absolute paths or paths relative to the client SSH account's
  home directory. Quote paths with spaces and quote any leading `~/` so the
  remote shell leaves it for the client.
- `fgrab` sends remote files or folders to the client's `~/Downloads/`. Use
  `-d` to select another existing directory on the client. Quote a leading
  `~/` for the destination as well.

```bash
fdrop '~/Documents/Project notes.txt' '~/Pictures/Trip photos'
fgrab 'Project notes.txt' Photos/
fgrab -d '~/Documents/Incoming' 'Project notes.txt'
```

The functions check `SSH_CONNECTION` directly in an SSH shell. In tmux,
they check that the session is attached and read the SSH marker that tmux
updates on attach. They then test non-interactive authentication back to the
client through the configured reverse forward. A regular SSH connection
needs the [reverse transfer setup](ssh-server.md#file-transfers-over-ssh) for
either command to work.

Both commands use rsync when both systems support protected arguments
(`-s`), with SFTP-mode SCP (`scp -s`) as the fallback. They stop on the first
failed transfer.

If your terminal pastes paths when you drag files into it, type `fdrop ` in
the remote pane, drag the files into it, and press Enter. As an optional
macOS example, add the following to Ghostty's config and reload it to insert
`fdrop ` with **Cmd+Shift+U**.

```ini
keybind = cmd+shift+u=text:fdrop\x20
```

See [`starship.md`](starship.md), [`fzf.md`](fzf.md), [`fnm.md`](fnm.md), [`zoxide.md`](zoxide.md), [`gh.md`](gh.md), [`bat.md`](bat.md), and [`1password.md`](1password.md) for tool-specific details.
