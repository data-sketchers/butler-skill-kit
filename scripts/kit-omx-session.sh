#!/bin/bash
# kit-omx-session.sh — tmux + omx (oh-my-codex) 세션 기동.
# OMX 자체가 tmux 관리도 하지만, butler-kit 명명 일관성 위해 outer tmux 도 띄움.
# OMX 의 자체 tmux/HUD 는 --direct 로 끄고 (충돌 회피), 단순 codex 처럼 동작시킴.
#
# 사용:
#   kit-omx-session.sh <session_name> <workdir> [--resume]
#   kit-omx-session.sh <session_name> <workdir> --high     # 추론 effort 높임
#   kit-omx-session.sh <session_name> <workdir> --yolo     # yolo 모드 (주의)
#
# 동작:
#   1. 세션 이미 있으면 skip
#   2. tmux new-session 후 omx --direct 실행
#   3. --resume 시 omx resume 추가
#
# 주의:
#   - OMX 첫 실행 시 consent 프롬프트 ("Yes, continue") 가 뜸. 자동 처리는 sleep + send-keys 'Enter'.
#   - --yolo / --madmax 는 sandbox 우회 — 운영 환경에선 신중히.
#
# 의존: omx CLI (보통 ~/.nvm/versions/node/<v>/bin/omx), tmux

set -uo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/kit-log-dir.sh" 2>/dev/null || {
  kit_log_path() { echo "$HOME/.logs/$1.log"; }
}

LOG="$(kit_log_path kit-omx-session)"
mkdir -p "$(dirname "$LOG")"

SESSION="${1:-}"
WORKDIR="${2:-}"
SUBCMD="omx --direct"
EXTRA_FLAGS=""

# 인자 파싱
shift 2 2>/dev/null || true
while [ $# -gt 0 ]; do
  case "$1" in
    --resume)  SUBCMD="omx resume"; shift ;;
    --high)    EXTRA_FLAGS="$EXTRA_FLAGS --high"; shift ;;
    --xhigh)   EXTRA_FLAGS="$EXTRA_FLAGS --xhigh"; shift ;;
    --yolo)    EXTRA_FLAGS="$EXTRA_FLAGS --yolo"; shift ;;
    --madmax)  EXTRA_FLAGS="$EXTRA_FLAGS --madmax"; shift ;;
    --spark)   EXTRA_FLAGS="$EXTRA_FLAGS --spark"; shift ;;
    *)         shift ;;
  esac
done

if [ -z "$SESSION" ] || [ -z "$WORKDIR" ]; then
  echo "사용: $0 <session_name> <workdir> [--resume] [--high|--xhigh] [--yolo] [--madmax] [--spark]"
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

# nvm 로드를 위해 zsh -lic
CMD="zsh -lic '$SUBCMD $EXTRA_FLAGS'"
tmux new-session -d -s "$SESSION" -c "$WORKDIR" "$CMD"
echo "[$(date '+%F %T')] START $SESSION (workdir=$WORKDIR cmd='$SUBCMD' flags='$EXTRA_FLAGS')" >> "$LOG"

# OMX consent 프롬프트 자동 통과 (Yes, continue 가 default 라 Enter 만)
sleep 5
PANE="$(tmux capture-pane -t "$SESSION" -p 2>/dev/null || echo "")"
if echo "$PANE" | grep -q "Yes, continue\|Press enter to continue"; then
  tmux send-keys -t "$SESSION" Enter
  echo "[$(date '+%F %T')] OMX consent 자동 승인 for $SESSION" >> "$LOG"
fi

echo "START $SESSION"
