# Harness Profile: Claude Code

id: claude-code
tier: A
verified: 2026-07-08 — loopspace's native harness; every release is
dogfooted here.

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
