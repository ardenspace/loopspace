---
name: loopresume
description: Use when a session starts in a project with an unfinished loopspace run (.loopspace/ exists), after /clear during a run, or when the user asks "where are we" or for the run's status.
---

# loopresume — Pick Up the Loop From Disk

The whole point of loopspace's disk-based state: a fresh session reading
only `.loopspace/` can continue exactly. This skill is that read path.

## Step 1 — Read state, in this order

1. `.loopspace/state.md` — run_status, current position, attempt counts.
   Missing while other `.loopspace/` files exist (pre-v0.3 run, or a crash
   before it was first written) → don't guess a run_status: infer the stage
   from `spec.md`/`plan.md` `status:` fields, report what you inferred, and
   recreate state.md to match before continuing.
2. `.loopspace/plan.md` — the task tree (skim: current phase in full,
   other phases by headers only — keep context light)
3. `.loopspace/spec.md` — Goals, Non-Goals, and the R-ids covered by the
   current phase only
4. `.loopspace/handoff.md` — the previous session's notes (may not exist
   on a crash; say so if missing)
5. `.loopspace/journal.md` — **tail only**: entries for the current task
   and current phase. Never read the whole journal.

## Step 2 — Validate before trusting

- Every file's `version:` is one you understand (currently `1`). Unknown
  version → stop and report; do not guess.
- `current_task` in state.md exists in plan.md.
- state.md has branch fields → the checked-out branch must equal
  `current_branch`; if it doesn't, check out `current_branch` before
  continuing — a fresh session starts wherever the human left the repo,
  and continuing on the wrong branch scatters checkpoints. One exception:
  if the checked-out branch is a *newer* phase branch than `current_branch`
  (e.g. `…/phase-3` checked out while state.md still says `…/phase-2`), a
  crash caught the run mid phase-hop — keep the newer branch and fix
  `current_branch` in state.md to match; never check out backwards. (No
  branch fields → non-git project → skip.)
- `harness:` in state.md names a profile other than the harness
  actually running this session → re-resolve per
  `../../harnesses/PROFILE-SPEC.md`, update `harness:` (and `tier:` if
  it changed), and journal the switch:
  `## [harness] switched <old> → <new> (tier <A|B|C> → <A|B|C>)`.
  Fields absent → pre-0.13 run: treat as claude-code / A and add the
  fields at the next state write.
- No task is `in_progress` with a journal PASS entry (a crash between
  verifier PASS and state update — if found, mark it done, journal the
  correction, continue).
- Corrupted/contradictory state you cannot mechanically reconcile → report
  precisely what disagrees and stop. Never guess a position.

## Step 3 — Report position

Always tell the user in 3 lines before doing anything:
current phase/task, attempts used, and run_status. If the user only asked
for status, stop here.

## Step 4 — Continue by run_status

- `executing` → invoke the looprun skill and re-enter the per-task
  cycle at `current_task`.
- `halted` → summarize `report.md` and its options; await the human's
  decision. Once they decide, hand over to the looprun skill's Halt-Resume
  procedure — never restart the loop on your own.
- `complete` → say so; if the human wants to change or extend what was
  built, suggest `/loopnext` — it turns usage feedback and the journal's
  advisories into the next run.
- `spec` → state.md has `run: N` with N≥2? An interrupted loopnext —
  suggest `/loopnext`; it resumes its own amendment draft. Otherwise:
  `spec.md` approved? suggest `/loopplan`. Still draft or absent?
  suggest `/loopspec` — it resumes from the existing draft and interview
  answers already captured in it.
- `planning` → state.md has `run: N` with N≥2? suggest `/loopnext` (its
  delta-plan stage). Otherwise: `plan.md` approved (crash before state
  was rewritten)? suggest `/looprun`. Otherwise suggest `/loopplan` to
  finish the draft.
