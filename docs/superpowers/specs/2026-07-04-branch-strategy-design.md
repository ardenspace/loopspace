# loopspace — Branch Strategy & Approval Checkpoints

**Date:** 2026-07-04
**Status:** Approved design, pre-implementation
**Builds on:** 2026-07-03-loopspace-plugin-design.md (v0.5.0 behavior)

## Problem

Dogfooding v0.5.0 surfaced two gaps:

1. **Approval artifacts are never committed.** `loopspec` and `loopplan` flip
   `status: approved` but leave the approved spec/plan uncommitted in the working
   tree. The loop starts with its own contract un-checkpointed.
2. **The loop runs directly on whatever branch is checked out.** `looprun` makes
   task checkpoint commits but knows nothing about branches — on a typical project
   that means committing straight to `main`. Safe enough solo; dangerous on any
   collaborative repo.

The constraint that shapes the fix: looprun's human touchpoints are exactly
{run complete, halt, context handoff}. A per-task "merge to main?" question would
break the autonomous-loop premise. Resolution: **inside the loop, a verifier PASS
is the merge authority; the human merge decision moves to the run-complete/halt
touchpoints that already exist.**

## Branch Model

Stacked phase branches under a per-run base branch:

```
(start branch, e.g. main)
  └→ loopspace/<slug>/run              ← created at loopspec approval
       ├─ "loopspace: spec approved — <slug>"
       ├─ "loopspace: plan approved — <slug>"     ← at loopplan approval
       └→ loopspace/<slug>/phase-1     ← created when looprun first enters
            ├─ task checkpoint commits (unchanged)
            ├─ "loopspace: phase 1 verified"      ← boundary commit, last on this branch
            └→ loopspace/<slug>/phase-2           ← created right after the boundary commit
                 └─ ...
```

- `<slug>` derives from the spec title (kebab-case).
- Branch from the **currently checked-out branch**, whatever it is; record it as
  the merge-back target. No assumption that the start branch is `main`.
- Phase branch N+1 is created on top of phase N's boundary commit, so each phase
  branch tip is a verified, named pointer. On a mid-run halt this gives the human
  a "merge only up to the last verified phase" option by branch name, and leaves
  the door open to per-phase PRs on collaborative repos later.
- Execution stays strictly sequential; this is history organization plus `main`
  protection, not parallelism.

## Component Changes

### loopspec

- On approval: create `loopspace/<slug>/run` from the current branch, then commit
  **only** `.loopspace/` files (`spec.md` plus `state.md`, which gains the
  branch fields at the same moment — never sweep unrelated working-tree
  changes). Message: `loopspace: spec approved — <slug>`.
- Branch-name collision (stale `loopspace/<slug>/*` branches from an earlier
  run): detect before creating and ask the human — spec stage is interactive,
  the human is present.
- A spec that gets abandoned costs one branch deletion; the start branch never
  sees it.

### loopplan

- On approval: commit **only** `.loopspace/` files (`plan.md`, the rewritten
  `state.md`, the initialized `journal.md`) on the run base branch, so the
  full ready-to-run state is checkpointed before autonomy starts.
  Message: `loopspace: plan approved — <slug>`.

### state.md (state-format.md update)

Three new fields:

| Field | Meaning |
|---|---|
| `base_branch` | Branch the run forked from; merge-back target |
| `run_branch` | `loopspace/<slug>/run` |
| `current_branch` | Branch work is happening on now |

state.md is created by loopspec, which sets all three at approval
(`current_branch` starts equal to `run_branch`). In a non-git project all three
are absent, which is also the signal for every other skill to skip branch logic.

### looprun

- **Entry:** if `current_branch` still equals `run_branch` (no phase branch
  yet), create `loopspace/<slug>/phase-1` from it and update `current_branch`.
- **Phase boundary:** phase verification PASS → boundary commit (existing) →
  create and switch to the next phase branch → update `current_branch` in
  state.md. Handoff/journal logic unchanged.
- **Run complete:** the final report offers three options — merge into
  `base_branch`, open a PR, or leave the branch as-is — and performs the chosen
  one. Merge means a regular merge commit (checkpoint history preserved);
  squashing is the human's own call outside the tool. This is already a human
  touchpoint, so the no-mid-run-decisions premise holds.
- **Halt:** report.md additionally names the current branch and the **last
  verified phase branch**, enabling a partial merge of verified work.
- Rollback (`git checkout -- .` + `git clean -fd`), diversity burst, and all
  other git logic operate within the current branch — no change.
- Never push or merge mid-run; the only moment either happens is the
  run-complete report, on an explicit human choice.

### loopresume

- On session resume, compare the checked-out branch against `current_branch`
  in state.md; if they differ, check out `current_branch` before continuing.

## Edge Cases

- **Not a git repository:** all branch logic is skipped, same conditional that
  already guards checkpoint commits. Nothing else changes.
- **Start branch is not main:** handled by design — `base_branch` records
  whatever was checked out.
- **Dirty working tree at approval time:** unrelated uncommitted changes are
  not safe to carry into a run — the loop's rollbacks and resets assume every
  change in the tree belongs to the run (a reset can destroy a carried-over
  file; a task commit can sweep one in). So before creating the branch,
  loopspec tells the human and asks them to commit, stash, or discard the
  unrelated changes first. Approval commits still stage only their own
  `.loopspace/` files.

## Non-Goals

- Parallel phase/task execution across branches or worktrees (still deferred;
  the naming scheme should not preclude it).
- Auto-merge to `base_branch` without a human choice — rejected: the moment work
  lands on the shared branch deserves a human eye, and collaborative repos need
  the PR path.
- Per-task branches. Sequential execution makes them ceremony over a phase
  branch; revisit only if worktree parallelism lands.
