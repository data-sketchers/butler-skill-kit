#!/bin/bash
# start-claude.sh — {{ROLE}} primary 세션 (Claude Code).
# 생성: agent-factory / butler-kit. 수동 편집 주의.
export PATH=$HOME/.bun/bin:$PATH
cd {{WORKDIR}}
PROJ_HASH_DIR=$(echo "$PWD" | sed 's#/#-#g')
if [ -d "$HOME/.claude/projects/$PROJ_HASH_DIR" ]; then
  exec claude --dangerously-skip-permissions -c
else
  exec claude --dangerously-skip-permissions
fi
