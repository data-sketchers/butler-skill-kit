#!/bin/bash
# kit-session-ensure.sh — 세션 idempotent 기동 래퍼.
# claude / codex / opencode / omx 통일된 인터페이스.
#
# 사용:
#   kit-session-ensure.sh <model: claude|codex|opencode|omx> <session> <workdir> [...flags]

set -uo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODEL="${1:-}"
SESSION="${2:-}"
WORKDIR="${3:-}"

# 나머지 인자는 그대로 패스 (--resume, --model, --high, --yolo 등)
shift 3 2>/dev/null || true

if [ -z "$MODEL" ] || [ -z "$SESSION" ] || [ -z "$WORKDIR" ]; then
  echo "사용: $0 <claude|codex|opencode|omx> <session> <workdir> [...flags]"
  exit 1
fi

case "$MODEL" in
  claude)   exec "$SOURCE_DIR/kit-claude-session.sh"   "$SESSION" "$WORKDIR" "$@" ;;
  codex)    exec "$SOURCE_DIR/kit-codex-session.sh"    "$SESSION" "$WORKDIR" "$@" ;;
  opencode) exec "$SOURCE_DIR/kit-opencode-session.sh" "$SESSION" "$WORKDIR" "$@" ;;
  omx)      exec "$SOURCE_DIR/kit-omx-session.sh"      "$SESSION" "$WORKDIR" "$@" ;;
  *)        echo "알 수 없는 모델: $MODEL (claude|codex|opencode|omx 중 하나)"; exit 1 ;;
esac
