---
name: loopnext
description: Use when a loopspace run is complete and the human wants to change or extend what was built — usage feedback and journal advisories become a spec amendment and a delta plan for the next run. The human touchpoint between runs.
---

# loopnext — Spec Versioning Between Runs

Principle: **the spec is frozen within a run, versioned between runs.**
An MVP is a spec-discovery device — humans are bad at specifying on a
blank page and good at criticizing something that exists. loopnext turns
"now that I've used it…" into an amended spec and a delta plan;
execution stays with /looprun, unchanged.

Preconditions: `.loopspace/spec.md` `status: approved` and
`.loopspace/state.md` `run_status: complete`. Anything else → stop and
point to the right skill: `executing`/`halted` → looprun; no approved
spec → loopspec; `planning` on run 1 → loopplan. An interrupted loopnext
— state.md has `run: N` (N≥2) with `run_status: spec` or `planning` —
is yours: resume at the matching step below, keeping whatever the draft
already records. All file formats: `../../docs/state-format.md` relative
to this skill's base directory.

## Step 0 — Ancestor check (git projects only)

The delta plan assumes run N-1's code exists in the working tree. "The
human is standing on some branch" does not guarantee that, so verify
mechanically before touching anything:

1. Resolve the finished run's tip: `git rev-parse <current_branch>`,
   reading `current_branch` from state.md (still live — the archive
   happens later).
2. `git merge-base --is-ancestor <sha> HEAD` — exit 0 means run N-1 is
   under HEAD; continue.
3. If the branch no longer exists, fall back to searching HEAD's
   history: `git log --oneline --grep "loopspace: run complete"` — a hit
   means the completed run was merged in; continue.
4. Both fail → stop and tell the human: merge run N-1 into this branch
   (or check out the run's branch), then re-run /loopnext. Never draft a
   delta over a tree that lacks the code it amends.

No branch fields in state.md → non-git project → skip this step.

## Step 1 — Gather inputs

1. Read the journal's **latest run section only** (entries after the
   last `# ── Run` header; no header means the whole file is run 1).
   Collect every `structure-note:` and `spec-concern:` line.
2. Present each advisory to the human, one at a time, as adopt/reject —
   loopspec's "asking means waiting" mechanics apply verbatim: the
   question tool or a turn-final question, and the answer arrives in the
   user's next message, never earlier.
3. Ask what using the MVP revealed — the human's own change requests.
   Clarify each to testable-requirement precision, one question per
   message. The interview is the same hard gate as loopspec's: never
   invent an answer, never adopt "recommended defaults"; this stage
   exists precisely to extract what only the human knows.
4. **Empty-handed exit:** zero adopted advisories and zero change
   requests → say there is nothing to change and stop. No archive, no
   state change — browsing what accumulated is free.

## Step 2 — Open run N: archive first, then draft the amendment

Archive before drafting, so a crash at any later point leaves a
resumable marker instead of a torn run:

1. Create `.loopspace/archive/run-<N-1>/`; **move** `plan.md`,
   `state.md`, and `handoff.md` (if present) into it; **copy** `spec.md`
   in as a snapshot. The snapshot is the abort path's restore material —
   spec.md itself stays in place, about to be amended.
2. Write a fresh header-only `state.md`: `run: N`, `run_status: spec`.
3. Amend `spec.md` per the state-format amendment rules: set
   `status: draft` and `spec_version: N`; edit Requirements in place
   (revised keeps its R-id with a latest-only `(revised in vN)` marker;
   dropped keeps its line prefixed `[dropped in vN]`; new continues the
   numbering); update only the lens sections the delta touches; append
   the `## Amendment Log` entry with every item's origin — `human
   feedback`, `structure-note <where>`, or `spec-concern <where>`.
   A structure-cleanup adoption becomes a requirement whose criteria pin
   behavior preservation (existing tests still pass + the specific
   consolidation).

## Step 3 — Delta verification panel

Dispatch **3 reviewers in parallel**, one fresh subagent each, using the
prompts in `references/delta-panel.md`: coherence, adversarial,
verifiability. Convergence loop as in loopspec: any `[BLOCKING]` finding
→ revise the amendment, re-panel, maximum 3 rounds; blocking findings
still standing after round 3 go to the human as open decisions. The
panel reviews the *written amendment*, never your memory of the
interview.

## Step 4 — Human gate #1: the amendment

Present the amended spec.md, what changed across panel rounds, and every
remaining non-blocking finding. Three outcomes:

- **Approve** → `status: approved`, complete the Amendment Log entry's
  approval line with today's date, continue to Step 5.
- **Revise** → back to Step 2's drafting with the corrections, then
  re-panel (Step 3).
- **Reject entirely** → full abort. Restore the pre-loopnext state
  exactly: copy the spec.md snapshot back over `spec.md`; move
  `plan.md`, `state.md`, `handoff.md` out of `archive/run-<N-1>/` back
  into `.loopspace/`; delete the run-N state.md you wrote and the
  now-empty archive dir. The result must be indistinguishable from never
  having run /loopnext — without this, a rejected draft strands the
  project in a limbo loopresume forever routes back here.

## Step 5 — Delta plan

Set `run_status: planning`. Decompose **only the delta** — the R-ids the
Amendment Log entry names, nothing else — into phases and tasks in the
standard plan.md format, following loopplan's rules by reference:
machine-checkable acceptance criteria, light/heavy risk tags per
loopplan's criteria, its gold-plating audit and both-directions
tag-honesty check. Phase and task numbering restarts at 1 — the
journal's run header scopes the ids.

## Step 6 — Human gate #2: the plan

Present the delta plan; approve or revise. On approval:

1. Set plan.md `status: approved`.
2. **Branch + checkpoint (git projects only):** run N's slug is
   `<slug>-v<N>` (base slug read from the archived state.md's
   `run_branch`, never re-derived). Working-tree cleanliness and stale
   `loopspace/<slug>-v<N>/*` branches are handled exactly as loopspec's
   approval step does — ask, never decide alone. Create and check out
   `loopspace/<slug>-v<N>/run` from HEAD; record `base_branch` (the
   branch you forked from), `run_branch` and `current_branch` (both the
   new branch) in state.md. looprun reads the slug from `run_branch`, so
   its phase-branch logic works on run N unmodified.
3. Append the run header to `journal.md` (state-format journal section):
   run number, spec_version, one-line amendment summary, adopted
   advisories.
4. Set `run_status: executing`. Commit with only the loopspace files
   staged — `git add .loopspace` — message
   `loopspace: run <N> opened — <slug>-v<N>`.
5. Suggest running `/looprun`.

## Rules

- One question per message during the interview; asking means waiting.
- Advisories are adopted or rejected by the human only — never
  auto-adopt a structure-note or spec-concern into the amendment.
- Requirements are edited in place; history lives in the Amendment Log.
  Never rewrite an existing log entry.
- Never modify anything under `archive/` except the Step 4 abort
  restore.
- The panel runs on the written amendment, with fresh subagents — never
  review your own draft inline and call it a panel.
- Everything downstream of Step 6 belongs to /looprun. loopnext never
  dispatches implementers.
