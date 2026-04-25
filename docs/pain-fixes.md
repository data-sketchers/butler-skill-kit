# Pain fixes — Phase 1 에서 찾은 9가지 함정과 대응

2026-04-24 an internal Data Sketchers production setup 세팅 중 발견. butler-kit 스크립트에 모두 반영됨.

## 1. Claude Code trust 다이얼로그

**증상**: 첫 실행 시 "Trust this folder?" 다이얼로그가 떠서 입력 없으면 멈춤.

**해결**: `kit-claude-session.sh` 가 세션 기동 후 4초 대기 → `capture-pane` 으로 다이얼로그 감지 → `send-keys '1' Enter` 로 자동 승인.

## 2. Codex sandbox 파일 쓰기 차단

**증상**: Codex 가 `Edited file` 실행하면 "command failed; retry without sandbox?" 프롬프트로 멈춤. interactive 승인 필요.

**해결**: `~/.codex/config.toml` 에 워크트리별 등록:

```toml
[projects."/absolute/path/to/workdir"]
trust_level = "trusted"
```

`kit-codex-session.sh` 가 세션 기동 전 자동 추가 (멱등).

## 3. `/var/log/*.log` 권한 없음

**증상**: 일반 사용자는 `/var/log/builder-*.log` 에 쓸 수 없어 스크립트 에러.

**해결**: `kit-log-dir.sh` 의 `kit_log_path()` 가 쓰기 가능 여부 체크 후 `~/.logs/` 로 fallback. 모든 kit 스크립트가 이 함수 사용.

## 4. `claude -c` / `codex resume --last` 세션 없을 때 exit

**증상**: 첫 기동 시 `-c` / `resume --last` 가 prior session 없어서 exit → tmux 세션 즉시 종료.

**해결**:
- Claude: `$HOME/.claude/projects/<hash>` 디렉토리 존재 여부로 감지. 없으면 `-c` 생략.
- Codex: `if codex resume --last; then :; else exec codex; fi` fallback.

## 5. Tmux send-keys paste-mode 이슈

**증상**: 멀티라인 프롬프트 send-keys 할 때 Claude Code 가 paste 로 인식해서 첫 Enter 가 개행으로 처리됨 → submit 안 됨.

**해결**: 메시지 + Enter 후 1초 기다렸다가 추가 Enter 한 번 더 전송.

```bash
tmux send-keys -t "$SESSION" "$MSG" Enter
sleep 1
tmux send-keys -t "$SESSION" Enter
```

## 6. git worktree 중복 생성 에러

**증상**: `git worktree add` 를 기존 경로에 재실행하면 에러.

**해결**: agent-factory 가 경로 존재 체크 후 스킵. 브랜치도 존재 여부 먼저 체크.

## 7. Cron 중복 등록

**증상**: `@reboot` 라인을 여러 번 추가하면 중복 실행.

**해결**: `kit-cron-register.sh` 가 기존 crontab 에 동일 라인 있으면 skip.

## 8. hermes 프로파일과 혼동

**증상**: hermes 프로파일명을 tmux 세션명에 그대로 쓰면 관리 포인트 혼재.

**해결**: 네이밍 규칙 분리:
- hermes 프로파일: `your-monorepo` (Discord/Telegram 봇 연동)
- tmux 세션: `builder-<role>-<model>` (순수 tmux 콘솔)

## 9. 재부팅 복구

**증상**: 서버 재부팅 시 tmux 세션 전부 증발.

**해결**: 두 레이어:
- `@reboot sleep 60 && spawn.sh` — 재부팅 후 재기동
- `*/5 * * * * spawn.sh` — 매 5분 idempotent 체크 (세션 죽으면 재기동)

Claude/Codex 세션 자체 conversation 이력은 `~/.claude/projects/` / `~/.codex/sessions/` 에 디스크 보존. `-c` / `resume --last` 로 이어짐.
