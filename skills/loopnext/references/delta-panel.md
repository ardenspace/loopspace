# Delta Verification Panel (3 lenses)

Dispatch all 3 reviewers **in parallel**, one fresh subagent each.
Replace `{SPEC_PATH}` with the absolute path to `.loopspace/spec.md`,
`{JOURNAL_PATH}` with `.loopspace/journal.md`, and `{VN}` with the
amendment's version (e.g. `v2`).

Why only 3 (vs loopspec's 6): the product-direction lenses (company,
user, designer) review judgments the human has already made by using
the MVP and asking for exactly these changes — their questions belong
in the loopnext interview, not in a panel. The delta risks are
different: contradiction with what's frozen, adversarial gaps in the
changes, and untestable new requirements.

Every prompt ends with the same reporting contract as loopspec's panel:

> Report each finding on one line:
> `[BLOCKING]` (the amendment cannot be safely implemented as written) or
> `[NON-BLOCKING]` (worth noting, does not gate approval), followed by
> the R-id or section it applies to and one sentence. Any statement the
> spec itself marks as an assumption, unconfirmed, or "confirm at
> approval" is automatically `[BLOCKING]`. If you find nothing, return
> exactly `NO FINDINGS`. Return only the findings list — no preamble.

## 1. Coherence reviewer (delta-only lens)

You are reviewing a spec amendment against what already exists. Read
{SPEC_PATH}: the `## Amendment Log` entry for {VN} lists exactly what
changed — treat every requirement it does not name as frozen context,
not review target. Read the latest run section of {JOURNAL_PATH} (all
entries after the last `# ── Run` header, or the whole file if no
header exists) to learn what was actually built and verified. You may
read the project's code, **read-only**. Judge: (1) does any added or
revised requirement contradict an un-amended requirement? (2) does any
revision silently invalidate behavior a previous task verified — and if
so, does the amendment acknowledge that rework instead of leaving it
implicit? (3) does a dropped requirement leave any un-amended
requirement referencing or depending on it? (4) do the lens sections
still match the amended Requirements, or does the delta imply a lens
update that never happened?
[reporting contract]

## 2. Adversarial reviewer (red team)

You are red-teaming a spec amendment. Read {SPEC_PATH}; the
`## Amendment Log` entry for {VN} tells you what changed — concentrate
your attack there and on its seams with the frozen requirements.
Actively try to break it: contradictions between changed and unchanged
requirements, edge cases the revision leaves unspecified where the old
wording specified them, abuse scenarios the new surface opens (hostile
input, resource exhaustion), failure modes with no specified recovery,
and implicit assumptions that held for the MVP but break under the
amendment. Be aggressive; your job is to find what polite reviewers
miss.
[reporting contract]

## 3. Verifiability reviewer

You are auditing a spec amendment for machine-checkability. Read
{SPEC_PATH}. For EVERY requirement the {VN} Amendment Log entry marks
added or revised, answer: can this be converted into acceptance
criteria that a test can pass or fail objectively? Any that needs human
judgment ("feels fast", "cleaner", "intuitive") is [BLOCKING] — propose
a testable rewording in the same line. Requirements the entry does not
name are out of scope. This lens sets the quality ceiling of the next
run.
[reporting contract]
