# Changelog

## 0.4.0 — 2026-07-03

Two test-time-compute upgrades to the loop, both scoped so the extra
tokens land only where they buy the most:

- **Three-lens verification panel for heavy tasks.** A heavy task's
  verification is now three fresh verifiers dispatched in parallel —
  correctness (runs the tests, maps criteria to tests, checks scope
  creep), security (secrets, injection surfaces, trust boundaries), and
  test-integrity (TDD failed-first evidence, test-gaming detection).
  PASS requires all three lenses: they are complementary coverage, not
  votes, so a security FAIL cannot be outvoted. Only the correctness
  lens runs commands; the other two are read-only, which is what makes
  the parallel dispatch safe. Light tasks keep the single mechanical
  verifier (Template B); the panel is Template D.
- **Diversity burst on persistent task stalls.** When 3 attempts fail
  with no plan or spec cause — the case that previously halted
  immediately — the orchestrator now runs up to 3 candidate
  implementers before halting. Each candidate sees every failed
  approach verbatim and must take a genuinely different one; each is
  independently verified; the first PASS wins. Candidates run strictly
  one at a time (they share the working tree), with a reset to the last
  git checkpoint before each. Implementer reports gain an `approach:`
  line to feed the directive. All candidates failing halts with
  `task-stall` as before, with every approach tried listed in the
  report. One burst per task.

## 0.3.0 — 2026-07-03

**Interview discipline hardened after the first dogfood run caught loopspec
skipping the interview** ("user seems absent → adopt recommended defaults"):
a question may be skipped only when the user's own words answer it;
"asking means waiting" — a question is delivered via the question tool or
as the turn's final line, and the answer arrives in the user's next
message, never narrated past mid-turn; harness autonomy guidance is
explicitly declared inapplicable during the interview; assumption markers
in a draft are auto-`[BLOCKING]` for every panel reviewer; an existing
draft is resumed with its assumptions treated as unanswered questions.

Robustness pass on all four skills after review:

- `state.md` now exists from the spec stage on (`run_status: spec` →
  `planning` → `executing`), so the SessionStart hook and `/loopresume`
  cover crashes anywhere in the pipeline — previously `spec`/`planning`
  were defined but unreachable.
- Defined the halt-resume procedure: `/looprun` on a halted run journals
  the human's decision, resets the failed task, deletes `report.md`, and
  re-enters the loop. Halts now mark the offending task `failed`.
- Implementer `BLOCKED` verdicts are now handled explicitly (external →
  halt, ambiguity → spec-gap, else failed attempt).
- Git checkpoint: commit after every verifier PASS in git repositories,
  plus a boundary commit after each phase verification so the phase
  journal entry and fresh handoff don't ride uncommitted into the next
  phase.
- New `## Project Facts` block in `state.md` (test/build commands, stack),
  seeded by loopplan and injected into every subagent dispatch.
- Implementer contract is now staged: UNDERSTAND (ambiguous criteria →
  BLOCKED, never guess) → PLAN (files, test list) → TDD.
- TDD-evidence check moved into the light verifier tier (was heavy-only).
- Phase verification capped at 3 rounds (new `phase-stall` halt trigger);
  handoff.md overwrites carry forward still-true items.
- Re-plan splits get letter-suffixed task ids (`2.3` → `2.3a`, `2.3b`).
- loopspec guards against clobbering an existing run; panel rounds prune
  resolved non-blocking findings.
- Context threshold gets a measurable proxy (10 task cycles per session);
  skill descriptions rewritten to trigger-only form; state-format paths
  made explicit relative to each skill's base directory.

## 0.2.0 — 2026-07-03

**Breaking:** skills renamed to `loopspec`, `loopplan`, `looprun`, `loopresume`.
The short forms of the old names collided with built-in commands (`/plan`,
`/resume`), forcing the verbose `/loopspace:*` invocation. Update any saved
commands: `/spec` → `/loopspec`, `/plan` → `/loopplan`, `/run` → `/looprun`,
`/resume` → `/loopresume`.

## 0.1.0 — 2026-07-03

Initial release: `spec`, `plan`, `run`, `resume` skills and the SessionStart
resume-reminder hook.
