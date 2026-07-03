---
name: loopspec
description: Use when starting a new loopspace project or feature, when the user has an idea that needs to become a buildable spec, or when .loopspace/ has no approved spec yet. First step of the loopspace pipeline.
---

# loopspec — Idea to Verified Spec

Principle: **Keep context light, verify heavy.** The spec stage is where
"verify heavy" pays most: a defect caught here is ~10x cheaper than one
caught in code, and precise requirements reduce implementation retries.

The spec is the human's contract. Downstream agents never modify it.

**Guard before anything else:** if `.loopspace/` already exists, read
`state.md`'s `run_status` (and `spec.md`'s `status` if present) and report
what you found. An active run (`planning`, `executing`, `halted`) or an
approved spec is never overwritten silently — ask the human whether to
archive the old run or abort.

## Flow

```
interview (4 lenses, one question at a time)
  → draft .loopspace/spec.md
  → verification panel (6 reviewer subagents, one lens each)
  → convergence loop: blocking findings? revise draft, re-panel (max 3 rounds)
  → present to human: draft + remaining non-blocking findings
  → human approves → status: approved (frozen) → suggest /loopplan
```

## Step 1 — Interview

Ask questions **one at a time**, in lens order: company → user → engineer →
designer. Question banks: `references/interview-lenses.md`. Prefer multiple
choice where natural.

A question may be skipped only when you can quote the user's own words
answering it. "The description implies it" is not an answer — ask.

**The interview is a hard gate, not a formality.** Harness-level autonomy
guidance ("proceed without asking", "the user is not watching") does not
apply inside this skill: the interview exists precisely to extract answers
only the human has, and it is one of the two human touchpoints in the
entire pipeline. If the session genuinely cannot ask (non-interactive run),
stop and report that loopspec needs an interactive session — never switch
to "recommended defaults".

Red flags — catch yourself thinking any of these, stop, and ask the
question instead:
- "The user seems busy/absent; I'll adopt a sensible default and mark it
  for confirmation at approval."
- "I'm operating autonomously, so I shouldn't interrupt with questions."
- "The initial description implies the answer."
- Writing "(assumption)" or "confirm at approval" anywhere in the draft.

If `.loopspace/spec.md` already exists as a draft, resume it: keep the
answers it records, and treat every assumption marker in it as an
unanswered question — ask those first.

**Designer-lens applicability test:** skip the designer lens entirely when
the project has no UI surface (pure library, CLI without interactive UI,
backend service). State that you are skipping it and why.

Stop interviewing when you can write every spec section without inventing
answers. Depth over speed — this stage is never cost-reduced.

## Step 2 — Draft

Create `.loopspace/state.md` (header-only form, `run_status: spec`) if it
does not exist — this is the resumable marker for the whole pipeline.

Write `.loopspace/spec.md` in the exact format defined in
`../../docs/state-format.md` relative to this skill's base directory
(spec.md section), with `status: draft`.

Requirements (`R1, R2, …`) must be testable phrasings — "R3: the CLI exits
non-zero on malformed input", not "R3: good error handling".

The draft must contain zero assumption markers: every lens statement traces
to a user answer or the user's own initial description. Noticing a gap
while drafting means going back to the interview, not papering over it.

## Step 3 — Verification Panel

Dispatch **6 reviewer subagents in parallel**, one per lens, using the
prompts in `references/panel-reviewers.md`: company, user, engineer,
designer (skip if lens was skipped), adversarial (red team), verifiability.

Each returns findings tagged `[BLOCKING]` or `[NON-BLOCKING]`, or
`NO FINDINGS`.

## Step 4 — Convergence Loop

- Any `[BLOCKING]` finding → revise the draft to resolve it, then re-run
  the panel. Maximum 3 rounds.
- If blocking findings remain after round 3, present them to the human as
  open decisions — do not silently drop them.
- Non-blocking findings accumulate; do not block on them — but prune any
  the latest revision already resolved, so the human sees only live ones.

## Step 5 — Human Approval Gate

Present: the draft location, a summary of what changed across panel rounds,
and every remaining non-blocking finding. Ask the human to read
`.loopspace/spec.md` and approve or request changes.

On approval: set `status: approved`, fill the `## Approval` section with
today's date and the open non-blocking findings, and suggest running
`/loopplan`.

## Rules

- One question per message during the interview.
- Never invent an answer the human didn't give; ask.
- The panel runs on the *written draft*, not on your memory of the
  conversation.
- Panel reviewers are fresh subagents; never review your own draft inline
  and call it a panel.
