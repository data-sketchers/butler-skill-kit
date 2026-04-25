# Contributing

Thanks for your interest in butler-kit. The project is small and intentionally so — we want to keep it that way.

## Philosophy

butler-kit is **plumbing**, not porcelain. It does *one* thing: makes Claude Code and Codex CLI sessions cooperate in tmux with a `.agent-state.md` handoff. Anything outside that scope belongs in a higher-level tool.

We will likely **not** merge:

- Daemons or persistent server processes
- Heavy frameworks (Python/Node) when bash + tmux + the underlying CLI suffice
- Org-specific features (GitLab issue automation, Discord notifications, etc.) — those belong in your wrapper, not here
- New language ports (Python rewrite, Rust port) — bash is a feature, not a limitation

## What we welcome

- Bug fixes for any of the 9 documented pain-fixes (or new ones we missed)
- Better defaults for cross-platform compatibility (macOS / Linux distros)
- Docs improvements
- New `kit-*` primitives that fit the "thin wrapper" philosophy
- Test cases (we don't have many — help wanted)

## Pull request guide

1. Open an issue first for non-trivial changes — saves your time and ours
2. Keep diffs small. One logical change per PR.
3. Match the existing bash style: `set -uo pipefail` at the top, helper functions before main flow, clear variable names.
4. Update `docs/pain-fixes.md` if you're adding a new fix.
5. Update `CHANGELOG.md` under `[Unreleased]`.
6. Conventional Commits format encouraged (`fix(handoff):`, `feat(session):`, `docs:`).

## Local testing

```bash
# Install kit scripts to ~/bin/ (or symlink):
ln -sf $(pwd)/scripts/* ~/bin/

# Verify environment
~/bin/kit-bootstrap.sh

# Spawn a dummy session
mkdir -p /tmp/kit-test
~/bin/kit-session-ensure.sh claude kit-test /tmp/kit-test

# Cleanup
tmux kill-session -t kit-test
rm -rf /tmp/kit-test
```

## Reporting security issues

Email `company@data-sketchers.com` instead of opening a public issue.

## Code of conduct

Be kind. Assume good intent. Disagree on substance, not style.
