#!/bin/bash
# kit-codex-session.sh — tmux + Codex CLI session ensure.
#
# Usage:
#   kit-codex-session.sh <session_name> <workdir> [--resume]
#
# Environment:
#   CODEX_MODEL / DSKET_CODEX_MODEL / KIT_CODEX_MODEL  model name, default gpt-5.3-codex
#   KIT_CODEX_BYPASS_APPROVALS=1                       add --dangerously-bypass-approvals-and-sandbox
#   KIT_CODEX_NO_ALT_SCREEN=1                          add --no-alt-screen, default 1
#   KIT_CODEX_EXTRA_ARGS="..."                         extra args appended after standard args
#
# Behavior:
#   1. Add workdir to ~/.codex/config.toml as trusted (idempotent)
#   2. Skip if tmux session already exists
#   3. Start Codex with explicit model and -C <workdir>
#   4. If --resume was requested, try `codex --model <model> resume --last ...`; fallback to fresh codex

set -uo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/kit-log-dir.sh" 2>/dev/null || {
  kit_log_path() { echo "$HOME/.logs/$1.log"; }
}

LOG="$(kit_log_path kit-codex-session)"
mkdir -p "$(dirname "$LOG")"

SESSION="${1:-}"
WORKDIR="${2:-}"
RESUME=""
[ "${3:-}" = "--resume" ] && RESUME="1"
CODEX_MODEL="${CODEX_MODEL:-${KIT_CODEX_MODEL:-${DSKET_CODEX_MODEL:-gpt-5.3-codex}}}"
NO_ALT_SCREEN="${KIT_CODEX_NO_ALT_SCREEN:-1}"
BYPASS="${KIT_CODEX_BYPASS_APPROVALS:-1}"
EXTRA_ARGS="${KIT_CODEX_EXTRA_ARGS:-}"

if [ -z "$SESSION" ] || [ -z "$WORKDIR" ]; then
  echo "Usage: $0 <session_name> <workdir> [--resume]" >&2
  exit 1
fi

if [ ! -d "$WORKDIR" ]; then
  echo "workdir missing: $WORKDIR" >&2
  exit 1
fi

CONFIG="$HOME/.codex/config.toml"
mkdir -p "$(dirname "$CONFIG")"
touch "$CONFIG"
ABSWORKDIR="$(cd "$WORKDIR" && pwd)"
if ! grep -Fq "\"$ABSWORKDIR\"" "$CONFIG"; then
  {
    echo ""
    echo "[projects.\"$ABSWORKDIR\"]"
    echo 'trust_level = "trusted"'
  } >> "$CONFIG"
  echo "[$(date '+%F %T')] codex config trust added: $ABSWORKDIR" >> "$LOG"
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "[$(date '+%F %T')] $SESSION exists — skip" >> "$LOG"
  exit 0
fi

COMMON_ARGS=(--model "$CODEX_MODEL")
if [ "$BYPASS" = "1" ]; then
  COMMON_ARGS+=(--dangerously-bypass-approvals-and-sandbox)
fi
COMMON_ARGS+=(-C "$ABSWORKDIR")
if [ "$NO_ALT_SCREEN" = "1" ]; then
  COMMON_ARGS+=(--no-alt-screen)
fi

# shell-escape arg array into command string for tmux.
printf -v COMMON_Q ' %q' "${COMMON_ARGS[@]}"
if [ -n "$EXTRA_ARGS" ]; then
  COMMON_Q="$COMMON_Q $EXTRA_ARGS"
fi

if [ -n "$RESUME" ]; then
  CMD="export PATH=\$HOME/.bun/bin:\$PATH; codex$COMMON_Q resume --last 2>/dev/null || exec codex$COMMON_Q"
else
  CMD="export PATH=\$HOME/.bun/bin:\$PATH; exec codex$COMMON_Q"
fi

tmux new-session -d -s "$SESSION" -c "$ABSWORKDIR" "$CMD"
echo "[$(date '+%F %T')] START $SESSION (workdir=$ABSWORKDIR resume=${RESUME:-0} model=$CODEX_MODEL bypass=$BYPASS no_alt_screen=$NO_ALT_SCREEN)" >> "$LOG"

sleep 5
PANE="$(tmux capture-pane -t "$SESSION" -p 2>/dev/null || echo "")"
if echo "$PANE" | grep -qE "trust.*contents|Do you trust"; then
  tmux send-keys -t "$SESSION" '1' Enter
  echo "[$(date '+%F %T')] trust dialog auto-approved for $SESSION" >> "$LOG"
fi

echo "START $SESSION"
