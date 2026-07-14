# Harness Profile: OpenCode

id: opencode
tier: A
verified: 2026-07-10 — subcut mini-run, 4 light tasks on
ornith-1.0-35b-Q5_K_M (all roles: orchestrator, implementer, verifier).
Verifier honesty confirmed: caught a real import-setup miss during the run
and a deliberately planted green-but-wrong test/impl trap.
2026-07-14 — gridcalc hybrid full run (loopspace 0.15.2): GPT-5.5
orchestrator + verifier (ChatGPT OAuth) × ornith 35B implementer,
~12h wall clock, heavy panels and 8 regulation halts exercised; the
cross-lineage verifier caught bugs live that same-lineage suites had
missed.

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
to verifier/reviewer roles first, and make the verifier a different
model lineage than the implementer — same-mind pairs share test blind
spots even at frontier scale. A 30B-class local coder is an effective
implementer if briefs stay small and the provider's output-token cap
and request timeout are raised well past defaults (gridcalc hybrid
used a 30000-token cap and 900s timeout for a 35B on a single-slot
server; the defaults' truncation/timeouts had previously masqueraded
as compliance failures). Guidance: docs/harness-support.md.

## Local Backend Timeouts
A single-slot local server (llama.cpp et al.) is slowest exactly when a
verifier's context is largest — prompt processing at a phase boundary
can exceed the client's request timeout, killing the verifier *and* the
orchestrator's next call in the same window (observed: two consecutive
300s timeouts, gridcalc rerun 2026-07-13; the boundary's journal entry,
commit, and handoff were all lost). Mitigations, in order: raise the
provider request timeout well past worst-case prompt processing for
your hardware; keep phase-verifier prompts lean (the file-reading
budget, not the model, is what peaks); run the supervisor with
`LOOPSPACE_MAX_FASTFAIL` (default on) so a dead backend stops the run
loudly instead of burning restarts. Boundary-debt recovery (0.15.1)
makes the loss non-permanent, but only a sane timeout prevents it.

## Question Tool
None assumed — turn-final questions.
