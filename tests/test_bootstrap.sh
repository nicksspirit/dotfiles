#!/usr/bin/env bash
set -euo pipefail

# Shared fixture: isolate the home and make apt packages appear uninstalled.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin" "$test_dir/home"
printf '#!/bin/sh\nexit 1\n' > "$test_dir/bin/dpkg-query"
printf '#!/bin/sh\nprintf "x86_64\\n"\n' > "$test_dir/bin/uname"
chmod +x "$test_dir/bin/dpkg-query" "$test_dir/bin/uname"
export HOME="$test_dir/home" PATH="$test_dir/bin:/usr/bin:/bin" NO_COLOR=1

test_setup_scripts_are_executable() {
  # Arrange
  local script
  local non_executable=()

  # Act
  for script in "$repo_root"/scripts/setup-*.sh; do
    [[ -x "$script" ]] || non_executable+=("$script")
  done

  # Assert
  if ((${#non_executable[@]})); then
    printf 'setup script is not executable: %s\n' "${non_executable[@]}" >&2
    return 1
  fi
}

test_default_baseline() {
  # Arrange
  local output unexpected
  local baseline='sudo apt-get install -y ca-certificates curl stow fastfetch'

  # Act
  output="$(WSL_DISTRO_NAME=test "$repo_root/bootstrap.sh" --dry-run)"

  # Assert
  [[ "$output" == *"$baseline"* ]] || { printf 'missing baseline\n' >&2; return 1; }
  for unexpected in 'npiperelay' '1password' 'stow -nv' '==> WSL' '==> micro plugins'; do
    [[ "$output" != *"$unexpected"* ]] || { printf 'unexpected: %s\n' "$unexpected" >&2; return 1; }
  done
}

test_wsl_opt_in() {
  # Arrange
  local output

  # Act
  output="$(WSL_DISTRO_NAME=test "$repo_root/bootstrap.sh" --dry-run -p wsl)"

  # Assert
  [[ "$output" == *'==> WSL'* && "$output" == *'/etc/wsl.conf'* && "$output" != *npiperelay* ]] || {
    printf 'WSL setup did not match the selected package\n' >&2; return 1;
  }
}

test_1password_dependencies() {
  # Arrange
  local output

  # Act
  output="$("$repo_root/bootstrap.sh" --dry-run -p 1password)"

  # Assert
  [[ "$output" == *socat* && "$output" == *unzip* && "$output" == *npiperelay.exe* && "$output" == *'stow -nv 1password'* && "$output" != *'==> WSL'* ]] || {
    printf '1Password dependencies did not match the selected package\n' >&2; return 1;
  }
}

test_transitive_dependencies() {
  # Arrange
  local output expected
  local expected_items=('ca-certificates curl stow' 'git patch' 'xclip build-essential ripgrep'
    'fastfetch' 'stow -nv tmux' 'stow -nv fzf' 'stow -nv local-bin'
    'stow -nv nvim' 'stow -nv treemux' 'stow -nv tmux-cpu-mem-monitor' 'uv venv')

  # Act
  output="$("$repo_root/bootstrap.sh" --dry-run -p treemux -p tmux-cpu-mem-monitor)"

  # Assert
  for expected in "${expected_items[@]}"; do
    [[ "$output" == *"$expected"* ]] || { printf 'missing: %s\n' "$expected" >&2; return 1; }
  done
}

test_zip_dependencies() {
  # Arrange
  local output

  # Act
  output="$("$repo_root/bootstrap.sh" --dry-run -p npiperelay)"

  # Assert
  [[ "$output" == *unzip* && "$output" != *build-essential* ]] || {
    printf 'ZIP dependencies did not match the selected package\n' >&2; return 1;
  }
}

test_core_baseline() {
  # Arrange
  local output
  local baseline='sudo apt-get install -y ca-certificates curl stow fastfetch'

  # Act
  output="$("$repo_root/bootstrap.sh" --dry-run -p core)"

  # Assert
  [[ "$output" == *"$baseline"* && "$output" != *universal-ctags* ]] || {
    printf 'core did not match the baseline\n' >&2; return 1;
  }
}

test_reinstall_selected_package() {
  # Arrange
  local output
  mkdir -p "$test_dir/installed"
  printf '#!/bin/sh\nprintf "install ok installed\\n"\n' > "$test_dir/installed/dpkg-query"
  chmod +x "$test_dir/installed/dpkg-query"

  # Act
  output="$(PATH="$test_dir/installed:$PATH" "$repo_root/bootstrap.sh" --dry-run --reinstall -p jq)"

  # Assert
  [[ "$output" == *'sudo apt-get install -y --reinstall jq'* && "$output" != *'--reinstall jq ca-certificates'* && "$output" == *'ca-certificates already installed'* ]] || {
    printf 'reinstall did not target only jq\n' >&2; return 1;
  }
}

test_reinstall_requires_package() {
  # Arrange
  local output result option dry_run

  for option in --reinstall -r; do
    for dry_run in '' --dry-run; do
      result=0

      # Act
      output="$("$repo_root/bootstrap.sh" $dry_run "$option" 2>&1)" || result=$?

      # Assert
      [[ "$result" != 0 && "$output" == *'--reinstall requires at least one --package'* && "$output" != *'==> apt packages'* ]] || {
        printf 'missing package accepted for %s %s\n' "$option" "$dry_run" >&2; return 1;
      }
    done
  done
}

test_reinstall_short_option() {
  # Arrange
  local output

  # Act
  output="$("$repo_root/bootstrap.sh" --dry-run -r -p jq -p yq)"

  # Assert
  [[ "$output" == *'sudo apt-get install -y --reinstall jq yq'* && "$output" == *'sudo apt-get install -y ca-certificates curl stow fastfetch'* ]] || {
    printf 'short option did not target both packages\n' >&2; return 1;
  }
}

test_reinstall_skips_installed_dependency_tools() {
  # Arrange
  local output tool
  mkdir -p "$test_dir/installed-tools"
  for tool in nvim uv fzf; do
    printf '#!/bin/sh\nexit 0\n' > "$test_dir/installed-tools/$tool"
    chmod +x "$test_dir/installed-tools/$tool"
  done

  # Act
  output="$(PATH="$test_dir/installed-tools:$PATH" "$repo_root/bootstrap.sh" --dry-run -r -p treemux)"

  # Assert
  [[ "$output" == *'nvim already installed'* && "$output" == *'uv already installed'* && "$output" == *'fzf already installed'* ]] || {
    printf 'reinstall unexpectedly forced a dependency tool\n' >&2; return 1;
  }
}

test_reinstall_github_alias() {
  # Arrange
  local output
  mkdir -p "$test_dir/installed-tools"
  printf '#!/bin/sh\nexit 0\n' > "$test_dir/installed-tools/nvim"
  chmod +x "$test_dir/installed-tools/nvim"

  # Act
  output="$(PATH="$test_dir/installed-tools:$PATH" "$repo_root/bootstrap.sh" --dry-run -r -p neovim)"

  # Assert
  [[ "$output" == *'github.com/neovim/neovim/releases/latest/download/'* ]] || {
    printf 'reinstall did not force the aliased GitHub package\n' >&2; return 1;
  }
}

test_removed_prerequisite_id() {
  # Arrange
  local output result=0

  # Act
  output="$("$repo_root/bootstrap.sh" --dry-run -p bootstrap-prerequisites 2>&1)" || result=$?

  # Assert
  [[ "$result" != 0 && "$output" == *'unknown bootstrap package: bootstrap-prerequisites'* ]] || {
    printf 'removed prerequisite ID was not rejected\n' >&2; return 1;
  }
}

test_setup_scripts_are_executable
test_default_baseline
test_wsl_opt_in
test_1password_dependencies
test_transitive_dependencies
test_zip_dependencies
test_core_baseline
test_reinstall_selected_package
test_reinstall_requires_package
test_reinstall_short_option
test_reinstall_skips_installed_dependency_tools
test_reinstall_github_alias
test_removed_prerequisite_id
