#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib.sh"

enable_error_trap
parse_dry_run_args scripts/setup-pi.sh "$@"

if ! registry_hook_selected setup-pi; then
  exit 0
fi

log "pi"

reinstall_pi=0
case " ${BOOTSTRAP_REINSTALL_PACKAGES:-} " in
  *" pi "*) reinstall_pi=1 ;;
esac

if [[ "$reinstall_pi" == 1 ]] || ! command -v pi >/dev/null 2>&1; then
  sublog "installer"
  run_sh "curl -fsSL https://pi.dev/install.sh | sh"
else
  status skip "pi CLI already installed"
fi

npm_dir="$HOME/.pi/agent/npm"

if [ ! -d "$npm_dir" ]; then
  status skip "~/.pi/agent/npm not found; no managed extensions to install"
elif [[ "$reinstall_pi" == 1 ]] || ! npm ls --prefix "$npm_dir" --depth=0 >/dev/null 2>&1; then
  sublog "extension packages"
  if is_dry_run; then
    status plan "npm install --prefix $npm_dir"
  else
    run npm install --prefix "$npm_dir"
  fi
else
  status skip "managed extension packages already installed"
fi
