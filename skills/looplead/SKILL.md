---
name: looplead
description: Use when a loopspace spec with acceptance groups has been approved and the run should execute in lead mode — one autonomous lead agent under machine-enforced gates, no plan.md. Also after a lead-mode halt the human has resolved.
---

# looplead — The Lead Loop (thin harness)

Principle: **Give autonomy. Enforce invariants.** The harness does not
conduct your process — no task tree, no dispatch choreography, no per-task
verdict rules. It enforces outcome boundaries only, and enforces them
mechanically: checkpoint gates you cannot skip, a completion state you
cannot write, budgets, and crash-safe state on disk. Everything between
those boundaries is yours.

Preconditions: `.loopspace/spec.md` `status: approved` and carrying an
`## Acceptance Groups` section; `.loopspace/state.md` exists; the project
is a git repository (gates make checkpoint commits and restore mutations —
without git, lead mode refuses to run). `plan.md` does not exist in lead
mode and is never read. Missing pieces → stop and name them (`/loopspec`
writes specs; the human adds acceptance groups before approval). File
formats: `../../docs/state-format.md`. `run_status: halted` → Halt-Resume
below. `complete` → say so, stop.

## Arming (first entry only — run_status: spec, mode absent)

The human touchpoint of lead mode — the analog of loopplan's approval.
Never arm silently:

1. Mechanical group check: every R-id in `## Requirements` appears in
   exactly one `## Acceptance Groups` group. Gaps or overlaps → report
   them and stop; the groups are part of the approved contract, so the
   human fixes the spec (or re-runs `/loopspec`), not you.
2. Ask the human for the budget — one question, two numbers: the
   subagent-dispatch cap for the whole run, and the wall-clock cap in
   hours. (Harness autonomy guidance never overrides this: arming without
   a human-stated budget is forbidden.)
3. Write to state.md, preserving every existing header field: `mode: lead`,
   `budget_dispatches: <N>`, `budget_wall_hours: <H>`. Seed `## Project
   Facts` from the spec's Engineer Lens ("none yet" where unknown).
4. Resolve the gate script's absolute path — `scripts/gate.sh`, sibling of
   `skills/` in this skill's base directory — and record it as a fact:
   `- gate: sh <abs-path>/scripts/gate.sh`. Fresh sessions read it from
   there instead of re-resolving.
5. Set `run_status: executing`; commit only the loopspace files:
   `git add .loopspace && git commit -m "loopspace: lead mode armed — <slug>"`.

## Your autonomy (the harness has no opinion)

- **Decomposition.** First action of every session: journal your current
  plan — `## [lead] plan` followed by your task list, ordering, and what
  changed since the last plan entry. No one approves it; it exists so the
  trajectory is observable and a fresh session can pick up your intent.
- **Dispatch.** Use subagents or don't — implement directly, dispatch an
  implementer per task, run panels, whatever serves the work (dispatch
  mechanics per the harness profile in `../../harnesses/`). Journal every
  dispatch as a `## [dispatch] <role/model> — <what>` line: that line is
  the budget accounting. Stay under `budget_dispatches`; when the count
  gets close, prefer direct work.
- **Verification style per task.** TDD, self-review, spot tests — your
  call. The harness only checks outcomes, at the gates.

## Your obligations (the invariants — these are mechanical, not advice)

1. **Gate every acceptance group.** When you believe a group `G<N>` is
   done, run the gate from the project root:
   `sh <gate-path> "$PWD" G<N>` (the path is in Project Facts).
   - exit 0 (PASS): the gate committed a checkpoint; continue.
   - exit 1 (FAIL): findings are on stdout and in `.loopspace/gates.md`.
     Repair, then re-gate the same group. Findings are verdicts — never
     argue with them in your own context; the next gate is the appeal.
   - exit 2: the run is halted (LOOPSPACE_GATE_MAX_FAIL consecutive FAILs, default 3) — report.md exists.
     End the turn immediately; a human decides.
   - exit 3: gate error — the machinery could not deliver a verdict; never
     a FAIL. Read the script's stderr: a verifier timeout or API outage is
     transient — retry once after a pause. Anything else it names (unknown
     group id, wrong run_status, a commit the repo refused) is
     deterministic — fix what it names if it is yours to fix, otherwise
     journal it and end the turn so the supervisor/human sees it.
   A group without a ledger PASS does not exist as progress, whatever
   your own tests say.
2. **Never write the machine's files.** `.loopspace/gates.md` is
   gate-script-only. `run_status: complete` is written only by the final
   gate — declaring done yourself is the one forbidden sentence. spec.md
   is frozen. Everything else in `.loopspace/` is yours to maintain, and
   state.md's header fields must survive your rewrites.
3. **Finish through the final gate.** When every group has a PASS: commit
   your remaining work, then run `sh <gate-path> "$PWD" --final`. It
   re-checks coverage mechanically, sweeps all acceptance criteria with
   fresh probes, and flips `run_status: complete` itself. Then report
   totals honestly (groups gated, FAILs repaired, dispatches used vs
   budget) and offer the branch decision (merge / PR / leave) exactly as
   a conducted run's completion does — the human picks, never you.
4. **Context threshold (the 30% rule).** Watch your context consumption;
   if you cannot tell, hand off after 8 substantial working stretches.
   Overwrite `handoff.md` (trigger: `context-threshold`,
   `position: gate:<newest-PASS-group or none>`) with what the next
   session needs, update state.md, journal where you stopped, and end the
   turn naming the harness profile's reset-and-resume commands. Never
   push past the threshold to "just finish" a group.
5. **Blocked is a halt, not an improvisation.** A spec contradiction or
   gap, or an external blocker (credentials, dead service, broken
   toolchain) → write `report.md` (trigger `spec-gap` /
   `external-blocker`, format in state-format.md), set
   `run_status: halted`, commit `.loopspace`, end the turn. The spec is
   the human's contract — never patch around it.

## Halt-Resume (run_status: halted)

1. Summarize `report.md`; ask the human which option they chose (skip if
   they already said).
2. Journal `## [halt] resolved — <decision, one line>`.
3. Delete `report.md`, set `run_status: executing`, commit `.loopspace`.
4. Re-enter the loop. A `gate-stall` halt re-enters at repairing that
   gate's findings; the gate's FAIL count is NOT reset by the resume —
   the next FAIL halts again — so repair before re-gating, and if the
   human's decision was "the spec is wrong here", that is `/loopnext`,
   not a patch.

## Rules

- Gate verdicts are final. The ledger outranks your tests, your memory,
  and your reading of the spec.
- Journal continuously — plans, dispatches, discoveries, repairs. In lead
  mode the journal is your notebook; only gate entries live elsewhere
  (gates.md, machine-written).
- Never modify spec.md. Never write gates.md. Never write
  `run_status: complete`.
