#!/bin/bash
# kit-install-skill.sh — butler-skill-kit 추천 스킬 설치기.
# skills.yaml 레지스트리 기반.
#
# 사용:
#   kit-install-skill.sh <name>          # 단일 스킬 설치
#   kit-install-skill.sh --all           # 등록된 모든 스킬 설치
#   kit-install-skill.sh --list          # 등록 스킬 목록·설치 상태
#   kit-install-skill.sh <name> --update # 이미 있으면 업데이트
#
# install_method 별 동작:
#   clone        — git clone <repo> <target_dir> (또는 git pull --ff-only)
#   zip-release  — gh release 의 latest asset 다운로드 후 target_dir 에 extract
#   pip          — pip install pip_pkg
#   npm          — npm install -g pip_pkg
#   reference    — git clone (read-only 표시)
#
# 의존: python3 + PyYAML, git, gh(zip-release용), pip/npm 해당 시

set -uo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(dirname "$SOURCE_DIR")"

# 레지스트리 위치: 같은 dir 의 skills.yaml, 또는 ~/.butler-kit/skills.yaml
if [ -f "$KIT_DIR/skills.yaml" ]; then
  REGISTRY="$KIT_DIR/skills.yaml"
elif [ -f "$HOME/.butler-kit/skills.yaml" ]; then
  REGISTRY="$HOME/.butler-kit/skills.yaml"
else
  echo "❌ skills.yaml 못 찾음 — $KIT_DIR/skills.yaml 또는 ~/.butler-kit/skills.yaml"
  exit 1
fi

REGISTRY_JSON=""

load_registry() {
  if ! python3 -c 'import yaml' 2>/dev/null; then
    echo "❌ PyYAML 필요. 설치: pip install pyyaml" >&2
    exit 1
  fi
  REGISTRY_JSON=$(python3 -c '
import sys, json, yaml
print(json.dumps(yaml.safe_load(open(sys.argv[1]))))
' "$REGISTRY")
}

get_field() {
  local name="$1" field="$2"
  python3 -c "
import json, sys
d = json.loads(sys.argv[1])
for s in d.get('skills', []):
    if s.get('name') == sys.argv[2]:
        v = s.get(sys.argv[3])
        print(v if v is not None else '')
        break
" "$REGISTRY_JSON" "$name" "$field"
}

list_names() {
  python3 -c "
import json, sys
d = json.loads(sys.argv[1])
for s in d.get('skills', []):
    print(s.get('name', ''))
" "$REGISTRY_JSON"
}

expand_path() { echo "${1/#\~/$HOME}"; }

is_pip_installed() {
  local pkg="$1"
  pip3 show "$pkg" >/dev/null 2>&1 || pip show "$pkg" >/dev/null 2>&1
}

list_skills() {
  load_registry
  echo "== butler-skill-kit registered skills =="
  echo

  for name in $(list_names); do
    local desc=$(get_field "$name" description)
    local method=$(get_field "$name" install_method)
    local target=$(get_field "$name" target_dir)
    local pip_pkg=$(get_field "$name" pip_pkg)
    local target_expanded=$(expand_path "$target")
    local installed="❌"

    if [ -n "$target" ] && [ -e "$target_expanded" ]; then
      installed="✅"
    elif [ "$method" = "pip" ] && [ -n "$pip_pkg" ]; then
      local base_pkg="${pip_pkg%%[*}"
      if is_pip_installed "$base_pkg"; then installed="✅"; fi
    fi

    printf "  %s [%-12s] %-32s %s\n" "$installed" "$method" "$name" "${desc:0:80}"
  done
  echo
}

install_clone() {
  local repo="$1" target="$2" update="$3"
  local target_expanded=$(expand_path "$target")
  if [ -e "$target_expanded" ]; then
    if [ "$update" = "1" ]; then
      echo "  ↻ git pull --ff-only"
      git -C "$target_expanded" pull --ff-only
    else
      echo "  ↳ 이미 설치됨: $target (--update 로 갱신)"
    fi
  else
    mkdir -p "$(dirname "$target_expanded")"
    echo "  ⬇ git clone https://github.com/$repo $target"
    git clone "https://github.com/$repo" "$target_expanded"
  fi
}

install_zip_release() {
  local repo="$1" target="$2" pattern="$3" update="$4"
  local target_expanded=$(expand_path "$target")
  if [ -e "$target_expanded" ] && [ "$update" != "1" ]; then
    echo "  ↳ 이미 설치됨: $target (--update 로 갱신)"
    return
  fi
  if ! command -v gh >/dev/null 2>&1; then
    echo "  ❌ gh (GitHub CLI) 필요. 설치: brew install gh / sudo apt install gh"
    return 1
  fi
  mkdir -p "$target_expanded"
  ( cd "$target_expanded" && \
    echo "  ⬇ gh release download --repo $repo --pattern $pattern" && \
    gh release download --repo "$repo" --pattern "$pattern" --clobber && \
    for f in $pattern; do
      [ -f "$f" ] || continue
      echo "  ⇲ unzip $f"
      unzip -o "$f" -d .
    done
  )
}

install_pip() {
  local pkg="$1"
  if command -v pip3 >/dev/null 2>&1; then
    PIP=pip3
  elif command -v pip >/dev/null 2>&1; then
    PIP=pip
  else
    echo "  ❌ pip 필요. 설치: python3 -m ensurepip"
    return 1
  fi
  echo "  ⬇ $PIP install -U $pkg"
  $PIP install -U "$pkg"
}

install_one() {
  load_registry
  local target_name="$1" update="$2"
  local found=0

  for name in $(list_names); do
    [ "$name" != "$target_name" ] && continue
    found=1
    local desc=$(get_field "$name" description)
    local repo=$(get_field "$name" repo)
    local method=$(get_field "$name" install_method)
    local target=$(get_field "$name" target_dir)

    echo "📦 $name"
    echo "   $desc"
    echo "   method: $method"

    case "$method" in
      clone|reference)
        install_clone "$repo" "$target" "$update"
        ;;
      zip-release)
        local pattern=$(get_field "$name" asset_pattern)
        install_zip_release "$repo" "$target" "$pattern" "$update"
        ;;
      pip)
        local pkg=$(get_field "$name" pip_pkg)
        install_pip "$pkg"
        ;;
      npm)
        local pkg=$(get_field "$name" npm_pkg)
        echo "  ⬇ npm install -g $pkg"
        npm install -g "$pkg"
        ;;
      *)
        echo "  ❌ 알 수 없는 install_method: $method"
        return 1
        ;;
    esac
    echo "   ✅ 완료: $name"
    return 0
  done

  if [ $found -eq 0 ]; then
    echo "❌ 등록되지 않은 스킬: $target_name"
    echo "   목록 확인: $0 --list"
    return 1
  fi
}

install_all() {
  load_registry
  local update="$1"
  for name in $(list_names); do
    install_one "$name" "$update" || true
    echo
  done
}

# 인자 파싱
ACTION=""
TARGET=""
UPDATE=0
for arg in "$@"; do
  case "$arg" in
    --list)   ACTION=list ;;
    --all)    ACTION=all ;;
    --update) UPDATE=1 ;;
    --help|-h)
      cat <<EOF
butler-skill-kit installer

사용:
  $0 <name>            단일 스킬 설치
  $0 --all             등록된 모든 스킬 설치
  $0 --list            등록 스킬 목록·설치 상태
  $0 <name> --update   이미 있으면 갱신
EOF
      exit 0
      ;;
    *)        TARGET="$arg" ;;
  esac
done

case "$ACTION" in
  list) list_skills ;;
  all)  install_all $UPDATE ;;
  *)
    [ -z "$TARGET" ] && { echo "사용: $0 <name> | --all | --list | --help"; exit 1; }
    install_one "$TARGET" "$UPDATE"
    ;;
esac
