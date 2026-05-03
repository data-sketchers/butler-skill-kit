# Codex CLI — sandbox / trust 설정 가이드

Codex CLI (OpenAI) 는 기본적으로 sandbox 권한이 제한적. 파일 쓰기·쉘 실행에서 interactive 프롬프트가 뜰 수 있음. 자율 에이전트로 돌리려면 워크트리별 trust 설정 필요.

## config.toml 위치

`~/.codex/config.toml`

## 워크트리별 trust 등록

```toml
[projects."/absolute/path/to/workdir"]
trust_level = "trusted"
```

- 경로는 절대경로 (tilde `~` 안 됨. `$HOME` expand 된 실제 경로)
- trust_level 값: `"trusted"` (권장, 자율 실행) | `"untrusted"` (default, 프롬프트 유발)
- 여러 워크트리 각각 따로 등록 필요

## butler-kit 자동 등록

`kit-codex-session.sh` 가 세션 기동 전 해당 워크트리 trust 를 자동 추가 (멱등). 현재 Codex CLI 정책에 맞춰 explicit model, `-C <workdir>`, `--no-alt-screen`, 그리고 선택적/기본 approval bypass를 사용한다.

```bash
CODEX_MODEL=gpt-5.3-codex kit-codex-session.sh builder-fe-codex /path/to/workdir --resume
KIT_CODEX_BYPASS_APPROVALS=1 KIT_CODEX_NO_ALT_SCREEN=1 kit-codex-session.sh builder-qa-codex /path/to/workdir
```

환경 변수:
- `CODEX_MODEL` / `KIT_CODEX_MODEL` / `DSKET_CODEX_MODEL`: 모델명, 기본 `gpt-5.3-codex`
- `KIT_CODEX_BYPASS_APPROVALS=1`: `--dangerously-bypass-approvals-and-sandbox` 추가
- `KIT_CODEX_NO_ALT_SCREEN=1`: `--no-alt-screen` 추가
- `KIT_CODEX_EXTRA_ARGS`: 추가 인자

## 세션 적용 시점 주의

**config.toml 변경은 *새로 시작하는 세션*에만 적용됨.** 이미 실행 중인 codex 세션은 config 업데이트 후에도 sandbox 프롬프트 계속 뜰 수 있음. 이 경우 세션 종료 후 재시작 필요.

```bash
tmux kill-session -t builder-be-codex
kit-codex-session.sh builder-be-codex ~/workspace/your-be-worktree
```

## 로그인 상태 확인

```bash
cat ~/.codex/auth.json | head -10
```

`auth_mode` 가 `chatgpt` 이고 `tokens.id_token` 이 유효하면 OK. 만료됐거나 없으면 `codex login` 으로 재인증.

## 참조 config 구조 예시

```toml
# 전체 홈디렉토리 trust (개발 환경에서 편함)
[projects."$HOME"]
trust_level = "trusted"

# 특정 프로젝트만 trust
[projects."$HOME/ai-workspace/your-monorepo"]
trust_level = "trusted"

[projects."$HOME/ai-workspace/your-be-worktree"]
trust_level = "trusted"

# UI 설정 (tui 모델 NUX 등)
[tui.model_availability_nux]
"gpt-5.5" = 1
```
