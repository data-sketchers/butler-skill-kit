# butler-kit

> **Failover orchestration for Claude Code + Codex CLI agents.**
> Claude hits its rate limit at the worst possible moment? Codex picks up where Claude left off. Same git worktree, same context, same task — different brain.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![tmux](https://img.shields.io/badge/runtime-tmux-1f425f.svg)](https://github.com/tmux/tmux)

---

## The problem

You're running Claude Code overnight. It's been making real progress. You wake up to:

```
Hit rate limit. Resets in 4h 17m.
```

Your agent stops. Your context is gone. Your overnight work just turned into "wait til lunch."

The same is true for Codex CLI. The same is true for any single-CLI agent setup.

## What this gives you

A pair of CLI sessions — one Claude, one Codex — sharing the same git worktree, with a clean handoff protocol when either of them hits a wall:

```
Claude (primary)  ──────  hits rate limit  ──┐
                                              │  kit-handoff.sh be claude-to-codex
Codex (standby)   ── reads .agent-state.md ──┘  picks up exactly where Claude stopped
```

When Claude comes back online, run the reverse handoff. Codex updates state, Claude resumes.

No servers. No daemons. Just bash, tmux, and a single state file per role.

---

## Quickstart

### 1. Install on the machine where your agents run

```bash
git clone https://github.com/data-sketchers/butler-kit.git
cd butler-kit
bash install.sh --host you@your.server --port 22 --key ~/.ssh/id_ed25519 --apply
```

This drops `kit-*.sh` into `~/bin/` and templates/docs into `~/.butler-kit/`.

For local-only setup, just symlink: `ln -s $(pwd)/scripts/* ~/bin/`.

### 2. Spin up a single agent

```bash
~/bin/kit-session-ensure.sh claude my-agent ~/workspace/my-project
```

A tmux session named `my-agent` boots, starts Claude Code in `~/workspace/my-project`, and **automatically dismisses the trust-folder prompt** so you don't have to babysit it.

### 3. Spin up a pair (Claude + Codex)

```bash
~/bin/kit-session-ensure.sh claude builder-be-claude ~/workspace/be
~/bin/kit-session-ensure.sh codex  builder-be-codex  ~/workspace/be
```

Two tmux sessions, same worktree. Claude works while it has tokens. Codex is alive but idle.

### 4. Handoff when Claude hits its limit

```bash
~/bin/kit-handoff.sh builder-be claude-to-codex ~/workspace/be
```

Claude commits its in-progress state to `.agent-state.md`, the role's "single source of truth" file. Codex reads it, picks up `next-step`, and continues.

When Claude resets:

```bash
~/bin/kit-handoff.sh builder-be codex-to-claude ~/workspace/be
```

That's it.

---

## The 9 pain-fixes baked in

butler-kit was extracted from a working production setup. Each script carries a fix for a real problem we hit:

| # | What broke | What the kit does |
|---|------------|-------------------|
| 1 | Claude's first-time "trust this folder?" dialog blocks the session | Auto-detect and confirm |
| 2 | Codex sandbox blocks file writes interactively | Auto-add `trust_level = "trusted"` to `~/.codex/config.toml` per worktree |
| 3 | `/var/log/*.log` permission denied on most user accounts | Fall back to `~/.logs/` |
| 4 | `claude -c` / `codex resume --last` exit immediately on first run | Detect prior-session presence before applying the resume flag |
| 5 | tmux `send-keys` paste-mode swallows the first Enter | Always send Enter twice |
| 6 | `git worktree add` fails on existing dirs | Pre-check before creating |
| 7 | `crontab` line duplicates on repeat runs | Grep for existing line, skip if present |
| 8 | hermes profile name and tmux session name collide | Strict naming convention separating the two |
| 9 | Server reboot kills every tmux session | `@reboot` cron + 5-min healthcheck both call the spawn script (idempotent) |

See [`docs/pain-fixes.md`](docs/pain-fixes.md) for full detail.

---

## Architecture

```
        ~/bin/                          ~/.butler-kit/
        ├── kit-bootstrap.sh             ├── docs/
        ├── kit-session-ensure.sh        │   ├── pain-fixes.md
        ├── kit-claude-session.sh        │   ├── codex-sandbox.md
        ├── kit-codex-session.sh         │   └── session-lifecycle.md
        ├── kit-handoff.sh               └── templates/
        ├── kit-cron-register.sh             ├── start-claude.sh.tpl
        └── kit-log-dir.sh                   ├── start-codex.sh.tpl
                                             └── agent-state.md.tpl
```

Each script is **idempotent**. Run them as many times as you want.

### `.agent-state.md` is the contract

```yaml
last-updated: 2026-04-25T18:30:00Z
active-model: claude
current-task: webbuilder#234
progress: 40%
next-step: Add integration test for findActive() in UserRepositoryTest.kt
open-questions:
  - Should UserRole.DELETED count as active? Asked PM.
handoff-notes: |
  [claude → codex 2026-04-24T18:30]
  Refactored findByEmail(). Test scaffold for findActive() exists.
  Hit 5h cap. Back in ~1h.
```

Whichever agent is "active" updates this file. Whoever takes over reads it. That's the entire handoff protocol.

---

## Use it with single agents too

The pair pattern is one option. You can also use butler-kit as a thin wrapper around a single Claude or Codex session for:

- Idempotent session spawning (`kit-session-ensure.sh`)
- Server reboot resilience (`kit-cron-register.sh`)
- Sane log directory fallback (`kit-log-dir.sh`)

You don't need pairing to benefit.

---

## What's not here

- Multi-model routing across N parallel agents (try [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) or [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) for that)
- Hosted servers, daemons, MCP servers
- A web UI

butler-kit is intentionally small: ~400 lines of bash. You can read every script in 10 minutes.

---

## Companion: `agent-factory`

butler-kit is the plumbing. If you want to define a *team* of agents (PM + backend + frontend + infra + QA) with role definitions, GitLab issue templates, and phase-gated rollout, that's [`agent-factory`](https://github.com/data-sketchers/agent-factory) — built on top of butler-kit.

(`agent-factory` is currently internal-only. Open-source release planned.)

---

## License

Apache License 2.0 — see [LICENSE](LICENSE).

## Maintainers

[Data Sketchers](https://data-sketchers.com) — built and battle-tested at our company.

Issues and PRs welcome.
