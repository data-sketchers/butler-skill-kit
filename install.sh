#!/bin/bash
# butler-skill-kit installer — 로컬에서 리모트 SSH 서버로 kit 배포.
# 기본 dry-run. --apply 있어야 실배포.
#
# 사용:
#   bash install.sh --host user@host --port 22 --key ~/.ssh/id_xxx
#   bash install.sh --host user@host --port 22 --key ~/.ssh/id_xxx --apply
#
# 설치 대상: ~/bin/kit-*.sh (리모트)
# 템플릿: ~/.butler-kit/templates/  (리모트)
# 문서: ~/.butler-kit/docs/  (리모트)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

HOST=""
PORT=""
KEY=""
APPLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)   HOST="$2"; shift 2 ;;
    --port)   PORT="$2"; shift 2 ;;
    --key)    KEY="$2"; shift 2 ;;
    --apply)  APPLY=1; shift ;;
    *)        echo "unknown arg: $1"; exit 1 ;;
  esac
done

if [ -z "$HOST" ]; then
  echo "사용: $0 --host user@host [--port N] [--key PATH] [--apply]"
  exit 1
fi

SSH_OPTS=""
SCP_OPTS=""
if [ -n "$PORT" ]; then SSH_OPTS="$SSH_OPTS -p $PORT"; SCP_OPTS="$SCP_OPTS -P $PORT"; fi
if [ -n "$KEY" ];  then SSH_OPTS="$SSH_OPTS -i $KEY"; SCP_OPTS="$SCP_OPTS -i $KEY"; fi

echo "== butler-kit install =="
echo "host: $HOST"
echo "mode: $([ $APPLY -eq 1 ] && echo APPLY || echo DRY-RUN)"
echo

FILES_TO_COPY=()
for f in scripts/kit-*.sh; do
  FILES_TO_COPY+=("$f")
done

echo "설치 계획 (리모트 ~/bin/ 에 복사):"
for f in "${FILES_TO_COPY[@]}"; do
  echo "  $(basename $f)"
done
echo
echo "템플릿 (리모트 ~/.butler-kit/templates/ 에 복사):"
for f in templates/*; do echo "  $(basename $f)"; done
echo
echo "문서 (리모트 ~/.butler-kit/docs/ 에 복사):"
for f in docs/*; do echo "  $(basename $f)"; done
echo
echo "스킬 레지스트리 (리모트 ~/.butler-kit/skills.yaml 에 복사):"
[ -f "$SCRIPT_DIR/skills.yaml" ] && echo "  skills.yaml" || echo "  (없음)"
echo

if [ $APPLY -eq 0 ]; then
  echo "(dry-run — 실배포는 --apply 추가)"
  exit 0
fi

echo "배포 시작…"
ssh $SSH_OPTS "$HOST" "mkdir -p ~/bin ~/.butler-kit/templates ~/.butler-kit/docs ~/.logs"

for f in "${FILES_TO_COPY[@]}"; do
  scp $SCP_OPTS "$SCRIPT_DIR/$f" "$HOST:~/bin/$(basename $f)"
  ssh $SSH_OPTS "$HOST" "chmod 755 ~/bin/$(basename $f)"
done

scp $SCP_OPTS $SCRIPT_DIR/templates/* "$HOST:~/.butler-kit/templates/"
scp $SCP_OPTS $SCRIPT_DIR/docs/*       "$HOST:~/.butler-kit/docs/"

# 스킬 레지스트리 — kit-install-skill.sh 가 ~/.butler-kit/skills.yaml 을 fallback 으로 읽음
if [ -f "$SCRIPT_DIR/skills.yaml" ]; then
  scp $SCP_OPTS "$SCRIPT_DIR/skills.yaml" "$HOST:~/.butler-kit/skills.yaml"
fi

echo "완료. 리모트에서 다음 확인:"
echo "  ls ~/bin/kit-*.sh"
echo "  ls ~/.butler-kit/"
echo "  ~/bin/kit-install-skill.sh --list"
