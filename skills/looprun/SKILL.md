---
name: looprun
description: Use when a loopspace plan has been approved and execution should start or continue, including after a halt the human has resolved. No human decisions until done, halted, or context handoff.
---

# looprun — The Autonomous Loop

Principle: **Keep context light, verify heavy.**

Preconditions: `.loopspace/spec.md` and `.loopspace/plan.md` both
`status: approved`, `.loopspace/state.md` exists. Missing → stop, suggest
the right skill. `run_status: halted` → do not loop; go to Halt-Resume
below. `run_status: complete` → say so, stop. All file formats:
`../../docs/state-format.md` relative to this skill's base directory.

## Orchestrator Contract (what keeps this loop alive)

- You are a dispatcher, not an implementer. You never write project code.
- **Fresh agent per task, never reused** — even if the previous one
  finished with context to spare. One task = one implementer + one
  verifier, minimum.
- **Harness dispatch:** state.md's `harness:`/`tier:` fields say how
  fresh agents are launched — mechanics in the harness profile
  (`../../harnesses/<harness>.md`), tier semantics in
  `../../harnesses/PROFILE-SPEC.md`. Tier A: this skill as written.
  Tier B: every parallel dispatch runs sequentially — same prompts,
  same verdict rules. Tier C: dispatch becomes the role-swap protocol.
  Fields absent (pre-0.13 run) → claude-code / A.
- **Diet:** consume verdicts, one-line summaries, and file lists. Never
  request or accept code dumps, diffs, or full test output into your own
  context. The prompts in `references/agent-prompts.md` enforce the report
  shape. Templates go out whole: fill the `{...}` placeholders, keep every
  fixed sentence around them verbatim — dropping the contract text under
  a filled block disarms the check it announces.
- Update `state.md` and `journal.md` after **every** task, before
  dispatching the next. A crash must never lose more than one task of
  progress.
- Every dispatch carries the `## Project Facts` block from state.md, so
  fresh agents never re-discover the repo. When an implementer's report
  corrects a fact (`facts:` line), update state.md before the next dispatch.
- **Git checkpoint:** if the project is a git repository, commit after every
  verifier PASS — message `loopspace: task <id> — <title>` — so one bad task
  can always be rolled back to the last verified state. Never push or merge
  mid-run: the only moment either can happen is the run-complete report, on
  an explicit human choice.
- **Branch discipline (git projects):** state.md's branch fields say where
  work happens; `<slug>` is read from `run_branch`, never re-derived from
  the spec title. On entry, put the run on the right phase branch
  mechanically: determine P, the phase number of the next non-done task in
  plan order; ensure `loopspace/<slug>/phase-<P>` exists and is checked out
  — create it from the current HEAD if it is missing — and set
  `current_branch` to it in state.md. This is self-healing: it opens
  phase-1 on the first entry, and it recovers both crash windows — a crash
  between a phase boundary commit and the next branch's creation, and one
  where the branch was created but `current_branch` was never updated. Task
  commits, rollbacks, and burst resets all happen on the current phase
  branch. No branch fields in state.md means a non-git project or a
  pre-0.6.0 run: skip all branch logic.

## Per-Task Cycle

```
next task = first non-done task in plan order
0. Debts (self-healing, like branch discipline — both re-derived from
   disk on every cycle entry, so they survive crashes and early
   turn-ends). Check panel debt first: a phase boundary must never seal
   a task the panel never fully checked.
   - Panel debt: if any done task carries `risk: heavy` in plan.md but
     its journal PASS entry records fewer than three lens verdicts, the
     panel never fully ran — the task was marked done on less
     verification than template D demands. Dispatch the missing lenses
     now (template D, the usual waves), before anything else. Any lens
     FAIL → the task re-enters the per-task cycle as a normal FAIL
     (status pending, attempts += 1, findings journaled).
   - Boundary debt: if any phase before the next task's phase has all
     its tasks done in state.md but no `[phase N] verified` entry in
     journal.md, that boundary never ran — a session ended in the window
     between the phase's last task and its verifier, and "when the last
     task is done" fired in a session that no longer exists. Run the
     Phase Boundary for the oldest such phase now, before dispatching
     anything.
   - Final debt: if every task in plan.md is done, there is no next task
     and the run is in its closing sequence — a session ended somewhere
     between the last task and `run_status: complete`. Re-derive where:
     any phase without a `[phase N] verified` entry gets its Phase
     Boundary first (oldest first); once every phase has one, go to Final
     Verification. Skip both if the journal already carries `[final]
     verified` — then only step 4's completion report is left.
1. Dispatch IMPLEMENTER (fresh) — prompt template A in references/agent-prompts.md
   - carries: Project Facts, spec excerpt (only the R-ids this task
     covers), the task block from plan.md, current handoff.md notes,
     and the PRIOR WORK THIS PHASE block — assembled from journal.md:
     one line per done task in the current phase, its `files:` and
     `exports:` lines verbatim ("none yet" on the phase's first task;
     done means done in state.md — a task re-opened by a phase FAIL is
     not; use a task's latest PASS entry when retries left several;
     an old journal entry without an exports line contributes files
     only). Assembly reads the journal, never project code — the diet
     holds.
   - staged contract: UNDERSTAND → PLAN → TDD (failing tests first,
     evidence required)
2. Implementer BLOCKED? Classify the blocker line:
   - external (missing credentials, service down, broken toolchain) →
     stall policy tier 3, immediately
   - ambiguous/contradictory criteria the plan could fix (bad
     decomposition) → stall policy tier 1 re-plan path
   - ambiguity only the spec owner can answer → stall policy tier 2
   - anything else → counts as a failed attempt: attempts += 1, journal
     the blocker, retry with a new fresh implementer carrying it
3. Dispatch VERIFICATION (fresh, never the implementer)
   - every verifier dispatch carries the same PRIOR WORK THIS PHASE
     block the implementer received
   - risk: light → one verifier, template B
   - risk: heavy → three-lens panel, template D, in two waves: dispatch
     security + test-integrity in ONE message (both read-only, safe in
     parallel, and they see the tree exactly as the implementer left
     it); when both report, dispatch correctness alone — it runs
     commands and briefly stashes the implementation for the mechanical
     failed-first check, so it can never run beside a reader. Verdict
     rule: PASS requires all three lenses PASS — lenses are
     complementary coverage, not votes; a security FAIL cannot be
     outvoted. Any lens FAIL → merge all FAIL findings (numbered,
     lens-tagged) and take the FAIL path. (Tier B: same waves, one
     agent at a time; Tier C: three sequential role-swaps, same lens
     order, correctness last.)
   - retry dispatches: fill the CONTESTED FINDINGS section with the
     `contested:` lines from the implementer's report (or "none").
     Never adjudicate a contest yourself — re-deriving facts is the
     verifier's job, and your diet stays.
4. PASS → state.md: task done; git checkpoint commit; journal entry
   including the implementer's `exports:` line and its `pre-existing:`
   line if present (heavy: record all three lens verdicts); next task
   (fresh implementer)
   FAIL → attempts += 1; journal the verifier findings; retry with a NEW
   fresh implementer that receives those findings (template A, findings
   section filled)
   Either way, journal any contested resolutions (`#N confirmed/dropped`);
   a dropped finding is never carried into the retry's findings. Journal
   any `spec-concern` lines verbatim — they never affect the verdict, are
   never carried into any dispatch (a "the spec looks wrong" note in an
   implementer's hands invites improvising around a frozen spec), and
   never trigger a halt. They wait in the journal for the human's next
   reading touchpoint: the halt report or the run-complete report.
```

## Stall Policy (3-tier escalation)

1. **Same task fails 3 attempts** → classify the cause from the verifier
   findings, and journal the classification with its evidence BEFORE
   branching: `## [stall <id>] cause: <plan | spec-gap | stubborn> —
   evidence: "<the verbatim finding line(s) that justify it>"`. A cause
   you cannot back with a quoted finding line is not available to you —
   default to the stubborn-task branch: a wrong burst only wastes
   candidates, while a wrong re-plan burns the task's one re-plan and a
   wrong halt costs a human roundtrip.
   - Plan problem (task too large, wrong order, missing prerequisite) →
     re-plan **within spec bounds**: split/reorder tasks, append to
     plan.md `## Re-plans` and journal.md, reset attempts, continue.
     Limit: **one re-plan per task** — a second stall on the same
     (re-planned) task halts: `state.md` `run_status: halted`, write
     `report.md` (trigger: `task-stall`), end turn with the report summary.
   - Spec contradiction or gap → tier 2.
   - Anything else (persistent implementation failure with no plan or
     spec cause) → relief gates, then halt. Every gate is once per task,
     guarded by its own journal entry — grep the journal before
     granting one.

     **Gate 1 — narrow resume.** Checked before the burst, because the
     burst resets the tree and would discard converging work: count the
     numbered findings in each of this task's verifier FAILs, in
     journal order. If the counts strictly decreased (e.g. 5→3→2) AND
     every finding in the final FAIL names a concrete missing test,
     case, or line — not approach-level rework — the attempts are
     converging, and more incremental retries beat both a burst and a
     halt. Journal `## [<id>] narrow resume — findings converging
     (<counts>)`, reset attempts to 0, and continue the task: fresh
     implementer, template A, findings section = the final FAIL's
     findings verbatim.

     **Gate 2 — diversity burst.** Sequential retries share a failure
     mode: each fresh implementer converges on roughly the same
     approach, so attempt 4 fails like attempts 1–3. The burst forces
     sampling diversity instead:
     1. Collect the `approach:` lines from every failed attempt.
     2. Up to 3 candidates, strictly one at a time (they share one
        working tree — never parallel). Before each: in a git repo,
        reset to the last checkpoint but exclude the tracked state dir
        (`git checkout -- . ':(exclude).loopspace'` +
        `git clean -fd -e .loopspace`) — a plain reset would revert the
        attempts counter, FAIL journal entries, and the stall
        classification now that `.loopspace/` is tracked; outside git,
        tell the candidate leftover files from failed attempts may exist
        and are theirs to replace.
        Dispatch a fresh implementer (template A) with the APPROACH
        DIRECTIVE section filled: all failed approaches verbatim, and
        the instruction to take a genuinely different one.
     3. Each DONE candidate goes through normal verification (step 3
        of the cycle — panel if heavy). attempts += 1 per candidate.
        First PASS wins: journal `[<id>] burst candidate N — PASS`,
        stop the burst, continue the run.
     4. All candidates FAIL or BLOCKED → **gate 3 — escalation
        ladder** (once per task): if state.md has an
        `implementer_fallback:` field, journal `## [<id>] escalated
        implementer → <fallback>`, reset attempts to 0, and continue
        the task with every implementer dispatch routed to the
        fallback (the harness profile's Model Routing section says how;
        verifier routing never changes). The burst stays spent — a
        later stall on this task finds every gate's journal entry
        already present and halts. No fallback field, or the gate
        already spent → halt: `run_status: halted`, `report.md`
        (trigger: `task-stall`) listing every approach tried — and
        which relief gates fired, when any did — end turn with the
        report summary.
2. **Spec contradiction or gap** → halt: `state.md` `run_status: halted`,
   write `report.md` (trigger: `spec-gap`), end turn with the report
   summary. The spec is the human's contract — never modify it, never
   improvise around it.
3. **External blocker** (missing API key/credentials, service down, broken
   toolchain) → halt immediately, `report.md` (trigger:
   `external-blocker`). Do not burn retries on environment problems.

Every halt, whatever the trigger, also sets the offending task's status to
`failed` in state.md. In a git repository, report.md additionally records
`current_branch:` and `last_verified_phase:` (the newest phase branch whose
boundary verification passed, or `none`) so the human can choose to merge
only verified work. If the journal holds any `spec-concern` lines, list
them in report.md under `## Spec concerns` — the halt is a human
touchpoint, and concerns wait for exactly these.

## Halt-Resume (run_status: halted)

Entered from the preconditions check, typically via `/looprun` after the
human resolved a halt:

1. Summarize `report.md` and ask the human which option they chose (skip
   the question if they already said).
2. Journal `## [halt] resolved — <the decision, one line>`.
3. Reset the failed task: status `pending`, `attempts: 0`. Apply the
   decision if it changed the plan (via the re-plan path) — spec changes
   still mean going back through `/loopspec`, not patching here.
4. Set `run_status: executing`, delete `report.md`, and (git projects)
   check out `current_branch` — the human may have wandered branches while
   resolving the halt — then re-enter the per-task cycle.

## Phase Boundary

When the last task of a phase is done:

1. Dispatch a **PHASE VERIFIER** (fresh) — template C: spec probes
   derived from the full spec BEFORE any exposure to the implementers'
   tests, full test suite, phase acceptance line from plan.md, cross-task
   integration, mutation spot-check (git projects). The dispatch carries
   the full spec.md text, the union of `covers:` R-ids across this and
   all earlier phases (template C's COVERED SO FAR input — the probe
   boundary), and the next phase's block from plan.md (template C's
   NEXT PHASE input, "none" on the last phase) for the freshness
   advisory. The probes exist because implementation and tests can share
   one mind's blind spot: the implementer-written suite is never accepted
   as evidence for a spec-level claim.
2. FAIL → treat as a failed task on the offending task id (it re-enters
   the per-task cycle with the findings). A failing probe travels twice:
   as a findings line (input, spec line, actual) and as the probe file
   left in the tree — the re-opened task's fix must turn it green; an
   implementer who can show a probe misreads the spec contests it like
   any finding, and the next verifier re-derives from the spec text.
   **Maximum 3 phase-verification rounds per phase** — fixing task A can
   break task B and ping-pong forever; a 4th FAIL halts (`report.md`,
   trigger: `phase-stall`).
3. PASS → do this for **every** phase, the last one included: journal
   `[phase N] verified` (append the verifier's `probes:` and `mutation:`
   lines, and its `structure-note`, `freshness-note`, and `spec-concern`
   lines verbatim, if any); overwrite
   `handoff.md`
   (trigger: `phase-boundary`, `position:` = the phase's last task id), carrying forward every previous-handoff
   item that is still true — phase 1's flaky-test warning must survive
   into phase 3 — and copying any `freshness-note` lines into "Watch out
   for", so the flagged tasks' own implementers see the suspicion. A
   freshness-note never changes plan.md and never triggers a re-plan by
   itself: if the suspicion is real, the implementer hits it and the
   existing blocked/stall routes handle it; commit the boundary
   (`loopspace: phase <N> verified`) so the phase journal entry, fresh
   handoff, and the phase's probe file are checkpointed, not riding
   uncommitted into the next phase. The committed probes join the suite
   as a regression floor for later phases — but they are never evidence
   at the next boundary: each phase verifier derives its own, fresh.
   Then branch **only if a next phase exists** — git projects, create
   `loopspace/<slug>/phase-<N+1>` on that boundary commit, check it out,
   and update `current_branch` in state.md, so each completed phase's tip
   stays a named, verified pointer — and continue to the next phase. If
   this was the last phase, create no new branch: go to Final
   Verification below, and return to step 4 only when it passes.
4. Last phase, Final Verification passed → set `run_status: complete`,
   write the final journal entry,
   and (git projects) make a final commit on the current phase branch —
   message `loopspace: run complete — <slug>` — so `run_status: complete`
   and the last journal entry are checkpointed and the merge or PR below
   carries completed state, not `executing`. Then report totals to the
   human (tasks, retries, re-plans) and the harness/tier the run
   executed under (state.md fields; plus per-role models if the
   profile routed any), the final verification's `probes:` and
   `mutation:` lines (what the last independent check actually
   exercised), plus every `spec-concern` line from
   the journal, verbatim — the loop built what the spec said; whether the
   spec said the right thing is the human's question, and this is where
   they get to ask it. Mention `/loopnext`: when the human wants changes
   after using what was built, it turns that feedback and the journal's
   advisories into an amended spec and a delta plan for the next run.
   Git projects: the run is over, so
   this report is a human touchpoint again — offer the branch decision and
   perform whichever the human picks, never picking for them:
   - merge `current_branch` into `base_branch` as a regular merge commit
     (checkpoint history preserved; squashing is the human's own call
     outside the tool),
   - push the branch and open a PR against `base_branch`, or
   - leave the branch as-is.

## Final Verification

The last phase boundary asks whether that phase holds together. This asks
whether the *product* does — once, at the end, against the whole spec.
Run it when the last phase's boundary PASSes, before anything in step 4.

1. **Mechanical pre-check — you do this yourself, no dispatch.** It is
   file reading, so it costs nothing, and it never spends a verifier call
   on a run that is visibly incomplete:
   - every R-id in spec.md's `## Requirements` appears in at least one
     task's `covers:` line in plan.md;
   - every phase has a `[phase N] verified` entry in journal.md;
   - (git projects) no tracked file is modified. An untracked final probe
     file is expected and fine — the next round replaces it.
   A violation is not a FAIL — it is a gap in the run, and it is fixed
   before the verifier is dispatched. Uncovered R-ids are the stall
   policy tier 1 re-plan path (the plan never claimed them). A missing
   boundary is boundary debt: run that Phase Boundary now, then start
   this section over. A **modified tracked file** at this point is a dead
   verifier's leftover, not work: every task and every boundary committed
   on PASS, so nothing of yours is uncommitted here, and the one thing
   that edits tracked files without committing is a mutation spot-check
   whose session died before restoring. Restore it (`git checkout -- .`)
   and journal the correction. Only when the modification is
   demonstrably a task's own uncommitted work does it belong in a commit
   on the current phase branch instead.
2. Dispatch a **FINAL VERIFIER** (fresh, never an implementer, never a
   phase verifier from this run) — template E: cross-phase probes derived
   from the full spec before any test file is opened, full suite,
   cross-phase mutation spot-check, and a product-level completeness read
   of the whole spec against the tree. The dispatch carries spec.md
   verbatim, one line per completed phase, and the union of `covers:`
   R-ids. It derives only scenarios that cross phase boundaries: each
   phase's own probe file is already committed and running in the suite,
   so re-deriving inside a phase buys nothing.
3. FAIL → treat as a failed task on `offending-task` (it re-enters the
   per-task cycle with the findings, exactly as a phase FAIL does). The
   failing probe file stays in the tree as the executable half of the
   finding. **Maximum 3 final-verification rounds** — a 4th FAIL halts
   (`report.md`, trigger: `final-stall`). After a repair, re-run this
   section from step 1: a re-opened task can leave the tree dirty or
   re-open a phase.
4. PASS → journal `[final] verified` (append the verifier's `probes:` and
   `mutation:` lines, and its `spec-concern` lines verbatim, if any);
   commit (`loopspace: final verification passed`) so the probe file and
   the journal entry are checkpointed. Then go to step 4 of the Phase
   Boundary — the completion report.

## Context Threshold (the 30% rule)

Watch your own context consumption (system warnings, or the sheer length
of your conversation). When roughly 30% is consumed — do not push your
luck past it. Self-estimates are unreliable, so use a hard proxy too:
**if you cannot tell, hand off after 10 task cycles in one session**,
whichever comes first:

1. Finish the in-flight task cycle (never abandon a dispatched verifier).
2. Overwrite `handoff.md` (trigger: `context-threshold`, `position:` =
   the task id that cycle just finished) with everything
   the next session needs.
3. Update `state.md`, then end the turn telling the user exactly the
   harness profile's reset-and-resume commands (Claude Code: `/clear`,
   then `/loopresume`). This is typing, not judgment — say so.

## Rules

- Verifier verdicts are final. No re-litigating a FAIL in your own context.
  A contested finding is settled only by the next verifier's
  confirm/drop — never by you.
- Never mark a task done without a verifier PASS in the journal.
- Never modify spec.md. plan.md changes only through the re-plan path.
