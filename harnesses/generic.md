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
