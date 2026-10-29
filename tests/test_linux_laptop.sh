#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/bin"
export PATH="$test_dir/bin:/usr/bin:/bin" NO_COLOR=1

# Keep all privileged commands and configuration writes inside the fixture.
cat > "$test_dir/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$LAPTOP_TEST_DIR/calls"
args=()
for arg in "$@"; do
  args+=("${arg/\/etc\/systemd\/logind.conf.d/$LAPTOP_TEST_DIR/logind}")
done
exec "${args[@]}"
EOF
cat > "$test_dir/bin/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${LAPTOP_TEST_OS:-Linux}"
EOF
cat > "$test_dir/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  'show --property=Version --value')
    [[ "${LAPTOP_TEST_NO_SYSTEMD:-0}" == 0 ]] || exit 1
    printf '257\n'
    ;;
  mask\ *)
    [[ "${LAPTOP_TEST_MASK_FAIL:-0}" == 0 ]] || exit 1
    shift
    for unit in "$@"; do touch "$LAPTOP_TEST_DIR/$unit"; done
    ;;
  'show --property=LoadState --value '*)
    [[ -f "$LAPTOP_TEST_DIR/$4" ]] || exit 1
    printf '%s\n' "${LAPTOP_TEST_LOAD_STATE:-masked}"
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$test_dir/bin/"*

fail() { printf '%s\n' "$*" >&2; exit 1; }
setup_laptop() { bash "$repo_root/scripts/setup-linux-laptop.sh" "$@" > "$LAPTOP_TEST_DIR/output" 2>&1; }
arrange_fixture() {
  export LAPTOP_TEST_DIR="$test_dir/$1"
  mkdir -p "$LAPTOP_TEST_DIR/logind"
  target="$LAPTOP_TEST_DIR/logind/90-dotfiles-linux-laptop.conf"
}
assert_no_mask() {
  if [[ -f "$LAPTOP_TEST_DIR/calls" ]] && grep -q '^systemctl mask ' "$LAPTOP_TEST_DIR/calls"; then
    fail 'unexpected sleep target mutation'
  fi
}

test_preview_and_invalid_option_do_not_invoke_sudo() (
  arrange_fixture preview
  export LAPTOP_TEST_OS=Darwin
  for option in --dry-run -n --help; do setup_laptop "$option"; done
  if setup_laptop --invalid; then fail 'unknown option accepted'; fi
  [[ ! -f "$LAPTOP_TEST_DIR/calls" ]] || fail 'preview or invalid option invoked sudo'
)

test_non_linux_is_rejected() (
  arrange_fixture non-linux
  export LAPTOP_TEST_OS=Darwin
  if setup_laptop; then fail 'non-Linux system accepted'; fi
  [[ ! -f "$LAPTOP_TEST_DIR/calls" ]] || fail 'non-Linux setup invoked sudo'
)

test_systemd_is_required_before_writes() (
  arrange_fixture no-systemd
  export LAPTOP_TEST_NO_SYSTEMD=1
  if setup_laptop; then fail 'unavailable systemd accepted'; fi
  [[ ! -e "$target" ]] || fail 'configuration written without systemd'
  assert_no_mask
)

test_install_and_repeat_run() (
  arrange_fixture install
  printf '[Login]\nHandleLidSwitch=ignore\nHandleLidSwitchExternalPower=ignore\nHandleLidSwitchDocked=ignore\nIdleAction=ignore\n' > "$LAPTOP_TEST_DIR/expected"
  setup_laptop
  cmp "$target" "$LAPTOP_TEST_DIR/expected" || fail 'incorrect installed policy'
  for unit in sleep suspend hibernate hybrid-sleep suspend-then-hibernate; do
    [[ -f "$LAPTOP_TEST_DIR/$unit.target" ]] || fail "missing mask: $unit"
  done
  : > "$LAPTOP_TEST_DIR/calls"
  setup_laptop
  cmp "$target" "$LAPTOP_TEST_DIR/expected" || fail 'repeat setup changed policy'
  if grep -q '^install ' "$LAPTOP_TEST_DIR/calls"; then fail 'repeat setup rewrote policy'; fi
  if grep -Eq '^systemctl (restart|reboot)' "$LAPTOP_TEST_DIR/calls"; then fail 'setup interrupted sessions'; fi
)

test_conflicting_file_is_preserved() (
  arrange_fixture conflict
  printf '# administrator policy\n' > "$target"
  cp "$target" "$LAPTOP_TEST_DIR/expected"
  if setup_laptop; then fail 'conflicting configuration accepted'; fi
  cmp "$target" "$LAPTOP_TEST_DIR/expected" || fail 'conflicting policy overwritten'
  assert_no_mask
)

test_symlink_is_preserved() (
  arrange_fixture symlink
  printf '# symlink destination\n' > "$LAPTOP_TEST_DIR/previous"
  cp "$LAPTOP_TEST_DIR/previous" "$LAPTOP_TEST_DIR/expected"
  ln -s "$LAPTOP_TEST_DIR/previous" "$target"
  if setup_laptop; then fail 'symlink configuration accepted'; fi
  [[ -L "$target" ]] || fail 'configuration symlink removed'
  cmp "$LAPTOP_TEST_DIR/previous" "$LAPTOP_TEST_DIR/expected" || fail 'symlink destination changed'
  assert_no_mask
)

test_directory_is_preserved() (
  arrange_fixture directory
  mkdir "$target"
  if setup_laptop; then fail 'directory configuration accepted'; fi
  [[ -d "$target" ]] || fail 'configuration directory removed'
  assert_no_mask
)

test_mask_failure_is_reported() (
  arrange_fixture mask-failure
  export LAPTOP_TEST_MASK_FAIL=1
  if setup_laptop; then fail 'mask failure accepted'; fi
  if grep -q 'sleep targets masked and verified' "$LAPTOP_TEST_DIR/output"; then fail 'false success after mask failure'; fi
)

test_unmasked_target_is_rejected() (
  arrange_fixture unmasked-target
  export LAPTOP_TEST_LOAD_STATE=loaded
  if setup_laptop; then fail 'unmasked target accepted'; fi
  grep -q 'sleep target is not masked: sleep.target' "$LAPTOP_TEST_DIR/output" || fail 'missing verification failure'
)

test_preview_and_invalid_option_do_not_invoke_sudo
test_non_linux_is_rejected
test_systemd_is_required_before_writes
test_install_and_repeat_run
test_conflicting_file_is_preserved
test_symlink_is_preserved
test_directory_is_preserved
test_mask_failure_is_reported
test_unmasked_target_is_rejected

printf 'Linux laptop setup tests passed\n'
