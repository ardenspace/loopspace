# loopspace Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the loopspace Claude Code plugin — a spec-driven autonomous harness (spec → plan → execute → verify loop) — and make it installable from the `ardenspace/loopspace` marketplace repo.

**Architecture:** Four markdown skills (`spec`, `plan`, `run`, `resume`) plus one SessionStart hook. All run state lives in `.loopspace/` files in the target project so any fresh session can resume. The orchestrator (`run`) dispatches fresh subagents per task: implementer (TDD contract) then independent verifier (risk-tiered checklist).

**Tech Stack:** Claude Code plugin format (`.claude-plugin/plugin.json`, `skills/*/SKILL.md`, `hooks/hooks.json`), POSIX sh + Windows polyglot hook, zero runtime dependencies.

**Spec:** `docs/superpowers/specs/2026-07-03-loopspace-plugin-design.md` — read it before starting any task.

## Global Constraints

- All user-facing content (skills, references, README, hook messages) is **English**.
- Plugin name `loopspace`; skills invoked as `loopspace:spec`, `loopspace:plan`, `loopspace:run`, `loopspace:resume`.
- The principle string, verbatim everywhere it appears: **"Keep context light, verify heavy."**
- State directory in target projects: `.loopspace/` at project root. Every state file's first body line is `version: 1`.
- Zero runtime dependencies. Hook must work on Windows, macOS, Linux and exit fast/silently when `.loopspace/` is absent.
- License MIT, author `ardenspace`.
- Repo `D:\loopspace` doubles as plugin and marketplace (`github.com/ardenspace/loopspace`).
- Skill frontmatter descriptions must start with "Use when …" (superpowers:writing-skills convention).
- Commit after every task with the message given in the task.

## File Structure

```
.claude-plugin/plugin.json           # plugin manifest
.claude-plugin/marketplace.json      # this repo as its own marketplace
docs/state-format.md                 # single source of truth for .loopspace/ file formats
skills/spec/SKILL.md                 # 4-lens interview + 6-lens panel + convergence loop
skills/spec/references/interview-lenses.md
skills/spec/references/panel-reviewers.md
skills/plan/SKILL.md                 # phase/task decomposition, criteria, risk tags
skills/run/SKILL.md                  # orchestrator loop
skills/run/references/agent-prompts.md   # implementer/verifier/phase-verifier prompt templates
skills/resume/SKILL.md               # state-file based resume + status
hooks/hooks.json                     # SessionStart registration
hooks/session-start.sh               # hook logic (POSIX sh)
hooks/run-hook.cmd                   # Windows/unix polyglot dispatcher (adapted from superpowers)
README.md                            # philosophy, install, quickstart
CHANGELOG.md
LICENSE
docs/example/                        # dogfood run artifacts (Task 11)
```

---

### Task 1: Plugin scaffold (manifests, license, changelog)

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`
- Create: `LICENSE`
- Create: `CHANGELOG.md`

**Interfaces:**
- Consumes: nothing
- Produces: plugin identity `loopspace` v`0.1.0`; marketplace source `./` — later tasks and install commands rely on these exact names.

- [ ] **Step 1: Write `.claude-plugin/plugin.json`**

```json
{
  "name": "loopspace",
  "description": "Spec-driven autonomous harness: rigorously verified specs and plans, then an autonomous implement-verify loop with TDD, fresh subagents per task, and disk-based resumable state. Keep context light, verify heavy.",
  "version": "0.1.0",
  "author": {
    "name": "ardenspace",
    "email": "ardensdevspace@gmail.com"
  },
  "homepage": "https://github.com/ardenspace/loopspace",
  "repository": "https://github.com/ardenspace/loopspace",
  "license": "MIT",
  "keywords": [
    "spec-driven",
    "autonomous",
    "harness",
    "tdd",
    "verification",
    "loop",
    "workflow"
  ]
}
```

- [ ] **Step 2: Write `.claude-plugin/marketplace.json`**

```json
{
  "name": "loopspace",
  "owner": {
    "name": "ardenspace"
  },
  "plugins": [
    {
      "name": "loopspace",
      "source": "./",
      "description": "Spec-driven autonomous harness: plan with multi-lens verification, execute with TDD and independent verifiers, resume from disk. Keep context light, verify heavy."
    }
  ]
}
```

- [ ] **Step 3: Write `LICENSE`** — standard MIT license text, copyright line:

```
MIT License

Copyright (c) 2026 ardenspace
```

(followed by the standard MIT license body, verbatim from https://opensource.org/license/mit — the canonical 3-paragraph text.)

- [ ] **Step 4: Write `CHANGELOG.md`**

```markdown
# Changelog

## 0.1.0 — Unreleased

Initial release: `spec`, `plan`, `run`, `resume` skills and the SessionStart
resume-reminder hook.
```

- [ ] **Step 5: Validate JSON parses**

Run: `powershell -Command "Get-Content .claude-plugin/plugin.json -Raw | ConvertFrom-Json | Out-Null; Get-Content .claude-plugin/marketplace.json -Raw | ConvertFrom-Json | Out-Null; 'JSON OK'"`
Expected: `JSON OK`

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin LICENSE CHANGELOG.md
git commit -m "feat: plugin scaffold - manifests, license, changelog"
```

---

### Task 2: State-file format reference (`docs/state-format.md`)

This document is the single source of truth for `.loopspace/` files. Every skill links to it instead of restating formats (DRY). It is written for agents that must parse these files with grep/sed-level tooling — formats are line-oriented on purpose.

**Files:**
- Create: `docs/state-format.md`

**Interfaces:**
- Consumes: nothing
- Produces: exact file names (`spec.md`, `plan.md`, `state.md`, `journal.md`, `handoff.md`, `report.md`), field names (`version`, `run_status` with values `spec|planning|executing|halted|complete`, task `id` format `<phase>.<n>`, task `status` values `pending|in_progress|done|failed`, `risk` values `light|heavy`), and the requirement-ID convention `R1, R2, …`. All skill tasks (3–6) and the hook (7) consume these names verbatim.

- [ ] **Step 1: Write `docs/state-format.md`** with exactly this content:

````markdown
# .loopspace/ State File Formats (version 1)

All loopspace state lives in `.loopspace/` at the target project root.
Design criterion: a fresh session reading only these files can continue the
run exactly. Formats are line-oriented so they can be parsed with grep/sed.

Every file's first body line is `version: 1`. Consumers must check it and
refuse to guess on unknown versions.

## spec.md — written by loopspace:spec, frozen after approval

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

## plan.md — written by loopspace:plan, frozen after approval except recorded re-plans

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

## state.md — written by loopspace:run after every task

```markdown
# Loopspace State
version: 1
run_status: executing       # spec | planning | executing | halted | complete
current_phase: 2
current_task: 2.3

## Tasks
| id  | status      | attempts | risk  |
|-----|-------------|----------|-------|
| 1.1 | done        | 1        | light |
| 2.3 | in_progress | 2        | heavy |
```

`status` values: `pending | in_progress | done | failed`.

## journal.md — append-only, written by loopspace:run

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

## [re-plan 2.3] <one line: what was split/reordered and why>

## [phase 1] verified — <one-line integration note>
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

## report.md — written only on halt

```markdown
# Halt Report
version: 1
written: <YYYY-MM-DD>
trigger: spec-gap           # task-stall | spec-gap | external-blocker

## Progress
<what is done, by phase/task id>

## Blocker
<precisely what blocked, with evidence (error output, contradiction)>

## Options
- A: <option + consequence>
- B: <option + consequence>
- C: <option + consequence>

## Awaiting
Human decision. Re-run /loopspace:run after resolving.
```
````

- [ ] **Step 2: Verify required sections exist**

Run: `grep -c "^## " docs/state-format.md`
Expected: `6` (one section per state file)

- [ ] **Step 3: Commit**

```bash
git add docs/state-format.md
git commit -m "feat: state-file format reference (single source of truth)"
```

---

### Task 3: `loopspace:spec` skill

**Files:**
- Create: `skills/spec/SKILL.md`
- Create: `skills/spec/references/interview-lenses.md`
- Create: `skills/spec/references/panel-reviewers.md`

**Interfaces:**
- Consumes: `docs/state-format.md` `spec.md` format (Task 2)
- Produces: `.loopspace/spec.md` with `status: approved`; hands off to `loopspace:plan`. Requirement IDs `R1…` are consumed by plan/run.

- [ ] **Step 1: Write `skills/spec/SKILL.md`** with exactly this content:

````markdown
---
name: spec
description: Use when starting a new loopspace project or feature — turns an idea into a rigorously verified spec through a 4-lens interview (company, user, engineer, designer) and a 6-lens verification panel, ending with human approval. First step of the loopspace pipeline.
---

# loopspace:spec — Idea to Verified Spec

Principle: **Keep context light, verify heavy.** The spec stage is where
"verify heavy" pays most: a defect caught here is ~10x cheaper than one
caught in code, and precise requirements reduce implementation retries.

The spec is the human's contract. Downstream agents never modify it.

## Flow

```
interview (4 lenses, one question at a time)
  → draft .loopspace/spec.md
  → verification panel (6 reviewer subagents, one lens each)
  → convergence loop: blocking findings? revise draft, re-panel (max 3 rounds)
  → present to human: draft + remaining non-blocking findings
  → human approves → status: approved (frozen) → suggest /loopspace:plan
```

## Step 1 — Interview

Ask questions **one at a time**, in lens order: company → user → engineer →
designer. Question banks: `references/interview-lenses.md`. Skip questions
already answered by the user's initial description. Prefer multiple choice
where natural.

**Designer-lens applicability test:** skip the designer lens entirely when
the project has no UI surface (pure library, CLI without interactive UI,
backend service). State that you are skipping it and why.

Stop interviewing when you can write every spec section without inventing
answers. Depth over speed — this stage is never cost-reduced.

## Step 2 — Draft

Write `.loopspace/spec.md` in the exact format defined in the plugin's
`docs/state-format.md` (spec.md section), with `status: draft`.

Requirements (`R1, R2, …`) must be testable phrasings — "R3: the CLI exits
non-zero on malformed input", not "R3: good error handling".

## Step 3 — Verification Panel

Dispatch **6 reviewer subagents in parallel**, one per lens, using the
prompts in `references/panel-reviewers.md`: company, user, engineer,
designer (skip if lens was skipped), adversarial (red team), verifiability.

Each returns findings tagged `[BLOCKING]` or `[NON-BLOCKING]`, or
`NO FINDINGS`.

## Step 4 — Convergence Loop

- Any `[BLOCKING]` finding → revise the draft to resolve it, then re-run
  the panel. Maximum 3 rounds.
- If blocking findings remain after round 3, present them to the human as
  open decisions — do not silently drop them.
- Non-blocking findings accumulate; do not block on them.

## Step 5 — Human Approval Gate

Present: the draft location, a summary of what changed across panel rounds,
and every remaining non-blocking finding. Ask the human to read
`.loopspace/spec.md` and approve or request changes.

On approval: set `status: approved`, fill the `## Approval` section with
today's date and the open non-blocking findings, and suggest running
`/loopspace:plan`.

## Rules

- One question per message during the interview.
- Never invent an answer the human didn't give; ask.
- The panel runs on the *written draft*, not on your memory of the
  conversation.
- Panel reviewers are fresh subagents; never review your own draft inline
  and call it a panel.
````

- [ ] **Step 2: Write `skills/spec/references/interview-lenses.md`** with exactly this content:

```markdown
# Interview Question Banks (4 lenses)

Ask one question at a time. Skip anything the user already answered.
These are starting points — follow up on interesting answers.

## Company Lens

- What is the deadline or time budget? What happens if it slips?
- What is the cost ceiling (infra, APIs, tokens, services)?
- What is the MVP — the smallest version you would actually ship?
- What is explicitly out of scope for v1?
- Who else (if anyone) depends on this shipping?

## User Lens

- Who uses this, and what do they do today without it?
- What is the single moment where this must feel effortless?
- How does a first-time user get from zero to value? How long may it take?
- What would make a user abandon it within the first minute?
- Is this a must-have or a nice-to-have for them? Why?

## Engineer Lens

Security first — always ask:
- What data does this handle? Any secrets, credentials, or PII?
- What inputs cross a trust boundary (user input, network, files)?

Then:
- What must NOT be over-engineered in v1? Where is "simple" acceptable?
- What failure modes matter (network down, bad input, partial writes)?
  What should the user see when they happen?
- What is the testing strategy — unit, integration, end-to-end? What is
  the one test that, if green, gives the most confidence?
- Any hard platform/runtime constraints (OS, versions, offline)?

## Designer Lens

(Skip entirely when there is no UI surface — say so.)

- Is there an existing design system, brand, or reference product to match?
- What is the primary screen or interaction? Sketch it in words.
- Accessibility requirements (keyboard, contrast, screen readers)?
- Light/dark theme? Responsive down to what width?
```

- [ ] **Step 3: Write `skills/spec/references/panel-reviewers.md`** with exactly this content:

````markdown
# Verification Panel Reviewer Prompts (6 lenses)

Dispatch all applicable reviewers **in parallel**, one fresh subagent each.
Replace `{SPEC_PATH}` with the absolute path to `.loopspace/spec.md`.

Every prompt ends with the same reporting contract:

> Report each finding on one line:
> `[BLOCKING]` (spec cannot be safely implemented as written) or
> `[NON-BLOCKING]` (worth noting, does not gate approval), followed by the
> spec section it applies to and one sentence. If you find nothing, return
> exactly `NO FINDINGS`. Return only the findings list — no preamble.

## 1. Company reviewer

You are reviewing a project spec as a pragmatic founder. Read {SPEC_PATH}.
Judge: Is the MVP scope actually minimal? Does the timeline/cost framing
match the requirement list? Is anything in Requirements secretly a v2
feature? Is anything load-bearing missing from Non-Goals?
[reporting contract]

## 2. User reviewer

You are reviewing a project spec as its most impatient end user. Read
{SPEC_PATH}. Judge: Does the spec state who needs this and why now? Is the
zero-to-value path convincing? Which requirement, if cut, would users
notice least — and is it marked MVP anyway? Is any "convenience" claim
untestable?
[reporting contract]

## 3. Engineer reviewer

You are reviewing a project spec as a senior engineer with a security
focus. Read {SPEC_PATH}. Judge, in priority order: (1) security — trust
boundaries, secrets handling, injection surfaces, missing input
validation; (2) error/exception handling — does each failure mode have a
specified user-visible behavior; (3) over-engineering — anything specified
more elaborately than its requirement justifies; (4) testability of the
stated testing strategy.
[reporting contract]

## 4. Designer reviewer

You are reviewing a project spec as a product designer. Read {SPEC_PATH}.
Judge: Is the Designer Lens section concrete enough to build from (primary
interaction, states, accessibility)? Do any requirements imply UI that the
Designer Lens never describes? Skip entirely (return `NO FINDINGS`) if the
spec says the lens is not applicable — unless you spot UI hiding in the
requirements, which is a [BLOCKING] finding.
[reporting contract]

## 5. Adversarial reviewer (red team)

You are red-teaming a project spec. Read {SPEC_PATH}. Actively try to
break it: find pairs of requirements that contradict each other, edge
cases with unspecified behavior, abuse scenarios (hostile input, resource
exhaustion), failure modes with no specified recovery, and implicit
assumptions that are false on some platform. Be aggressive; your job is
to find what polite reviewers miss.
[reporting contract]

## 6. Verifiability reviewer

You are auditing a project spec for machine-checkability. Read
{SPEC_PATH}. For EVERY requirement R1…Rn, answer: can this be converted
into acceptance criteria that a test can pass or fail objectively? Any
requirement that needs human judgment to evaluate ("feels fast",
"intuitive", "clean code") is [BLOCKING] — propose a testable rewording in
the same line. This lens sets the quality ceiling of the autonomous loop.
[reporting contract]
````

- [ ] **Step 4: Verify skill structure**

Run: `grep -l "Use when" skills/spec/SKILL.md && grep -c "^## " skills/spec/references/panel-reviewers.md`
Expected: `skills/spec/SKILL.md` and `6`

- [ ] **Step 5: Commit**

```bash
git add skills/spec
git commit -m "feat: loopspace:spec skill - 4-lens interview, 6-lens panel, convergence loop"
```

---

### Task 4: `loopspace:plan` skill

**Files:**
- Create: `skills/plan/SKILL.md`

**Interfaces:**
- Consumes: approved `.loopspace/spec.md` (Task 3), `plan.md`/`state.md` formats (Task 2), panel reporting contract (Task 3, `panel-reviewers.md`)
- Produces: `.loopspace/plan.md` with `status: approved`, `.loopspace/state.md` initialized with `run_status: executing`-ready task table. `loopspace:run` consumes both.

- [ ] **Step 1: Write `skills/plan/SKILL.md`** with exactly this content:

````markdown
---
name: plan
description: Use when a loopspace spec has been approved — decomposes .loopspace/spec.md into phases and tasks with machine-checkable acceptance criteria and light/heavy risk tags, verifies the plan with a review panel, and gets human approval. This is the last human touchpoint before the autonomous loop.
---

# loopspace:plan — Spec to Verified Plan

Principle: **Keep context light, verify heavy.** Acceptance-criteria
precision set here is the quality ceiling of the autonomous loop — each
criterion becomes a TDD test.

Precondition: `.loopspace/spec.md` exists with `status: approved`. If not,
stop and suggest `/loopspace:spec`.

## Step 1 — Decompose

Write `.loopspace/plan.md` in the exact format defined in the plugin's
`docs/state-format.md` (plan.md section), `status: draft`.

**Phases:** each phase is a shippable increment — after it, the project
runs and its tests pass, even if features are missing. Write the phase
acceptance line: what the phase verifier will check across tasks.

**Tasks:** the smallest unit worth a fresh implementer and a fresh
verifier. Each task must have:

- `covers:` — the requirement IDs (R1…) it implements. Every spec
  requirement must be covered by at least one task.
- `acceptance:` — criteria in test-description form. "returns 401 when the
  token is expired", never "auth works". A criterion an agent cannot turn
  into a pass/fail test is a planning bug.
- `risk:` — `light` (config files, simple CRUD, markup, docs) or `heavy`
  (auth/security, core business logic, data migrations, anything touching
  a trust boundary). **When in doubt, tag heavy.**

## Step 2 — Plan Review Panel

Dispatch 3 fresh reviewer subagents in parallel. Reporting contract is the
same as the spec panel (`[BLOCKING]` / `[NON-BLOCKING]` / `NO FINDINGS`,
one line each):

1. **Verifiability** — every acceptance criterion machine-checkable? Every
   R-id covered by a task? Any task without criteria?
2. **Adversarial** — wrong task ordering (task needs something a later task
   builds)? Hidden coupling between tasks in different phases? A phase
   that isn't actually shippable? Tasks too large to implement in one
   fresh context?
3. **Scope & risk audit** — plan matches spec (no gold-plating, nothing
   missing)? Risk tags honest? (An auth task tagged `light` is a
   [BLOCKING] finding.)

Blocking findings → revise → re-panel, max 3 rounds, same rules as the
spec convergence loop.

## Step 3 — Human Approval Gate

Present the plan location, phase/task count, risk-tag distribution, and
remaining non-blocking findings. **Remind the human: this is the last
approval — after this, the loop runs autonomously.** On approval:

1. Set `plan.md` `status: approved`.
2. Initialize `.loopspace/state.md` (format: `docs/state-format.md`):
   `run_status: executing`, `current_phase: 1`, first task
   `in_progress`-ready, all tasks `pending` with `attempts: 0`.
3. Initialize empty `.loopspace/journal.md` (header + version line).
4. Suggest running `/loopspace:run`.

## Rules

- Never start implementing. This skill only plans.
- Do not modify `spec.md`. Spec gaps found here go back through the spec
  panel: report to the human instead of quietly patching the plan around
  them.
````

- [ ] **Step 2: Verify skill structure**

Run: `grep -c "Use when" skills/plan/SKILL.md`
Expected: `1`

- [ ] **Step 3: Commit**

```bash
git add skills/plan
git commit -m "feat: loopspace:plan skill - decomposition, criteria, risk tags, plan panel"
```

---

### Task 5: `loopspace:run` skill (orchestrator)

**Files:**
- Create: `skills/run/SKILL.md`
- Create: `skills/run/references/agent-prompts.md`

**Interfaces:**
- Consumes: approved `spec.md` + `plan.md`, `state.md`/`journal.md`/`handoff.md`/`report.md` formats (Task 2)
- Produces: the running loop; updates `state.md`/`journal.md` after every task; `handoff.md` at phase boundaries and context threshold; `report.md` on halt. `loopspace:resume` (Task 6) re-enters this skill's loop.

- [ ] **Step 1: Write `skills/run/SKILL.md`** with exactly this content:

````markdown
---
name: run
description: Use when a loopspace plan has been approved — runs the autonomous implement-verify loop. Dispatches a fresh implementer subagent (TDD contract) then a fresh independent verifier per task, updates .loopspace/ state after every task, and escalates or halts per the stall policy. No human decisions until done, halted, or context handoff.
---

# loopspace:run — The Autonomous Loop

Principle: **Keep context light, verify heavy.**

Preconditions: `.loopspace/spec.md` and `.loopspace/plan.md` both
`status: approved`, `.loopspace/state.md` exists. Missing → stop, suggest
the right skill. All file formats: plugin `docs/state-format.md`.

## Orchestrator Contract (what keeps this loop alive)

- You are a dispatcher, not an implementer. You never write project code.
- **Fresh subagent per task, never reused** — even if the previous one
  finished with context to spare. One task = one implementer + one
  verifier, minimum.
- **Diet:** consume verdicts, one-line summaries, and file lists. Never
  request or accept code dumps, diffs, or full test output into your own
  context. The prompts in `references/agent-prompts.md` enforce the report
  shape.
- Update `state.md` and `journal.md` after **every** task, before
  dispatching the next. A crash must never lose more than one task of
  progress.

## Per-Task Cycle

```
next task = first non-done task in plan order
1. Dispatch IMPLEMENTER (fresh) — prompt template A in references/agent-prompts.md
   - carries: spec excerpt (only the R-ids this task covers), the task
     block from plan.md, current handoff.md notes
   - TDD contract: failing tests first (evidence required), then implement
2. Dispatch VERIFIER (fresh, never the implementer) — template B
   - risk tier from the task's risk tag decides checklist depth
3. PASS → state.md: task done; journal entry; next task (fresh implementer)
   FAIL → attempts += 1; journal the verifier findings; retry with a NEW
   fresh implementer that receives those findings (template A, findings
   section filled)
```

## Stall Policy (3-tier escalation)

1. **Same task fails 3 attempts** → classify the cause yourself from the
   verifier findings:
   - Plan problem (task too large, wrong order, missing prerequisite) →
     re-plan **within spec bounds**: split/reorder tasks, append to
     plan.md `## Re-plans` and journal.md, reset attempts, continue.
     Limit: **one re-plan per task** — a second stall on the same
     (re-planned) task escalates to tier 2 reporting.
   - Anything else → tier 2.
2. **Spec contradiction or gap** → halt: `state.md` `run_status: halted`,
   write `report.md` (trigger: `spec-gap`), end turn with the report
   summary. The spec is the human's contract — never modify it, never
   improvise around it.
3. **External blocker** (missing API key/credentials, service down, broken
   toolchain) → halt immediately, `report.md` (trigger:
   `external-blocker`). Do not burn retries on environment problems.

## Phase Boundary

When the last task of a phase is done:

1. Dispatch a **PHASE VERIFIER** (fresh) — template C: full test suite,
   phase acceptance line from plan.md, cross-task integration.
2. FAIL → treat as a failed task on the offending task id (it re-enters
   the per-task cycle with the findings).
3. PASS → journal `[phase N] verified`; overwrite `handoff.md`
   (trigger: `phase-boundary`); continue to the next phase.
4. Last phase → `run_status: complete`, final journal entry, report
   totals to the human (tasks, retries, re-plans).

## Context Threshold (the 30% rule)

Watch your own context consumption (system warnings, or the sheer length
of your conversation). When roughly 30% is consumed — do not push your
luck past it:

1. Finish the in-flight task cycle (never abandon a dispatched verifier).
2. Overwrite `handoff.md` (trigger: `context-threshold`) with everything
   the next session needs.
3. Update `state.md`, then end the turn telling the user exactly:
   run `/clear`, then `/loopspace:resume`. This is typing, not judgment —
   say so.

## Rules

- Verifier verdicts are final. No re-litigating a FAIL in your own context.
- Never mark a task done without a verifier PASS in the journal.
- Never modify spec.md. plan.md changes only through the re-plan path.
````

- [ ] **Step 2: Write `skills/run/references/agent-prompts.md`** with exactly this content:

````markdown
# Subagent Prompt Templates

Replace `{...}` placeholders before dispatch. Keep each dispatch
self-contained: subagents have NO conversation context.

## Template A — Implementer

You are implementing one task in a spec-driven project. Work only on this
task.

TASK (from plan.md):
{task block verbatim: title, risk, covers, files, acceptance}

RELEVANT SPEC REQUIREMENTS:
{only the R-id lines this task covers, plus the Engineer Lens security
notes if risk: heavy}

HANDOFF NOTES (from previous work):
{handoff.md "Next session must know" + "Watch out for" bullets, or "none"}

PRIOR VERIFIER FINDINGS (retry only):
{verifier findings from the failed attempt, or "first attempt"}

TDD CONTRACT — mandatory order:
1. Write failing tests derived from the acceptance criteria (one or more
   per criterion).
2. Run them; confirm they fail. Capture the failing output.
3. Implement the minimal code to pass.
4. Run them; confirm they pass.
Skipping step 2 invalidates your work — the verifier checks for evidence.

Do not touch files outside this task's scope. Do not implement anything
the acceptance criteria don't require.

REPORT BACK (exactly this shape, nothing more):
- verdict: DONE | BLOCKED
- summary: <one line>
- tdd-evidence: <test file> failed-first: <the one-line failure header
  from step 2>
- files: <comma-separated files created/modified>
- blocker: <only if BLOCKED: one line — what and why>

## Template B — Verifier

You are independently verifying a task implementation. You did not write
it. Trust nothing in the implementer's report — re-derive everything.

TASK & ACCEPTANCE CRITERIA:
{task block verbatim}

IMPLEMENTER REPORT:
{implementer's report}

RISK TIER: {light | heavy}

CHECKS — light tier (mechanical):
1. Re-run the tests yourself. They must pass.
2. Map criteria → tests: every acceptance criterion has at least one test
   that would fail if the criterion were violated.
3. Secret scan: no hardcoded credentials/keys/tokens in changed files.

CHECKS — heavy tier (all of light, plus):
4. Test-gaming detection: open the tests. Flag empty tests, tests with no
   assertions, tests that mock away the behavior under test.
5. Security review of changed files: injection surfaces, missing input
   validation at trust boundaries, unsafe file/path/shell handling.
6. Scope creep: anything built that the acceptance criteria don't ask for.
7. TDD evidence: the implementer's failed-first output is present and
   plausible for these tests.

REPORT BACK (exactly this shape):
- verdict: PASS | FAIL
- note: <one line>
- findings: <only if FAIL: numbered, one line each, actionable — the next
  implementer sees these verbatim>

## Template C — Phase Verifier

You are verifying that a completed phase holds together. Individual tasks
passed in isolation; your job is the seams.

PHASE: {phase block from plan.md, including the phase acceptance line}
TASKS COMPLETED: {task ids + one-line summaries from journal.md}

CHECKS:
1. Run the FULL test suite (not per-task subsets). All green.
2. Evaluate the phase acceptance line — is the increment actually
   shippable?
3. Integration seams: do the tasks' pieces reference each other correctly
   (names, types, contracts)? Grep for TODO/FIXME left in changed files.
4. Cross-task scope drift: does the sum of tasks match the phase goal?

REPORT BACK (exactly this shape):
- verdict: PASS | FAIL
- note: <one line>
- offending-task: <only if FAIL: the task id to re-open>
- findings: <only if FAIL: numbered, one line each>
````

- [ ] **Step 3: Verify skill structure**

Run: `grep -c "Template" skills/run/references/agent-prompts.md`
Expected: `6` (3 headers + 3 mentions in SKILL.md references — verify with: `grep -c "^## Template" skills/run/references/agent-prompts.md` → `3`)

- [ ] **Step 4: Commit**

```bash
git add skills/run
git commit -m "feat: loopspace:run skill - orchestrator loop, TDD contract, tiered verification, stall policy"
```

---

### Task 6: `loopspace:resume` skill

**Files:**
- Create: `skills/resume/SKILL.md`

**Interfaces:**
- Consumes: all `.loopspace/` formats (Task 2); re-enters the `loopspace:run` loop (Task 5)
- Produces: a resumed orchestrator in a fresh session; doubles as `status` query.

- [ ] **Step 1: Write `skills/resume/SKILL.md`** with exactly this content:

````markdown
---
name: resume
description: Use when a session starts in a project with an unfinished loopspace run (.loopspace/ exists), after /clear during a run, or when the user asks "where are we" — rebuilds orchestrator state from disk and continues the loop exactly where it stopped. Also answers status without resuming.
---

# loopspace:resume — Pick Up the Loop From Disk

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

- `executing` → invoke the loopspace:run skill and re-enter the per-task
  cycle at `current_task`.
- `halted` → summarize `report.md` and its options; await the human's
  decision. Do not restart the loop on your own.
- `complete` → say so; nothing to resume.
- `spec` / `planning` → the pipeline never reached execution; suggest
  `/loopspace:spec` or `/loopspace:plan`.
````

- [ ] **Step 2: Verify skill structure**

Run: `grep -c "Use when" skills/resume/SKILL.md`
Expected: `1`

- [ ] **Step 3: Commit**

```bash
git add skills/resume
git commit -m "feat: loopspace:resume skill - disk-based resume with state validation"
```

---

### Task 7: SessionStart hook (cross-platform)

**Files:**
- Create: `hooks/session-start.sh`
- Create: `hooks/run-hook.cmd`
- Create: `hooks/hooks.json`

**Interfaces:**
- Consumes: `state.md` `run_status` field (Task 2)
- Produces: session-start reminder text mentioning `/loopspace:resume`.

**Reference for the polyglot pattern (this machine):**
`C:\Users\User\.claude\plugins\cache\claude-plugins-official\superpowers\6.1.0\hooks\run-hook.cmd` and
`C:\Users\User\.claude\plugins\cache\claude-plugins-official\superpowers\6.1.0\docs\windows\polyglot-hooks.md`.
Read both, then adapt the dispatcher so `hooks.json` invokes one command that works on Windows (cmd) and unix (sh). The *logic* below is fixed; only the dispatch wrapper follows superpowers' proven pattern.

- [ ] **Step 1: Write the failing test** (manual test script, run before the hook exists)

```bash
TMP=$(mktemp -d) && cd "$TMP" && mkdir .loopspace && printf 'version: 1\nrun_status: executing\n' > .loopspace/state.md
sh D:/loopspace/hooks/session-start.sh
```

- [ ] **Step 2: Run it to verify it fails**

Expected: `sh: D:/loopspace/hooks/session-start.sh: No such file` (or equivalent) — confirms the test exercises a missing hook.

- [ ] **Step 3: Write `hooks/session-start.sh`**

```sh
#!/bin/sh
# loopspace SessionStart hook.
# Fast and silent when the project has no loopspace run; otherwise remind
# the session that an unfinished run exists. Always exit 0 — a hook must
# never break session start.

[ -f ".loopspace/state.md" ] || exit 0

status=$(sed -n 's/^run_status:[[:space:]]*//p' .loopspace/state.md | head -n 1 | tr -d '\r')

case "$status" in
  ""|complete) exit 0 ;;
esac

printf 'This project has an unfinished loopspace run (run_status: %s). ' "$status"
printf 'Suggest /loopspace:resume to continue it, or /loopspace:resume for status only.\n'
exit 0
```

- [ ] **Step 4: Run the tests to verify behavior**

```bash
# In the $TMP dir from Step 1 (unfinished run):
sh D:/loopspace/hooks/session-start.sh
# Expected: "This project has an unfinished loopspace run (run_status: executing). ..."

# run_status complete → silent:
printf 'version: 1\nrun_status: complete\n' > .loopspace/state.md
sh D:/loopspace/hooks/session-start.sh
# Expected: no output, exit 0

# No .loopspace at all → silent:
cd "$(mktemp -d)" && sh D:/loopspace/hooks/session-start.sh; echo "exit=$?"
# Expected: no output, exit=0
```

- [ ] **Step 5: Write `hooks/run-hook.cmd`** — adapt superpowers' polyglot dispatcher (paths above) so the same `hooks.json` command runs `session-start.sh` via `sh` on unix and via the available shell (Git Bash) on Windows. Keep it argument-driven (`run-hook.cmd session-start`) so future hooks reuse it.

- [ ] **Step 6: Write `hooks/hooks.json`**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start"
          }
        ]
      }
    ]
  }
}
```

(The `clear` matcher is load-bearing: the 30% rule tells users to `/clear` then resume — this hook is what reminds them if they forget.)

- [ ] **Step 7: Verify hooks.json parses and the dispatcher runs on this machine (Windows)**

Run: `powershell -Command "Get-Content hooks/hooks.json -Raw | ConvertFrom-Json | Out-Null; 'JSON OK'"` then re-run the Step 4 test matrix through `run-hook.cmd` instead of direct `sh`.
Expected: `JSON OK`, identical hook outputs.

- [ ] **Step 8: Commit**

```bash
git add hooks
git commit -m "feat: SessionStart hook - unfinished-run reminder, cross-platform"
```

---

### Task 8: README

**Files:**
- Create: `README.md` (replace the placeholder one-liner)

**Interfaces:**
- Consumes: everything above (documents it)
- Produces: the public face; install commands that Task 10 verifies.

- [ ] **Step 1: Write `README.md`** covering, in this order (write real prose, English, no marketing fluff):

1. Title + one-line: "A spec-driven autonomous harness for Claude Code. **Keep context light, verify heavy.**"
2. **The bet** (verbatim from the spec): verification cost is bounded, unverified-failure cost is not.
3. **How it works** — the pipeline as an ASCII diagram:

```
 idea ──▶ /loopspace:spec ──▶ /loopspace:plan ──▶ /loopspace:run ─────▶ done
           4-lens interview     phases → tasks       ┌──────────────┐
           6-lens verify panel  criteria + risk tags │ per task:    │
           human approves       human approves       │  implementer │
                                (last touchpoint)    │  → verifier  │
                                                     │  fresh agents│
                                                     └──── loop ────┘
        state lives in .loopspace/ — kill the session, /loopspace:resume continues
```

4. **Install** (two lines):

```
/plugin marketplace add ardenspace/loopspace
/plugin install loopspace
```

5. **Quickstart** — 5 numbered steps from idea to running loop.
6. **The rules that make it work** — fresh subagent per task; independent verifier; TDD contract with failed-first evidence; light/heavy risk tiers; 3-tier stall policy; 30% context handoff (be honest that /clear + /loopspace:resume is a manual step).
7. **State files** — the 6-file table (one line each) linking to `docs/state-format.md`.
8. **FAQ** — "Isn't double-agent verification expensive?" (the bet + risk tiers), "Why can't it clear its own context?" (harness constraint, stated honestly), "Other harnesses (Codex etc.)?" (v2; disk state is harness-neutral by design).
9. License (MIT).

- [ ] **Step 2: Verify structure**

Run: `grep -c "loopspace:" README.md`
Expected: ≥ 8 (skill mentions throughout)

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: README - philosophy, pipeline diagram, install, FAQ"
```

---

### Task 9: Local install validation

**Files:** none created — validation gate.

- [ ] **Step 1: Validate plugin manifest with the CLI**

Run: `claude plugin validate .` (from `D:\loopspace`)
Expected: validation passes. If the subcommand doesn't exist in the installed CLI version, fall back to: both JSON files parse, `skills/*/SKILL.md` all have `name` + `description` frontmatter (`grep -L "^description:" skills/*/SKILL.md` returns empty).

- [ ] **Step 2: Install from the local path** (manual — ask the user to run these in a Claude Code session)

```
/plugin marketplace add D:\loopspace
/plugin install loopspace@loopspace
```

- [ ] **Step 3: Verify the four skills are listed** (manual) — in a fresh session in any project, the skill list should show `loopspace:spec`, `loopspace:plan`, `loopspace:run`, `loopspace:resume`, and starting a session in a project containing `.loopspace/state.md` with `run_status: executing` should surface the hook reminder.

- [ ] **Step 4: Commit any fixes surfaced by validation**

```bash
git add -A
git commit -m "fix: address plugin validation findings"
```

(Skip the commit if validation was clean.)

---

### Task 10: Publish to GitHub + tag

- [ ] **Step 1: Push**

```bash
git push origin main
```

- [ ] **Step 2: Verify remote install** (manual, in a Claude Code session): `/plugin marketplace remove loopspace` (drop the local one), then

```
/plugin marketplace add ardenspace/loopspace
/plugin install loopspace@loopspace
```

Expected: installs from GitHub; skills listed as in Task 9 Step 3.

- [ ] **Step 3: Tag the release**

```bash
git tag v0.1.0 && git push origin v0.1.0
```

- [ ] **Step 4: Update CHANGELOG** — change `## 0.1.0 — Unreleased` to `## 0.1.0 — <today's date>`, commit `docs: mark 0.1.0 released`, push.

---

### Task 11: Dogfood run → `docs/example/`

The scenario checklist from the spec's Testing section, executed for real. This is the plugin's regression baseline.

- [ ] **Step 1: Pick the toy project** — a unit-converter CLI (Node, zero deps): `convert 3 km mi` prints `1.864`. Small enough for ~2 phases / ~5 tasks, real enough to have a test suite, security surface (input parsing), and no UI (exercises the designer-lens skip).

- [ ] **Step 2: Run the full pipeline in a scratch directory** with the installed plugin: `/loopspace:spec` (answer the interview as the human), approve; `/loopspace:plan`, approve; `/loopspace:run`.

- [ ] **Step 3: Execute the scenario checklist** — every box must be checked, with evidence in the run's `.loopspace/` files:

- [ ] spec interview covered company/user/engineer lenses; designer lens auto-skipped with stated reason
- [ ] verification panel ran (5 reviewers — designer skipped); convergence loop revised on at least one blocking finding (if none occur naturally, temporarily plant an untestable requirement like "feels fast" and confirm the verifiability reviewer blocks it)
- [ ] plan tasks all have `covers:`, `acceptance:` in test-description form, and risk tags
- [ ] state files match `docs/state-format.md` schemas after every task
- [ ] journal shows TDD evidence (failed-first) for every task
- [ ] kill the session mid-phase → new session → hook fires → `/loopspace:resume` continues at the exact task
- [ ] force 3 failures on one task (temporarily add an impossible acceptance criterion) → correct tier-1 re-plan or tier-2 `report.md`
- [ ] finish the run → `run_status: complete`, totals reported

- [ ] **Step 4: Commit the artifacts** — copy the toy project's final `.loopspace/` directory (spec.md, plan.md, state.md, journal.md, handoff.md) into `docs/example/`, plus a `docs/example/README.md` (5 lines: what this is, how it was produced, date).

```bash
git add docs/example
git commit -m "docs: dogfood run artifacts - regression baseline"
git push origin main
```

- [ ] **Step 5: File fixes** — every checklist deviation found in Step 3 becomes a fix commit to the relevant SKILL.md before this task closes. If a deviation requires redesign (not wording), stop and report to the human instead of improvising.

---

## Self-Review (completed)

- **Spec coverage:** lens system → Tasks 3–4; execution loop, risk tiers, stall policy, phase boundaries, 30% rule → Task 5; resumability → Tasks 6–7; distribution/marketplace → Tasks 1, 9, 10; testing/dogfooding → Task 11; harness error handling → hook silent-exit (Task 7), resume validation (Task 6), version fields (Task 2). Non-goals correctly absent.
- **Placeholder scan:** all file contents included verbatim except LICENSE body (canonical MIT text, pointer given), README prose (structure + required content specified per section), and the polyglot dispatcher (exact source paths to adapt from given — deliberate: copy a proven pattern rather than invent one).
- **Type consistency:** `run_status` values, task `status` values, `risk` values, R-id convention, journal entry shapes, and report field names cross-checked between Task 2 formats and Tasks 3–7 consumers.
