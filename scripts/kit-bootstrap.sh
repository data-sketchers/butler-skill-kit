#!/bin/bash
# kit-bootstrap.sh — 리모트 서버 최초 세팅 점검·보강.
# 멱등. 이미 설치된 것은 skip.
#
# 체크 항목:
# - tmux 설치 여부
# - ~/bin 존재
# - ~/.logs 존재
# - PATH 에 ~/bin 포함 여부 (bashrc 점검)
# - claude / codex CLI 존재 여부 (없으면 안내)

set -uo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=kit-log-dir.sh
source "$SOURCE_DIR/kit-log-dir.sh" 2>/dev/null || true

LOG="$(kit_log_path kit-bootstrap 2>/dev/null || echo "$HOME/.logs/kit-bootstrap.log")"
mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "== kit-bootstrap start =="

# 1. tmux
if ! command -v tmux >/dev/null; then
  log "WARN: tmux 없음. 설치 필요 (apt install tmux / brew install tmux)"
  exit 1
fi
log "OK tmux ($(tmux -V))"

# 2. ~/bin
mkdir -p "$HOME/bin"
log "OK ~/bin"

# 3. ~/.logs
mkdir -p "$HOME/.logs"
log "OK ~/.logs"

# 4. PATH 에 ~/bin 있나
if ! echo "$PATH" | grep -q "$HOME/bin"; then
  log "WARN: PATH 에 ~/bin 없음. ~/.bashrc (또는 ~/.zshrc) 에 다음 추가 필요:"
  log "  export PATH=\"\$HOME/bin:\$PATH\""
else
  log "OK PATH includes ~/bin"
fi

# 5. claude CLI
if command -v claude >/dev/null; then
  log "OK claude ($(claude --version 2>/dev/null | head -1 | awk '{print $1" "$2}'))"
else
  log "INFO: claude CLI 없음. https://docs.claude.com/claude-code 참조해서 설치."
fi

# 6. codex CLI
if command -v codex >/dev/null; then
  log "OK codex ($(codex --version 2>/dev/null | head -1))"
else
  log "INFO: codex CLI 없음. npm install -g @openai/codex 참조."
fi

# 7. ~/.butler-kit 구조
mkdir -p "$HOME/.butler-kit/templates" "$HOME/.butler-kit/docs"
log "OK ~/.butler-kit/"

log "== kit-bootstrap complete =="
