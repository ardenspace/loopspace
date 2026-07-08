# Changelog

## 0.12.0 — 2026-07-08

- **`/loopnext` — spec versioning between runs (backlog item 10).** The
  pipeline was a waterfall: one frozen spec, one run. loopnext is the
  human touchpoint between a completed run and the next — usage feedback
  plus the journal's advisories (structure-note and spec-concern finally
  get their consumer) become an in-place spec amendment (`spec_version`,
  R-ids revised/dropped/added with an origin-tagged Amendment Log) and a
  delta plan, verified by a 3-lens panel (coherence — new, checks the
  amendment against frozen requirements and what the last run actually
  built — plus adversarial and verifiability). Execution is unchanged:
  run N branches as `loopspace/<slug>-v<N>/run`, so looprun's logic runs
  verbatim; its only edit is a one-sentence pointer in the run-complete
  report. Run lifecycle is now defined: prior runs archive to
  `.loopspace/archive/run-<N>/` (spec snapshot included), the journal
  persists across runs under run headers, an ancestor check refuses to
  draft a delta on a tree that lacks run N-1's code, and rejecting the
  amendment restores the pre-loopnext state exactly. The spec stays
  frozen within a run — versioning happens only between runs, at human
  approval gates.

## 0.11.0 — 2026-07-06

- **Headless supervisor (opt-in, backlog item 6 v1).** A new `/loopsupervise`
  skill and `scripts/supervise.sh` let an unattended run restart itself across
  context thresholds and crashes: each `claude -p "/loopresume"` is a fresh
  process, so process death is the context clear — no `/clear` to type. The
  supervisor reads only `.loopspace/state.md` (`run_status`): `executing`
  relaunches, `complete`/`halted` notify and exit, and a halt is **never**
  auto-resumed (its whole meaning is "await a human"). A no-progress guard
  stops after two restarts that change nothing. Optional Telegram alerts fire
  on halt/complete when `LOOPSPACE_TG_BOT_TOKEN` and `LOOPSPACE_TG_CHAT_ID`
  are set; otherwise it logs to stdout. Nothing in the existing loop changed —
  looprun, loopresume, and the state format are untouched; the supervisor is a
  read-only control layer. The interactive run keeps its mandatory `/clear`
  handoff; the supervisor is a separate path for truly unattended (overnight)
  runs and assumes a container/dedicated machine (`--dangerously-skip-permissions`).
  Hardening: a SIGINT/SIGTERM trap stops the loop instead of relaunching past a
  Ctrl-C, an absolute restart ceiling (`LOOPSPACE_MAX_RESTARTS`, default 50)
  bounds token spend even when every restart "makes progress", an unrecognized
  `run_status` is retried once before exiting (torn mid-rewrite reads survive),
  and the progress signature now hashes the whole `state.md` so
  `current_task` movement alone counts as progress.

## 0.10.0 — 2026-07-06

- **Spec-concern advisory (all verifiers).** The loop's rigor is capped by the
  spec's quality: a contradictory spec halts (`spec-gap`), but a spec that is
  consistent-yet-questionable verifies clean and gets built at 100% coverage.
  Backlog item 5 resolved this trade-off on the advisory side — the unattended
  loop is the product's core value, so no new human checkpoint. Every verifier
  (light, heavy lenses, phase) can now report `spec-concern`: work that is
  correctly implemented per the spec but questionable *as* spec design.
  Concerns never affect a verdict, never trigger a halt, and are deliberately
  kept out of every dispatch — a "the spec looks wrong" note in an
  implementer's hands invites improvising around a frozen spec. They accumulate
  verbatim in the journal and surface at the human's two reading touchpoints:
  the halt report (new optional `## Spec concerns` section in report.md) and
  the run-complete summary. Escalating to an opt-in human checkpoint stays
  gated on observing that advisory isn't enough.

## 0.9.0 — 2026-07-06

- **Plan-freshness advisory (phase verifier).** plan.md fixes every
  phase's task decomposition upfront, so a late phase's tasks were written
  blind to what earlier phases actually built — and the only correction
  was the stall path, which costs three failures first. Backlog item 8's
  observation gate stays (the Lane C run was too short to prove or refute
  the failure mode), so this ships the instrument, not the fix: template C
  now receives the next phase's task blocks and flags, as `freshness-note`
  (advisory only, never a FAIL, never a re-plan trigger), criteria the
  current code already satisfies, stale `files:` references, and conflicts
  with constraints discovered this phase. Notes are journaled verbatim on
  the `[phase N] verified` entry and carried into the handoff's "Watch out
  for", so the flagged task's own implementer sees the suspicion — if it's
  real, the existing blocked/stall routes handle it. Promotion to an early
  re-plan trigger (or closing item 8) waits on what the notes show in the
  next multi-phase dogfood.

## 0.8.0 — 2026-07-06

- **`/loopupdate`.** One command to update the plugin: refreshes the
  marketplace, runs `claude plugin update`, and shows the changelog
  entries between the installed and new versions. Loopspace-specific
  guard: when a run is `executing`, it recommends restarting at a stable
  point (task cycle done or handoff written) so one run never mixes
  template versions mid-task. Restarting Claude Code is still required
  to load the new version — a harness constraint, not a skill choice.

## 0.7.0 — 2026-07-06

First backlog pass after the Lane C dogfood (ledger:
`docs/backlog-2026-07-05.md`). A cost diagnosis on the run journal — 14/14
tasks first-attempt PASS, verification = 62% of dispatches, both
spend-limit hits inside verification waves — drove all three changes:

- **Comment discipline (implementer).** Dogfood output ran 31% comments,
  mostly restated acceptance criteria. Template A now rules: comments only
  for constraints the code cannot show — never restating criteria,
  narrating the next line, or justifying the change.
- **Sharper risk-tag criteria.** A pure-domain task (haversine math, no
  I/O) ran the full 3-lens panel with nothing for the security lens to
  see. loopplan now tags pure in-memory logic (no I/O, no trust boundary,
  no new dependency) `light` however central it is, and the heavy examples
  name the real cases instead of "core business logic": state machines
  with concurrency or partial-failure branches, native platform
  integration, trust boundaries. The plan panel's tag-honesty check is now
  bidirectional — over-tagging heavy is a [NON-BLOCKING] finding (a
  three-lens panel on code with no security surface burns dispatches).
- **Structural economy advisory (phase verifier).** A display-only map
  screen grew to 7 files while three defense layers watched per-task scope
  only — cumulative structural bloat was nobody's lens. Template C gains
  an advisory check (files/indirection proportionate to what shipped;
  acceptance-required seams like test-isolation fakes are exempt),
  reported as `structure-note` and journaled verbatim. Advisory only —
  it never turns a PASS into a FAIL; promotion to FAIL waits on repeat
  observations.

## 0.6.0 — 2026-07-04

Branch strategy + approval checkpoints, from the first collaborative-repo
dogfood concern: the loop used to commit straight onto whatever branch was
checked out, and approved specs/plans sat uncommitted in the working tree.

- **Approval commits.** loopspec and loopplan now commit the artifact the
  human just approved (`loopspace: spec approved — <slug>`, `loopspace:
  plan approved — <slug>`), staging only `.loopspace/` files — the loop's
  contract is checkpointed before the loop starts.
- **Stacked phase branches.** Spec approval creates `loopspace/<slug>/run`
  from the current branch; looprun stacks `loopspace/<slug>/phase-N` per
  phase, so every completed phase tip is a named, verified pointer and the
  start branch never sees unverified work. Inside the loop a verifier PASS is
  the merge authority — no per-task merge questions — and the human merge
  decision lives at the touchpoints that already exist: the run-complete
  report offers merge / PR / leave-as-is, and a halt report names the
  last verified phase branch for partial merges. state.md gains
  `base_branch` / `run_branch` / `current_branch`; their absence (non-git
  project) switches all branch logic off. Mid-run the loop still never
  pushes and now explicitly never merges.

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
