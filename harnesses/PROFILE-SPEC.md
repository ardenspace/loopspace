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
fields, and journals the switch.

## Required fields — the questions every profile answers

Each profile is a markdown file with these exact headers (the
portability lint checks them):

- `id:` — the harness id, matching the filename.
- `tier:` — `A | B | C`, derived from the capability answers below.
- `verified:` — date of the last real loopspace run on this harness,
  or `unverified`. An unverified profile is a best-effort map, not a
  guarantee; say so when reporting. `n/a` is also valid, but only for
  a profile that is a definitional floor rather than a mappable
  harness (e.g. generic.md) — it never maps to a real harness to run
  loopspace on, so "verified" doesn't apply.
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
