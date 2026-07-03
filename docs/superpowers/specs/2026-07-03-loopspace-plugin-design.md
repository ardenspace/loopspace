# loopspace — Spec-Driven Autonomous Harness Plugin

**Date:** 2026-07-03
**Status:** Approved design, pre-implementation
**Principle:** Keep context light, verify heavy.

## Overview

loopspace is a Claude Code plugin that turns a project idea into working code through a
spec → plan → execute → verify loop. Humans approve only the planning artifacts (spec and
plan); implementation runs autonomously with an orchestrator dispatching fresh subagents
per task. Every artifact the loop needs lives on disk, so the loop survives session death
and context resets.

The bet this tool makes: verification cost is bounded, unverified-failure cost is not.
Tokens spent on relentless verification are cheaper than the compounding damage of one
bad task polluting everything built on top of it.

## Goals

- A human approves a rigorously-verified spec and plan, then walks away; the loop
  implements the plan task by task with TDD and independent verification.
- Context hygiene by construction: one task = one fresh implementer subagent, never
  reused; orchestrator receives verdicts and summaries, never code dumps.
- Full resumability: a brand-new session can continue the loop from `.loopspace/` state
  files alone.
- Distributed on the Claude Code plugin marketplace; all user-facing content in English.

## Non-Goals (v1)

- **Multi-harness support** (Codex, OpenCode, Gemini, Cursor). Deferred to v2. The
  portable core (markdown skills + disk state) is preserved now; harness adapters come
  later, following the superpowers porting model.
- Parallel task execution. v1 runs tasks sequentially; the state format should not
  preclude parallelism later.
- CI/headless driver scripts (the "true fresh session" runner). The state-file format is
  session-independent, so a headless runner can be added in v2 without redesign.

## Architecture

Four skills plus one hook:

| Component | Role |
|---|---|
| `loopspace:spec` | Idea → 4-lens interview → spec draft → 6-lens verification panel → convergence loop → human approval |
| `loopspace:plan` | Approved spec → phases → tasks with machine-checkable acceptance criteria and risk tags → panel verification → human approval (last human touchpoint) |
| `loopspace:run` | The autonomous loop: per task, dispatch fresh implementer then fresh verifier; enforce TDD contract; escalation policy on stalls; phase-boundary verification |
| `loopspace:resume` | Rebuild orchestrator state from `.loopspace/` files in a fresh session; also answers "where are we?" (status) |
| SessionStart hook | If the project has an unfinished run in `.loopspace/`, remind the user to `/loopspace:resume`. Silently no-ops in projects without `.loopspace/` |

### The Lens System

**Interview lenses (4)** — questions a human can answer, asked one at a time during
`loopspace:spec`:

1. **Company** — timeline, cost, MVP scope, what ships first
2. **User** — convenience, ease of adoption, necessity, who hurts without this
3. **Engineer** — security (top priority), over-engineering check, error/exception
   handling, testing strategy
4. **Designer** — UI/UX guidance. Auto-skipped when the project has no UI surface;
   the skill states the applicability test explicitly.

**Verification panel lenses (6)** — subagent reviewers, one lens each, run against the
spec draft:

1–4. Same four lenses as the interview (alignment: interview → document → review share
one axis)
5. **Adversarial (red team)** — tries to break the spec: edge cases, abuse scenarios,
failure modes, contradictory requirements
6. **Verifiability** — audits that every requirement converts to machine-checkable
acceptance criteria. This is the load-bearing lens: acceptance-criteria precision sets
the quality ceiling of the autonomous loop and becomes the TDD test list.

**Convergence loop** — panel findings are classified blocking / non-blocking. Blocking
findings trigger a spec revision and a re-panel, up to 3 rounds. Remaining non-blocking
issues are listed explicitly at the human approval gate. Planning-stage verification is
never cost-reduced: a defect caught in the spec is ~10x cheaper than one caught in code,
and precise criteria reduce implementation retries.

### State Files

All in `.loopspace/` at the project root. Design criterion: a fresh session reading only
these files can continue the run exactly. Every file carries a `version` field for future
format migrations.

| File | Content | Writer |
|---|---|---|
| `spec.md` | Approved spec with lens sections | spec skill; frozen after approval |
| `plan.md` | Phase → task tree; per-task acceptance criteria (test-description form) and `risk: light \| heavy` tag | plan skill; frozen after approval except recorded re-plans |
| `state.md` | Current phase/task pointer, per-task attempt counts, completion checkmarks | orchestrator, after every task |
| `journal.md` | Append-only log: task, agents dispatched, verdict, files changed | orchestrator |
| `handoff.md` | Notes for the next session: what is known, what to watch out for | orchestrator, at phase boundaries and at the 30% context threshold |
| `report.md` | Halt report: progress so far, what blocked, options A/B/C | orchestrator, only on halt |

### Execution Loop

For each task in `plan.md`:

1. **Implementer** (fresh subagent) receives: relevant spec excerpt, the task, its
   acceptance criteria, current handoff notes. TDD contract is mandatory: write failing
   tests from the criteria → show them fail → implement → show them pass. The report
   back includes the failing-first evidence, a verdict, a one-line summary, and the list
   of changed files — no code dumps.
2. **Verifier** (fresh subagent, never the implementer) independently checks:
   - ① re-runs the tests (implementer's claims are not trusted)
   - ② criteria coverage — every criterion has a corresponding test
   - ③ test-gaming detection — empty tests, all-mock tests, assertion-free tests
   - ④ security review — hardcoded secrets, injection, missing input validation
   - ⑤ scope creep — nothing built that the spec does not ask for
3. **PASS** → update `state.md` and `journal.md` → next task with a brand-new implementer.
4. **FAIL** → retry with a fresh implementer that receives the verifier's findings.
   Maximum 3 attempts per task.

**Risk-tiered verification depth.** The plan tags each task `light` or `heavy`; the
panel audits the tagging during plan review.

- `light` (config files, simple CRUD, markup): verifier runs the mechanical checklist
  only — re-run tests, criteria mapping, secret scan.
- `heavy` (auth/security, core business logic, data migrations): full checks ①–⑤.
- Tie-breaker: when in doubt, tag heavy.

Light tasks passing shallow checks are backstopped by phase-boundary verification.

### Stall Policy (3-tier escalation)

1. **Same task fails 3 times** → orchestrator classifies the cause. If it is a plan
   problem (task too large, wrong ordering), re-plan **within spec bounds**: split or
   reorder tasks, record the re-plan in `journal.md`, continue. Limit: one re-plan per
   task.
2. **Spec contradiction or gap discovered** → halt immediately, write `report.md`
   (progress, blocker, options). The spec is the human's contract; agents never modify it.
3. **External blocker** (missing API key, service down) → halt immediately with
   `report.md`. No retry burn.

### Phase Boundaries & Context Management

- **Phase verifier**: tasks can pass individually yet fail together. On phase completion
  a dedicated verifier runs the full test suite, checks phase-level acceptance, and
  reviews cross-task integration. Only then is `handoff.md` written and the next phase
  started.
- **Worker isolation**: every task gets a brand-new implementer even if the previous one
  finished with context to spare. Workers are never reused.
- **Orchestrator diet**: the orchestrator consumes verdicts, one-line summaries, and
  file lists — never diffs or dumps.
- **30% rule**: when orchestrator context approaches 30%, it writes `handoff.md`, ends
  the turn, and instructs the user to run `/clear` then `/loopspace:resume`. This is the
  one mechanical human touch during execution (typing, not judgment); the orchestrator
  diet exists to minimize its frequency. A Claude Code session cannot clear its own
  context — this constraint is documented rather than hidden.

## Repository, Distribution, Marketplace

One repo serves as plugin and marketplace: `github.com/ardenspace/loopspace`.

```
loopspace/
├── .claude-plugin/
│   ├── plugin.json          # manifest: name, version, description, keywords
│   └── marketplace.json     # makes this repo installable as a marketplace
├── skills/
│   ├── spec/
│   │   ├── SKILL.md
│   │   └── references/      # lens question banks, panel reviewer prompts
│   ├── plan/SKILL.md
│   ├── run/SKILL.md
│   └── resume/SKILL.md
├── hooks/
│   ├── hooks.json           # SessionStart registration
│   └── session-start        # cross-platform (Windows/macOS/Linux) from day one
├── docs/
│   └── example/             # committed dogfood run: spec, plan, journal of a toy project
├── README.md                # English: philosophy, install, quickstart, loop diagram
├── CHANGELOG.md
└── LICENSE                  # MIT
```

Install experience (two lines):

```
/plugin marketplace add ardenspace/loopspace
/plugin install loopspace
```

The hook follows the superpowers `run-hook.cmd` pattern for Windows compatibility, since
the primary development environment is Windows.

## Testing the Plugin Itself

Skills are behavioral instructions, not code; verification is scenario-based:

1. **Dogfooding as the test suite.** Build a small toy project (e.g., a mini CLI tool)
   end-to-end with loopspace, against a scenario checklist:
   - spec interview covers all applicable lenses; designer lens auto-skips for no-UI
   - verification panel runs 6 lenses; convergence loop revises on blocking findings
   - state files match their schemas after every task
   - kill the session mid-phase → `/loopspace:resume` continues exactly
   - force 3 failures on a task → correct escalation and `report.md`
   - TDD evidence present in journal entries
   The dogfood run's artifacts are committed to `docs/example/` as both documentation
   and a regression baseline.
2. **Harness error handling:**
   - hook exits fast and silently in projects without `.loopspace/`
   - `resume` validates state files; on corruption it reports instead of guessing
   - state files carry `version` for future migrations

## Risks & Mitigations

- **Verification token cost** — mitigated by risk tiers (light/heavy) and the
  orchestrator diet; planning-stage rigor reduces retries, which is where the real
  token burn lives.
- **Orchestrator context exhaustion mid-run** — mitigated by the diet protocol, the 30%
  handoff rule, and the SessionStart hook reminding about unfinished runs.
- **Verifier rubber-stamping** — mitigated by explicit checklists per tier, mandatory
  test re-execution, and test-gaming detection duties in the verifier prompt.
- **Spec drift during autonomous execution** — mitigated by scope-creep checks in every
  verification and the hard rule that agents never modify the spec.
