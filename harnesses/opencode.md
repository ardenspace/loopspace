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
