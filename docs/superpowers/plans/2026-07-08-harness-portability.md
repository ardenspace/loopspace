# Harness Portability (Neutral Core + Adapter Pack) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make loopspace runnable on non-Claude-Code harnesses (Codex, OpenCode, local-LLM agents) by rewriting the skill core harness-neutral and isolating per-harness mechanics into profile files, with capability tiers A/B/C recorded honestly in state and reports.

**Architecture:** Skills stop naming Claude Code primitives ("subagent", Task tool) and instead say "dispatch a fresh agent — mechanics per the harness profile". A new `harnesses/` directory holds one profile per harness plus `PROFILE-SPEC.md` (the contract: resolution procedure, required fields, tier definitions, Tier C role-swap protocol). `state.md` gains `harness:`/`tier:` fields; every human-facing report states what actually ran. A portability lint in `scripts/test/` prevents regression.

**Tech Stack:** Markdown (skills, profiles, docs), POSIX sh (lint test). No new dependencies.

**Spec:** `docs/superpowers/specs/2026-07-08-harness-portability-design.md`

## Global Constraints

- All skill/doc prose is English; line width ~72-76 chars matching existing files.
- Skills reference sibling repo files relative to their base directory: `../../docs/state-format.md`, `../../harnesses/…` (from `skills/<name>/references/` it is `../../../harnesses/…`).
- Tier values are exactly `A | B | C`. Harness ids are exactly `claude-code | codex | opencode | generic` (filename = id).
- `harness:`/`tier:` absent in an existing run's state.md = pre-0.13 run = treat as `claude-code` / `A`.
- Tests are POSIX sh, pattern of `scripts/test/supervise.test.sh`, run manually: `sh scripts/test/<name>.test.sh`.
- Never change execution semantics: Tier B changes scheduling only; Tier C changes dispatch mechanism only. Verdict rules (panel unanimity, lens merging, verifier finality) are untouched.
- `scripts/supervise.sh` is NOT modified (spec: RESUME_CMD seam already exists).
- `skills/loopupdate/SKILL.md` is NOT modified (Claude Code-only by design; lint allowlists it).
- Commit after every task: `git add <files>` then `git commit -m "<message>"`.
- Edit old-strings in this plan are verbatim from the current files; if an Edit fails to match, re-read the file — do not improvise a similar edit.

---

### Task 1: `harnesses/PROFILE-SPEC.md` — the adapter-pack contract

**Files:**
- Create: `harnesses/PROFILE-SPEC.md`

**Interfaces:**
- Produces: resolution procedure referenced by loopspec/loopnext/loopresume (Tasks 3-4); tier table + Tier C role-swap protocol referenced by every panel/dispatch edit (Tasks 3-4); required field names (`id:`, `tier:`, `verified:`, `## Dispatch`, `## Parallelism`, `## Install`, `## Reset & Resume`, `## Model Routing`, optional `## Question Tool`) consumed by the profiles (Task 5) and checked by the lint (Task 7).

- [ ] **Step 1: Write the file**

Create `harnesses/PROFILE-SPEC.md` with exactly this content:

````markdown
# Harness Profiles — the Adapter-Pack Contract

version: 1

loopspace's skills are harness-neutral: they say *what* to do
("dispatch a fresh agent with this prompt"), never *how* a specific
harness does it. The *how* lives here, one profile per harness.
Supporting a new harness = adding one profile file that answers the
questions below; the skills never change.

## Resolution — which profile applies

At pipeline entry (loopspec's draft step, loopnext's run-open step)
and at every resume (loopresume's validation step):

1. Identify the harness running this session. You know what you are —
   a Claude Code session knows it is Claude Code, a Codex session
   knows it is Codex.
2. Read `harnesses/<harness-id>.md` from the loopspace checkout (the
   same base directory the skills resolve `../../docs/state-format.md`
   against). No file matches → use `generic.md`.
3. Record `harness: <id>` and `tier: <A|B|C>` in `.loopspace/state.md`
   (fields defined in docs/state-format.md). Absent fields on an
   existing run = pre-0.13 run = `claude-code` / `A`.

A run may switch harnesses between sessions — the state files are
neutral by design. loopresume detects the mismatch, updates the
fields, and journals the switch when the tier changed.

## Required fields — the questions every profile answers

Each profile is a markdown file with these exact headers (the
portability lint checks them):

- `id:` — the harness id, matching the filename.
- `tier:` — `A | B | C`, derived from the capability answers below.
- `verified:` — date of the last real loopspace run on this harness,
  or `unverified`. An unverified profile is a best-effort map, not a
  guarantee; say so when reporting.
- `## Dispatch` — how to launch a fresh agent with a given prompt and
  get its report back. "None" is a valid answer (forces Tier C).
- `## Parallelism` — whether two read-only agents can genuinely run
  at the same time.
- `## Install` — how loopspace's skills become invocable commands on
  this harness, and how updates arrive.
- `## Reset & Resume` — the context-reset step and resume command
  (interactive), plus the headless resume command to put in
  `LOOPSPACE_RESUME_CMD` for `scripts/supervise.sh`.
- `## Model Routing` — how to pin models per role, if the harness
  can; "single model" is a valid answer. Role guidance lives in
  docs/harness-support.md, not here.
- `## Question Tool` (optional) — the structured question mechanism
  loopspec's interview prefers, if one exists.

## Tiers

| Tier | Capabilities | Semantics |
|------|--------------|-----------|
| A | fresh dispatch + parallelism | skills run as written |
| B | fresh dispatch, no parallelism | every "in parallel" dispatch runs sequentially — same prompts, same verdict rules, more wall-clock |
| C | no fresh dispatch | every dispatch becomes a role-swap (below) — weaker isolation, recorded honestly |

Tier B changes *scheduling only*. Panel unanimity, lens merging, wave
ordering (readers before correctness), verdict finality — unchanged.

## Tier C — the role-swap protocol

Without a fresh-agent mechanism, the orchestrating agent performs
each dispatch itself:

1. Write the exact dispatch prompt (the same filled template a fresh
   agent would receive) into the conversation.
2. Declare the swap: "Acting as <role> for <task/panel id>. Prior
   context outside the prompt above and the files it names is out of
   scope."
3. Perform the role using only those inputs. Verifier and reviewer
   roles re-derive every fact from files and commands — memory of
   having written the code is contamination, not context.
4. Produce the exact report format the template demands, then declare
   the swap closed and return to orchestrating.

Parallel waves become strict sequence. Verdict rules are unchanged.
The isolation is best-effort, not real: never present a Tier C panel
as independent verification — `tier: C` in state.md and the
harness/tier lines in reports carry that caveat.

## Honesty rule

Every human-facing report states what actually ran: report.md carries
`harness:` and `tier:` header lines; the run-complete report names
the harness, tier, and any per-role model routing. Weaker guarantees
are allowed — hiding them is not.
````

- [ ] **Step 2: Verify structure**

Run: `grep -c '^## ' harnesses/PROFILE-SPEC.md`
Expected: `5` (Resolution, Required fields, Tiers, Tier C, Honesty rule)

- [ ] **Step 3: Commit**

```bash
git add harnesses/PROFILE-SPEC.md
git commit -m "feat: harness adapter-pack contract (PROFILE-SPEC, tiers, role-swap protocol)"
```

---

### Task 2: state-format.md — `harness:`/`tier:` fields + report neutralization

**Files:**
- Modify: `docs/state-format.md`

**Interfaces:**
- Produces: `harness:`/`tier:` state.md fields (exact spelling) consumed by skill edits in Tasks 3-4; report.md `harness:`/`tier:` header lines; the neutral "Resume the run" awaiting line (Task 7's lint checks `Re-run /looprun` is gone).

- [ ] **Step 1: Add fields to the header-only state.md form**

Edit `docs/state-format.md` — old_string:

```
run_status: spec            # spec | planning | executing | halted | complete
```

new_string:

```
run_status: spec            # spec | planning | executing | halted | complete
harness: claude-code        # harness profile id (harnesses/ in the loopspace
                            # checkout); absent = claude-code (pre-0.13 run)
tier: A                     # A | B | C — dispatch capability from the
                            # profile; absent = A
```

- [ ] **Step 2: Add fields to the full state.md form**

old_string:

```
run_status: executing
current_phase: 2
```

new_string:

```
run_status: executing
harness: claude-code
tier: A
current_phase: 2
```

- [ ] **Step 3: Extend the preserve-unknown-headers rule**

old_string:

```
Header fields a rewriter does not own are preserved verbatim —
looprun's per-task rewrites must not drop `run:`.
```

new_string:

```
Header fields a rewriter does not own are preserved verbatim —
looprun's per-task rewrites must not drop `run:`, `harness:`, or
`tier:`.
```

- [ ] **Step 4: Neutralize the Project Facts prose**

old_string:

```
Project Facts exist so fresh subagents never re-discover the repo: loopplan
```

new_string:

```
Project Facts exist so fresh agents never re-discover the repo: loopplan
```

- [ ] **Step 5: Add harness/tier to the report.md template**

old_string:

```
trigger: spec-gap           # task-stall | phase-stall | spec-gap | external-blocker
current_branch: loopspace/<slug>/phase-3   # git projects only
```

new_string:

```
trigger: spec-gap           # task-stall | phase-stall | spec-gap | external-blocker
harness: claude-code        # what actually ran — the honesty rule in
tier: A                     # harnesses/PROFILE-SPEC.md
current_branch: loopspace/<slug>/phase-3   # git projects only
```

- [ ] **Step 6: Neutralize the awaiting line**

old_string:

```
## Awaiting
Human decision. Re-run /looprun after resolving.
```

new_string:

```
## Awaiting
Human decision. Resume the run after resolving.
```

- [ ] **Step 7: Verify**

Run: `grep -n 'harness:' docs/state-format.md | wc -l` — Expected: `3` (header form, full form, report).
Run: `grep -c 'Re-run /looprun' docs/state-format.md` — Expected: `0` (grep exits 1).
Run: `grep -c 'subagent' docs/state-format.md` — Expected: `0` (grep exits 1).

- [ ] **Step 8: Commit**

```bash
git add docs/state-format.md
git commit -m "feat: state format — harness/tier fields, neutral report resume line"
```

---

### Task 3: Neutralize the panel skills (loopspec, loopplan, loopnext + panel references)

**Files:**
- Modify: `skills/loopspec/SKILL.md`
- Modify: `skills/loopplan/SKILL.md`
- Modify: `skills/loopnext/SKILL.md`
- Modify: `skills/loopspec/references/panel-reviewers.md:3`
- Modify: `skills/loopnext/references/delta-panel.md:3`

**Interfaces:**
- Consumes: `harness:`/`tier:` field names (Task 2); PROFILE-SPEC resolution + tier semantics (Task 1).
- Produces: no interface for later tasks; behavior-preserving on Tier A.

- [ ] **Step 1: Red evidence**

Run: `grep -rn "subagent" skills/loopspec skills/loopplan skills/loopnext`
Expected: 6 hits (loopspec lines 27, 96, 148; loopplan line 54; loopnext lines 93, 177) plus reference-file line 3 hits. These all disappear by Step 8.

- [ ] **Step 2: loopspec — flow diagram, question tool, harness resolution**

Three edits to `skills/loopspec/SKILL.md`.

Edit 2a — old_string:

```
  → verification panel (6 reviewer subagents, one lens each)
```

new_string:

```
  → verification panel (6 fresh reviewers, one lens each)
```

Edit 2b — old_string:

```
ways: through the question tool (AskUserQuestion — preferred, with options),
```

new_string:

```
ways: through the harness's question tool if it has one (see the
harness profile — preferred, with options),
```

Edit 2c — old_string:

```
Create `.loopspace/state.md` (header-only form, `run_status: spec`) if it
does not exist — this is the resumable marker for the whole pipeline.
```

new_string:

```
Create `.loopspace/state.md` (header-only form, `run_status: spec`) if it
does not exist — this is the resumable marker for the whole pipeline.
Resolve the harness while you are at it: identify the harness running
this session, read `../../harnesses/<harness-id>.md` relative to this
skill's base directory (`generic.md` when nothing matches), and record
`harness:` and `tier:` in state.md — resolution rules in
`../../harnesses/PROFILE-SPEC.md`.
```

- [ ] **Step 3: loopspec — panel dispatch and rules**

Edit 3a — old_string:

```
Dispatch **6 reviewer subagents in parallel**, one per lens, using the
prompts in `references/panel-reviewers.md`: company, user, engineer,
```

new_string:

```
Dispatch **6 fresh reviewers**, one per lens — in parallel on Tier A,
sequentially on Tier B, as role-swaps on Tier C (dispatch mechanics:
harness profile; tier protocols: `../../harnesses/PROFILE-SPEC.md`) —
using the prompts in `references/panel-reviewers.md`: company, user, engineer,
```

Edit 3b — old_string:

```
- Panel reviewers are fresh subagents; never review your own draft inline
  and call it a panel.
```

new_string:

```
- Panel reviewers are fresh agents; never review your own draft inline
  and call it a panel. (Tier C's sanctioned form is the role-swap
  protocol, followed exactly — not casual self-review.)
```

- [ ] **Step 4: loopplan — panel dispatch and state rewrite**

Edit 4a — old_string:

```
Dispatch 3 fresh reviewer subagents in parallel. Reporting contract is the
same as the spec panel
```

new_string:

```
Dispatch 3 fresh reviewers — in parallel on Tier A, sequentially on
Tier B, as role-swaps on Tier C (`../../harnesses/PROFILE-SPEC.md`).
Reporting contract is the
same as the spec panel
```

Edit 4b — old_string:

```
   `attempts: 0`, and the three branch fields carried over unchanged (git
   projects).
```

new_string:

```
   `attempts: 0`, and the `harness:`/`tier:` fields and the three branch
   fields carried over unchanged (branch fields: git projects only).
```

- [ ] **Step 5: loopnext — run-open state, panel dispatch, state rewrite, rules**

Edit 5a — old_string:

```
2. Write a fresh header-only `state.md`: `run: N`, `run_status: spec`.
```

new_string:

```
2. Write a fresh header-only `state.md`: `run: N`, `run_status: spec`,
   and re-resolved `harness:`/`tier:` fields (PROFILE-SPEC resolution —
   the harness may have changed since run N-1).
```

Edit 5b — old_string:

```
Dispatch **3 reviewers in parallel**, one fresh subagent each, using the
prompts in `references/delta-panel.md`: coherence, adversarial,
```

new_string:

```
Dispatch **3 fresh reviewers**, one per lens — in parallel on Tier A,
sequentially on Tier B, as role-swaps on Tier C — using the
prompts in `references/delta-panel.md`: coherence, adversarial,
```

Edit 5c — old_string (note: 3-space continuation indent, it is a numbered-list item):

```
   section of the format doc, mirroring loopplan's approval step): keep
   `run: N`; set `run_status: executing`, `current_phase: 1`, and
```

new_string:

```
   section of the format doc, mirroring loopplan's approval step): keep
   `run: N` and the `harness:`/`tier:` fields; set
   `run_status: executing`, `current_phase: 1`, and
```

Edit 5d — old_string:

```
- The panel runs on the written amendment, with fresh subagents — never
  review your own draft inline and call it a panel.
```

new_string:

```
- The panel runs on the written amendment, with fresh agents — never
  review your own draft inline and call it a panel (Tier C: the
  role-swap protocol, followed exactly).
```

- [ ] **Step 6: panel-reviewers.md header**

Edit `skills/loopspec/references/panel-reviewers.md` — old_string:

```
Dispatch all applicable reviewers **in parallel**, one fresh subagent each.
```

new_string:

```
Dispatch all applicable reviewers, one fresh agent each — in parallel
on Tier A, sequentially on Tier B, as role-swaps on Tier C (tier
protocols: `../../../harnesses/PROFILE-SPEC.md`).
```

- [ ] **Step 7: delta-panel.md header**

Edit `skills/loopnext/references/delta-panel.md` — old_string:

```
Dispatch all 3 reviewers **in parallel**, one fresh subagent each.
```

new_string:

```
Dispatch all 3 reviewers, one fresh agent each — in parallel on
Tier A, sequentially on Tier B, as role-swaps on Tier C (tier
protocols: `../../../harnesses/PROFILE-SPEC.md`).
```

- [ ] **Step 8: Green check**

Run: `grep -rin "subagent" skills/loopspec skills/loopplan skills/loopnext`
Expected: no output (exit 1).

- [ ] **Step 9: Commit**

```bash
git add skills/loopspec skills/loopplan skills/loopnext
git commit -m "refactor: panel skills harness-neutral — fresh-agent dispatch, tier semantics, harness resolution"
```

---

### Task 4: Neutralize the loop core (looprun, loopresume, agent-prompts, loopsupervise)

**Files:**
- Modify: `skills/looprun/SKILL.md`
- Modify: `skills/looprun/references/agent-prompts.md:1-4`
- Modify: `skills/loopresume/SKILL.md`
- Modify: `skills/loopsupervise/SKILL.md`

**Interfaces:**
- Consumes: `harness:`/`tier:` fields (Task 2); PROFILE-SPEC tier semantics + role-swap protocol (Task 1).
- Produces: loopresume's harness-switch journal line format `## [harness] switched <old> → <new> (tier <A|B|C> → <A|B|C>)` (documentation only; no later task consumes it).

- [ ] **Step 1: Red evidence**

Run: `grep -rin "subagent" skills/looprun skills/loopresume skills/loopsupervise`
Expected: hits in looprun SKILL.md (lines 19, 30) and agent-prompts.md (lines 1, 4). All gone by Step 7.

- [ ] **Step 2: looprun — orchestrator contract**

Edit 2a — old_string:

```
- **Fresh subagent per task, never reused** — even if the previous one
  finished with context to spare. One task = one implementer + one
  verifier, minimum.
```

new_string:

```
- **Fresh agent per task, never reused** — even if the previous one
  finished with context to spare. One task = one implementer + one
  verifier, minimum.
- **Harness dispatch:** state.md's `harness:`/`tier:` fields say how
  fresh agents are launched — mechanics in the harness profile
  (`../../harnesses/<harness>.md`), tier semantics in
  `../../harnesses/PROFILE-SPEC.md`. Tier A: this skill as written.
  Tier B: every parallel dispatch runs sequentially — same prompts,
  same verdict rules. Tier C: dispatch becomes the role-swap protocol.
  Fields absent (pre-0.13 run) → claude-code / A.
```

Edit 2b — old_string:

```
  fresh subagents never re-discover the repo. When an implementer's report
```

new_string:

```
  fresh agents never re-discover the repo. When an implementer's report
```

- [ ] **Step 3: looprun — heavy-panel tier note**

old_string:

```
     outvoted. Any lens FAIL → merge all FAIL findings (numbered,
     lens-tagged) and take the FAIL path.
```

new_string:

```
     outvoted. Any lens FAIL → merge all FAIL findings (numbered,
     lens-tagged) and take the FAIL path. (Tier B: same waves, one
     agent at a time; Tier C: three sequential role-swaps, same lens
     order, correctness last.)
```

- [ ] **Step 4: looprun — context threshold + run-complete honesty**

Edit 4a — old_string:

```
3. Update `state.md`, then end the turn telling the user exactly:
   run `/clear`, then `/loopresume`. This is typing, not judgment —
   say so.
```

new_string:

```
3. Update `state.md`, then end the turn telling the user exactly the
   harness profile's reset-and-resume commands (Claude Code: `/clear`,
   then `/loopresume`). This is typing, not judgment — say so.
```

Edit 4b — old_string:

```
Then report totals to the
   human (tasks, retries, re-plans), plus every `spec-concern` line from
```

new_string:

```
Then report totals to the
   human (tasks, retries, re-plans) and the harness/tier the run
   executed under (state.md fields; plus per-role models if the
   profile routed any), plus every `spec-concern` line from
```

- [ ] **Step 5: agent-prompts.md — title and framing**

Edit 5a — old_string:

```
# Subagent Prompt Templates
```

new_string:

```
# Agent Prompt Templates
```

Edit 5b — old_string:

```
self-contained: subagents have NO conversation context.
```

new_string:

```
self-contained: dispatched agents have NO conversation context.
```

- [ ] **Step 6: loopresume — harness validation bullet**

Edit `skills/loopresume/SKILL.md` — old_string:

```
- No task is `in_progress` with a journal PASS entry (a crash between
```

new_string:

```
- `harness:` in state.md names a profile other than the harness
  actually running this session → re-resolve per
  `../../harnesses/PROFILE-SPEC.md`, update `harness:` (and `tier:` if
  it changed), and journal the switch:
  `## [harness] switched <old> → <new> (tier <A|B|C> → <A|B|C>)`.
  Fields absent → pre-0.13 run: treat as claude-code / A and add the
  fields at the next state write.
- No task is `in_progress` with a journal PASS entry (a crash between
```

- [ ] **Step 7: loopsupervise — RESUME_CMD pointer**

Edit `skills/loopsupervise/SKILL.md` — old_string:

```
`scripts/supervise.sh` in this plugin; this skill only checks preconditions
and prints the command to launch it elsewhere.
```

new_string:

```
`scripts/supervise.sh` in this plugin; this skill only checks preconditions
and prints the command to launch it elsewhere. On a non-Claude-Code
harness, the same supervisor drives the run through
`LOOPSPACE_RESUME_CMD` — set it to the headless resume command in your
harness profile (`../../harnesses/`).
```

- [ ] **Step 8: Green check**

Run: `grep -rin "subagent" skills/`
Expected: hits ONLY under `skills/loopupdate/` if any (currently none — loopupdate says "Claude Code", not "subagent"), i.e. no output (exit 1).

- [ ] **Step 9: Commit**

```bash
git add skills/looprun skills/loopresume skills/loopsupervise
git commit -m "refactor: loop core harness-neutral — dispatch via profile, tier branches, harness-switch handling"
```

---

### Task 5: The four harness profiles

**Files:**
- Create: `harnesses/claude-code.md`
- Create: `harnesses/codex.md`
- Create: `harnesses/opencode.md`
- Create: `harnesses/generic.md`

**Interfaces:**
- Consumes: PROFILE-SPEC required field names (Task 1) — every profile must contain `id:`, `tier:`, `verified:`, `## Dispatch`, `## Parallelism`, `## Install`, `## Reset & Resume`, `## Model Routing` (the lint enforces this in Task 7).
- Produces: headless resume commands quoted by `docs/harness-support.md` (Task 6).

**Honesty note:** codex.md and opencode.md are mapped from docs, not from a validated run — their `verified: unverified` lines are load-bearing, not placeholders. Do not "improve" them to a date; only a real dogfood run does that (see Manual Verification).

- [ ] **Step 1: claude-code.md**

Create `harnesses/claude-code.md`:

````markdown
# Harness Profile: Claude Code

id: claude-code
tier: A
verified: 2026-07-08 — loopspace's native harness; every release is
dogfooded here.

## Dispatch
Use the subagent tool (Task/Agent) — one call per fresh agent, the
filled prompt template as the payload. The agent's final message
returns as the tool result; that is the report. Never reuse an agent
for a second dispatch.

## Parallelism
Yes. Multiple subagent calls issued in a single message run
concurrently — this is how the read-only panel waves ship.

## Install
Plugin: `/plugin install loopspace@loopspace` (marketplace:
github.com/ardenspace/loopspace). Skills surface as `/loopspec`,
`/loopplan`, `/looprun`, `/loopresume`, `/loopnext`, `/loopsupervise`.
Updates: `/loopupdate` (Claude Code-only skill).

## Reset & Resume
Interactive: `/clear`, then `/loopresume`.
Headless (`LOOPSPACE_RESUME_CMD` default):
`claude -p '/loopresume' --dangerously-skip-permissions`
Note: `-p` buffers all output until the turn ends — a silent terminal
means working, not stuck.

## Model Routing
Harness-managed: dispatched agents inherit the session model. Per-role
routing is not configured through loopspace here.

## Question Tool
AskUserQuestion — loopspec's interview prefers it for multiple-choice
questions.
````

- [ ] **Step 2: codex.md**

Create `harnesses/codex.md`:

````markdown
# Harness Profile: Codex CLI

id: codex
tier: A
verified: unverified — mapped from Codex CLI documentation; validate
with a mini-run before trusting an overnight run, then update this
line with the date.

## Dispatch
No in-session subagent tool — use subprocess dispatch instead:

    codex exec "<filled prompt template>"

Each invocation is a fresh process with no conversation context —
exactly what the skills mean by "fresh agent"; process isolation is
stronger than tool-level isolation. Run it from the project root. The
report is the tail of stdout — the prompt templates already end in a
fixed report format. Approval/sandbox flags follow the user's Codex
configuration; an unattended dispatch needs Codex's
permission-skipping mode, under the same trusted-environment
assumption supervise.sh documents.

## Parallelism
Yes, cautiously: read-only dispatches (panel reviewers, the
security + test-integrity wave) may run as concurrent `codex exec`
subprocesses. Everything the skills say about the shared working tree
still applies — never run two tree-writing agents at once.

## Install
Clone the loopspace checkout somewhere stable, then create one stub
prompt per skill in `~/.codex/prompts/` so each becomes a slash
command — e.g. `~/.codex/prompts/loopspec.md` containing one line:

    Read <checkout>/skills/loopspec/SKILL.md and follow it exactly.

Stubs-pointing-at-checkout (never copied bodies) keep the skills'
relative references (`../../docs/state-format.md`, `../../harnesses/`)
working, and updates become `git pull` in the checkout. Full
walkthrough: docs/harness-support.md.

## Reset & Resume
Interactive: start a new session, run `/loopresume` (the stub).
Headless (`LOOPSPACE_RESUME_CMD`):
`codex exec "Read <checkout>/skills/loopresume/SKILL.md and follow it exactly."`

## Model Routing
`codex exec -m <model>` pins a model per dispatch, so per-role routing
is a wrapper away. Local models via Codex's OSS-provider support, if
configured. Capability guidance: docs/harness-support.md.

## Question Tool
None — loopspec's interview uses turn-final questions.
````

- [ ] **Step 3: opencode.md**

Create `harnesses/opencode.md`:

````markdown
# Harness Profile: OpenCode

id: opencode
tier: A
verified: unverified — mapped from OpenCode documentation; validate
with a mini-run, then update this line with the date.

## Dispatch
OpenCode has subagent primitives: invoke a task-scoped agent with the
filled prompt template as its instruction. Fallback that always
works: subprocess dispatch — `opencode run "<filled prompt template>"`
from the project root, a fresh process per dispatch, report on stdout.

## Parallelism
Subagents: yes. Subprocess fallback: the same cautious rule as the
Codex profile — concurrent processes for read-only dispatches only;
never two tree-writing agents at once.

## Install
Clone the loopspace checkout, then create one stub command per skill
in `.opencode/command/` (project-level) or the global command
directory, body:

    Read <checkout>/skills/<name>/SKILL.md and follow it exactly.

Updates: `git pull` in the checkout. Full walkthrough:
docs/harness-support.md.

## Reset & Resume
Interactive: new session, `/loopresume` stub command.
Headless (`LOOPSPACE_RESUME_CMD`):
`opencode run "Read <checkout>/skills/loopresume/SKILL.md and follow it exactly."`

## Model Routing
Per-agent model configuration, including local providers (Ollama et
al.) — this is the primary local-LLM path. Route your strongest model
to verifier/reviewer roles first; guidance: docs/harness-support.md.

## Question Tool
None assumed — turn-final questions.
````

- [ ] **Step 4: generic.md**

Create `harnesses/generic.md`:

````markdown
# Harness Profile: Generic (any agent — the Tier C floor)

id: generic
tier: C
verified: n/a — this profile assumes nothing beyond file access,
shell access, and the ability to follow markdown instructions.

Any agentic harness that can read files, run commands, and follow
instructions can run loopspace at Tier C. If your harness can spawn
fresh agents — or run a CLI subprocess per dispatch — write it a real
profile instead: PROFILE-SPEC.md says what to answer.

## Bootstrap
Tell your agent:

    Read <checkout>/harnesses/generic.md, then read
    <checkout>/skills/loopresume/SKILL.md and follow it, operating on
    <project directory>.

loopresume routes to the right pipeline stage from `.loopspace/`
state; for a brand-new project point it at
`<checkout>/skills/loopspec/SKILL.md` instead.

## Dispatch
None. Every "dispatch a fresh agent" instruction in the skills runs
as a role-swap — PROFILE-SPEC.md's Tier C protocol, followed exactly.

## Parallelism
No. All waves and panels run in strict sequence.

## Install
None. Skills are read directly from the loopspace checkout; updates
are `git pull`.

## Reset & Resume
Interactive: start a new conversation and repeat the Bootstrap line.
Headless (`LOOPSPACE_RESUME_CMD`): whatever one-shot command your
harness offers, wrapping the Bootstrap line; if it has none,
supervise.sh cannot drive this harness.

## Model Routing
Single model — whatever the harness runs. The guarantee floor follows
the model (see docs/harness-support.md); `tier: C` is recorded in
state.md and every report either way.
````

- [ ] **Step 5: Verify required fields**

Run:
```bash
for f in harnesses/claude-code.md harnesses/codex.md harnesses/opencode.md harnesses/generic.md; do
  for field in 'id:' 'tier:' 'verified:' '## Dispatch' '## Parallelism' '## Install' '## Reset & Resume' '## Model Routing'; do
    grep -qF "$field" "$f" || echo "MISSING $field in $f"
  done
done
```
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add harnesses/
git commit -m "feat: harness profiles — claude-code (verified), codex, opencode, generic Tier C floor"
```

---

### Task 6: docs/harness-support.md + README

**Files:**
- Create: `docs/harness-support.md`
- Modify: `README.md` (tagline line 3, "Other harnesses" FAQ)

**Interfaces:**
- Consumes: profile headless commands (Task 5), tier definitions (Task 1).

- [ ] **Step 1: Write docs/harness-support.md**

````markdown
# Harness Support

loopspace's skills are a harness-neutral core; per-harness mechanics
live in `harnesses/` — one profile each, contract in
`harnesses/PROFILE-SPEC.md`. The `.loopspace/` state format is plain
markdown, so a run started on one harness can be resumed on another;
loopresume records the switch.

## Support matrix

| Harness | Profile | Tier | Status |
|---------|---------|------|--------|
| Claude Code | `harnesses/claude-code.md` | A | verified — native home, plugin install |
| Codex CLI | `harnesses/codex.md` | A (subprocess dispatch) | unverified — validate with a mini-run |
| OpenCode | `harnesses/opencode.md` | A (subagents) | unverified — primary local-LLM path |
| anything else | `harnesses/generic.md` | C | the floor — role-swap protocol |

Tier meanings (definitions in PROFILE-SPEC.md): **A** — full pipeline
as written; **B** — same pipeline, parallel waves run sequentially;
**C** — single context, role-swap protocol: runs everywhere, weaker
isolation, recorded honestly in state.md and every report.

## Install

### Claude Code
`/plugin install loopspace@loopspace`; update via `/loopupdate`.

### Codex CLI
1. `git clone https://github.com/ardenspace/loopspace` somewhere
   stable.
2. For each skill, create `~/.codex/prompts/<name>.md` containing one
   line: `Read <checkout>/skills/<name>/SKILL.md and follow it
   exactly.` Cover loopspec, loopplan, looprun, loopresume, loopnext;
   skip loopupdate (Claude Code-only) and loopsupervise unless you
   run unattended.
3. Update: `git pull` in the checkout — the stubs need no change.

### OpenCode
Same as Codex, with stubs in `.opencode/command/` (or the global
command directory).

### Anything else
No install — see the Bootstrap section of `harnesses/generic.md`.

## Unattended runs (supervise.sh)

`scripts/supervise.sh` is already harness-neutral: point
`LOOPSPACE_RESUME_CMD` at your profile's headless resume command.

    # Claude Code (the default)
    LOOPSPACE_RESUME_CMD="claude -p '/loopresume' --dangerously-skip-permissions"
    # Codex CLI
    LOOPSPACE_RESUME_CMD="codex exec 'Read <checkout>/skills/loopresume/SKILL.md and follow it exactly.'"
    # OpenCode
    LOOPSPACE_RESUME_CMD="opencode run 'Read <checkout>/skills/loopresume/SKILL.md and follow it exactly.'"

The trusted-environment warning applies on every harness: an
unattended run needs permission-skipping, so use a container or a
dedicated machine.

## Model capability guidance (recommendations, not gates)

loopspace never blocks a model; it records what ran. But the
pipeline's guarantees assume the model can follow long procedural
skills and fail its own work honestly. Where that assumption is
thinnest, route your strongest model:

| Role | What it needs | Strong-model priority |
|------|---------------|-----------------------|
| verifier / panel reviewer | adversarial honesty: re-derive facts, refuse to rubber-stamp | highest |
| orchestrator | procedural discipline across a long session | high |
| implementer | coding ability, TDD discipline | medium — retries catch weakness |

Rules of thumb: frontier models and large open coder models
(30B-class and up) hold up across all roles; small local models (≤8B)
will run the loop, but verification tends to rubber-stamp — expect
Tier C-grade guarantees regardless of the harness tier, and read the
journal skeptically.
````

- [ ] **Step 2: README tagline**

Edit `README.md` — old_string:

```
A spec-driven autonomous harness for Claude Code. **Keep context light, verify heavy.**
```

new_string:

```
A spec-driven autonomous harness — native to Claude Code, portable beyond it. **Keep context light, verify heavy.**
```

- [ ] **Step 3: README FAQ rewrite**

old_string:

```
**Other harnesses (Codex, etc.)?** Not in v1 — this plugin targets Claude Code only. The
`.loopspace/` state format (plain markdown, versioned, line-oriented) was designed to be
harness-neutral so an adapter for another harness could read and write the same files
later, but no such adapter exists yet.
```

new_string:

```
**Other harnesses (Codex, OpenCode, local LLMs)?** Yes — the skills are a
harness-neutral core, and per-harness mechanics live in `harnesses/` (one profile
each). Quality degrades honestly by capability tier: A = full pipeline, B = panels
run sequentially, C = single-context role-swap — the tier is recorded in state.md
and every report, so a weaker run never pretends otherwise. The `.loopspace/` state
format is plain markdown, so a run started on one harness can resume on another.
Install walkthroughs, the support matrix, and model-capability guidance:
[`docs/harness-support.md`](docs/harness-support.md).
```

- [ ] **Step 4: Verify**

Run: `grep -c 'harness-support' README.md` — Expected: `1`.
Run: `grep -n 'Not in v1' README.md` — Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add docs/harness-support.md README.md
git commit -m "docs: harness support matrix, install walkthroughs, model guidance; README portability"
```

---

### Task 7: Portability lint

**Files:**
- Create: `scripts/test/portability.test.sh`

**Interfaces:**
- Consumes: profile required-field names (Task 1), the neutralized skills (Tasks 3-4), state-format awaiting line (Task 2), profiles (Task 5).

- [ ] **Step 1: Write the test**

Create `scripts/test/portability.test.sh`:

```sh
#!/bin/sh
# Portability lint: the skill core must stay harness-neutral.
# POSIX sh. Run: sh scripts/test/portability.test.sh
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
ok()   { PASS=$((PASS+1)); }

# 1) Harness-specific terms are banned in skill bodies.
#    Allowlist: skills/loopupdate (Claude Code-only by design).
hits="$(find "$ROOT/skills" -name '*.md' ! -path '*/loopupdate/*' \
  -exec grep -niE 'subagent|task tool' {} + 2>/dev/null)" || true
if [ -n "${hits:-}" ]; then
  fail "harness-specific terms in the neutral core:
$hits"
else ok; fi

# 2) The report template must not require a slash command to resume.
if grep -q 'Re-run /looprun' "$ROOT/docs/state-format.md"; then
  fail "state-format.md report template still says 'Re-run /looprun'"
else ok; fi

# 3) Every harness profile answers PROFILE-SPEC's required questions.
found_profile=0
for f in "$ROOT"/harnesses/*.md; do
  base="$(basename "$f")"
  [ "$base" = "PROFILE-SPEC.md" ] && continue
  found_profile=1
  for field in 'id:' 'tier:' 'verified:' '## Dispatch' '## Parallelism' '## Install' '## Reset & Resume' '## Model Routing'; do
    if grep -qF "$field" "$f"; then ok; else fail "$base missing '$field'"; fi
  done
done
[ "$found_profile" -eq 1 ] || fail "no harness profiles found in harnesses/"

echo "portability lint: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: Run it — expect PASS**

Run: `sh scripts/test/portability.test.sh`
Expected: `portability lint: 34 passed, 0 failed` (1 term check + 1 report check + 4 profiles x 8 fields), exit 0.

- [ ] **Step 3: Prove it catches regressions (red check, then revert)**

```bash
printf 'temporary: dispatch a subagent\n' >> skills/looprun/SKILL.md
sh scripts/test/portability.test.sh; echo "exit=$?"
git checkout -- skills/looprun/SKILL.md
```
Expected: `FAIL: harness-specific terms...` and `exit=1`, then the revert restores the file.

- [ ] **Step 4: Full suite green**

Run: `sh scripts/test/supervise.test.sh && sh scripts/test/portability.test.sh`
Expected: both report 0 failed.

- [ ] **Step 5: Commit**

```bash
git add scripts/test/portability.test.sh
git commit -m "test: portability lint — term ban, neutral resume line, profile completeness"
```

---

### Task 8: CHANGELOG + version bump

**Files:**
- Modify: `CHANGELOG.md` (new 0.13.0 section above 0.12.0)
- Modify: `.claude-plugin/plugin.json` (version, description)

**Interfaces:** none — release bookkeeping.

- [ ] **Step 1: CHANGELOG entry**

Insert directly under the `# Changelog` line:

```markdown
## 0.13.0 — 2026-07-08

- **Harness portability (backlog item 7) — neutral core + adapter
  pack.** The skills no longer name Claude Code primitives: every
  "dispatch a fresh agent" resolves through a harness profile in
  `harnesses/` (contract: `PROFILE-SPEC.md`). Capability tiers degrade
  honestly — A: full pipeline (Claude Code, and Codex/OpenCode via
  subprocess/subagent dispatch), B: panels run sequentially, C:
  single-context role-swap protocol (the `generic.md` floor: any agent
  that reads files and follows instructions, local LLMs included) —
  and the tier is recorded in `state.md` (`harness:`/`tier:` fields)
  and every report. Codex/OpenCode profiles ship `unverified` until a
  real mini-run validates them. New: `docs/harness-support.md`
  (support matrix, install walkthroughs, `LOOPSPACE_RESUME_CMD` values
  per harness, model-capability guidance) and a portability lint
  (`scripts/test/portability.test.sh`). Absent fields on an existing
  run mean `claude-code`/`A` — no migration needed.
```

- [ ] **Step 2: plugin.json**

Edit `.claude-plugin/plugin.json`:
- `"version": "0.12.0"` → `"version": "0.13.0"`
- In `"description"`, `fresh subagents per task` → `fresh agents per task`.

(If the description does not contain that phrase verbatim, read the file and neutralize any "subagent" wording; leave the rest untouched.)

- [ ] **Step 3: Verify + full suite**

Run: `grep '"version"' .claude-plugin/plugin.json` — Expected: `0.13.0`.
Run: `sh scripts/test/supervise.test.sh && sh scripts/test/portability.test.sh` — Expected: both 0 failed.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "docs: changelog + bump to 0.13.0 (harness portability)"
```

---

## Manual Verification (user, after implementation)

Not tasks — these need the user's environments, and they close the spec's acceptance:

1. **Codex mini-run (spec acceptance 1):** on a machine with Codex CLI, follow `docs/harness-support.md` install, run a small spec through the pipeline. Confirm `harness: codex` / `tier: A` land in state.md and the run-complete report. Then update `harnesses/codex.md`'s `verified:` line with the date. If `codex exec` flags or prompt-stub behavior differ from the profile, fix the profile — that is the profile's job; the skills should not need touching.
2. **Claude Code no-regression (spec acceptance 2):** a mini-run on Claude Code; confirm it behaves exactly as 0.12.0 and records `harness: claude-code` / `tier: A`.
3. **Backlog ledger:** mark item 7 in `docs/backlog-2026-07-05.md` — gate released 2026-07-08 (user demand), spec + this plan linked, status per dogfood outcome.

## Notes for reviewers

- The spec's lint example mentioned banning "Claude Code" as a string; the shipped lint bans `subagent`/`task tool` only. Deliberate: skills legitimately keep parenthetical Claude Code examples ("Claude Code: `/clear`"), and the audit's actual leak class was primitive terminology, not the product name.
- `interview-lenses.md`, Template bodies in `agent-prompts.md`, and `scripts/supervise.sh` need no changes (already neutral / already seamed).
- Tier B has no shipping profile — it exists as a semantic so a future profile (a harness with dispatch but no concurrency) is one file, zero skill edits.
