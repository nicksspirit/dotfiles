_ssh_transfer_in_session() {
  if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
    local session
    # The pane's environment can outlive the SSH connection that started it.
    session=$(tmux display-message -p -t "$TMUX_PANE" '#{?session_attached,#{session_id},}' 2>/dev/null)
    [ -n "$session" ] || return 1
    case "$(tmux show-environment -t "$session" SSH_CONNECTION 2>/dev/null)" in
      SSH_CONNECTION=?*) return 0 ;;
      *) return 1 ;;
    esac
  fi
  [ -n "${SSH_CONNECTION:-}" ]
}

_ssh_transfer() {
  local direction="$1" destination="$2" host="${SSH_TRANSFER_CLIENT:-transfer-client}" source capabilities
  shift 2

  if ! _ssh_transfer_in_session; then
    printf '%s\n' 'Run fdrop or fgrab in a remote SSH shell or a tmux session attached over SSH.' >&2
    return 1
  fi

  for source in "$@"; do
    if [ -z "$source" ]; then
      printf '%s\n' 'File transfer paths cannot be empty.' >&2
      return 2
    fi
  done

  if ! capabilities=$(ssh -n -o BatchMode=yes -o ConnectTimeout=5 -- "$host" '
    if rsync -s --version >/dev/null 2>&1; then printf "rsync-protected-args\n"; fi
  '); then
    printf 'Cannot reach the SSH client via %s. Reconnect using the alias with the reverse forward and check that the client SSH server is running.\n' "$host" >&2
    return 1
  fi

  local use_rsync=no
  if [ "$capabilities" = rsync-protected-args ] && rsync -s --version >/dev/null 2>&1; then
    use_rsync=yes
  fi

  for source in "$@"; do
    # Copy a named directory with either engine, even if the input ends in a slash.
    while [ "$source" != / ] && [ "${source%/}" != "$source" ]; do
      source=${source%/}
    done
    if [ "$direction" = pull ]; then
      case "$source" in
        '~') source=. ;;
        '~/'*) source=${source#\~/} ;;
      esac
      if [ "$use_rsync" = yes ]; then
        rsync -avz -s --progress -e 'ssh -o BatchMode=yes' -- "$host:$source" "$destination" || return
      else
        # SFTP-based scp still interprets glob characters in download sources.
        source=${source//\\/\\\\}
        source=${source//\*/\\*}
        source=${source//\?/\\?}
        source=${source//\[/\\[}
        scp -s -r -o BatchMode=yes -- "$host:$source" "$destination" || return
      fi
    else
      case "$source" in
        /*) ;;
        *) source="$PWD/$source" ;;
      esac
      if [ "$use_rsync" = yes ]; then
        rsync -avz -s --progress -e 'ssh -o BatchMode=yes' -- "$source" "$host:$destination" || return
      else
        scp -s -r -o BatchMode=yes -- "$source" "$host:$destination" || return
      fi
    fi
  done
}

fdrop() {
  [ "${1:-}" != -- ] || shift
  if [ "$#" -eq 0 ]; then
    printf '%s\n' 'Usage: fdrop <client-paths...>' >&2
    return 2
  fi

  _ssh_transfer pull . "$@"
}

fgrab() {
  local destination=Downloads
  if [ "${1:-}" = -d ]; then
    if [ "$#" -lt 3 ] || [ -z "$2" ]; then
      printf '%s\n' 'Usage: fgrab [-d client-directory] <remote-paths...>' >&2
      return 2
    fi
    destination=${2#\~/}
    shift 2
  fi
  [ "${1:-}" != -- ] || shift
  if [ "$#" -eq 0 ]; then
    printf '%s\n' 'Usage: fgrab [-d client-directory] <remote-paths...>' >&2
    return 2
  fi
  _ssh_transfer push "${destination%/}/" "$@"
}
