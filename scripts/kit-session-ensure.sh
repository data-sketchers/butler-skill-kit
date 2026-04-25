#!/bin/bash
# kit-session-ensure.sh — 세션 idempotent 기동 래퍼.
# claude / codex 어느 쪽이든 통일된 인터페이스.
#
# 사용:
#   kit-session-ensure.sh <model: claude|codex> <session> <workdir> [--resume]

set -uo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODEL="${1:-}"
SESSION="${2:-}"
WORKDIR="${3:-}"
EXTRA="${4:-}"

if [ -z "$MODEL" ] || [ -z "$SESSION" ] || [ -z "$WORKDIR" ]; then
  echo "사용: $0 <claude|codex> <session> <workdir> [--resume]"
  exit 1
fi

case "$MODEL" in
  claude) exec "$SOURCE_DIR/kit-claude-session.sh" "$SESSION" "$WORKDIR" "$EXTRA" ;;
  codex)  exec "$SOURCE_DIR/kit-codex-session.sh"  "$SESSION" "$WORKDIR" "$EXTRA" ;;
  *)      echo "알 수 없는 모델: $MODEL"; exit 1 ;;
esac
