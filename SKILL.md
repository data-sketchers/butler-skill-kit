---
name: butler-skill-kit
description: SSH 서버에 Claude Code / Codex CLI / tmux 기반 에이전트 운용 원시 요소를 배포·관리. trust 다이얼로그 자동 승인, codex sandbox trust_level 설정, tmux 세션 idempotent 기동, claude↔codex handoff, @reboot cron, 로그 경로 fallback 포함. agent-factory 스킬의 하위 레이어.
---

# butler-skill-kit — 원격 에이전트 운용 키트

## 무엇

리모트 SSH 서버에서 AI 에이전트(Claude Code / Codex CLI)를 tmux 세션으로 운용하기 위한 **플러밍**. agent-factory 가 내부적으로 호출하는 저수준 스크립트 모음.

## 언제 쓰나

- 새 서버(SSH 접속 가능)에 최초 세팅
- 기존 에이전트의 handoff / 재시작 / 로그 점검
- 신규 tmux 세션을 idempotent 하게 기동
- agent-factory 가 요청한 에이전트 프로비저닝

agent-factory 를 통해 쓰는 게 일반적이지만, 디버깅·특수 케이스에선 직접 사용도 가능.

## 구성

```
butler-kit/
├── install.sh                        # 리모트에 kit 설치 (~/bin/ 에 스크립트 배포)
├── scripts/
│   ├── kit-bootstrap.sh              # 리모트 초기 세팅 (tmux·log dir·PATH 점검)
│   ├── kit-claude-session.sh         # tmux + claude 세션 기동 (trust 자동)
│   ├── kit-codex-session.sh          # tmux + codex 세션 기동 (sandbox config 자동)
│   ├── kit-session-ensure.sh         # idempotent 세션 체크/스폰 래퍼
│   ├── kit-handoff.sh                # claude ↔ codex handoff (.agent-state 기반)
│   ├── kit-log-dir.sh                # /var/log 권한 없을 때 ~/.logs/ fallback
│   └── kit-cron-register.sh          # @reboot + healthcheck cron idempotent
├── templates/
│   ├── start-claude.sh.tpl
│   ├── start-codex.sh.tpl
│   └── agent-state.md.tpl
├── docs/
│   ├── codex-sandbox.md              # trust_level / config.toml 가이드
│   ├── session-lifecycle.md          # 세션 수명주기·resume·handoff 흐름
│   └── pain-fixes.md                 # Phase 1 에서 찾은 페인포인트 해결 기록
└── examples/
    └── single-agent.sh               # 최소 예시 (1 에이전트 1 세션)
```

## 설치 (리모트 서버)

```bash
# 로컬에서 리모트로 kit 배포 (dry-run 기본)
bash install.sh --host user@server:port --key ~/.ssh/id_ed25519

# 실배포
bash install.sh --host user@server:port --key ~/.ssh/id_ed25519 --apply
```

`--apply` 없이 실행하면 어떤 파일을 어디로 복사할지 목록만 출력.

## 주요 커맨드 (리모트에서)

### 1. 세션 기동 (idempotent)

```bash
kit-session-ensure.sh <name> <workdir> <start-script>
# 예: kit-session-ensure.sh my-agent ~/workspace ~/workspace/start-claude.sh
```

### 2. Handoff

```bash
kit-handoff.sh <role> claude-to-codex
kit-handoff.sh <role> codex-to-claude
```

`.agent-state.md` 가 인수인계의 단일 진실 원천. `builder-<role>-claude` / `builder-<role>-codex` 네이밍 규칙 가정 (agent-factory 가 이 규칙 지킴).

### 3. 로그

모든 kit 스크립트는 `/var/log/builder-*.log` 에 기록 시도 후, 권한 없으면 `~/.logs/builder-*.log` 로 fallback. `kit-log-dir.sh` 가 이 로직을 일관되게 제공.

### 4. Cron 등록

```bash
kit-cron-register.sh reboot /home/user/bin/my-spawn.sh
kit-cron-register.sh healthcheck 5min /home/user/bin/my-spawn.sh
```

기존 crontab 에 동일 라인 있으면 skip.

## 페인포인트 해결 내장

Phase 1 (2026-04-24) 에서 발견·해결한 사항:

1. Claude 최초 실행 시 "trust this folder?" 다이얼로그 → 자동 감지 후 "1" Enter
2. Codex sandbox 가 파일 쓰기 차단 → `~/.codex/config.toml` 에 워크트리별 `trust_level = "trusted"` 자동 추가
3. 로그 경로 `/var/log/` 권한 없음 → `~/.logs/` fallback
4. `claude -c` / `codex resume --last` 가 prior session 없으면 exit → 첫 실행 감지해서 플래그 생략
5. Tmux send-keys 의 paste-mode 이슈 → Enter 두 번 전송
6. git worktree 기존 여부 체크 후 생성
7. Cron 중복 라인 방지 (grep 으로 확인)
8. hermes 프로파일과 독립 운용 (네임스페이스 분리)
9. 재부팅 복구 (@reboot sleep 60 + healthcheck 매 5분)

세부 사항은 `docs/pain-fixes.md`.

## agent-factory 와의 관계

| 레이어 | 스킬 | 무엇 |
|-------|------|------|
| 포슬린 | agent-factory | 팀 정의·역할 분담·다중 에이전트 조율 |
| 플러밍 | butler-kit | 원시 세션 기동·handoff·로그·cron |

agent-factory 의 `spawn.sh` 가 butler-kit 의 스크립트를 내부 호출. 단독 사용도 가능.

## 경계 (절대 규칙)

- `install.sh` 는 `--apply` 없으면 dry-run (파일 목록만 출력, 실배포 X)
- 외부 포스팅·메시징 자동 실행 없음
- GitHub/GitLab 자동 커밋·PR 없음 (도구만 제공)
- 리모트 서버의 기존 파일 덮어쓰기 전에 존재 여부 확인 + 로그

## 이력

- 2026-04-24 v0.1: D-SKET Webbuilder Phase 1 결과물 기반 초기 작성
