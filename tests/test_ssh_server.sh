#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/bin"
export PATH="$test_dir/bin:/usr/bin:/bin" NO_COLOR=1

# Run the real setup with privileged paths and commands isolated in the fixture.
cat > "$test_dir/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$SSH_TEST_DIR/calls"
if [[ "$1" == /usr/sbin/sshd ]]; then
  if [[ "$2" == -t ]]; then
    [[ "${SSH_TEST_REJECT:-}" != syntax || ! -f "$SSH_TEST_DIR/sshd/00-dotfiles-opener.conf" ]]
  elif [[ "${SSH_TEST_REJECT:-}" == overridden ]]; then
    printf 'streamlocalbindunlink no\nstreamlocalbindmask 0177\n'
  else
    printf 'streamlocalbindunlink yes\nstreamlocalbindmask 0177\n'
  fi
  exit $?
fi
if [[ "$1" == systemctl ]]; then
  [[ "$2" != is-active || "${SSH_TEST_INACTIVE:-0}" != 1 ]]
  exit $?
fi
args=()
for arg in "$@"; do
  args+=("${arg/\/etc\/ssh\/sshd_config.d/$SSH_TEST_DIR/sshd}")
done
exec "${args[@]}"
EOF
chmod +x "$test_dir/bin/sudo"

fail() { printf '%s\n' "$*" >&2; exit 1; }
setup_server() { bash "$repo_root/scripts/setup-ssh-server.sh" "$@" > "$SSH_TEST_DIR/output" 2>&1; }

arrange_fixture() {
  export SSH_TEST_DIR="$test_dir/$1"
  mkdir -p "$SSH_TEST_DIR/sshd"
  target="$SSH_TEST_DIR/sshd/00-dotfiles-opener.conf"
}

test_dry_run_does_not_invoke_sudo() (
  # Arrange
  arrange_fixture dry-run

  # Act
  setup_server --dry-run

  # Assert
  [[ ! -e "$SSH_TEST_DIR/calls" ]] || fail 'dry run invoked sudo'
)

test_invalid_option_is_rejected_without_sudo() (
  # Arrange
  arrange_fixture invalid-option
  result=0

  # Act
  setup_server --invalid || result=$?

  # Assert
  [[ "$result" != 0 ]] || fail 'unknown option accepted'
  [[ ! -e "$SSH_TEST_DIR/calls" ]] || fail 'invalid option invoked sudo'
)

test_new_configuration_is_installed_and_reloaded() (
  # Arrange
  arrange_fixture new-configuration
  printf 'StreamLocalBindUnlink yes\nStreamLocalBindMask 0177\n' > "$SSH_TEST_DIR/expected"

  # Act
  setup_server

  # Assert
  cmp "$target" "$SSH_TEST_DIR/expected" || fail 'installed configuration differs'
  [[ "$(grep -c '^systemctl reload ssh$' "$SSH_TEST_DIR/calls")" == 1 ]] || fail 'active service not reloaded'
)

test_repeat_setup_preserves_configuration() (
  # Arrange
  arrange_fixture repeat-setup
  setup_server
  cp "$target" "$SSH_TEST_DIR/expected"
  : > "$SSH_TEST_DIR/calls"

  # Act
  setup_server

  # Assert
  cmp "$target" "$SSH_TEST_DIR/expected" || fail 'repeat setup changed configuration'
  [[ "$(grep -c '^systemctl reload ssh$' "$SSH_TEST_DIR/calls")" == 1 ]] || fail 'repeat setup did not reload active service'
)

test_overridden_settings_restore_previous_configuration() (
  # Arrange
  arrange_fixture overridden-settings
  printf '# previous configuration\n' > "$SSH_TEST_DIR/expected"
  cp "$SSH_TEST_DIR/expected" "$target"
  export SSH_TEST_REJECT=overridden
  result=0

  # Act
  setup_server || result=$?

  # Assert
  [[ "$result" != 0 ]] || fail 'overridden settings accepted'
  cmp "$target" "$SSH_TEST_DIR/expected" || fail 'previous configuration not restored'
  if grep -q '^systemctl reload' "$SSH_TEST_DIR/calls"; then fail 'reloaded rejected configuration'; fi
)

test_invalid_new_configuration_is_removed() (
  # Arrange
  arrange_fixture invalid-syntax
  export SSH_TEST_REJECT=syntax
  result=0

  # Act
  setup_server || result=$?

  # Assert
  [[ "$result" != 0 ]] || fail 'invalid syntax accepted'
  [[ ! -e "$target" ]] || fail 'new invalid configuration not removed'
  if grep -q '^systemctl reload' "$SSH_TEST_DIR/calls"; then fail 'reloaded invalid configuration'; fi
)

test_inactive_service_is_not_reloaded() (
  # Arrange
  arrange_fixture inactive-service
  export SSH_TEST_INACTIVE=1
  printf 'StreamLocalBindUnlink yes\nStreamLocalBindMask 0177\n' > "$SSH_TEST_DIR/expected"

  # Act
  setup_server

  # Assert
  cmp "$target" "$SSH_TEST_DIR/expected" || fail 'inactive service configuration not installed'
  if grep -q '^systemctl reload' "$SSH_TEST_DIR/calls"; then fail 'reloaded inactive service'; fi
)

test_configuration_symlink_is_preserved() (
  # Arrange
  arrange_fixture symlink
  printf '# existing symlink destination\n' > "$SSH_TEST_DIR/expected"
  cp "$SSH_TEST_DIR/expected" "$SSH_TEST_DIR/previous"
  ln -s "$SSH_TEST_DIR/previous" "$target"
  result=0

  # Act
  setup_server || result=$?

  # Assert
  [[ "$result" != 0 ]] || fail 'configuration symlink accepted'
  [[ -L "$target" ]] || fail 'configuration symlink removed'
  [[ "$(readlink "$target")" == "$SSH_TEST_DIR/previous" ]] || fail 'configuration symlink retargeted'
  cmp "$SSH_TEST_DIR/previous" "$SSH_TEST_DIR/expected" || fail 'symlink destination changed'
)

test_dry_run_does_not_invoke_sudo
test_invalid_option_is_rejected_without_sudo
test_new_configuration_is_installed_and_reloaded
test_repeat_setup_preserves_configuration
test_overridden_settings_restore_previous_configuration
test_invalid_new_configuration_is_removed
test_inactive_service_is_not_reloaded
test_configuration_symlink_is_preserved

printf 'SSH server setup tests passed\n'
