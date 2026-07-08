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
