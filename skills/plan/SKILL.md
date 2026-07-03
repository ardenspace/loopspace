---
name: plan
description: Use when a loopspace spec has been approved — decomposes .loopspace/spec.md into phases and tasks with machine-checkable acceptance criteria and light/heavy risk tags, verifies the plan with a review panel, and gets human approval. This is the last human touchpoint before the autonomous loop.
---

# loopspace:plan — Spec to Verified Plan

Principle: **Keep context light, verify heavy.** Acceptance-criteria
precision set here is the quality ceiling of the autonomous loop — each
criterion becomes a TDD test.

Precondition: `.loopspace/spec.md` exists with `status: approved`. If not,
stop and suggest `/loopspace:spec`.

## Step 1 — Decompose

Write `.loopspace/plan.md` in the exact format defined in the plugin's
`docs/state-format.md` (plan.md section), `status: draft`.

**Phases:** each phase is a shippable increment — after it, the project
runs and its tests pass, even if features are missing. Write the phase
acceptance line: what the phase verifier will check across tasks.

**Tasks:** the smallest unit worth a fresh implementer and a fresh
verifier. Each task must have:

- `covers:` — the requirement IDs (R1…) it implements. Every spec
  requirement must be covered by at least one task.
- `acceptance:` — criteria in test-description form. "returns 401 when the
  token is expired", never "auth works". A criterion an agent cannot turn
  into a pass/fail test is a planning bug.
- `risk:` — `light` (config files, simple CRUD, markup, docs) or `heavy`
  (auth/security, core business logic, data migrations, anything touching
  a trust boundary). **When in doubt, tag heavy.**

## Step 2 — Plan Review Panel

Dispatch 3 fresh reviewer subagents in parallel. Reporting contract is the
same as the spec panel (`[BLOCKING]` / `[NON-BLOCKING]` / `NO FINDINGS`,
one line each):

1. **Verifiability** — every acceptance criterion machine-checkable? Every
   R-id covered by a task? Any task without criteria?
2. **Adversarial** — wrong task ordering (task needs something a later task
   builds)? Hidden coupling between tasks in different phases? A phase
   that isn't actually shippable? Tasks too large to implement in one
   fresh context?
3. **Scope & risk audit** — plan matches spec (no gold-plating, nothing
   missing)? Risk tags honest? (An auth task tagged `light` is a
   [BLOCKING] finding.)

Blocking findings → revise → re-panel, max 3 rounds, same rules as the
spec convergence loop.

## Step 3 — Human Approval Gate

Present the plan location, phase/task count, risk-tag distribution, and
remaining non-blocking findings. **Remind the human: this is the last
approval — after this, the loop runs autonomously.** On approval:

1. Set `plan.md` `status: approved`.
2. Initialize `.loopspace/state.md` (format: `docs/state-format.md`):
   `run_status: executing`, `current_phase: 1`, first task
   `in_progress`-ready, all tasks `pending` with `attempts: 0`.
3. Initialize empty `.loopspace/journal.md` (header + version line).
4. Suggest running `/loopspace:run`.

## Rules

- Never start implementing. This skill only plans.
- Do not modify `spec.md`. Spec gaps found here go back through the spec
  panel: report to the human instead of quietly patching the plan around
  them.
