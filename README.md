# loopspace

A spec-driven autonomous harness — native to Claude Code, portable beyond it. **Keep context light, verify heavy.**

## The bet

> The bet this tool makes: verification cost is bounded, unverified-failure cost is not.
> Tokens spent on relentless verification are cheaper than the compounding damage of one
> bad task polluting everything built on top of it.

Everything else in loopspace follows from that sentence: cheap, mechanical, repeatable
verification on every task, in exchange for not having to discover — three phases later —
that task 2.3 quietly broke the thing task 4.1 depends on.

## How it works

```
 idea ──▶ /loopspec ─────────▶ /loopplan ───────▶ /looprun ──────────────▶ done
           4-lens interview     phases → tasks     ┌────────────────────┐
           6-lens verify panel  criteria + risk    │ per task (fresh):  │
           human approves       human approves     │  implementer (TDD) │
                                (last touchpoint)  │  → verify:         │
                                                   │    light: 1 agent  │
                                                   │    heavy: 3 lenses │
                                                   │  stalled? burst of │
                                                   │  diverse retries   │
                                                   └──────── loop ──────┘
        state lives in .loopspace/ — kill the session, /loopresume continues

 done ──▶ use it ──▶ /loopnext ─────────────▶ /looprun ──▶ done ──▶ …
                      feedback + journal advisories
                      → spec amendment (v2, v3, …) + delta plan
                      → two human approvals, then the same loop
```

`/loopspec` turns an idea into a rigorously reviewed spec through a four-lens
interview (company, user, engineer, designer) and a six-lens verification panel, converging
over up to three rounds before a human approves it. `/loopplan` decomposes the
approved spec into phases and tasks, each with machine-checkable acceptance criteria and a
`light`/`heavy` risk tag, reviewed by a three-lens panel, then approved by a human — the
last human decision in the pipeline. `/looprun` is the autonomous loop: for every
task, a fresh implementer subagent builds it under a TDD contract, and fresh verifiers
independently check it — one mechanical verifier for `light` tasks, a three-lens panel
(correctness, security, test-integrity) for `heavy` ones — until the plan is done or the
loop halts with a report. A task that keeps failing escalates through a diversity burst
of approach-forced retries before it is allowed to halt the run.
`/loopresume` rebuilds the orchestrator's position from `.loopspace/` alone, so a
killed session, a `/clear`, or a crash never loses more than the last task's progress.
`/loopnext` closes the cycle: when a run is complete and using the result
reveals what the spec got wrong, it turns your feedback — plus the
advisories verifiers accumulated in the journal — into a versioned spec
amendment and a small delta plan, then hands back to `/looprun`. The spec
is frozen within a run and versioned between runs, so iteration never
weakens the unattended loop.

## Install

```
/plugin marketplace add ardenspace/loopspace
/plugin install loopspace@loopspace
```

To update later, run `/loopupdate` — it refreshes the marketplace,
updates the plugin, and shows the changelog entries you're picking up.
(Restart Claude Code to load the new version; a running loop should
restart at a stable point — task cycle done or handoff written.)

## Quickstart

1. Install the plugin (above).
2. In your project, run `/loopspec` and answer the interview one question at a
   time — company, user, engineer, then designer (auto-skipped if the project has no UI).
   Read the drafted `.loopspace/spec.md`, resolve any open panel findings you care about,
   and approve it.
3. Run `/loopplan`. It turns the approved spec into phases and tasks with
   acceptance criteria and risk tags, runs its own review panel, and asks you to approve
   the result. This is the last approval — after it, the loop runs unattended.
4. Run `/looprun`. The orchestrator dispatches a fresh implementer per task, then
   verification sized to the task's risk tag — one verifier for `light`, a three-lens
   panel for `heavy`. It updates `.loopspace/state.md` and `.loopspace/journal.md` after
   every task and keeps going until the plan is complete or something halts it. Retries,
   re-plans, and diversity bursts (see below) all happen without you; you only hear about
   a task again if the whole escalation ladder failed.
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
  get a **three-lens panel** — correctness (tests, criteria mapping, scope creep, and a
  mechanical failed-first proof: stash the implementation files, watch the task's tests
  actually fail without them, restore), security (secrets, injection surfaces, trust
  boundaries), and test-integrity (TDD evidence, test-gaming detection: empty tests,
  assertion-free tests, tests that mock away the behavior under test). The two read-only
  lenses go out in parallel, then correctness runs alone — a lens that stashes the tree
  can never run beside a reader — and a PASS requires all three lenses to pass. The
  lenses are complementary coverage, not votes: a security FAIL cannot be outvoted by
  two other PASSes. And findings flow both ways: a retry implementer that can prove a
  finding factually wrong (file:line, command output) contests it instead of "fixing" a
  non-problem; the next verifier must explicitly confirm or drop every contested
  finding, and a dropped finding never reaches the next retry.
- **Staged TDD contract with failed-first evidence.** Implementers work in three stages:
  understand the task's contract (contradictory or guess-requiring criteria mean
  reporting BLOCKED, not improvising), plan the change (files, test list, approach),
  then TDD — write the tests from the acceptance criteria first, show them fail,
  implement until they pass. The journal entry for a task must show the failing-first
  evidence — a task without it hasn't actually proven anything.
- **Phase boundaries verify in both directions.** When a phase's last task lands, a
  fresh phase verifier runs the full suite and checks the seams between tasks — pieces
  that passed in isolation still have to hold together. It also emits two advisories
  that never flip the verdict: structural economy (are the files and indirection layers
  this phase created proportionate to what it shipped?) and plan freshness (do the
  *next* phase's task blocks still match reality — criteria the current code already
  satisfies, stale file references, conflicts with constraints this phase surfaced?).
  Advisory notes are journaled and carried into the handoff, so a flagged task's own
  implementer sees the suspicion before building; the plan itself still changes only
  through the re-plan path.
- **Git checkpoints and branch isolation.** In a git repository the whole run lives on
  its own branch stack: spec approval creates `loopspace/<slug>/run` (spec and plan
  approvals are committed there), and execution stacks one branch per phase
  (`loopspace/<slug>/phase-N`), so each completed phase's tip is a named, verified
  pointer (the current phase's tip is still work in progress). The orchestrator
  commits after every verified task, so one bad task can always be rolled back to the
  last verified state instead of poisoning everything after it. Inside the loop a
  verifier PASS is the merge authority; the branch you started from is touched only at
  the run-complete report, where the human chooses: merge, open a PR, or leave the
  branch. A halt report names the last verified phase branch, so partial merges of
  verified work are one command.
- **Light/heavy risk tiers.** The plan tags every task `light` (config, simple CRUD,
  markup, docs — and pure in-memory logic with no I/O, no trust boundary, and no new
  dependency, however central: its whole surface is unit-testable) or `heavy` (auth,
  data migrations, state machines with concurrency or partial-failure branches, native
  platform integration, anything touching a trust boundary). Light tasks get the cheap
  mechanical checklist; heavy tasks get the three-lens panel. When a task's risk is
  ambiguous, the plan is supposed to tag it heavy, and the plan review panel checks the
  tags in both directions — an auth task tagged light blocks approval, and pure logic
  tagged heavy gets flagged for burning panel dispatches on code with no security
  surface.
- **Escalation before halting.** A failing task climbs a ladder — findings-carrying
  retries, cause classification (journaled with the verbatim verifier-finding lines that
  justify it — a cause without quotable evidence defaults to the burst, the only branch
  that is cheap to be wrong about), one re-plan if the plan is at fault, a diversity burst
  of approach-forced candidates if the task is just stubborn — and only halts the run
  when the whole ladder is exhausted, or immediately when the cause is one no retry can
  fix: a spec contradiction (`spec-gap` — agents never modify the spec, it's the human's
  contract) or an external blocker (`external-blocker` — no retries burned on a dead
  service or missing credentials). The full ladder is drawn in the next section.
- **30% context handoff.** When the orchestrator's own context approaches roughly 30%, it
  finishes the task currently in flight, overwrites `.loopspace/handoff.md`, updates
  `state.md`, and ends its turn telling you to run `/clear` then `/loopresume`. Be
  clear about what this is: a Claude Code session cannot clear its own context, so this
  handoff is a real manual step, not a formality. It's typing, not judgment, but you have
  to do it.

**Unattended runs (opt-in).** That 30% handoff is a real manual step — fine
when you're at the keyboard, impossible overnight. For truly unattended runs
there's `/loopsupervise`: it prints a one-liner you run in a separate
terminal, and a small shell supervisor (`scripts/supervise.sh`) relaunches the
run each time it hits the threshold or crashes — a fresh `claude -p
"/loopresume"` process is its own clear, so nothing needs typing. It notifies
you (Telegram, or stdout) only at the moments that matter: the run completes,
or it halts and needs your decision — a halt is never auto-resumed. This is a
power-user path that runs `claude` with `--dangerously-skip-permissions`, so
it assumes a container or a machine you trust; the normal interactive flow and
its manual handoff are unchanged.

## What happens when a task fails

You don't do anything — the escalation ladder is automatic, and every rung is journaled:

```
verifier FAIL ──▶ retry: new fresh implementer, carrying the findings   (up to 3×)
                    │
     3 failed ──▶ orchestrator classifies the cause:
                    ├─ plan problem   ──▶ one re-plan (split/reorder), continue
                    ├─ spec gap       ──▶ HALT — the spec is yours, agents never touch it
                    ├─ external       ──▶ HALT — no retries burned on a dead service
                    └─ stubborn task  ──▶ diversity burst:
                         up to 3 candidates, one at a time, tree reset to the
                         last checkpoint before each; every candidate sees all
                         failed approaches and must take a different one; each
                         is independently verified — first PASS wins
                           └─ all fail ──▶ HALT + report.md listing every approach
```

The burst exists because plain retries converge: a fresh implementer given the same task
tends to rediscover the same approach, so attempt 4 fails like attempts 1–3. Forcing each
candidate onto a genuinely different route buys the best-of-N sampling diversity that
sequential retries don't have — targeted at the only tasks that need it, the ones that
already burned three attempts and would otherwise stop the run to wait for you.

When a run does halt, `.loopspace/report.md` tells you what progressed, what blocked, and
your options; decide, then run `/looprun` again — it journals your decision, resets the
failed task, and re-enters the loop.

## State files

Everything the loop needs lives in `.loopspace/` at the project root, so a fresh session
reading only these files can continue the run exactly. Full formats, including every
field and example, are in [`docs/state-format.md`](docs/state-format.md).

| File | Content |
|---|---|
| `spec.md` | The approved spec: lens sections, requirements, approval record. Frozen after approval. |
| `plan.md` | Phase → task tree with acceptance criteria and risk tags. Frozen after approval except recorded re-plans. |
| `state.md` | Run status from spec stage onward, current phase/task pointer, per-task status and attempt counts, project facts (test/build commands) injected into every subagent. |
| `journal.md` | Append-only log across runs: every task attempt, verdict, TDD evidence, files changed — run headers scope each run's entries. |
| `archive/run-<N>/` | Prior runs' plan/state/handoff plus a spec snapshot, moved aside by `/loopnext` when the next run opens. |
| `handoff.md` | Notes for the next session, overwritten at phase boundaries and at the context threshold. |
| `report.md` | Halt report — progress, blocker, and options — written only when the run halts. |

## FAQ

**Isn't double-agent verification expensive?** Yes, it costs more tokens than a single
implementer pass — that's the bet described above: this cost is bounded and predictable,
while the cost of an unverified failure compounds as later tasks build on top of it. Risk
tiers keep the average down: most tasks should be `light` and get the cheap mechanical
checklist, and only `heavy` tasks (auth, migrations, trust boundaries) pay for the
three-lens panel. The diversity burst is the same trade at the task level: it only spends extra
candidates on tasks that already burned 3 attempts, where the alternative is halting and
waiting for a human.

**What if the spec itself is wrong?** A contradictory spec stops the run: implementers
report BLOCKED instead of guessing, and the loop halts with a `spec-gap` report — agents
never modify the spec. A spec that is consistent but *questionable* — the kind that
verifies clean because the loop faithfully built what it said — can't halt anything, so
verifiers have an advisory channel instead: a `spec-concern` line for work they'd pass
but would question as spec design. Concerns never affect a verdict, never reach an
implementer (a "the spec looks wrong" note invites improvising around a frozen spec),
and never stop the loop; they accumulate in the journal and are shown to you at the next
report you'd read anyway — a halt or the run-complete summary. The loop stays unattended;
you still get to hear "this is what you asked for, but are you sure?"

**Why can't it clear its own context?** Because a Claude Code session cannot clear its own
context — that's a harness constraint, not a design choice. loopspace works around it by
writing everything the next session needs to `.loopspace/` before the threshold, then
asking you to run `/clear` and `/loopresume` yourself. That manual step is the one
place a human touches an otherwise autonomous run.

**The run is done and I want changes — new spec?** No: run `/loopnext`.
It reads the journal's advisories (`structure-note`, `spec-concern`),
interviews you about what using the MVP revealed, amends the spec in
place (versioned, with an Amendment Log naming every change's origin),
plans only the delta, and hands back to `/looprun` — which is untouched:
to it, run 2 is just another approved spec and plan. Guard rails: it
verifies run N-1's code is actually under your HEAD before drafting
(no deltas built on a tree without the MVP), and rejecting the amendment
restores everything exactly as before.

**Other harnesses (Codex, OpenCode, local LLMs)?** Yes — the skills are a
harness-neutral core, and per-harness mechanics live in `harnesses/` (one profile
each). Quality degrades honestly by capability tier: A = full pipeline, B = panels
run sequentially, C = single-context role-swap — the tier is recorded in state.md
and every report, so a weaker run never pretends otherwise. The `.loopspace/` state
format is plain markdown, so a run started on one harness can resume on another.
Install walkthroughs, the support matrix, and model-capability guidance:
[`docs/harness-support.md`](docs/harness-support.md).

## License

MIT — see [`LICENSE`](LICENSE).
