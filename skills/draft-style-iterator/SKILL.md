---
name: draft-style-iterator
description: Track and evolve your own writing voice through draft → polish → diff cycles. Each time the human polishes a draft, this skill captures the diff, classifies the changes (vocabulary, structure, tone, ending, etc.), updates the rule list, and feeds it back into the next draft. Best for content channels with a single voice (Threads, blog, newsletter) where consistency matters but the voice itself is still being discovered.
license: Apache-2.0
metadata:
  version: "0.1"
  author: data-sketchers (butler-skill-kit)
---

# Draft Style Iterator

A skill for evolving a personal writing voice through repeated draft→polish→diff cycles.

## Why this exists

When an AI writes drafts on your behalf (Threads, LinkedIn, newsletter, blog), the first few outputs feel generic. You polish each one before publishing — but that polish energy disappears unless you capture *what* you changed.

This skill turns each polish into a learning round:

1. AI produces draft v(N)
2. You publish v(N+1)
3. The skill diffs v(N) → v(N+1), categorizes the changes, and adds them as rules
4. Next time the AI drafts, it consults the rules first

After 5–10 rounds, the AI's first draft starts landing close to your voice.

## Directory structure

```
draft-style-iterator/
├── SKILL.md          # this file
├── rules.md          # active style rules (you maintain this)
├── checklist.md      # before-publish checklist (auto-generated from rules)
├── reject-categories.md   # topics you've consistently rejected
└── examples/
    ├── YYYY-MM-DD-{topic}.md   # one per polish round
    └── ...
```

## Core workflow

### 1. Before drafting

```
Read rules.md
Read reject-categories.md
Skim recent examples/*.md (last 3)
```

Apply all active rules to the draft.

### 2. After human polishes

Diff the AI version (v) against the published version (v'):

```bash
diff <(echo "$DRAFT_V") <(echo "$DRAFT_V_FINAL")
```

For each change, classify:

| Category | Example |
|----------|---------|
| Order | "data → personal" → "personal → data" |
| Vocabulary | English jargon → local everyday word |
| Tone | "definitely" → "tends to be" |
| Personal layer | added "we currently use X, so..." line |
| Ending | "X is the answer." → "X seems good — anyone tried it?" |
| Detail | added inside parenthetical operational note |

Save the v vs v' table to `examples/YYYY-MM-DD-{topic}.md`.

### 3. Update rules

For each new pattern (showing up 2+ times across examples), add a rule to `rules.md`:

```markdown
### {Letter}. {Rule name}
- **Avoid**: {pattern from v}
- **Prefer**: {pattern from v'}
- Why: {reason from human feedback or inferred}
```

### 4. Periodic review

Every 10 polish rounds, run:
- Conflict check: do any rules contradict each other? Resolve.
- Frequency check: which rules are firing every round? Promote to checklist.
- Stale rules: any not used in 5 rounds? Mark optional.

## Suggested rule categories

Based on common Threads/LinkedIn polish patterns:

- **A. Order** — first paragraph anchor (1st person fact / question / sensory hook)
- **B. Tone** — assertive → exploratory ("I think" → "what I'm seeing is")
- **C. Ending** — banned patterns (forced questions) and allowed alternatives (community calls)
- **D. Detail** — parenthetical operational notes for credibility
- **E. Localization** — English jargon to local everyday word
- **F. Hedging** — absolute words → soft modifiers
- **G. Self-positioning** — one short line of "where I'm coming from"
- **H. First-person economy** — drop redundant words ("we also" → "we")
- **I. Vocabulary** — formal → casual where audience is community-tone

## Example: rule entry

```markdown
### B. Assertive → exploratory tone

- **Avoid**: "X is the answer." / "X is best."
- **Prefer**: "X seems best — but I'm still checking." / "Looks like X tends to win."
- Why: Reader joins the discovery rather than receiving a verdict. Threads thrives on discussion, not declaration.
- First seen: 2026-05-04 (mimo-cost-comparison example)
- Reinforced: (track future occurrences here)
```

## Companion artifacts

Each polish round, also save:

```
examples/YYYY-MM-DD-{topic}.md
```

Format:
- v(N) (AI draft) full text
- v(N+1) (human polish) full text
- Numbered diff table
- 1-line take-away

## When to start fresh

If you change channels (e.g. Threads → newsletter), spawn a sibling skill:
- `draft-style-iterator-threads/`
- `draft-style-iterator-newsletter/`

Each maintains its own rules.md tuned to the channel's audience.

## Counter-anti-patterns

- Don't make the AI read the entire `examples/` history every draft — only the most recent 3
- Don't add a rule from a single occurrence — wait for the second hit (avoid one-off overfit)
- Don't track grammatical fixes — those aren't voice, they're proofreading
- Don't let rules.md grow past ~20 active rules — split into channels or retire stale ones

## Provenance

This skill was extracted from a real Korean-language Threads channel (Data Sketchers, threads.com/@datasketchers.dev) after the AI realized it was producing drafts that consistently needed the same 9 categories of polish. By naming and tracking those polish patterns, the AI's first-draft quality climbed steadily.
