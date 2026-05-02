#!/bin/bash
# kit-opencode-session.sh — tmux + opencode TUI 세션 기동.
# opencode 는 자체 TUI 라 trust 다이얼로그 없음 (OpenCode CLI 가 자체 처리).
#
# 사용:
#   kit-opencode-session.sh <session_name> <workdir> [--resume]
#   kit-opencode-session.sh <session_name> <workdir> --model openai/gpt-5.5
#
# 동작:
#   1. 세션 이미 있으면 skip (idempotent)
#   2. tmux new-session 후 opencode TUI 실행
#   3. --resume 시 -c (continue last session) 추가
#
# 의존: opencode CLI (보통 ~/.nvm/versions/node/<v>/bin/opencode), tmux

set -uo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/kit-log-dir.sh" 2>/dev/null || {
  kit_log_path() { echo "$HOME/.logs/$1.log"; }
}

LOG="$(kit_log_path kit-opencode-session)"
mkdir -p "$(dirname "$LOG")"

SESSION="${1:-}"
WORKDIR="${2:-}"
EXTRA_FLAG=""
MODEL=""

# 인자 파싱 (--resume, --model X)
shift 2 2>/dev/null || true
while [ $# -gt 0 ]; do
  case "$1" in
    --resume) EXTRA_FLAG="$EXTRA_FLAG -c"; shift ;;
    --model)  MODEL="$2"; shift 2 ;;
    *)        shift ;;
  esac
done

if [ -z "$SESSION" ] || [ -z "$WORKDIR" ]; then
  echo "사용: $0 <session_name> <workdir> [--resume] [--model provider/model]"
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

# opencode 는 nvm 으로 설치되는 경우가 많아서 nvm 로드를 위해 zsh -lic 사용
# (PATH 자동 정렬)
MODEL_ARG=""
[ -n "$MODEL" ] && MODEL_ARG="--model $MODEL"

CMD="zsh -lic 'opencode $EXTRA_FLAG $MODEL_ARG'"
tmux new-session -d -s "$SESSION" -c "$WORKDIR" "$CMD"
echo "[$(date '+%F %T')] START $SESSION (workdir=$WORKDIR resume=$([ -n \"$EXTRA_FLAG\" ] && echo yes || echo no) model=${MODEL:-default})" >> "$LOG"

echo "START $SESSION"
