#!/usr/bin/env bash
set -euo pipefail

# kit-codex-tmux-submit.sh — robust prompt submit helper for Codex TUI in tmux.
#
# Usage:
#   printf '%s' "$PROMPT" | kit-codex-tmux-submit.sh <session> [buffer-name]
#
# Behavior:
#   - refuses missing/empty prompts
#   - refuses currently active/compacting panes
#   - refuses approval/permission prompts instead of blindly accepting
#   - clears stale idle input such as Codex default suggestions
#   - pastes via tmux buffer, sends Enter twice, then final Enter only if still idle/queued
#   - logs decisions to ~/.logs/kit-codex-tmux-submit.log unless KIT_CODEX_SUBMIT_LOG is set

SESSION="${1:?session required}"
BUFFER="${2:-kit-codex-submit}"
REAL_HOME="$HOME"
LOG="${KIT_CODEX_SUBMIT_LOG:-$REAL_HOME/.logs/kit-codex-tmux-submit.log}"
mkdir -p "$(dirname "$LOG")"

log(){ echo "$(date '+%F %T') $*" >> "$LOG"; }

pane_tail(){ tmux capture-pane -t "$SESSION" -p -S -30 2>/dev/null | tail -20 || true; }

pane_has_current_active_status(){
  # Codex TUI can leave stale "Working (...)" lines above a fresh prompt.
  # Treat active markers as current only when the latest active marker appears
  # after the latest input prompt marker.
  awk '
    /Working \([0-9]+[smh]/ || /Compacting conversation/ || /^[[:space:]]*(✻|✽|✶|◦|·) [A-Za-z][A-Za-z -]*[.…]/ { active=NR }
    /^› / || /^\[Pasted Content/ { prompt=NR }
    END { exit !((active > 0) && (active > prompt)) }
  '
}

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  log "ERROR missing session=$SESSION"
  exit 2
fi

prompt_text="$(cat)"
if [ -z "$prompt_text" ]; then
  log "ERROR empty prompt session=$SESSION"
  exit 3
fi

before="$(pane_tail)"
if printf '%s\n' "$before" | pane_has_current_active_status; then
  log "SKIP active session=$SESSION"
  exit 4
fi

if printf '%s\n' "$before" | grep -Eqi 'approval required|requires approval|requires permission|permission prompt|continue\?|proceed\?|would you like|allow .*\?|Yes,.*No|Press enter to confirm'; then
  log "SKIP approval_or_permission session=$SESSION"
  exit 5
fi

# Clear stale default suggestions/input before paste.
tmux send-keys -t "$SESSION" C-u || true
sleep 0.2
printf '%s' "$prompt_text" | tmux load-buffer -b "$BUFFER" -
tmux paste-buffer -t "$SESSION" -b "$BUFFER"

# Codex no-alt-screen in tmux often needs two submits: one to accept the edited
# prompt buffer and one to queue/run it.
tmux send-keys -t "$SESSION" C-m
sleep 0.7
tmux send-keys -t "$SESSION" C-m
sleep 2

after="$(pane_tail)"
if printf '%s\n' "$after" | grep -q 'Press up to edit queued messages'; then
  log "queued_after_submit session=$SESSION; sending another Enter"
  tmux send-keys -t "$SESSION" C-m
  sleep 2
  after="$(pane_tail)"
fi

# If the pane is idle and our prompt still appears at the input line, send one
# final Enter. Escape first line for grep ERE.
first_line="$(printf '%s' "$prompt_text" | sed -n '1p' | sed 's/[.[\*^$()+?{}|]/\\&/g')"
if printf '%s\n' "$after" | grep -Eq '^› |\[Pasted Content' && printf '%s\n' "$after" | grep -Eq "$first_line|\[Pasted Content"; then
  if ! printf '%s\n' "$after" | pane_has_current_active_status; then
    log "prompt_still_visible session=$SESSION; sending final Enter"
    tmux send-keys -t "$SESSION" C-m
    sleep 1
  fi
fi

log "submitted session=$SESSION"
