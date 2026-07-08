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
skill per loopspace skill under `~/.agents/skills/` (Codex's
user-level Agent Skills directory; the older `~/.codex/prompts/`
custom-prompt mechanism is deprecated and no longer registers slash
commands). Each stub is `~/.agents/skills/<name>/SKILL.md` with
`name:`/`description:` frontmatter and a one-line body:

    Read <checkout>/skills/<name>/SKILL.md and follow it exactly.

Invoke via the `$<name>` mention or the `/skills` picker — Codex
skills do not get per-skill slash commands. Stubs-pointing-at-checkout
(never copied bodies) keep the skills' relative references
(`../../docs/state-format.md`, `../../harnesses/`) working, and
updates become `git pull` in the checkout. Full walkthrough:
docs/harness-support.md.

## Reset & Resume
Interactive: start a new session, invoke the loopresume stub
(`$loopresume` or the `/skills` picker).
Headless (`LOOPSPACE_RESUME_CMD`):
`codex exec "Read <checkout>/skills/loopresume/SKILL.md and follow it exactly."`

## Model Routing
`codex exec -m <model>` pins a model per dispatch, so per-role routing
is a wrapper away. Local models via Codex's OSS-provider support, if
configured. Capability guidance: docs/harness-support.md.

## Question Tool
None — loopspec's interview uses turn-final questions.
