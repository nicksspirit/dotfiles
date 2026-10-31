#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
export NO_COLOR=1

fail() { printf '%s\n' "$*" >&2; exit 1; }

arrange_fixture() {
  fixture="$test_dir/$1"
  mkdir -p "$fixture/repo/scripts" "$fixture/home" "$fixture/bin"
  cp "$repo_root/scripts/"{lib.sh,package-registry.sh,setup-tmux.sh} "$fixture/repo/scripts/"
  printf '#!/bin/sh\nexit 1\n' > "$fixture/bin/git"
  chmod +x "$fixture/bin/git"
}

install_fake_tpm() {
  mkdir -p "$fixture/home/.tmux/plugins/tpm/bin"
  cat > "$fixture/home/.tmux/plugins/tpm/bin/install_plugins" <<'EOF'
#!/usr/bin/env bash
set -eu
mkdir -p "$HOME/.tmux/plugins/downloaded-plugin"
EOF
  chmod +x "$fixture/home/.tmux/plugins/tpm/bin/install_plugins"
}

setup_tmux() {
  HOME="$fixture/home" PATH="$fixture/bin:/usr/bin:/bin" bash "$fixture/repo/scripts/setup-tmux.sh" "$@" > "$fixture/output" 2>&1
}

test_folded_plugin_parents_are_rejected() (
  # Arrange
  local parent
  for parent in .tmux .tmux/plugins; do
    arrange_fixture "${parent//\//-}"
    mkdir -p "$fixture/repo/monitor/.tmux/plugins" "$(dirname "$fixture/home/$parent")"
    ln -s "$fixture/repo/monitor/$parent" "$fixture/home/$parent"
    install_fake_tpm
    result=0

    # Act
    setup_tmux || result=$?

    # Assert
    [[ "$result" != 0 ]] || fail "accepted folded $parent"
    grep -q 'plugin directory resolves inside the dotfiles repository' "$fixture/output" || fail 'missing migration guidance'
    [[ ! -e "$fixture/repo/monitor/.tmux/plugins/downloaded-plugin" ]] || fail 'TPM wrote into the repository'
    [[ -L "$fixture/home/$parent" ]] || fail 'existing link was removed'
  done
)

test_real_plugin_parents_allow_installation() (
  # Arrange
  arrange_fixture real-directories
  install_fake_tpm

  # Act
  setup_tmux

  # Assert
  [[ -d "$fixture/home/.tmux/plugins/downloaded-plugin" ]] || fail 'TPM did not install into home'
  [[ ! -e "$fixture/repo/monitor" ]] || fail 'TPM wrote into the repository'
)

test_folded_tmux_without_plugins_is_rejected() (
  # Arrange
  arrange_fixture empty-folded-tmux
  mkdir "$fixture/repo/.tmux"
  ln -s "$fixture/repo/.tmux" "$fixture/home/.tmux"
  result=0

  # Act
  setup_tmux || result=$?

  # Assert
  [[ "$result" != 0 ]] || fail 'accepted folded parent without plugins'
  grep -q 'plugin directory resolves inside the dotfiles repository' "$fixture/output" || fail 'missing migration guidance'
  [[ ! -e "$fixture/repo/.tmux/plugins" ]] || fail 'created plugins inside the repository'
)

test_dry_run_preserves_folded_parents() (
  # Arrange
  arrange_fixture dry-run
  mkdir -p "$fixture/repo/monitor/.tmux/plugins"
  ln -s "$fixture/repo/monitor/.tmux" "$fixture/home/.tmux"
  install_fake_tpm

  # Act
  setup_tmux --dry-run

  # Assert
  [[ -L "$fixture/home/.tmux" ]] || fail 'dry run removed the existing link'
  [[ ! -e "$fixture/repo/monitor/.tmux/plugins/downloaded-plugin" ]] || fail 'dry run invoked TPM'
)

test_stow_keeps_plugin_downloads_outside_the_repository() (
  # Arrange
  if ! command -v stow >/dev/null 2>&1; then
    printf 'SKIP: real Stow deployment test requires stow\n' >&2
    exit 0
  fi
  arrange_fixture real-stow
  source "$repo_root/scripts/package-registry.sh"
  registry_load_unit tmux-cpu-mem-monitor
  package_dir="$fixture/repo/$REGISTRY_STOW_PACKAGE"
  mkdir -p "$package_dir/.tmux/plugins/tmux-cpu-mem-monitor"
  printf '# monitor fixture\n' > "$package_dir/.tmux/plugins/tmux-cpu-mem-monitor/plugin.tmux"

  # Act
  stow -d "$fixture/repo" -t "$fixture/home" "${REGISTRY_STOW_ARGS[@]}" "$REGISTRY_STOW_PACKAGE"
  mkdir "$fixture/home/.tmux/plugins/downloaded-plugin"
  stow -d "$fixture/repo" -t "$fixture/home" "${REGISTRY_STOW_ARGS[@]}" "$REGISTRY_STOW_PACKAGE"

  # Assert
  [[ ! -L "$fixture/home/.tmux" && ! -L "$fixture/home/.tmux/plugins" ]] || fail 'Stow folded plugin parents'
  [[ -f "$fixture/home/.tmux/plugins/tmux-cpu-mem-monitor/plugin.tmux" ]] || fail 'monitor was not deployed'
  [[ ! -e "$package_dir/.tmux/plugins/downloaded-plugin" ]] || fail 'plugin download leaked into the repository'
)

test_folded_plugin_parents_are_rejected
test_folded_tmux_without_plugins_is_rejected
test_real_plugin_parents_allow_installation
test_dry_run_preserves_folded_parents
test_stow_keeps_plugin_downloads_outside_the_repository
