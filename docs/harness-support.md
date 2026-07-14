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
| OpenCode | `harnesses/opencode.md` | A (subagents) | verified — primary local-LLM path (mini-run 2026-07-10, full hybrid run 2026-07-14) |
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
2. For each skill, create `~/.agents/skills/<name>/SKILL.md` (Codex's
   user-level Agent Skills directory — `~/.codex/prompts/` is
   deprecated) with `name:`/`description:` frontmatter and a one-line
   body: `Read <checkout>/skills/<name>/SKILL.md and follow it
   exactly.` Cover loopspec, loopplan, looprun, loopresume, loopnext;
   skip loopupdate (Claude Code-only) and loopsupervise unless you
   run unattended.
3. Invoke via the `$<name>` mention or the `/skills` picker (no
   per-skill slash commands in Codex).
4. Update: `git pull` in the checkout — the stubs need no change.

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
| verifier / panel reviewer | adversarial honesty: re-derive facts, refuse to rubber-stamp; a different model lineage than the implementer | highest |
| orchestrator | procedural discipline across a long session | high |
| implementer | coding ability, TDD discipline | medium — retries catch weakness |

Rules of thumb: frontier models hold up across all roles. Large open
coder models (30B-class) are effective implementers given small,
self-contained briefs and infrastructure limits raised well past
defaults — an output-token cap or backend request timeout that is too
low masquerades as a compliance failure (observed: what looked like
"dropped reasoning" and "skipped phase boundary" on a 35B were an
8192-token cap truncating output and a 300s backend timeout killing
the process; gridcalc runs, 2026-07). Their fitness as orchestrator is
unproven rather than refuted — the earlier "unfit" reading was mostly
those infrastructure artifacts. Small local models (≤8B) will run the
loop, but verification tends to rubber-stamp — expect Tier C-grade
guarantees regardless of the harness tier, and read the journal
skeptically.

Lineage matters as much as size: route the verifier to a different
model lineage than the implementer. Same-mind implement/verify pairs
share blind spots — a bug the implementer writes is a bug the verifier
fails to test for — and this reproduces even at frontier scale: in the
gridcalc hybrid run (2026-07-14) the only shipped bug lived at the
run's only same-lineage pairing, while the cross-lineage verifier
caught the same defect class live everywhere else.
