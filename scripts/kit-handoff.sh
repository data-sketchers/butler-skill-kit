#!/bin/bash
# kit-handoff.sh — Primary ↔ Backup 전환 (claude ↔ codex).
# .agent-state.md 기반.
#
# 사용:
#   kit-handoff.sh <session_prefix> claude-to-codex <workdir>
#   kit-handoff.sh <session_prefix> codex-to-claude <workdir>
#
# 예:
#   kit-handoff.sh builder-be claude-to-codex ~/ai-workspace/dsket-webbuilder-be
#
# 세션 네이밍 규칙:
#   <prefix>-claude / <prefix>-codex

set -uo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/kit-log-dir.sh" 2>/dev/null || {
  kit_log_path() { echo "$HOME/.logs/$1.log"; }
}

LOG="$(kit_log_path kit-handoff)"
mkdir -p "$(dirname "$LOG")"

PREFIX="${1:-}"
DIRECTION="${2:-}"
WORKDIR="${3:-}"

if [ -z "$PREFIX" ] || [ -z "$DIRECTION" ] || [ -z "$WORKDIR" ]; then
  echo "사용: $0 <prefix> <claude-to-codex|codex-to-claude> <workdir>"
  exit 1
fi

case "$DIRECTION" in
  claude-to-codex) FROM="claude"; TO="codex" ;;
  codex-to-claude) FROM="codex"; TO="claude" ;;
  *) echo "알 수 없는 direction: $DIRECTION"; exit 1 ;;
esac

FROM_SESSION="${PREFIX}-${FROM}"
TO_SESSION="${PREFIX}-${TO}"

for s in "$FROM_SESSION" "$TO_SESSION"; do
  if ! tmux has-session -t "$s" 2>/dev/null; then
    echo "ERR: $s 세션 없음" >&2
    exit 1
  fi
done

echo "[$(date '+%F %T')] handoff $PREFIX: $FROM → $TO (workdir=$WORKDIR)" >> "$LOG"

# FROM 에 handoff 커밋·state 확정·standby 전환 프롬프트
HANDOFF_MSG="[HANDOFF] 작업을 일시 중단. 순서: 1) 현재 변경을 'chore(${PREFIX#builder-}): handoff from ${FROM}' 로 커밋+푸시. 2) .agent-state.md 갱신 (네가 한 일 요약 → handoff-notes, 다음 스텝 → next-step, 미해결 의문 → open-questions). 3) standby 상태로 전환."
tmux send-keys -t "$FROM_SESSION" "$HANDOFF_MSG" Enter
sleep 1
tmux send-keys -t "$FROM_SESSION" Enter

# 5초 대기
sleep 5

# TO 에 활성화 프롬프트
RESUME_MSG="[HANDOFF IN] 네가 ${PREFIX#builder-} 역할의 primary 로 활성화됐어. 순서: 1) ${WORKDIR}/.agent-state.md 전체 읽기. 2) handoff-notes·next-step·open-questions 확인. 3) current-task (GitLab 이슈) 조회. 4) .agent-state.md 의 active-model 을 ${TO} 로 업데이트. 5) next-step 부터 이어서 시작."
tmux send-keys -t "$TO_SESSION" "$RESUME_MSG" Enter
sleep 1
tmux send-keys -t "$TO_SESSION" Enter

echo "handoff dispatched: $FROM_SESSION → $TO_SESSION"
echo "[$(date '+%F %T')] handoff prompts sent" >> "$LOG"
