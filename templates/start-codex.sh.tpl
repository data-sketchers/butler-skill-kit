#!/bin/bash
# start-codex.sh — {{ROLE}} standby 세션 (Codex CLI).
# 생성: agent-factory / butler-kit. 수동 편집 주의.
export PATH=$HOME/.bun/bin:$PATH
cd {{WORKDIR}}
if codex resume --last 2>/dev/null; then
  :
else
  exec codex
fi
