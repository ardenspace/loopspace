# loopspace

A spec-driven autonomous harness for Claude Code. **Keep context light, verify heavy.**

## The bet

> The bet this tool makes: verification cost is bounded, unverified-failure cost is not.
> Tokens spent on relentless verification are cheaper than the compounding damage of one
> bad task polluting everything built on top of it.

Everything else in loopspace follows from that sentence: cheap, mechanical, repeatable
verification on every task, in exchange for not having to discover — three phases later —
that task 2.3 quietly broke the thing task 4.1 depends on.

## How it works

```
 idea ──▶ /loopspec ─────────▶ /loopplan ───────▶ /looprun ───────────▶ done
           4-lens interview     phases → tasks       ┌──────────────┐
           6-lens verify panel  criteria + risk tags │ per task:    │
           human approves       human approves       │  implementer │
                                (last touchpoint)    │  → verifier  │
                                                     │  fresh agents│
                                                     └──── loop ────┘
        state lives in .loopspace/ — kill the session, /loopresume continues
```

`/loopspec` turns an idea into a rigorously reviewed spec through a four-lens
interview (company, user, engineer, designer) and a six-lens verification panel, converging
over up to three rounds before a human approves it. `/loopplan` decomposes the
approved spec into phases and tasks, each with machine-checkable acceptance criteria and a
`light`/`heavy` risk tag, reviewed by a three-lens panel, then approved by a human — the
last human decision in the pipeline. `/looprun` is the autonomous loop: for every
task, a fresh implementer subagent builds it under a TDD contract and a fresh verifier
subagent independently checks it, until the plan is done or the loop halts with a report.
`/loopresume` rebuilds the orchestrator's position from `.loopspace/` alone, so a
killed session, a `/clear`, or a crash never loses more than the last task's progress.

## Install

```
/plugin marketplace add ardenspace/loopspace
/plugin install loopspace@loopspace
```

## Quickstart

1. Install the plugin (above).
2. In your project, run `/loopspec` and answer the interview one question at a
   time — company, user, engineer, then designer (auto-skipped if the project has no UI).
   Read the drafted `.loopspace/spec.md`, resolve any open panel findings you care about,
   and approve it.
3. Run `/loopplan`. It turns the approved spec into phases and tasks with
   acceptance criteria and risk tags, runs its own review panel, and asks you to approve
   the result. This is the last approval — after it, the loop runs unattended.
4. Run `/looprun`. The orchestrator dispatches a fresh implementer and a fresh
   verifier per task, updates `.loopspace/state.md` and `.loopspace/journal.md` after
   every task, and keeps going until the plan is complete or something halts it.
5. If the session dies, or the orchestrator tells you it's approaching its context
   threshold and to `/clear`, do that, then run `/loopresume` in the fresh session.
   It reads `.loopspace/` and continues exactly where it stopped — or reports why it
   halted, if it halted.

## The rules that make it work

- **Fresh subagent per task.** Every task gets a brand-new implementer, even if the
  previous one finished with context to spare. Workers are never reused across tasks —
  that's what keeps a bad assumption in task 2 from quietly leaking into task 5.
- **Independent verification.** Fresh subagents that never wrote the code check the work
  and trust nothing in the implementer's report. Light tasks get one verifier running the
  mechanical baseline: re-run the tests, map every acceptance criterion to a test that
  would fail if it were violated, scan changed files for hardcoded secrets, and check
  that the implementer's failed-first TDD evidence is present and plausible. Heavy tasks
  get a **three-lens panel** — correctness (tests, criteria mapping, scope creep),
  security (secrets, injection surfaces, trust boundaries), and test-integrity (TDD
  evidence, test-gaming detection: empty tests, assertion-free tests, tests that mock
  away the behavior under test) — dispatched in parallel, and a PASS requires all three
  lenses to pass. The lenses are complementary coverage, not votes: a security FAIL
  cannot be outvoted by two other PASSes.
- **Staged TDD contract with failed-first evidence.** Implementers work in three stages:
  understand the task's contract (contradictory or guess-requiring criteria mean
  reporting BLOCKED, not improvising), plan the change (files, test list, approach),
  then TDD — write the tests from the acceptance criteria first, show them fail,
  implement until they pass. The journal entry for a task must show the failing-first
  evidence — a task without it hasn't actually proven anything.
- **Git checkpoints.** In a git repository, the orchestrator commits after every verified
  task, so one bad task can always be rolled back to the last verified state instead of
  poisoning everything after it.
- **Light/heavy risk tiers.** The plan tags every task `light` (config, simple CRUD,
  markup, docs) or `heavy` (auth, core business logic, data migrations, anything touching
  a trust boundary). Light tasks get the cheap mechanical checklist; heavy tasks get the
  full verifier pass. When a task's risk is ambiguous, the plan is supposed to tag it
  heavy, and the plan review panel checks that the tags are honest.
- **3-tier stall policy with a diversity burst.** If a task fails 3 attempts, the
  orchestrator classifies why. A plan problem (task too large, wrong order, missing
  prerequisite) gets one re-plan within spec bounds — split or reorder, reset attempts,
  continue; a second stall on that same re-planned task halts the run and writes
  `.loopspace/report.md` with `trigger: task-stall`. A persistent implementation failure
  with no plan or spec cause gets a **diversity burst** before halting: up to 3 fresh
  candidate implementers, each shown every failed approach and required to take a
  genuinely different one, each independently verified — the first PASS wins, and only
  if all candidates fail does the run halt. Sequential retries tend to converge on the
  same approach; the burst buys the best-of-N sampling diversity that plain retries
  don't have. A spec contradiction
  or gap halts immediately with `trigger: spec-gap` — agents never modify the spec, it's
  the human's contract. An external blocker (missing credentials, a service that's down)
  halts immediately with `trigger: external-blocker`, no retries burned on an environment
  problem. A halted run resumes with `/looprun` once you've decided: it journals the
  decision, resets the failed task, and re-enters the loop.
- **30% context handoff.** When the orchestrator's own context approaches roughly 30%, it
  finishes the task currently in flight, overwrites `.loopspace/handoff.md`, updates
  `state.md`, and ends its turn telling you to run `/clear` then `/loopresume`. Be
  clear about what this is: a Claude Code session cannot clear its own context, so this
  handoff is a real manual step, not a formality. It's typing, not judgment, but you have
  to do it.

## State files

Everything the loop needs lives in `.loopspace/` at the project root, so a fresh session
reading only these files can continue the run exactly. Full formats, including every
field and example, are in [`docs/state-format.md`](docs/state-format.md).

| File | Content |
|---|---|
| `spec.md` | The approved spec: lens sections, requirements, approval record. Frozen after approval. |
| `plan.md` | Phase → task tree with acceptance criteria and risk tags. Frozen after approval except recorded re-plans. |
| `state.md` | Run status from spec stage onward, current phase/task pointer, per-task status and attempt counts, project facts (test/build commands) injected into every subagent. |
| `journal.md` | Append-only log: every task attempt, verdict, TDD evidence, files changed. |
| `handoff.md` | Notes for the next session, overwritten at phase boundaries and at the context threshold. |
| `report.md` | Halt report — progress, blocker, and options — written only when the run halts. |

## FAQ

**Isn't double-agent verification expensive?** Yes, it costs more tokens than a single
implementer pass — that's the bet described above: this cost is bounded and predictable,
while the cost of an unverified failure compounds as later tasks build on top of it. Risk
tiers keep the average down: most tasks should be `light` and get the cheap mechanical
checklist, and only `heavy` tasks (auth, core logic, migrations) pay for the three-lens
panel. The diversity burst is the same trade at the task level: it only spends extra
candidates on tasks that already burned 3 attempts, where the alternative is halting and
waiting for a human.

**Why can't it clear its own context?** Because a Claude Code session cannot clear its own
context — that's a harness constraint, not a design choice. loopspace works around it by
writing everything the next session needs to `.loopspace/` before the threshold, then
asking you to run `/clear` and `/loopresume` yourself. That manual step is the one
place a human touches an otherwise autonomous run.

**Other harnesses (Codex, etc.)?** Not in v1 — this plugin targets Claude Code only. The
`.loopspace/` state format (plain markdown, versioned, line-oriented) was designed to be
harness-neutral so an adapter for another harness could read and write the same files
later, but no such adapter exists yet.

## License

MIT — see [`LICENSE`](LICENSE).
