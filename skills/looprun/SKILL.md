---
name: looprun
description: Use when a loopspace plan has been approved — runs the autonomous implement-verify loop. Dispatches a fresh implementer subagent (TDD contract) then a fresh independent verifier per task, updates .loopspace/ state after every task, and escalates or halts per the stall policy. No human decisions until done, halted, or context handoff.
---

# looprun — The Autonomous Loop

Principle: **Keep context light, verify heavy.**

Preconditions: `.loopspace/spec.md` and `.loopspace/plan.md` both
`status: approved`, `.loopspace/state.md` exists. Missing → stop, suggest
the right skill. All file formats: plugin `docs/state-format.md`.

## Orchestrator Contract (what keeps this loop alive)

- You are a dispatcher, not an implementer. You never write project code.
- **Fresh subagent per task, never reused** — even if the previous one
  finished with context to spare. One task = one implementer + one
  verifier, minimum.
- **Diet:** consume verdicts, one-line summaries, and file lists. Never
  request or accept code dumps, diffs, or full test output into your own
  context. The prompts in `references/agent-prompts.md` enforce the report
  shape.
- Update `state.md` and `journal.md` after **every** task, before
  dispatching the next. A crash must never lose more than one task of
  progress.

## Per-Task Cycle

```
next task = first non-done task in plan order
1. Dispatch IMPLEMENTER (fresh) — prompt template A in references/agent-prompts.md
   - carries: spec excerpt (only the R-ids this task covers), the task
     block from plan.md, current handoff.md notes
   - TDD contract: failing tests first (evidence required), then implement
2. Dispatch VERIFIER (fresh, never the implementer) — template B
   - risk tier from the task's risk tag decides checklist depth
3. PASS → state.md: task done; journal entry; next task (fresh implementer)
   FAIL → attempts += 1; journal the verifier findings; retry with a NEW
   fresh implementer that receives those findings (template A, findings
   section filled)
```

## Stall Policy (3-tier escalation)

1. **Same task fails 3 attempts** → classify the cause yourself from the
   verifier findings:
   - Plan problem (task too large, wrong order, missing prerequisite) →
     re-plan **within spec bounds**: split/reorder tasks, append to
     plan.md `## Re-plans` and journal.md, reset attempts, continue.
     Limit: **one re-plan per task** — a second stall on the same
     (re-planned) task halts: `state.md` `run_status: halted`, write
     `report.md` (trigger: `task-stall`), end turn with the report summary.
   - Spec contradiction or gap → tier 2.
   - Anything else (persistent implementation failure with no plan or
     spec cause) → halt the same way with `report.md`
     (trigger: `task-stall`).
2. **Spec contradiction or gap** → halt: `state.md` `run_status: halted`,
   write `report.md` (trigger: `spec-gap`), end turn with the report
   summary. The spec is the human's contract — never modify it, never
   improvise around it.
3. **External blocker** (missing API key/credentials, service down, broken
   toolchain) → halt immediately, `report.md` (trigger:
   `external-blocker`). Do not burn retries on environment problems.

## Phase Boundary

When the last task of a phase is done:

1. Dispatch a **PHASE VERIFIER** (fresh) — template C: full test suite,
   phase acceptance line from plan.md, cross-task integration.
2. FAIL → treat as a failed task on the offending task id (it re-enters
   the per-task cycle with the findings).
3. PASS → journal `[phase N] verified`; overwrite `handoff.md`
   (trigger: `phase-boundary`); continue to the next phase.
4. Last phase → `run_status: complete`, final journal entry, report
   totals to the human (tasks, retries, re-plans).

## Context Threshold (the 30% rule)

Watch your own context consumption (system warnings, or the sheer length
of your conversation). When roughly 30% is consumed — do not push your
luck past it:

1. Finish the in-flight task cycle (never abandon a dispatched verifier).
2. Overwrite `handoff.md` (trigger: `context-threshold`) with everything
   the next session needs.
3. Update `state.md`, then end the turn telling the user exactly:
   run `/clear`, then `/loopresume`. This is typing, not judgment —
   say so.

## Rules

- Verifier verdicts are final. No re-litigating a FAIL in your own context.
- Never mark a task done without a verifier PASS in the journal.
- Never modify spec.md. plan.md changes only through the re-plan path.
