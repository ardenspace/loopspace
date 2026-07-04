# Branch Strategy & Approval Checkpoints Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every loopspace run its own branch stack (base branch at spec approval, one branch per phase) and commit spec/plan at their approval gates, per `docs/superpowers/specs/2026-07-04-branch-strategy-design.md`.

**Architecture:** loopspace is a plugin of markdown skill files — the "implementation" is precise prose in 4 SKILL.md files plus the state-format contract doc. Branch state lives in three new state.md fields; their absence is the non-git off-switch every skill honors. No code, no test suite: each task's verification step is a mechanical grep against expected output, and the final task cross-checks field/branch/message names across all touched files.

**Tech Stack:** Markdown skill files (Claude Code plugin), git.

## Global Constraints

Copied verbatim from the spec — every task must use these exact strings:

- state.md field names: `base_branch`, `run_branch`, `current_branch`
- report.md field names: `current_branch`, `last_verified_phase`
- Branch names: `loopspace/<slug>` (base), `loopspace/<slug>/phase-<N>` (phases); `<slug>` derives from the spec title, kebab-case
- Commit messages: `loopspace: spec approved — <slug>`, `loopspace: plan approved — <slug>` (em dash, not hyphen — matches existing `loopspace: task <id> — <title>` convention)
- Non-git projects: branch fields absent from state.md, and that absence is the signal to skip ALL branch logic (no separate flag)
- Approval commits stage only `.loopspace/` files — never sweep unrelated working-tree changes
- Merge at run-complete = regular merge commit (no squash); mid-run the loop never pushes and never merges
- All user-facing content in English

---

### Task 1: state-format.md — branch fields contract

**Files:**
- Modify: `docs/state-format.md` (state.md section ~lines 81-124, report.md section ~lines 185-207)

**Interfaces:**
- Produces: the three state.md branch fields and two report.md branch lines that Tasks 2-5 reference by exact name. This doc is the contract; downstream SKILL.md files must match it verbatim.

- [ ] **Step 1: Add branch fields to both state.md forms**

In `docs/state-format.md`, replace the header-only block:

```markdown
Before plan approval, state.md is header-only:

```markdown
# Loopspace State
version: 1
run_status: spec            # spec | planning | executing | halted | complete
```
```

with:

```markdown
Before plan approval, state.md is header-only. The three branch fields
appear at spec approval in git projects; before approval, and in non-git
projects, they are absent — and their absence is the signal for every
skill to skip all branch logic:

```markdown
# Loopspace State
version: 1
run_status: spec            # spec | planning | executing | halted | complete
base_branch: main                 # branch the run forked from; merge-back target
run_branch: loopspace/<slug>      # per-run base branch, created at spec approval
current_branch: loopspace/<slug>  # where work happens now; looprun moves it to
                                  # loopspace/<slug>/phase-<N> as phases open
```
```

And in the full form block (starts `# Loopspace State` / `run_status: executing`), insert the same three lines directly after `current_task: 2.3`:

```markdown
current_task: 2.3
base_branch: main
run_branch: loopspace/feat-x
current_branch: loopspace/feat-x/phase-2
```

- [ ] **Step 2: Add branch lines to the report.md format**

In the report.md section, replace:

```markdown
# Halt Report
version: 1
written: <YYYY-MM-DD>
trigger: spec-gap           # task-stall | phase-stall | spec-gap | external-blocker
```

with:

```markdown
# Halt Report
version: 1
written: <YYYY-MM-DD>
trigger: spec-gap           # task-stall | phase-stall | spec-gap | external-blocker
current_branch: loopspace/<slug>/phase-3   # git projects only
last_verified_phase: loopspace/<slug>/phase-2   # newest phase branch whose
                            # boundary verification passed, or "none" —
                            # lets the human merge verified work only
```

- [ ] **Step 3: Verify**

Run: `grep -c "base_branch" docs/state-format.md && grep -c "last_verified_phase" docs/state-format.md`
Expected: `2` then `2` (or higher; both non-zero)

- [ ] **Step 4: Commit**

```bash
git add docs/state-format.md
git commit -m "feat: branch fields in state.md and report.md contracts"
```

---

### Task 2: loopspec — base branch creation + spec approval commit

**Files:**
- Modify: `skills/loopspec/SKILL.md` (Step 5 — Human Approval Gate, ~lines 109-117)

**Interfaces:**
- Consumes: field names and branch naming from Task 1.
- Produces: `loopspace/<slug>` branch semantics and the `loopspace: spec approved — <slug>` commit that loopplan (Task 3) builds on.

- [ ] **Step 1: Rewrite the approval-gate paragraph**

In `skills/loopspec/SKILL.md`, replace:

```markdown
On approval: set `status: approved`, fill the `## Approval` section with
today's date and the open non-blocking findings, and suggest running
`/loopplan`.
```

with:

```markdown
On approval:

1. Set `status: approved`, fill the `## Approval` section with today's
   date and the open non-blocking findings.
2. **Branch + checkpoint (git repositories only):** derive `<slug>` from
   the spec title (kebab-case). If `loopspace/<slug>` already exists — a
   stale earlier run — ask the human whether to delete it, reuse it, or
   pick a different slug; never decide alone (you are at a human
   touchpoint, use it). Create and check out `loopspace/<slug>` from the
   currently checked-out branch, then record in state.md: `base_branch:`
   (the branch you forked from), `run_branch:` and `current_branch:`
   (both `loopspace/<slug>`). Commit with **only** the loopspace files
   staged — `git add .loopspace/spec.md .loopspace/state.md` — message
   `loopspace: spec approved — <slug>`. Unrelated working-tree changes
   are never swept into an approval commit. In a non-git project, skip
   this step entirely: the absent branch fields in state.md are how every
   downstream skill knows to skip branch logic too.
3. Suggest running `/loopplan`.
```

- [ ] **Step 2: Verify**

Run: `grep -n "spec approved — <slug>" skills/loopspec/SKILL.md && grep -n "base_branch" skills/loopspec/SKILL.md`
Expected: one match each

- [ ] **Step 3: Commit**

```bash
git add skills/loopspec/SKILL.md
git commit -m "feat: loopspec creates run branch and commits approved spec"
```

---

### Task 3: loopplan — branch sync on entry + plan approval commit

**Files:**
- Modify: `skills/loopplan/SKILL.md` (precondition paragraph ~line 12, Step 3 approval list ~lines 69-78)

**Interfaces:**
- Consumes: `run_branch`/`current_branch` set by loopspec (Task 2); the state.md full form with branch fields (Task 1).
- Produces: the `loopspace: plan approved — <slug>` commit; state.md full form carrying branch fields into looprun (Task 4).

- [ ] **Step 1: Add branch sync to the entry precondition**

In `skills/loopplan/SKILL.md`, replace:

```markdown
Precondition: `.loopspace/spec.md` exists with `status: approved`. If not,
stop and suggest `/loopspec`.
```

with:

```markdown
Precondition: `.loopspace/spec.md` exists with `status: approved`. If not,
stop and suggest `/loopspec`. If state.md records branch fields (git
projects), make sure `current_branch` is checked out before touching any
file — a fresh session may start wherever the human left the repo; check
it out if it isn't.
```

- [ ] **Step 2: Extend the approval list**

Replace the four-item approval list:

```markdown
1. Set `plan.md` `status: approved`.
2. Rewrite `.loopspace/state.md` in its full form (state.md section of the
   format doc): `run_status: executing`, `current_phase: 1`,
   `current_task:` the first task's id, every task `pending` with
   `attempts: 0`. Seed `## Project Facts` (test command, build/run command,
   stack) from the spec's Engineer Lens — "none yet" is a valid value for a
   greenfield project.
3. Initialize empty `.loopspace/journal.md` (header + version line).
4. Suggest running `/looprun`.
```

with:

```markdown
1. Set `plan.md` `status: approved`.
2. Rewrite `.loopspace/state.md` in its full form (state.md section of the
   format doc): `run_status: executing`, `current_phase: 1`,
   `current_task:` the first task's id, every task `pending` with
   `attempts: 0`, and the three branch fields carried over unchanged (git
   projects). Seed `## Project Facts` (test command, build/run command,
   stack) from the spec's Engineer Lens — "none yet" is a valid value for a
   greenfield project.
3. Initialize empty `.loopspace/journal.md` (header + version line).
4. **Checkpoint (git repositories only):** commit with only the loopspace
   files staged — `git add .loopspace/plan.md .loopspace/state.md
   .loopspace/journal.md` — message `loopspace: plan approved — <slug>`,
   so the loop's full ready-to-run state is checkpointed on the run branch
   before autonomy starts.
5. Suggest running `/looprun`.
```

- [ ] **Step 3: Verify**

Run: `grep -n "plan approved — <slug>" skills/loopplan/SKILL.md && grep -n "current_branch" skills/loopplan/SKILL.md`
Expected: one match each

- [ ] **Step 4: Commit**

```bash
git add skills/loopplan/SKILL.md
git commit -m "feat: loopplan syncs run branch and commits approved plan"
```

---

### Task 4: looprun — phase branches, completion menu, halt branch report

**Files:**
- Modify: `skills/looprun/SKILL.md` (Orchestrator Contract ~lines 16-34, Stall Policy closing line ~line 124, Phase Boundary ~lines 141-158)

**Interfaces:**
- Consumes: branch fields from state.md (Tasks 1-3); `last_verified_phase` report.md line (Task 1).
- Produces: `loopspace/<slug>/phase-<N>` branch lifecycle that loopresume (Task 5) validates against.

- [ ] **Step 1: Amend the git-checkpoint bullet and add a branch-discipline bullet**

In `skills/looprun/SKILL.md`, replace:

```markdown
- **Git checkpoint:** if the project is a git repository, commit after every
  verifier PASS — message `loopspace: task <id> — <title>` — so one bad task
  can always be rolled back to the last verified state. Never push.
```

with:

```markdown
- **Git checkpoint:** if the project is a git repository, commit after every
  verifier PASS — message `loopspace: task <id> — <title>` — so one bad task
  can always be rolled back to the last verified state. Never push or merge
  mid-run: the only moment either can happen is the run-complete report, on
  an explicit human choice.
- **Branch discipline:** state.md's branch fields say where work happens.
  On entry (git projects): check out `current_branch` if it isn't already
  checked out. If `current_branch` still equals `run_branch` — no phase
  branch yet — create `loopspace/<slug>/phase-1` from it, check it out, and
  update `current_branch` in state.md. Task commits, rollbacks, and burst
  resets all happen on the current phase branch. No branch fields in
  state.md means a non-git project: skip all branch logic.
```

- [ ] **Step 2: Add branch lines to the halt rule**

Replace:

```markdown
Every halt, whatever the trigger, also sets the offending task's status to
`failed` in state.md.
```

with:

```markdown
Every halt, whatever the trigger, also sets the offending task's status to
`failed` in state.md. In a git repository, report.md additionally records
`current_branch:` and `last_verified_phase:` (the newest phase branch whose
boundary verification passed, or `none`) so the human can choose to merge
only verified work.
```

- [ ] **Step 3: Add the phase-branch hop to the Phase Boundary**

In Phase Boundary step 3, replace:

```markdown
   phase 1's flaky-test warning must survive
   into phase 3; commit the boundary (`loopspace: phase <N> verified`) so
   the phase journal entry and fresh handoff are checkpointed, not riding
   uncommitted into the next phase; continue to the next phase.
```

with:

```markdown
   phase 1's flaky-test warning must survive
   into phase 3; commit the boundary (`loopspace: phase <N> verified`) so
   the phase journal entry and fresh handoff are checkpointed, not riding
   uncommitted into the next phase. Git projects: create
   `loopspace/<slug>/phase-<N+1>` on that boundary commit, check it out,
   and update `current_branch` in state.md — every phase branch tip stays
   a named, verified pointer. Continue to the next phase.
```

- [ ] **Step 4: Add the completion branch menu**

In Phase Boundary step 4, replace:

```markdown
4. Last phase → `run_status: complete`, final journal entry, report
   totals to the human (tasks, retries, re-plans).
```

with:

```markdown
4. Last phase → `run_status: complete`, final journal entry, report
   totals to the human (tasks, retries, re-plans). Git projects: the
   run is over, so this report is a human touchpoint again — offer the
   branch decision and perform whichever the human picks, never picking
   for them:
   - merge `current_branch` into `base_branch` as a regular merge commit
     (checkpoint history preserved; squashing is the human's own call
     outside the tool),
   - push the branch and open a PR against `base_branch`, or
   - leave the branch as-is.
```

- [ ] **Step 5: Verify**

Run: `grep -c "current_branch" skills/looprun/SKILL.md && grep -n "phase-<N+1>" skills/looprun/SKILL.md && grep -n "Never push or merge" skills/looprun/SKILL.md`
Expected: count ≥ 4, then one match each

- [ ] **Step 6: Commit**

```bash
git add skills/looprun/SKILL.md
git commit -m "feat: looprun phase branches, completion merge menu, halt branch report"
```

---

### Task 5: loopresume — branch validation on resume

**Files:**
- Modify: `skills/loopresume/SKILL.md` (Step 2 — Validate before trusting, ~lines 27-36)

**Interfaces:**
- Consumes: `current_branch` semantics from Tasks 1 and 4.

- [ ] **Step 1: Add the branch check to Step 2**

In `skills/loopresume/SKILL.md`, in "Step 2 — Validate before trusting", insert a new bullet directly after the `current_task` bullet:

```markdown
- `current_task` in state.md exists in plan.md.
- state.md has branch fields → the checked-out branch must equal
  `current_branch`; if it doesn't, check out `current_branch` before
  continuing — a fresh session starts wherever the human left the repo,
  and continuing on the wrong branch scatters checkpoints. (No branch
  fields → non-git project → skip.)
```

(The first line shown is the existing anchor bullet — keep it, add the new bullet after it.)

- [ ] **Step 2: Verify**

Run: `grep -n "current_branch" skills/loopresume/SKILL.md`
Expected: ≥ 2 matches, all inside Step 2's new bullet

- [ ] **Step 3: Commit**

```bash
git add skills/loopresume/SKILL.md
git commit -m "feat: loopresume validates and restores the run branch"
```

---

### Task 6: README, CHANGELOG, version bump, cross-file consistency check

**Files:**
- Modify: `README.md` (Git checkpoints bullet, ~lines 101-103)
- Modify: `CHANGELOG.md` (new 0.6.0 section at top, after `# Changelog`)
- Modify: `.claude-plugin/plugin.json` (`"version": "0.5.0"` → `"0.6.0"`)

**Interfaces:**
- Consumes: everything Tasks 1-5 produced; this task is also the whole-feature consistency gate.

- [ ] **Step 1: Expand the README git-checkpoints bullet**

In `README.md`, replace:

```markdown
- **Git checkpoints.** In a git repository, the orchestrator commits after every verified
  task, so one bad task can always be rolled back to the last verified state instead of
  poisoning everything after it.
```

with:

```markdown
- **Git checkpoints and branch isolation.** In a git repository the whole run lives on
  its own branch stack: spec approval creates `loopspace/<slug>` (spec and plan approvals
  are committed there), and execution stacks one branch per phase
  (`loopspace/<slug>/phase-N`), each tip a named, verified pointer. The orchestrator
  commits after every verified task, so one bad task can always be rolled back to the
  last verified state instead of poisoning everything after it. Inside the loop a
  verifier PASS is the merge authority; the branch you started from is touched only at
  the run-complete report, where the human chooses: merge, open a PR, or leave the
  branch. A halt report names the last verified phase branch, so partial merges of
  verified work are one command.
```

- [ ] **Step 2: Add the 0.6.0 changelog entry**

In `CHANGELOG.md`, insert directly after the `# Changelog` line (before `## 0.5.0`):

```markdown
## 0.6.0 — 2026-07-04

Branch strategy + approval checkpoints, from the first collaborative-repo
dogfood concern: the loop used to commit straight onto whatever branch was
checked out, and approved specs/plans sat uncommitted in the working tree.

- **Approval commits.** loopspec and loopplan now commit the artifact the
  human just approved (`loopspace: spec approved — <slug>`, `loopspace:
  plan approved — <slug>`), staging only `.loopspace/` files — the loop's
  contract is checkpointed before the loop starts.
- **Stacked phase branches.** Spec approval creates `loopspace/<slug>`
  from the current branch; looprun stacks `loopspace/<slug>/phase-N` per
  phase, so every phase tip is a named, verified pointer and the start
  branch never sees unverified work. Inside the loop a verifier PASS is
  the merge authority — no per-task merge questions — and the human merge
  decision lives at the touchpoints that already exist: the run-complete
  report offers merge / PR / leave-as-is, and a halt report names the
  last verified phase branch for partial merges. state.md gains
  `base_branch` / `run_branch` / `current_branch`; their absence (non-git
  project) switches all branch logic off. Mid-run the loop still never
  pushes and now explicitly never merges.
```

- [ ] **Step 3: Bump the plugin version**

In `.claude-plugin/plugin.json`, change `"version": "0.5.0"` to `"version": "0.6.0"`.

- [ ] **Step 4: Whole-feature consistency check**

Run: `grep -rn "base_branch\|run_branch\|last_verified_phase" skills/ docs/state-format.md README.md | grep -v "current_branch"`
Expected: every occurrence uses exactly the Global Constraints spellings; no variants like `baseBranch`, `run-branch`, `last_verified_phase_branch`

Run: `grep -rn "loopspace/<slug>" skills/ docs/state-format.md README.md CHANGELOG.md`
Expected: matches in all five locations; phase form always `loopspace/<slug>/phase-<N>` or `phase-N` (README/CHANGELOG prose), never `phase_<N>`

Run: `python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])"`
Expected: `0.6.0`

- [ ] **Step 5: Commit**

```bash
git add README.md CHANGELOG.md .claude-plugin/plugin.json
git commit -m "feat: branch strategy + approval checkpoints (0.6.0)"
```
