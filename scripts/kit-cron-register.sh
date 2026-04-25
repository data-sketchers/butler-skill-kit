#!/bin/bash
# kit-cron-register.sh — 사용자 crontab 에 idempotent 한 줄 등록.
# 이미 동일 라인 있으면 skip.
#
# 사용:
#   kit-cron-register.sh reboot <command>          # @reboot 실행
#   kit-cron-register.sh healthcheck <N>min <cmd>  # 매 N 분 실행 (N ∈ {1,5,10,15,30,60})
#   kit-cron-register.sh cron '<expr>' <command>   # 자유 cron 표현식

set -uo pipefail

TYPE="${1:-}"

case "$TYPE" in
  reboot)
    CMD="${2:-}"
    [ -z "$CMD" ] && { echo "사용: $0 reboot <command>"; exit 1; }
    LINE="@reboot sleep 60 && $CMD"
    ;;
  healthcheck)
    INTERVAL="${2:-}"
    CMD="${3:-}"
    [ -z "$INTERVAL" ] || [ -z "$CMD" ] && { echo "사용: $0 healthcheck <Nmin> <command>"; exit 1; }
    case "$INTERVAL" in
      1min)  SCHEDULE="* * * * *" ;;
      5min)  SCHEDULE="*/5 * * * *" ;;
      10min) SCHEDULE="*/10 * * * *" ;;
      15min) SCHEDULE="*/15 * * * *" ;;
      30min) SCHEDULE="*/30 * * * *" ;;
      60min) SCHEDULE="0 * * * *" ;;
      *) echo "지원 간격: 1min|5min|10min|15min|30min|60min"; exit 1 ;;
    esac
    LINE="$SCHEDULE $CMD >/dev/null 2>&1"
    ;;
  cron)
    EXPR="${2:-}"
    CMD="${3:-}"
    [ -z "$EXPR" ] || [ -z "$CMD" ] && { echo "사용: $0 cron '<expr>' <command>"; exit 1; }
    LINE="$EXPR $CMD"
    ;;
  *)
    echo "사용: $0 {reboot|healthcheck|cron} ..."; exit 1 ;;
esac

CURRENT="$(crontab -l 2>/dev/null || true)"
# 동일 라인 존재하면 skip (공백 차이는 무시)
if echo "$CURRENT" | sed 's/  */ /g' | grep -Fq "$(echo "$LINE" | sed 's/  */ /g')"; then
  echo "이미 등록됨: $LINE"
  exit 0
fi

NEW="$CURRENT
$LINE"
echo "$NEW" | sed '/^$/d' | crontab -

echo "등록: $LINE"
