# Changelog

## Unreleased

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
- Git checkpoint: commit after every verifier PASS in git repositories.
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
