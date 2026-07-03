# .loopspace/ State File Formats (version 1)

All loopspace state lives in `.loopspace/` at the target project root.
Design criterion: a fresh session reading only these files can continue the
run exactly. Formats are line-oriented so they can be parsed with grep/sed.

Every file's first body line is `version: 1`. Consumers must check it and
refuse to guess on unknown versions.

## spec.md — written by loopspec, frozen after approval

```markdown
# Spec: <project name>
version: 1
status: approved            # draft | approved

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

Before plan approval, state.md is header-only:

```markdown
# Loopspace State
version: 1
run_status: spec            # spec | planning | executing | halted | complete
```

From plan approval on, the full form, rewritten by looprun after every task:

```markdown
# Loopspace State
version: 1
run_status: executing
current_phase: 2
current_task: 2.3

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

`status` values: `pending | in_progress | done | failed`. `failed` is set
only on the task that triggered a halt; the halt-resume procedure in looprun
resets it to `pending` (attempts 0) when the human resolves the halt.

Project Facts exist so fresh subagents never re-discover the repo: loopplan
seeds them from the spec's Engineer Lens (a greenfield project may start
with "none yet"), looprun injects them into every dispatch and corrects
them whenever an implementer reports a differing fact.

## journal.md — append-only, written by looprun

```markdown
# Journal
version: 1

## [1.1] attempt 1 — PASS
- implementer: <one-line summary>
- tdd-evidence: <test file>:<first-fail confirmed>
- verifier: PASS — <one-line note>
- files: <comma-separated changed files>

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

## [2.3] burst candidate 1 — FAIL  <!-- diversity burst after 3 stalled attempts -->
- approach: <one line — must differ from every failed approach>
- verifier: FAIL — <finding>

## [2.3] burst candidate 2 — PASS

## [re-plan 2.3] <one line: what was split/reordered and why>

## [phase 1] verified — <one-line integration note>

## [halt] resolved — <one line: the human's decision that cleared the halt>
```

## handoff.md — overwritten at phase boundaries and at the context threshold

```markdown
# Handoff
version: 1
written: <YYYY-MM-DD>
trigger: phase-boundary     # phase-boundary | context-threshold

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
trigger: spec-gap           # task-stall | phase-stall | spec-gap | external-blocker

## Progress
<what is done, by phase/task id>

## Blocker
<precisely what blocked, with evidence (error output, contradiction)>

## Options
- A: <option + consequence>
- B: <option + consequence>
- C: <option + consequence>

## Awaiting
Human decision. Re-run /looprun after resolving.
```
