#!/bin/bash
# 최소 예시: 리모트 서버에 1 에이전트 1 세션 세팅.
# butler-skill-kit 설치가 완료된 리모트에서 실행한다고 가정.
#
# 이 스크립트는 예시. 그대로 실행하지 말고 상황에 맞춰 수정.

set -euo pipefail

WORKDIR="$HOME/ai-workspace/my-project"
SESSION="my-agent"

# 1. 초기 세팅 (~/bin / ~/.logs / CLI 점검)
~/bin/kit-bootstrap.sh

# 2. 워크디렉토리 준비
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# 3. 프로젝트 CLAUDE.md / start script 배치 (직접 작성 or 템플릿 복사)
cat > "$WORKDIR/CLAUDE.md" <<'EOF'
# my-agent

1인 에이전트. 그냥 Claude Code 가 이 디렉토리에서 작업하게 함.
EOF

# 4. 세션 기동 (idempotent)
~/bin/kit-session-ensure.sh claude "$SESSION" "$WORKDIR"

# 5. Cron 등록 (재기동 보장)
cat > ~/bin/my-spawn.sh <<EOF
#!/bin/bash
~/bin/kit-session-ensure.sh claude $SESSION $WORKDIR --resume
EOF
chmod +x ~/bin/my-spawn.sh
~/bin/kit-cron-register.sh reboot ~/bin/my-spawn.sh
~/bin/kit-cron-register.sh healthcheck 5min ~/bin/my-spawn.sh

echo "완료. tmux attach -t $SESSION 로 접속 가능."
