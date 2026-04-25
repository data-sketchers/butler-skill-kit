# {{ROLE}} — Agent State

**역할**: {{RESPONSIBILITIES}}
**워크트리**: {{WORKDIR}}
**브랜치**: {{BRANCH}}

---

last-updated: {{DATE}} (초기화)
active-model: none (대기)
current-task: — (첫 태스크 대기)
progress: 0%
next-step: PM 의 첫 태스크 할당 받기
open-questions: none
handoff-notes: |
  (초기 생성. 아직 handoff 이력 없음.)

---

## 업데이트 의무 (Primary 모델 공통)

매 5~15분 또는 의미 있는 변화 시 갱신:
- 태스크 시작: current-task 설정, active-model, progress=0%
- 작업 중간: progress %, next-step 갱신
- 의문·블로커: open-questions 에 추가
- 완료: progress=100%, PR 링크 메모
- Handoff: active-model 전환 + handoff-notes 상세 기록

## 핵심 필드

- **active-model**: `claude` | `codex` | `none`
- **current-task**: GitLab 이슈 번호 (예: `project#234`)
- **progress**: `N%`
- **next-step**: 다음 할 일 1줄
- **open-questions**: PM/팀에 물어봐야 할 것 리스트
- **handoff-notes**: 모델 전환 시 인수인계 요약
