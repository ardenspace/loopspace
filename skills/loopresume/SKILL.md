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
   other phases by headers only — keep context light). **Lead mode**
   (state.md has `mode: lead`): there is no plan.md — read
   `.loopspace/gates.md` instead (tail: the last few gate entries; which
   groups have a `verdict: PASS`).
3. `.loopspace/spec.md` — Goals, Non-Goals, and the R-ids covered by the
   current phase only
4. `.loopspace/handoff.md` — the previous session's notes (may not exist
   on a crash; say so if missing. May also be *stale*: a session that
   died before its handoff step — crash, backend timeout — leaves the
   previous boundary's handoff behind. Step 2 checks this; don't act on
   its contents before that check.)
5. `.loopspace/journal.md` — **tail only**: entries for the current task
   and current phase. Never read the whole journal.

## Step 2 — Validate before trusting

- Every file's `version:` is one you understand (currently `1`). Unknown
  version → stop and report; do not guess.
- `current_task` in state.md exists in plan.md. (Lead mode: skip — there
  is no task table; position lives in the journal's `## [lead]` entries
  and gates.md.)
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
- **handoff.md freshness.** If handoff.md has a `position:` field, check
  the journal for verifier-PASS or `[phase N] verified` entries for any
  task *after* that position (plan.md order). Found any → the handoff is
  **stale**: the session(s) after it died before writing their own.
  Announce it ("handoff.md is stale — written at <position>, run is now
  at <current>"), take position exclusively from state.md + the journal
  tail, and ignore the stale handoff's "Where we are" / "Next session
  must know" position claims. Its "Watch out for" items may still be
  true — read them as historical warnings, nothing more. No `position:`
  field (pre-0.15.2 handoff) → freshness is unknown: prefer state.md +
  journal over the handoff wherever they disagree.
- **Lead-mode handoff freshness.** `position: gate:<G>` → stale if
  gates.md holds a `verdict: PASS` for any gate entered after that
  group's own PASS line (`gate:none` → stale if any PASS exists). Stale →
  same rule as above: trust gates.md + the journal tail, read the
  handoff's warnings as history.
- **Lead mode, dangling gate.** gates.md ends with an `opened` line that has
  no verdict/error line after it, and tracked files are dirty → a session
  died mid-gate: the modifications are a dead verifier's leftovers, not
  lead work (the candidate commit made HEAD exactly the lead's tree).
  Restore tracked files (`git checkout -- .`), journal
  `## [lead] dead gate <id> — verifier leftovers discarded`, and resume.
- Corrupted/contradictory state you cannot mechanically reconcile → report
  precisely what disagrees and stop. Never guess a position.

## Step 3 — Report position

Always tell the user in 3 lines before doing anything:
current phase/task, attempts used, and run_status. If the user only asked
for status, stop here.

## Step 4 — Continue by run_status

- `executing` → invoke the looprun skill and re-enter the per-task cycle
  at `current_task`. Lead mode (`mode: lead` in state.md) → invoke the
  looplead skill instead; it re-plans from its own journal entries.
- `halted` → summarize `report.md` and its options; await the human's
  decision. Once they decide, hand over to the looprun skill's Halt-Resume
  procedure (lead mode: the looplead skill's) — never restart the loop on
  your own.
- `complete` → say so; if the human wants to change or extend what was
  built, suggest `/loopnext` — it turns usage feedback and the journal's
  advisories into the next run.
- `spec` → state.md has `run: N` with N≥2? An interrupted loopnext —
  suggest `/loopnext`; it resumes its own amendment draft. Otherwise:
  `spec.md` approved? suggest `/loopplan` — or `/looplead` when it carries
  an `## Acceptance Groups` section (a lead-intent spec whose arming never
  ran). Still draft or absent? suggest `/loopspec` — it resumes from the
  existing draft and interview answers already captured in it.
- `planning` → state.md has `run: N` with N≥2? suggest `/loopnext` (its
  delta-plan stage). Otherwise: `plan.md` approved (crash before state
  was rewritten)? suggest `/looprun`. Otherwise suggest `/loopplan` to
  finish the draft.
