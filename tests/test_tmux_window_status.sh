#!/usr/bin/env bash
set -euo pipefail

if ! command -v tmux >/dev/null 2>&1; then
  printf 'SKIP: window status test requires tmux\n' >&2
  exit 0
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
tmux() { command tmux -S "$test_dir/tmux.sock" "$@"; }
trap 'tmux kill-session -t window-status 2>/dev/null || true; rm -rf "$test_dir"' EXIT

tmux -f /dev/null new-session -d -s window-status -n pi
window=$(tmux display-message -p -t window-status '#{window_id}')
# Load only the tab options; TPM and the user's running server are unrelated.
sed -n '/^set -g window-status-/p' "$repo_root/tmux/.tmux.conf" > "$test_dir/tabs.conf"
tmux source-file "$test_dir/tabs.conf"

assert_tab() {
  local option="$1" bg="$2" fg="$3" format
  format=$(tmux display-message -p -t "$window" "#{E:$option}")
  [[ "$format" == "#[fg=black,bg=$bg,nobold,noitalics,nounderscore] "* ]] \
    && { [[ "$format" == *"#[fg=$fg,bg=$bg]"* ]] || [[ "$format" == *"#[bg=$bg,fg=$fg]"* ]]; } \
    && [[ "$format" == *"#[fg=$bg,bg=black,nobold,noitalics,nounderscore]" ]] \
    || { printf 'FAIL: %s should use %s/%s throughout: %s\n' "$option" "$fg" "$bg" "$format" >&2; exit 1; }
}

assert_tab window-status-format brightblack white
assert_tab window-status-current-format cyan black

# These are the window styles agent-state.sh applies for attention states.
for color in yellow red; do
  tmux set-window-option -t "$window" window-status-style "bg=$color,fg=black"
  tmux set-window-option -t "$window" window-status-current-style "bg=$color,fg=black"
  assert_tab window-status-format "$color" black
  assert_tab window-status-current-format "$color" black
done

# Focusing the pane or starting another turn restores the inherited Nord styles.
tmux set-window-option -ut "$window" window-status-style
tmux set-window-option -ut "$window" window-status-current-style
assert_tab window-status-format brightblack white
assert_tab window-status-current-format cyan black
printf 'PASS: Nord tabs follow window styles and restore their default colors\n'
