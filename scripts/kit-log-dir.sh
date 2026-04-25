#!/bin/bash
# kit-log-dir.sh — 로그 디렉터리 fallback 로직 일관 제공.
# /var/log/ 가능하면 거기, 아니면 ~/.logs/.
# 모든 kit-*.sh 스크립트 시작부에서 source 하는 것을 권장.

kit_log_path() {
  local name="$1"  # 예: builder-tmux-spawn
  local system="/var/log/${name}.log"
  if [ -w "$(dirname "$system")" ] 2>/dev/null; then
    # 쓰기 가능 (sudo 환경 or root)
    echo "$system"
    return 0
  fi
  # 사용자 디렉터리 fallback
  mkdir -p "$HOME/.logs"
  echo "$HOME/.logs/${name}.log"
}

kit_log() {
  local logfile="$1"; shift
  echo "[$(date '+%F %T')] $*" >> "$logfile"
}

# 직접 실행 시 경로 확인용
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  name="${1:-kit-test}"
  path="$(kit_log_path "$name")"
  echo "log path for '$name': $path"
fi
