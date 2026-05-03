# Session lifecycle — 에이전트 세션 수명주기

## 단계

```
[생성] → [활성] → [대기/standby] → [handoff] → [활성/대기 역전환] → ... → [종료/재기동]
```

## 1. 생성

`kit-session-ensure.sh <model> <session> <workdir>`

- tmux `has-session` 체크 → 있으면 skip (idempotent)
- claude: trust 다이얼로그 자동 승인 포함
- codex: config.toml trust_level 자동 등록 포함
- first-run 은 `-c` / `--last` 플래그 생략 (prior session 없음)

## 2. 활성 (active)

에이전트가 작업 중. `.agent-state.md` 주기적 업데이트:
- `active-model`: 현재 작업 중인 모델 (`claude` | `codex`)
- `current-task`: GitLab 이슈
- `progress`: %
- `next-step`: 한 줄

## 3. Standby (대기)

Paired 세션 (같은 역할 다른 모델) 은 idle 상태. API 호출 없이 tmux 세션만 유지.

## 4. Handoff

Primary 가 limit 맞거나 수동 트리거 시:

`kit-handoff.sh <prefix> claude-to-codex <workdir>`

내부 순서:
1. FROM 세션에 커밋·state 확정·standby 전환 프롬프트 전송
2. 5초 대기
3. TO 세션에 state 읽고 재개 프롬프트 전송

.agent-state.md 가 인수인계 진실 원천.

## 5. 재기동 (crash / reboot)

두 겹 방어:

- **@reboot cron**: `sleep 60 && spawn.sh` — 부팅 후 1분 대기 후 전 세션 확인·재기동
- **매 5분 cron**: `spawn.sh` — tmux 죽으면 idempotent 재기동

Claude / Codex 자체의 대화 이력은 디스크 영속:
- Claude: `~/.claude/projects/<workdir-hash>/`
- Codex: `~/.codex/sessions/`

재기동 시 start 스크립트가 `-c` / `resume --last` 로 이어감.

## 6. 종료

수동:
```bash
tmux kill-session -t builder-be-claude
```

재기동 방지가 필요하면 cron 의 spawn.sh 라인을 편집하거나 주석 처리.

## 상태 관찰

```bash
tmux ls | grep builder        # 세션 목록
tmux capture-pane -t <session> -p | tail -20  # 현 화면
cat <workdir>/.agent-state.md  # 작업 상태
tail ~/.logs/kit-*.log         # 이벤트 로그
```

## 안전한 Codex 프롬프트 제출

Codex tmux/no-alt-screen 세션에는 raw `tmux send-keys` 대신 submit helper를 사용한다.

```bash
printf '%s' "$PROMPT" | kit-codex-tmux-submit.sh <session>
```

원칙:
- pane이 실제 `Working`/compacting이면 interrupt하지 않고 skip
- stale `Working` 아래 새 `›` prompt가 있으면 idle로 판정 가능
- approval/permission prompt는 broad auto-approve하지 않음
- 기본 제안(`/review`, `Write tests for @filename` 등)은 submit 전에 clear
- PM cron/tick 류 스크립트는 helper 실패 시 blind fallback 금지

## 핵심 원칙

1. **Idempotent**: 모든 기동 스크립트는 "이미 있으면 skip". 100번 돌려도 1번과 같음.
2. **State externalization**: 런타임 상태는 `.agent-state.md` 로 파일화. 세션 죽어도 정보 유지.
3. **Layered recovery**: @reboot (거시) + 5min healthcheck (미시) + model resume flag (대화).
4. **Pair isolation**: Primary/Backup 이 같은 git worktree 공유하되 tmux 세션은 분리. 한 쪽 죽어도 다른 쪽 영향 X.
