# Changelog

All notable changes to butler-kit are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-25

### Added

- Initial public release. Extracted from internal Data Sketchers production setup
  (an internal Data Sketchers production setup, 2026-04-24).
- 7 core scripts in `scripts/`:
  - `kit-bootstrap.sh` — environment readiness check
  - `kit-session-ensure.sh` — idempotent tmux session spawner (claude or codex)
  - `kit-claude-session.sh` — Claude Code session with auto-trust dialog handling
  - `kit-codex-session.sh` — Codex CLI session with auto sandbox `trust_level` config
  - `kit-handoff.sh` — Primary/Backup handoff (claude ↔ codex) via `.agent-state.md`
  - `kit-cron-register.sh` — idempotent crontab line registration (@reboot, healthcheck, custom)
  - `kit-log-dir.sh` — `/var/log` → `~/.logs/` fallback helper (sourceable)
- 3 templates: `start-claude.sh.tpl`, `start-codex.sh.tpl`, `agent-state.md.tpl`.
- 3 docs: `pain-fixes.md`, `codex-sandbox.md`, `session-lifecycle.md`.
- `install.sh` — local-to-remote SSH-based installer with default dry-run
  (use `--apply` to actually deploy).
- Single-agent example in `examples/single-agent.sh`.

### Pain points addressed (vs. raw CLI use)

- Claude trust dialog auto-dismiss
- Codex sandbox `trust_level = "trusted"` auto-injection
- Log path fallback (`/var/log/` → `~/.logs/`)
- `-c` / `--last` flag conditional (skip on first run)
- tmux `send-keys` paste-mode double-Enter
- `git worktree` existence check
- `crontab` deduplication
- Hermes profile vs. tmux session name disambiguation
- `@reboot` + healthcheck cron resilience
