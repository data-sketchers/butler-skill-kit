<p align="center">
  <img src="assets/butler-skill-kit-logo.png" alt="butler-skill-kit" width="280" />
</p>

<h1 align="center">butler-skill-kit</h1>

<p align="center">
  <strong>Failover orchestration for Claude Code + Codex CLI agents.</strong><br/>
  When one rate-limits, the other picks up — same worktree, same context, same task.
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: Apache 2.0" src="https://img.shields.io/badge/License-Apache%202.0-blue.svg"></a>
  <a href="https://github.com/tmux/tmux"><img alt="Runtime: tmux" src="https://img.shields.io/badge/runtime-tmux-1f425f.svg"></a>
  <img alt="Bash" src="https://img.shields.io/badge/written_in-bash-4eaa25.svg">
  <img alt="Status" src="https://img.shields.io/badge/status-v0.1_alpha-orange.svg">
</p>

<p align="center">
  <a href="#quickstart">Quickstart</a> ·
  <a href="#the-9-pain-fixes-baked-in">Pain fixes</a> ·
  <a href="#architecture">Architecture</a> ·
  <a href="#agent-state-md">State protocol</a> ·
  <a href="#companion-agent-factory">Companion</a>
</p>

---

## Who is this for

- **Solo developers** running long Claude Code sessions overnight
- **Indie hackers** burning through Codex CLI tokens on production projects
- **Small teams** running multiple agents on a shared dev server
- **Anyone** who has had Claude or Codex die at 80% of the way through a refactor

If you've never hit a rate limit you'll be wondering why this exists. If you have, you'll know.

## The problem

You're running Claude Code overnight. It's been making real progress. You wake up to:

```
Hit rate limit. Resets in 4h 17m.
```

Your agent stops. Your context is gone. Your overnight work just turned into "wait til lunch."

The same is true for Codex CLI. The same is true for any single-CLI agent setup. That's the gap.

## The fix

A pair of CLI sessions — one Claude, one Codex — sharing the same git worktree, with a clean handoff protocol when either hits a wall.

```
Claude (primary) ─────  hits rate limit ──┐
                                          │  kit-handoff.sh be claude-to-codex
Codex (standby) ── reads .agent-state.md ─┘  picks up exactly where Claude stopped
```

When Claude comes back online, run the reverse handoff. Codex commits state, Claude resumes.

**No servers. No daemons. ~400 lines of bash.** Read every script in 10 minutes.

---

## Use cases

### 1 · Overnight refactor that doesn't die at 3am

Set up a Claude/Codex pair on the project. Schedule a healthcheck cron. Go to bed. When Claude hits cap, Codex picks up. When Claude returns, the kit hands back. You wake up with the work *done*.

### 2 · Long-running production migration

You're cutting client-v1 over to client-v2 and it'll take days. Each step needs to be verifiable, committed, reversible. The pair pattern + `.agent-state.md` give you a continuous log of *who did what when* across model switches.

### 3 · Multi-agent team on a shared dev box

Phase the rollout. Start with one role pair (`builder-be-claude` + `builder-be-codex`). Verify handoff. Add the next pair. The naming convention and worktree separation prevent the most common foot-gun: two agents fighting over the same files.

### 4 · Survive server reboots without manual reattach

`kit-cron-register.sh reboot ~/bin/your-spawn.sh` and you stop caring about reboots. tmux sessions come back. Claude and Codex resume their last sessions via `-c` / `--last`. The state file picks up where it was.

### 5 · Don't pay for parallel models you don't need

Codex stays idle (no API calls) while Claude is working. Switching is on demand, not always-on. Real cost in our setup: ~1.2× single-Claude, not 2×.

---

## Why each pain-fix exists (the stories)

The 9 fixes in the table below didn't come from theory. They came from one production setup biting us once each, in the worst possible moment:

1. **Trust dialog**: Spawned 9 sessions overnight in a script. Came back to 9 stalled prompts because Claude wanted folder confirmation. ~2h lost. Fixed.
2. **Codex sandbox**: Codex auto-approval prompt for "command failed; retry without sandbox?" silently froze our handoff. Now config is set per worktree before session boots.
3. **/var/log permissions**: Cron script worked under sudo, silently failed for the user. Logs vanished. We learned the hard way to fall back to `~/.logs/`.
4. **`-c` / `--last` on first run**: Tmux session quit immediately because there was no prior session to continue. Confusing. Now: detect first-run, drop the flag.
5. **Paste-mode Enter**: Send a multi-line prompt to Claude via send-keys. First Enter is treated as part of the paste, not submit. Prompt sits there forever. Send Enter twice.
6. **Worktree exists**: Re-running spawn after a partial setup blew up because `git worktree add` saw the dir. Idempotent check.
7. **Cron duplicates**: We added the same `@reboot` line three times before noticing. Three identical jobs at boot. grep-then-skip.
8. **hermes vs tmux name collision**: Naming the tmux session the same as the hermes profile gets mistaken for the same thing in scripts. Hard prefix split (`builder-*` vs hermes profile names) avoids it.
9. **Reboot resilience**: One server reboot wiped 5 active sessions. We didn't know because there was no alert. Two-layer cron: `@reboot` + 5-min healthcheck. Both call the spawn script. Idempotent. Recovered every time since.

---

## Quickstart

### 1 · Install on the machine where your agents run

```bash
git clone https://github.com/data-sketchers/butler-skill-kit.git
cd butler-skill-kit

# Remote install (default dry-run)
bash install.sh --host you@your.server --port 22 --key ~/.ssh/id_ed25519

# Remote install (actual)
bash install.sh --host you@your.server --port 22 --key ~/.ssh/id_ed25519 --apply
```

This drops `kit-*.sh` into `~/bin/` and templates/docs into `~/.butler-kit/` on the target machine.

For local-only setup: `ln -sf $(pwd)/scripts/* ~/bin/`.

### 2 · Spin up a single agent

```bash
~/bin/kit-session-ensure.sh claude my-agent ~/workspace/my-project
```

A tmux session named `my-agent` boots, starts Claude Code in `~/workspace/my-project`, and **automatically dismisses the trust-folder prompt** so you don't have to babysit it.

### 3 · Spin up a pair (Claude + Codex)

```bash
~/bin/kit-session-ensure.sh claude builder-be-claude ~/workspace/be
~/bin/kit-session-ensure.sh codex  builder-be-codex  ~/workspace/be
```

Two tmux sessions, same worktree. Claude works while it has tokens. Codex stays alive but idle.

### 4 · Handoff when Claude hits its limit

```bash
~/bin/kit-handoff.sh builder-be claude-to-codex ~/workspace/be
```

Claude commits its in-progress state to `.agent-state.md`, the role's single source of truth. Codex reads it, picks up `next-step`, and continues.

When Claude resets:

```bash
~/bin/kit-handoff.sh builder-be codex-to-claude ~/workspace/be
```

That's it.

---

## The 9 pain-fixes baked in

butler-skill-kit was extracted from a working production setup. Every script carries a fix for a real problem we hit:

| # | What broke | What the kit does |
|---|------------|-------------------|
| 1 | Claude's first-time "trust this folder?" dialog blocks the session | Auto-detect, confirm with `'1'` + Enter |
| 2 | Codex sandbox blocks file writes interactively | Auto-add `trust_level = "trusted"` to `~/.codex/config.toml` per worktree |
| 3 | `/var/log/*.log` permission denied on most user accounts | Fall back to `~/.logs/` |
| 4 | `claude -c` / `codex resume --last` exit immediately on first run | Detect prior-session presence before applying the resume flag |
| 5 | tmux `send-keys` paste-mode swallows the first Enter | Always send Enter twice |
| 6 | `git worktree add` fails on existing dirs | Pre-check before creating |
| 7 | `crontab` line duplicates on repeat runs | Grep for existing line, skip if present |
| 8 | hermes profile name and tmux session name collide | Strict naming convention |
| 9 | Server reboot kills every tmux session | `@reboot` cron + 5-min healthcheck both call the idempotent spawn script |

See [`docs/pain-fixes.md`](docs/pain-fixes.md) for full detail and reproduction steps.

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

Every script is **idempotent**. Run them a hundred times — same outcome, no side effects.

> Note: the runtime install dir stays `~/.butler-kit/` (concise, no name repetition). Repo and brand are `butler-skill-kit`.

### `.agent-state.md`

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

Whichever agent is "active" updates this file. Whoever takes over reads it. That's the entire handoff protocol — one file, six fields, no schema enforcement, no daemon.

---

## Use it with single agents too

You don't need the pair pattern to benefit. Useful even with one Claude:

- Idempotent session spawning — `kit-session-ensure.sh`
- Server reboot resilience — `kit-cron-register.sh`
- Sane log directory fallback — `kit-log-dir.sh` (sourceable in your scripts)
- Clean tmux conventions, scriptable handoff hooks

---

## What's not here

We deliberately stay narrow:

- Multi-model routing across N parallel agents → try [oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) or [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)
- Hosted servers, daemons, MCP servers
- A web UI
- Org-specific glue (issue templates, Discord notifications, etc.)

butler-skill-kit is intentionally small. The whole repo is ~400 lines of bash + docs. **Readable in one sitting.**

---

## Companion: `agent-factory`

butler-skill-kit is the plumbing. If you want to define a *team* of agents — PM + backend + frontend + infra + QA — with role definitions, GitLab issue templates, and phase-gated rollout, that's [`agent-factory`](https://github.com/data-sketchers/agent-factory).

(agent-factory is internal-only as of v0.1. Public release after butler-skill-kit stabilizes.)

---

## Status

`v0.1.0-alpha` — extracted from a single production setup (D-SKET Webbuilder Phase 1, 2026-04-24). Not battle-tested by the broader community yet. **Bug reports welcome.**

Tested on:

- Linux Ubuntu 22.04 — primary deployment target
- macOS — local dev (some `sed` differences handled)
- tmux 3.x
- Claude Code 2.x · Codex CLI 0.12x

---

## License

[Apache License 2.0](LICENSE) — use it, fork it, ship it. We just ask attribution.

## Made by

[Data Sketchers](https://data-sketchers.com) — Korean AI startup, built this for our own daily workflow.

Issues and PRs welcome. Discussion: [`/discussions`](https://github.com/data-sketchers/butler-skill-kit/discussions) once enabled.
