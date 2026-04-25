#!/bin/bash
# kit-claude-session.sh — tmux + Claude Code 세션 기동.
# trust 다이얼로그 자동 승인.
#
# 사용:
#   kit-claude-session.sh <session_name> <workdir> [--resume]
#
# 동작:
#   1. 세션 이미 있으면 skip
#   2. tmux new-session -d -s <name> -c <workdir> 'claude ...'
#   3. 4초 대기 후 trust 다이얼로그 있으면 '1' + Enter 자동 전송
#
# 의존: claude CLI, tmux, kit-log-dir.sh

set -uo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/kit-log-dir.sh" 2>/dev/null || {
  kit_log_path() { echo "$HOME/.logs/$1.log"; }
}

LOG="$(kit_log_path kit-claude-session)"
mkdir -p "$(dirname "$LOG")"

SESSION="${1:-}"
WORKDIR="${2:-}"
RESUME_FLAG=""
[ "${3:-}" = "--resume" ] && RESUME_FLAG="-c"

if [ -z "$SESSION" ] || [ -z "$WORKDIR" ]; then
  echo "사용: $0 <session_name> <workdir> [--resume]"
  exit 1
fi

if [ ! -d "$WORKDIR" ]; then
  echo "workdir 없음: $WORKDIR" >&2
  exit 1
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "[$(date '+%F %T')] $SESSION 이미 존재 — skip" >> "$LOG"
  exit 0
fi

# resume 가능 여부 재확인 — Claude Code 세션 디렉터리 존재하면 -c 유효
if [ -n "$RESUME_FLAG" ]; then
  PROJ_HASH="$(echo "$WORKDIR" | sed 's|/|-|g')"
  if [ ! -d "$HOME/.claude/projects/$PROJ_HASH" ]; then
    RESUME_FLAG=""
    echo "[$(date '+%F %T')] 이전 세션 없음 — --resume 무시" >> "$LOG"
  fi
fi

CMD="export PATH=\$HOME/.bun/bin:\$PATH && claude --dangerously-skip-permissions $RESUME_FLAG"
tmux new-session -d -s "$SESSION" -c "$WORKDIR" "$CMD"
echo "[$(date '+%F %T')] START $SESSION (workdir=$WORKDIR resume=${RESUME_FLAG:-none})" >> "$LOG"

# trust 다이얼로그 자동 승인
sleep 4
PANE="$(tmux capture-pane -t "$SESSION" -p 2>/dev/null || echo "")"
if echo "$PANE" | grep -q "trust this folder\|trust the folder"; then
  tmux send-keys -t "$SESSION" '1' Enter
  sleep 1
  tmux send-keys -t "$SESSION" Enter
  echo "[$(date '+%F %T')] trust dialog auto-approved for $SESSION" >> "$LOG"
fi

echo "START $SESSION"
