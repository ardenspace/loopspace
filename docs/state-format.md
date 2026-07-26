# .loopspace/ State File Formats (version 1)

All loopspace state lives in `.loopspace/` at the target project root.
Design criterion: a fresh session reading only these files can continue the
run exactly. Formats are line-oriented so they can be parsed with grep/sed.

Every file's first body line is `version: 1`. Consumers must check it and
refuse to guess on unknown versions.

## spec.md — written by loopspec, frozen after approval; amended between runs by loopnext

```markdown
# Spec: <project name>
version: 1                  # file-format version (this document's axis)
status: approved            # draft | approved
spec_version: 2             # content version; absent = 1. Bumped only by
                            # loopnext, between runs — never during one.

## Overview
<2-4 sentences>

## Goals
- ...

## Non-Goals
- ...

## Company Lens
<timeline, cost bounds, MVP scope>

## User Lens
<who needs this, convenience, adoption>

## Engineer Lens
<security requirements (top priority), error/exception handling, testing
strategy, over-engineering boundaries>

## Designer Lens
<UI/UX guidance — or the single line "Not applicable: no UI surface.">

## Requirements
- R1: <requirement, testable phrasing>
- R2: ...

## Approval
Approved by human on <YYYY-MM-DD>. Open non-blocking issues at approval:
- <finding or "none">
```

Amendment rules (loopnext only — the spec is still frozen *within* a run):

- Requirements are edited **in place**; the Requirements section is always
  the current truth, because looprun excerpts it by R-id into dispatches.
- A revised requirement keeps its R-id and carries the marker
  `(revised in vN)` — the **latest marker only**; full history lives in
  the Amendment Log, markers never accumulate.
- A dropped requirement keeps its line, prefixed `[dropped in vN]` —
  numbering holes stay explained, old journal references stay resolvable.
  Dropped R-ids are never reused.
- New requirements continue the numbering and carry an `(added in vN)`
  marker — `R8: … (added in vN)`; the latest-marker-only rule applies to
  it too.
- Lens sections are updated in place only where the delta touches them.
- The `## Amendment Log` section is append-only:

```markdown
## Amendment Log

### v2 — <YYYY-MM-DD>, approved by human
- R8 added: <one-line rationale> (origin: human feedback)
- R3 revised: <one-line rationale> (origin: spec-concern [2.4])
- R5 dropped: <one-line rationale> (origin: structure-note phase 2)
```

While drafting (before human approval), the heading reads `### v2 —
draft`; gate #1 approval rewrites it to `### v2 — <YYYY-MM-DD>, approved
by human` — the example above shows the post-approval form.

Every entry names its origin — `human feedback`, `structure-note <where>`,
or `spec-concern <where>` — so whether the advisory pipeline is actually
consumed stays auditable.

### Acceptance Groups (lead mode only)

A spec that will run in lead mode carries one extra section, written by
loopspec (when the human asks for lead mode) or added by the human before
approval — it is part of the approved contract and frozen with the rest:

```markdown
## Acceptance Groups
- G1: R1, R2, R3 — cell store
- G2: R4, R5 — formulas
```

Rules: every R-id in `## Requirements` appears in exactly one group; group
ids are `G1, G2, …` in spec order. Groups are the checkpoint unit — each
`G<N>` must pass a gate (scripts/gate.sh) before the run can complete.
Conducted (looprun) runs ignore this section.

## plan.md — written by loopplan, frozen after approval except recorded re-plans

```markdown
# Plan: <project name>
version: 1
status: approved            # draft | approved

## Phase 1: <name>
Goal: <one sentence — a shippable increment>
Phase acceptance: <how the phase verifier decides the phase holds together>

### Task 1.1: <title>
risk: light                 # light | heavy — when in doubt, heavy
covers: R1, R3              # requirement IDs from spec.md
files: <expected files, best effort>
acceptance:
- <test-description form, e.g. "returns 401 when the token is expired">
- <every criterion must be machine-checkable>

### Task 1.2: ...

## Phase 2: ...

## Re-plans
<appended by the orchestrator when a task is split/reordered; never edited
by hand. Format: "- <date> task <id>: <what changed and why>">
```

When a re-plan splits a task, the new tasks take letter suffixes of the
original id in plan order: `2.3` → `2.3a`, `2.3b`. The original id never
reappears in the task tree; state.md and journal.md reference the suffixed
ids from then on.

## state.md — created by loopspec, updated by every skill

Lifecycle: `spec` (loopspec is drafting/interviewing) → `planning` (loopplan
is drafting) → `executing` (set at plan approval) → `halted` or `complete`.
The file exists from the moment loopspec starts drafting, so a crash at any
pipeline stage leaves a resumable marker on disk.

Before plan approval, state.md is header-only. The three branch fields are
absent until spec approval, and in non-git projects they never appear —
their absence is the signal for every skill to skip all branch logic.

The pre-approval, header-only form (no branch fields):

```markdown
# Loopspace State
version: 1
run: 2                      # which run this state belongs to; absent = 1.
                            # Written by loopnext when it opens run N.
run_status: spec            # spec | planning | executing | halted | complete
harness: claude-code        # harness profile id (harnesses/ in the loopspace
                            # checkout); absent = claude-code (pre-0.13 run)
tier: A                     # A | B | C — dispatch capability from the
                            # profile; absent = A
implementer_fallback: openai/gpt-5.5
                            # optional — a model/route the harness profile
                            # can dispatch one task's implementers to;
                            # arms the escalation ladder in looprun's
                            # stall policy. Absent = no ladder, a stall
                            # halts as before. Set by the human (any time
                            # before or during a run); never set by a skill.
mode: lead                  # optional; absent = conducted (looprun). Set by
                            # looplead's arming step, with human approval.
budget_dispatches: 40       # lead mode only — dispatch cap for the
                            # whole run. Self-accounted: the lead journals
                            # `## [dispatch]` lines and must stay under it.
budget_wall_hours: 12       # lead mode only — wall-clock cap, enforced by
                            # scripts/supervise.sh (env LOOPSPACE_WALL_BUDGET
                            # in seconds overrides it for ops/tests).
```

Added at spec approval (git projects only) — the three branch fields:

```markdown
base_branch: main                     # branch the run forked from; merge-back target
run_branch: loopspace/<slug>/run      # per-run base branch, created at spec approval
current_branch: loopspace/<slug>/run  # where work happens now; looprun moves it to
                                      # loopspace/<slug>/phase-<N> as phases open
```

From plan approval on, the full form, rewritten by looprun after every task:

```markdown
# Loopspace State
version: 1
run: 2                      # absent = 1; rewriters preserve it
run_status: executing
harness: claude-code
tier: A
current_phase: 2
current_task: 2.3
base_branch: main
run_branch: loopspace/feat-x/run
current_branch: loopspace/feat-x/phase-2

## Project Facts
- test: <command that runs the test suite>
- build/run: <command, or "none yet">
- stack: <language + framework, one line>

## Tasks
| id  | status      | attempts | risk  |
|-----|-------------|----------|-------|
| 1.1 | done        | 1        | light |
| 2.3 | in_progress | 2        | heavy |
```

Header fields a rewriter does not own are preserved verbatim —
looprun's per-task rewrites must not drop `run:`, `harness:`, or
`tier:`. In lead mode the same rule covers `mode:` and the two
`budget_*` fields; the `## Tasks` table does not exist — the lead owns
its own decomposition in the journal.

`status` values: `pending | in_progress | done | failed`. `failed` is set
only on the task that triggered a halt; the halt-resume procedure in looprun
resets it to `pending` (attempts 0) when the human resolves the halt.

Project Facts exist so fresh agents never re-discover the repo: loopplan
seeds them from the spec's Engineer Lens (a greenfield project may start
with "none yet"), looprun injects them into every dispatch and corrects
them whenever an implementer reports a differing fact.

## journal.md — append-only; written by looprun, plus loopnext's run
header and loopresume's harness-switch entry

```markdown
# Journal
version: 1

# ── Run 2 — opened <YYYY-MM-DD> (spec v2) ──   <!-- written by loopnext;
                                     entries before the first run header
                                     belong to run 1 -->
## [loopnext] run 2 opened
- amendment: <one line — what changed, spec_version>
- adopted advisories: <adopted structure-note/spec-concern summary, or "none">

## [1.1] attempt 1 — PASS
- implementer: <one-line summary>
- tdd-evidence: <test file>:<first-fail confirmed>
- verifier: PASS — <one-line note>
- files: <comma-separated changed files>
- exports: <public symbols the task added or changed for use outside it,
  module-qualified — or "none". looprun assembles the next dispatches'
  PRIOR WORK THIS PHASE block from these lines>
- pre-existing: <optional — verbatim from the implementer: the behavior
  already existed (an earlier task built past its boundary) and the red
  evidence came from the temporary-removal route>
- spec-concern: <optional, advisory — verbatim from the verifier: R-id or
  criterion that is correctly implemented but questionable as spec design;
  surfaces to the human in the halt or run-complete report>

## [2.3] attempt 1 — FAIL
- verifier: FAIL — <finding driving the retry>

## [2.3] attempt 2 — FAIL
- verifier: FAIL — <finding driving the retry>
- contested: #2 dropped — <verifier's one-line reason; a dropped finding
  is never carried into the retry's findings>

## [2.4] attempt 1 — FAIL          <!-- heavy task: three-lens panel -->
- implementer: <one-line summary>
- approach: <one line — feeds the diversity burst if the task stalls>
- panel: correctness PASS / security FAIL / test-integrity PASS
- findings: <lens-tagged findings driving the retry>

## [stall 2.3] cause: stubborn — evidence: "<verbatim finding line that justified the classification>"

## [2.3] narrow resume — findings converging (5→3→2)  <!-- relief gate 1:
                                     once per task; this entry is the guard -->

## [2.3] burst candidate 1 — FAIL  <!-- diversity burst after 3 stalled attempts -->
- approach: <one line — must differ from every failed approach>
- verifier: FAIL — <finding>

## [2.3] burst candidate 2 — PASS

## [2.3] escalated implementer → openai/gpt-5.5  <!-- relief gate 3: once per
                                     task, needs implementer_fallback: in
                                     state.md; this entry is the guard -->

## [re-plan 2.3] <one line: what was split/reordered and why>

## [phase 1] verified — <one-line integration note>
- probes: <N scenarios derived from spec → tests/probes_phase_1.*; all pass>
- mutation: <behavior broken → suite went red | skipped: not a git repository>
- structure-note: <verbatim, advisory — phase-level structural-economy
  observation consumed by loopnext>

## [final] verified — <one-line product-level note>   <!-- conducted mode:
                                     once, after the last phase boundary
                                     and before run_status: complete -->
- probes: <N cross-phase scenarios derived from spec → tests/probes_final.*; all pass>
- mutation: <behavior broken → suite went red | skipped: not a git repository>
- spec-concern: <verbatim, advisory — carried into the completion report>

## [halt] resolved — <one line: the human's decision that cleared the halt>

## [harness] switched <old> → <new> (tier <A|B|C> → <A|B|C>)

## [lead] plan                     <!-- lead mode only: the lead's journaled
                                     decomposition — observational, never
                                     approved; rewritten intent goes in a
                                     new entry, not an edit -->
- <task list, ordering, and what changed since the last plan entry>

## [dispatch] <role/model> — <what was delegated, one line>
                                   <!-- lead mode only: one line per subagent
                                     dispatch; budget_dispatches accounting
                                     counts these lines -->
```

In lead mode the lead agent writes the journal freely; the two entry shapes above that are mechanical are `## [lead] plan` (observational decomposition) and `## [dispatch]` (one line per subagent dispatch, accounted toward `budget_dispatches`).

Task ids restart at 1.1 inside each run; the nearest run header above an
entry scopes it.

## gates.md — append-only ledger; written ONLY by scripts/gate.sh (lead mode)

The machine half of lead mode. The lead agent calls `scripts/gate.sh` when
it believes an acceptance group is done; the script runs a cross-lineage
verifier and records the verdict here mechanically. The lead never writes
this file — a checkpoint that isn't in the ledger never happened, and
`run_status: complete` can only be written by the final gate's PASS path.

```markdown
# Gates
version: 1

## [gate G1] opened 2026-07-15T09:00:12Z
## [gate G1] verdict: PASS — 2026-07-15T09:14:02Z
- note: <verifier's one line>
- probes: 4 scenarios → tests/probes_gate_G1.py; all pass
- mutation: dropped propagation → suite went red
- commit: abc1234

## [gate G2] opened 2026-07-15T11:02:44Z
## [gate G2] verdict: FAIL — 2026-07-15T11:15:31Z
- note: <one line>
- probes: 3 scenarios → tests/probes_gate_G2.py; 1 failing — see findings
- mutation: <one line>
- finding: 1. <numbered, actionable — the lead repairs from these>

## [gate G2] error — verifier timeout after 2400s   <!-- never counts as FAIL -->

## [gate final] blocked 2026-07-16 — ungated groups: G4
## [gate final] verdict: PASS — 2026-07-16T02:10:09Z
```

Entry kinds: `opened` (gate started — also the supervisor's liveness
signal during a long verification), `verdict: PASS|FAIL`, `error` (timeout
or unparseable verifier output; exit 3, excluded from FAIL counting),
`blocked` (final gate's mechanical pre-check refused — also not a FAIL).
Consecutive-FAIL counting per gate id = FAIL verdicts since that gate's
last PASS verdict; reaching `LOOPSPACE_GATE_MAX_FAIL` (default 3) halts
the run (trigger `gate-stall`). Every PASS makes a checkpoint commit
(`loopspace: gate <id> verified`); before every verification the script
commits the tree as `loopspace: gate <id> candidate` so the verifier's
mutation-restore (`git checkout -- <file>`) can never destroy uncommitted
lead work. A PASS verdict line is written only after its verified commit
succeeds — a gate that dies on a broken repo (exit 3) leaves an error
line, never a phantom PASS — and the entry itself rides in a follow-up
`loopspace: gate <id> ledger` commit.

## handoff.md — overwritten at phase boundaries and at the context threshold

```markdown
# Handoff
version: 1
written: <YYYY-MM-DD>
trigger: phase-boundary     # phase-boundary | context-threshold
position: <task id>         # last task whose cycle finished when this was
                            # written — the staleness anchor. A session can
                            # die (crash, backend timeout) without reaching
                            # its handoff step; the file left behind then
                            # describes an older position. loopresume
                            # compares this field against the journal: any
                            # verified progress past it means the handoff is
                            # stale and must not be trusted for position.
                            # Lead mode: `position: gate:<group>` — the
                            # newest PASS gate when written (`gate:none`
                            # before the first). loopresume compares it
                            # against gates.md instead of the journal.

## Where we are
<current phase/task, one paragraph max>

## Next session must know
- <hard-won facts: quirks discovered, decisions made mid-run>

## Watch out for
- <traps: flaky test, slow command, naming collision>
```

## report.md — written only on halt, deleted by the halt-resume procedure
after its content is journaled

```markdown
# Halt Report
version: 1
written: <YYYY-MM-DD>
trigger: spec-gap           # task-stall | phase-stall | final-stall | spec-gap | external-blocker | gate-stall (lead mode)
harness: claude-code        # what actually ran — the honesty rule in
tier: A                     # harnesses/PROFILE-SPEC.md
current_branch: loopspace/<slug>/phase-3   # git projects only
last_verified_phase: loopspace/<slug>/phase-2   # newest phase branch whose
                            # boundary verification passed, or "none" —
                            # lets the human merge verified work only
last_verified_gate: G2      # lead mode replaces last_verified_phase with
                            # the newest gate id whose verdict is PASS, or
                            # "none"

## Progress
<what is done, by phase/task id>

## Blocker
<precisely what blocked, with evidence (error output, contradiction)>

## Options
- A: <option + consequence>
- B: <option + consequence>
- C: <option + consequence>

## Spec concerns
<optional — omit when the journal has none. Verbatim `spec-concern` lines
accumulated in the journal: spec-compliant work a verifier would question
as spec design. Advisory for the human only — never a halt cause, never
shown to implementers.>

## Awaiting
Human decision. Resume the run after resolving.
```

## archive/ — prior runs, written only by loopnext

When loopnext opens run N it moves the finished run's per-run files
aside and snapshots the spec **before** drafting the amendment, so a
crash at any later point leaves a resumable marker (fresh header-only
state.md with `run: N`) instead of a torn run:

```
.loopspace/archive/run-<N-1>/
  spec.md      # snapshot at run N-1 completion — the abort path's
               # restore material (git restore can't cover non-git projects)
  plan.md      # moved
  state.md     # moved, final form (run_status: complete)
  handoff.md   # moved, if present
```

`spec.md` and `journal.md` themselves are persistent — they live across
runs at the top level (the spec is amended in place; the journal appends
under run headers). `report.md` never appears here: it only exists on a
halt and halt-resume deletes it.

Restore contract (loopnext's amendment-rejected abort), in this exact
order: (1) delete the run-N `state.md` loopnext wrote when it opened the
run; (2) move `plan.md`, `state.md`, `handoff.md` out of
`archive/run-<N-1>/` back into `.loopspace/`; (3) copy the `spec.md`
snapshot in `archive/run-<N-1>/` back over `.loopspace/spec.md`; (4)
delete the directory `archive/run-<N-1>/` recursively — the snapshot
copy is still in it, so the directory is not empty at this point. This
must never touch `archive/` itself or any earlier `run-<K>/` directory —
reproducing the pre-loopnext state exactly means run-1's archive
survives a run-3 abort untouched.
