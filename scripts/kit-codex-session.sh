#!/bin/bash
# kit-codex-session.sh — tmux + Codex CLI 세션 기동.
# trust 다이얼로그 자동 승인 + ~/.codex/config.toml 에 trust_level 자동 추가.
#
# 사용:
#   kit-codex-session.sh <session_name> <workdir> [--resume]
#
# 동작:
#   1. workdir 을 ~/.codex/config.toml 의 [projects."<workdir>"] trust_level="trusted" 로 등록 (없으면)
#   2. 세션 이미 있으면 skip
#   3. tmux new-session 후 trust 다이얼로그 자동 승인
#
# 의존: codex CLI, tmux, kit-log-dir.sh

set -uo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/kit-log-dir.sh" 2>/dev/null || {
  kit_log_path() { echo "$HOME/.logs/$1.log"; }
}

LOG="$(kit_log_path kit-codex-session)"
mkdir -p "$(dirname "$LOG")"

SESSION="${1:-}"
WORKDIR="${2:-}"
RESUME_FLAG=""
[ "${3:-}" = "--resume" ] && RESUME_FLAG="resume --last"

if [ -z "$SESSION" ] || [ -z "$WORKDIR" ]; then
  echo "사용: $0 <session_name> <workdir> [--resume]"
  exit 1
fi

if [ ! -d "$WORKDIR" ]; then
  echo "workdir 없음: $WORKDIR" >&2
  exit 1
fi

# 1. Codex config 에 trust 추가 (멱등)
CONFIG="$HOME/.codex/config.toml"
mkdir -p "$(dirname "$CONFIG")"
touch "$CONFIG"
ABSWORKDIR="$(cd "$WORKDIR" && pwd)"
if ! grep -q "\"$ABSWORKDIR\"" "$CONFIG"; then
  {
    echo ""
    echo "[projects.\"$ABSWORKDIR\"]"
    echo 'trust_level = "trusted"'
  } >> "$CONFIG"
  echo "[$(date '+%F %T')] codex config trust 추가: $ABSWORKDIR" >> "$LOG"
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "[$(date '+%F %T')] $SESSION 이미 존재 — skip" >> "$LOG"
  exit 0
fi

# Codex 실행 — resume 가능하면 시도, 실패시 fresh
if [ -n "$RESUME_FLAG" ]; then
  CMD="export PATH=\$HOME/.bun/bin:\$PATH && (codex $RESUME_FLAG 2>/dev/null || codex)"
else
  CMD="export PATH=\$HOME/.bun/bin:\$PATH && codex"
fi

tmux new-session -d -s "$SESSION" -c "$WORKDIR" "$CMD"
echo "[$(date '+%F %T')] START $SESSION (workdir=$WORKDIR resume=${RESUME_FLAG:-none})" >> "$LOG"

# trust 다이얼로그 자동 승인 (Codex 도 같은 패턴)
sleep 5
PANE="$(tmux capture-pane -t "$SESSION" -p 2>/dev/null || echo "")"
if echo "$PANE" | grep -qE "trust.*contents|Do you trust"; then
  tmux send-keys -t "$SESSION" '1' Enter
  echo "[$(date '+%F %T')] trust dialog auto-approved for $SESSION" >> "$LOG"
fi

echo "START $SESSION"
