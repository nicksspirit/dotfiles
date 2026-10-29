#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib.sh"

enable_error_trap
parse_dry_run_args scripts/setup-linux-laptop.sh "$@"

log "Linux laptop server power policy"
target=/etc/systemd/logind.conf.d/90-dotfiles-linux-laptop.conf
settings=$'[Login]\nHandleLidSwitch=ignore\nHandleLidSwitchExternalPower=ignore\nHandleLidSwitchDocked=ignore\nIdleAction=ignore'
sleep_targets=(sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target)

if is_dry_run; then
  status plan 'require Linux with a running systemd manager'
  status plan "install $target with:
$settings"
  run sudo systemctl mask "${sleep_targets[@]}"
  status todo 'reboot when convenient to load the lid policy; sleep targets are blocked immediately'
  exit 0
fi

[[ "$(uname -s)" == Linux ]] || die 'Linux laptop setup requires Linux'
need_cmd sudo
need_cmd systemctl
run systemctl show --property=Version --value

make_temp_dir setup-linux-laptop tmp_dir
printf '%s\n' "$settings" > "$tmp_dir/logind.conf"
if sudo test -e "$target" || sudo test -L "$target"; then
  if sudo test -L "$target" || ! sudo test -f "$target" ||
      ! sudo cmp -s "$tmp_dir/logind.conf" "$target"; then
    die "refusing to replace existing configuration: $target; inspect it before retrying"
  fi
  status skip 'laptop logind configuration already installed'
else
  run sudo mkdir -p /etc/systemd/logind.conf.d
  run sudo install -m 0644 "$tmp_dir/logind.conf" "$target"
fi

run sudo systemctl mask "${sleep_targets[@]}"
for unit in "${sleep_targets[@]}"; do
  [[ "$(systemctl show --property=LoadState --value "$unit")" == masked ]] ||
    die "sleep target is not masked: $unit"
done
status done 'sleep targets masked and verified'
# Avoid restarting logind during an active remote session.
status todo 'reboot when convenient to load the lid policy; sleep targets are blocked immediately'
