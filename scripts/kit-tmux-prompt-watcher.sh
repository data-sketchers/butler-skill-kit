#!/bin/bash
# kit-tmux-prompt-watcher.sh — conservative tmux prompt watcher.
#
# This watcher is intentionally report-first. It no longer broad-auto-approves
# Codex prompts. Use kit-codex-tmux-submit.sh or explicit PM policy for prompt
# submission/approval.
#
# Environment:
#   KIT_WATCH_SESSION_REGEX  session regex, default covers butler-kit standard naming (builder-)
#   KIT_WATCH_AUTOFIX_PASTE  if 1, press Enter for stale pasted-content only when pane is idle
#   KIT_WATCH_LOG            log path

set -uo pipefail

REAL_HOME="$HOME"
LOG="${KIT_WATCH_LOG:-$REAL_HOME/.logs/tmux-prompt-watcher.log}"
mkdir -p "$(dirname "$LOG")"

stamp() { date '+%F %T'; }
log(){ echo "[$(stamp)] $*" >> "$LOG"; }

SESSION_REGEX="${KIT_WATCH_SESSION_REGEX:-^builder-.*(codex|claude|fe|be|qa|pm|fix|watchdog|fullstack|logger)(-[0-9]+)?$}"
AUTOFIX_PASTE="${KIT_WATCH_AUTOFIX_PASTE:-1}"

pane_has_current_active_status(){
  awk '
    /Working \([0-9]+[smh]/ || /Compacting conversation/ || /^[[:space:]]*(✻|✽|✶|◦|·) [A-Za-z][A-Za-z -]*[.…]/ { active=NR }
    /^› / || /^\[Pasted Content/ { prompt=NR }
    END { exit !((active > 0) && (active > prompt)) }
  '
}

SESSIONS=$(tmux ls 2>/dev/null | awk -F: '{print $1}' | grep -E "$SESSION_REGEX" || true)

for SESSION in $SESSIONS; do
  PANE=$(tmux capture-pane -t "$SESSION" -p 2>/dev/null | tail -40)
  [ -z "$PANE" ] && continue

  if echo "$PANE" | grep -qE "rm -rf /|git push.*--force.*main|git push.*-f.*main|--no-verify|kubectl delete|helm uninstall|argocd app sync|docker system prune -a"; then
    log "$SESSION DANGER pattern visible; no automatic action taken"
    continue
  fi

  if echo "$PANE" | grep -Eqi 'approval required|requires approval|requires permission|permission prompt|continue\?|proceed\?|would you like|allow .*\?|Yes,.*No|Press enter to confirm'; then
    log "$SESSION approval/permission prompt suspected; report only"
    continue
  fi

  if echo "$PANE" | pane_has_current_active_status; then
    continue
  fi

  # Safe-ish narrow autofix: stale pasted content that is idle and needs Enter.
  if [ "$AUTOFIX_PASTE" = "1" ] && echo "$PANE" | grep -qE "Pasted text #[0-9]+ \+[0-9]+ lines|\[Pasted Content"; then
    tmux send-keys -t "$SESSION" Enter
    log "$SESSION idle pasted content → Enter"
    continue
  fi

  if echo "$PANE" | grep -qE 'Write tests for @filename|Find and fix a bug in @filename|Run /review on my current changes|Explain this codebase|Improve documentation in @filename|Use /skills'; then
    log "$SESSION stale default suggestion visible; no automatic action taken"
    continue
  fi
done
