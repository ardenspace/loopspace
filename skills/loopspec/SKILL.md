---
name: loopspec
description: Use when starting a new loopspace project or feature — turns an idea into a rigorously verified spec through a 4-lens interview (company, user, engineer, designer) and a 6-lens verification panel, ending with human approval. First step of the loopspace pipeline.
---

# loopspec — Idea to Verified Spec

Principle: **Keep context light, verify heavy.** The spec stage is where
"verify heavy" pays most: a defect caught here is ~10x cheaper than one
caught in code, and precise requirements reduce implementation retries.

The spec is the human's contract. Downstream agents never modify it.

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
designer. Question banks: `references/interview-lenses.md`. Skip questions
already answered by the user's initial description. Prefer multiple choice
where natural.

**Designer-lens applicability test:** skip the designer lens entirely when
the project has no UI surface (pure library, CLI without interactive UI,
backend service). State that you are skipping it and why.

Stop interviewing when you can write every spec section without inventing
answers. Depth over speed — this stage is never cost-reduced.

## Step 2 — Draft

Write `.loopspace/spec.md` in the exact format defined in the plugin's
`docs/state-format.md` (spec.md section), with `status: draft`.

Requirements (`R1, R2, …`) must be testable phrasings — "R3: the CLI exits
non-zero on malformed input", not "R3: good error handling".

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
- Non-blocking findings accumulate; do not block on them.

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
