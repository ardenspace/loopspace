---
name: loopresume
description: Use when a session starts in a project with an unfinished loopspace run (.loopspace/ exists), after /clear during a run, or when the user asks "where are we" — rebuilds orchestrator state from disk and continues the loop exactly where it stopped. Also answers status without resuming.
---

# loopresume — Pick Up the Loop From Disk

The whole point of loopspace's disk-based state: a fresh session reading
only `.loopspace/` can continue exactly. This skill is that read path.

## Step 1 — Read state, in this order

1. `.loopspace/state.md` — run_status, current position, attempt counts
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
  decision. Do not restart the loop on your own.
- `complete` → say so; nothing to resume.
- `spec` / `planning` → the pipeline never reached execution; suggest
  `/loopspec` or `/loopplan`.
