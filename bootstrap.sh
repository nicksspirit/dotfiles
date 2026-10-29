#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/scripts/lib.sh"

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [options]

Installs the bootstrap baseline and any selected packages and dependencies.

Options:
  -n, --dry-run          Print planned commands without changing files
  -p, --package NAME     Add a package and its dependencies
      --adopt            Pass --adopt to GNU Stow when stowing packages
      --overwrite        Remove existing package-file targets before stowing
  -r, --reinstall        Reinstall explicitly selected packages' tools
  -h, --help             Show this help message

Optional environment:
  NO_COLOR=1        Disable colored bootstrap output

Examples:
  ./bootstrap.sh --dry-run
  ./bootstrap.sh
  ./bootstrap.sh --adopt
  ./bootstrap.sh --overwrite
  ./bootstrap.sh --dry-run --reinstall --package jq
  ./bootstrap.sh --package claude
EOF
}

DRY_RUN=0
ADOPT=0
OVERWRITE=0
REINSTALL=0
declare -a BOOTSTRAP_PACKAGES=()

# Parse and validate package IDs before running any setup.
while (($#)); do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -p|--package)
      if [ "$#" -lt 2 ]; then
        printf 'bootstrap: missing value for %s\n' "$1" >&2
        usage >&2
        exit 1
      fi
      BOOTSTRAP_PACKAGES+=("$2")
      shift 2
      ;;
    --package=*)
      BOOTSTRAP_PACKAGES+=("${1#*=}")
      shift
      ;;
    --adopt)
      ADOPT=1
      shift
      ;;
    --overwrite)
      OVERWRITE=1
      shift
      ;;
    -r|--reinstall)
      REINSTALL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'bootstrap: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$REINSTALL" == 1 ]] && ((${#BOOTSTRAP_PACKAGES[@]} == 0)); then
  printf 'bootstrap: --reinstall requires at least one --package (for example: --reinstall --package jq)\n' >&2
  exit 1
fi

if ((${#BOOTSTRAP_PACKAGES[@]})); then
  if ! registry_validate "${BOOTSTRAP_PACKAGES[@]}"; then
    usage >&2
    exit 1
  fi
  declare -a canonical_packages=()

  for requested in "${BOOTSTRAP_PACKAGES[@]}"; do
    canonical_packages+=("$(registry_resolve "$requested")")
  done
  BOOTSTRAP_PACKAGES=("${canonical_packages[@]}")
fi

BOOTSTRAP_REINSTALL_PACKAGES=
if [[ "$REINSTALL" == 1 ]]; then
  BOOTSTRAP_REINSTALL_PACKAGES="${BOOTSTRAP_PACKAGES[*]}"
fi

# The baseline and transitive dependencies are selected for every run.
case " ${BOOTSTRAP_PACKAGES[*]-} " in
  *' __core__ '*) ;;
  *) BOOTSTRAP_PACKAGES+=(__core__) ;;
esac

for ((package_index = 0; package_index < ${#BOOTSTRAP_PACKAGES[@]}; package_index++)); do
  selected_package="${BOOTSTRAP_PACKAGES[package_index]}"
  registry_load_unit "$selected_package"
  if ((${#REGISTRY_PACKAGE_DEPENDENCIES[@]})); then
    for required_package in "${REGISTRY_PACKAGE_DEPENDENCIES[@]}"; do
      required_package="$(registry_resolve "$required_package")"
      case " ${BOOTSTRAP_PACKAGES[*]} " in
        *" $required_package "*) ;;
        *) BOOTSTRAP_PACKAGES+=("$required_package") ;;
      esac
    done
  fi
done

if [[ "$ADOPT" == "1" && "$OVERWRITE" == "1" ]]; then
  printf 'bootstrap: --adopt and --overwrite cannot be used together\n' >&2
  exit 1
fi

export DRY_RUN
export ADOPT
export OVERWRITE
export BOOTSTRAP_REINSTALL_PACKAGES
export BOOTSTRAP_PACKAGES="${BOOTSTRAP_PACKAGES[*]-}"
selected_packages="$BOOTSTRAP_PACKAGES"

# Run package-specific setup only when its owner was selected.
scripts=()
if registry_hook_selected setup-wsl; then
  scripts+=(setup-wsl.sh)
fi

scripts+=(setup-tools.sh setup-stow.sh)

if registry_hook_selected setup-ssh-server; then
  scripts+=(setup-ssh-server.sh)
fi

if registry_hook_selected setup-linux-laptop; then
  scripts+=(setup-linux-laptop.sh)
fi

if bootstrap_package_selected micro; then
  scripts+=(setup-micro.sh)
fi

if bootstrap_package_selected tmux; then
  scripts+=(setup-tmux.sh)
fi

if bootstrap_package_selected treemux; then
  scripts+=(setup-treemux.sh)
fi

if bootstrap_package_selected nvim; then
  scripts+=(setup-nvim.sh)
fi

if bootstrap_package_selected pi; then
  scripts+=(setup-pi.sh)
fi

for script in "${scripts[@]}"; do
  ensure_executable "${script_dir}/scripts/${script}"
  BOOTSTRAP_PACKAGES="$selected_packages" "${script_dir}/scripts/${script}"
done

log "Bootstrap complete"
