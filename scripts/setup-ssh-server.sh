#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib.sh"

enable_error_trap
parse_dry_run_args scripts/setup-ssh-server.sh "$@"

log "SSH server socket forwarding"
target=/etc/ssh/sshd_config.d/00-dotfiles-opener.conf
settings=$'StreamLocalBindUnlink yes\nStreamLocalBindMask 0177'

if is_dry_run; then
  status plan "install $target with:
$settings"
  run sudo /usr/sbin/sshd -t
  status plan 'verify effective socket settings with sudo /usr/sbin/sshd -T'
  status plan 'sudo systemctl reload ssh (if active)'
  exit 0
fi

need_cmd sudo
run sudo /usr/sbin/sshd -t
make_temp_dir setup-ssh-server tmp_dir
printf '%s\n' "$settings" > "$tmp_dir/opener.conf"
had_previous=0
if sudo test -e "$target" || sudo test -L "$target"; then
  if sudo test -L "$target" || ! sudo test -f "$target"; then
    die "refusing to replace non-regular configuration: $target"
  fi
  run sudo cp -p "$target" "$tmp_dir/previous.conf"
  had_previous=1
fi

run sudo mkdir -p /etc/ssh/sshd_config.d
run sudo install -m 0644 "$tmp_dir/opener.conf" "$target"
if sudo /usr/sbin/sshd -t && effective="$(sudo /usr/sbin/sshd -T)" &&
    grep -qx 'streamlocalbindunlink yes' <<< "$effective" &&
    grep -Eq '^streamlocalbindmask 0?177$' <<< "$effective"; then
  status done 'socket forwarding configuration validated'
else
  if [[ "$had_previous" == 1 ]]; then
    run sudo cp -p "$tmp_dir/previous.conf" "$target"
  else
    run sudo rm -- "$target"
  fi
  die 'SSH configuration invalid or socket settings overridden; restored previous configuration'
fi

if sudo systemctl is-active --quiet ssh; then
  run sudo systemctl reload ssh
else
  status skip 'ssh service inactive; settings apply when it starts'
fi
