# Changelog

## 0.5.0 — 2026-07-03

Three trust-to-mechanics conversions after the first real runs — each
replaces a link where an agent's claim was read and believed with one
where it is executed and checked, at near-zero runtime cost (no new
dispatches; prompt and rule changes only):

- **Mechanical failed-first proof (heavy tier).** The correctness lens no
  longer just reads the implementer's failed-first evidence: it stashes
  the implementation files (`git stash push -u -- <impl files>`), re-runs
  the tests, confirms the task's tests actually FAIL without the
  implementation, and restores. This kills both fabricated TDD evidence
  and tests that never exercise the implementation. Consequence: the
  heavy panel now dispatches in two waves — security + test-integrity in
  parallel (read-only), then correctness alone — because a lens that
  stashes the tree can never run beside a reader. The light tier keeps
  the plausibility read.
- **Contested-findings channel.** A retry implementer that can prove a
  prior finding factually wrong (file:line or command output) contests it
  in its report instead of "fixing" a non-problem — a hallucinated FAIL
  previously produced scope creep exactly this way. The next verifier
  must explicitly confirm or drop every contested finding in its lens;
  dropped findings never reach the next retry. Judgment calls are not
  contestable, and verdict authority never leaves the verifiers — the
  orchestrator passes contests through, it never adjudicates them.
- **Evidence-cited stall classification.** The stall-cause branch (plan
  problem / spec gap / stubborn) was the pipeline's only unverified
  judgment point. The orchestrator now journals the classification
  quoting the verbatim finding lines that justify it before branching
  (`## [stall <id>] cause: ... — evidence: "..."`); a cause it cannot
  back with a quoted finding defaults to the stubborn-task branch — the
  only branch that is cheap to be wrong about (a wasted burst, not a
  burned re-plan or a needless halt).

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
