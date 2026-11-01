#!/usr/bin/env bash
set -euo pipefail

if ! command -v tmux >/dev/null 2>&1; then
  printf 'SKIP: session dots test requires tmux\n' >&2
  exit 0
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
sock="$test_dir/tmux.sock"
real_tmux="$(command -v tmux)"
tmux() { "$real_tmux" -S "$sock" "$@"; }
cleanup() {
  if [[ -S "$sock" ]]; then
    while IFS= read -r session; do
      tmux kill-session -t "$session" 2>/dev/null || true
    done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)
  fi
  rm -rf "$test_dir"
}
trap cleanup EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

mkdir -p "$test_dir/scripts" "$test_dir/bin"
if ! git -C "$HOME/.tmux/plugins/tmux-agent-indicator" show HEAD:scripts/session-dots.sh > "$test_dir/scripts/session-dots.sh" 2>/dev/null; then
  printf 'SKIP: session dots test requires an installed tmux-agent-indicator git checkout\n' >&2
  exit 0
fi
patch -s -d "$test_dir" -p1 < "$repo_root/tmux/patches/tmux-agent-indicator-session-dots.patch"
cat > "$test_dir/bin/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$TMUX_CALLS"
exec "$REAL_TMUX" -S "$TMUX_SOCK" "$@"
EOF
chmod +x "$test_dir/bin/tmux"
export REAL_TMUX="$real_tmux" TMUX_SOCK="$sock" TMUX_CALLS="$test_dir/calls"

tmux -f /dev/null new-session -d -s alpha
tmux new-session -d -s beta
tmux new-session -d -s gamma
pane=$(tmux display-message -p -t beta '#{pane_id}')
tmux set-environment -g "TMUX_AGENT_PANE_${pane}_STATE" running
# Preserve explicitly empty symbols as well as options containing spaces.
tmux set-option -g @agent-indicator-session-dots-active ''
tmux set-option -g @agent-indicator-session-dots-running 'WORK ING'
tmux set-option -g @agent-indicator-session-dots-running-color brightred
tmux set-option -g @agent-indicator-session-dots-separator '|'
tmux set-option -g @agent-indicator-session-dots-idle '1,2,3'
tmux set-option -g @agent-indicator-session-dots-reset-style '#[fg=white]'
run_dots() {
  : > "$TMUX_CALLS"
  PATH="$test_dir/bin:$PATH" bash "$test_dir/scripts/session-dots.sh" alpha
}
output=$(run_dots)
[[ "$output" == '|#[fg=brightred]WORK ING#[fg=white]|3' ]] || fail "custom/empty options or running state: $output"
[[ $(grep -c '^show-options$' "$TMUX_CALLS") == 1 ]] || fail 'expected one batched option presence read'
[[ $(grep -c '^display-message$' "$TMUX_CALLS") == 3 ]] || fail 'expected one batched option value read plus initial and pane lookup'
[[ $(wc -l < "$TMUX_CALLS") == 7 ]] || fail 'unexpected tmux child process count'

# Higher-priority needs-input wins even when a different pane is running.
alert_pane=$(tmux split-window -d -P -F '#{pane_id}' -t beta)
tmux set-environment -g "TMUX_AGENT_PANE_${alert_pane}_STATE" needs-input
output=$(run_dots)
[[ "$output" == '|#[fg=yellow]●#[fg=white]|3' ]] || fail "needs-input priority: $output"
tmux set-environment -gu "TMUX_AGENT_PANE_${alert_pane}_STATE"

tmux set-environment -g "TMUX_AGENT_PANE_${pane}_STATE" done
output=$(run_dots)
[[ "$output" == '|#[fg=green]✓#[fg=white]|3' ]] || fail "done marker: $output"
tmux set-option -g @agent-indicator-session-dots-attention-states 'blocked,done'
tmux set-environment -g "TMUX_AGENT_PANE_${pane}_STATE" blocked
output=$(run_dots)
[[ "$output" == '|#[fg=yellow]●#[fg=white]|3' ]] || fail "custom attention marker: $output"
tmux set-environment -gu "TMUX_AGENT_PANE_${pane}_STATE"
output=$(run_dots)
[[ "$output" == '|2|3' ]] || fail "idle marker: $output"
patch --dry-run --reverse --forward -s -d "$test_dir" -p1 < "$repo_root/tmux/patches/tmux-agent-indicator-session-dots.patch" >/dev/null 2>&1 || fail 'complete patch not recognized'
sed -i '/^attention_style=/d' "$test_dir/scripts/session-dots.sh"
if patch --dry-run --reverse --forward -s -d "$test_dir" -p1 < "$repo_root/tmux/patches/tmux-agent-indicator-session-dots.patch" >/dev/null 2>&1; then
  fail 'partial patch mistaken for complete installation'
fi
printf 'PASS: patched session dots batch option reads and preserve marker styling\n'
