---
name: loopplan
description: Use when a loopspace spec has been approved (.loopspace/spec.md, status approved) and the project has no approved plan yet. This is the last human touchpoint before the autonomous loop.
---

# loopplan — Spec to Verified Plan

Principle: **Keep context light, verify heavy.** Acceptance-criteria
precision set here is the quality ceiling of the autonomous loop — each
criterion becomes a TDD test.

Precondition: `.loopspace/spec.md` exists with `status: approved`. If not,
stop and suggest `/loopspec`. If state.md records branch fields (git
projects), make sure `current_branch` is checked out before touching any
file — a fresh session may start wherever the human left the repo; check
it out if it isn't.

If `.loopspace/plan.md` already exists as a draft, resume it: keep its
decomposition and re-enter at Step 2 — panel results are not persisted on
disk, and re-verifying is cheaper than trusting a previous session's
memory. Never re-decompose from scratch unless the human asks.

## Step 1 — Decompose

Set `.loopspace/state.md` `run_status: planning` (create the header-only
file if loopspec somehow didn't).

Write `.loopspace/plan.md` in the exact format defined in
`../../docs/state-format.md` relative to this skill's base directory
(plan.md section), `status: draft`.

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
- `risk:` — `light` (config files, simple CRUD, markup, docs, and pure
  in-memory logic with no I/O, no trust boundary, and no new dependency —
  however central: its whole surface is unit-testable, so the single
  verifier covers it) or `heavy` (auth/security, data migrations, state
  machines with concurrency or partial-failure branches, native platform
  integration, anything touching a trust boundary). **When in doubt, tag
  heavy.**

## Step 2 — Plan Review Panel

Dispatch 3 fresh reviewers — in parallel on Tier A, sequentially on
Tier B, as role-swaps on Tier C (`../../harnesses/PROFILE-SPEC.md`).
Reporting contract is the
same as the spec panel (`[BLOCKING]` / `[NON-BLOCKING]` / `NO FINDINGS`,
one line each):

1. **Verifiability** — every acceptance criterion machine-checkable? Every
   R-id covered by a task? Any task without criteria?
2. **Adversarial** — wrong task ordering (task needs something a later task
   builds)? Hidden coupling between tasks in different phases? A phase
   that isn't actually shippable? Tasks too large to implement in one
   fresh context?
3. **Scope & risk audit** — plan matches spec (no gold-plating, nothing
   missing)? Risk tags honest in both directions? (An auth task tagged
   `light` is a [BLOCKING] finding; pure in-memory logic tagged `heavy`
   is a [NON-BLOCKING] finding — a three-lens panel on code with no
   security surface burns dispatches for nothing.)

Blocking findings → revise → re-panel, max 3 rounds, same rules as the
spec convergence loop.

## Step 3 — Human Approval Gate

Present the plan location, phase/task count, risk-tag distribution, and
remaining non-blocking findings. **Remind the human: this is the last
approval — after this, the loop runs autonomously.** On approval:

1. Set `plan.md` `status: approved`.
2. Rewrite `.loopspace/state.md` in its full form (state.md section of the
   format doc): `run_status: executing`, `current_phase: 1`,
   `current_task:` the first task's id, every task `pending` with
   `attempts: 0`, and the `harness:`/`tier:` fields and the three branch
   fields carried over unchanged (branch fields: git projects only). Seed `## Project Facts` (test command, build/run command,
   stack) from the spec's Engineer Lens — "none yet" is a valid value for a
   greenfield project.
3. Initialize empty `.loopspace/journal.md` (header + version line).
4. **Checkpoint (git repositories only):** commit with only the loopspace
   files staged — `git add .loopspace/plan.md .loopspace/state.md
   .loopspace/journal.md` — message `loopspace: plan approved — <slug>`,
   where `<slug>` is read from `run_branch` in state.md, never re-derived
   from the spec title — so the loop's full ready-to-run state is
   checkpointed on the run branch before autonomy starts.
5. Suggest running `/looprun`.

## Rules

- Never start implementing. This skill only plans.
- Do not modify `spec.md`. Spec gaps found here go back through the spec
  panel: report to the human instead of quietly patching the plan around
  them.
