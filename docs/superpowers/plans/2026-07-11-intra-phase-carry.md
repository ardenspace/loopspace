# Intra-phase Carry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 같은 phase 안의 이전 태스크 산출물(files+exports)을 모든 디스패치에 주입하고, 병렬 재구현을 태스크 verifier(1차)와 phase verifier(백스톱) 양층에서 FAIL로 강제한다.

**Architecture:** implementer가 `exports:` 라인을 자가보고 → 저널에 기록 → orchestrator가 저널의 현재-phase done 태스크 `files:`+`exports:`로 "PRIOR WORK THIS PHASE" 블록을 조립(코드는 읽지 않음 — diet 유지) → implementer·verifier 디스패치 모두에 주입. 전 변경이 markdown 프롬프트/스킬/문서 편집이며, 검증은 grep 앵커 확인 + `sh scripts/test/portability.test.sh`.

**Tech Stack:** markdown 스킬 파일 (Claude Code plugin), POSIX sh lint.

**Spec:** `docs/superpowers/specs/2026-07-11-intra-phase-carry-design.md`

## Global Constraints

- 스킬 본문(`skills/**/*.md`)에 `subagent`, `task tool`, `AskUserQuestion` 단어 금지 — portability lint가 잡는다 (`scripts/test/portability.test.sh` check 1). 새 문구는 "fresh agent", "dispatch", "verifier" 어휘를 쓴다.
- 블록 이름은 어디서나 정확히 `PRIOR WORK THIS PHASE`. 저널 라인은 정확히 `- exports:`.
- 기존 advisory(structural economy, plan freshness, spec-concern)는 문구·지위 불변. 신설 blocking check와 섞지 않는다.
- 기존 파일의 문체(영어, 줄바꿈 ~72자, 하이픈 불릿)를 따른다.
- 각 태스크 끝: `sh scripts/test/portability.test.sh` 통과 확인 후 커밋.

---

### Task 1: Template A — PRIOR WORK 입력 블록 + exports 자가보고

**Files:**
- Modify: `skills/looprun/references/agent-prompts.md` (Template A: 입력 블록은 HANDOFF NOTES 뒤, `exports:`는 REPORT BACK `- files:` 뒤)

**Interfaces:**
- Produces: 입력 블록 헤더 `PRIOR WORK THIS PHASE (already in the tree, built by earlier tasks):` — Task 2·3·4가 같은 블록을 verifier 입력으로 참조. 리포트 라인 `- exports:` — Task 4(SKILL.md 조립 규칙)와 Task 5(state-format 저널 예시)가 소비.

- [ ] **Step 1: HANDOFF NOTES와 PRIOR VERIFIER FINDINGS 사이에 입력 블록 삽입**

Edit `skills/looprun/references/agent-prompts.md` — old_string:

```
HANDOFF NOTES (from previous work):
{handoff.md "Next session must know" + "Watch out for" bullets, or "none"}

PRIOR VERIFIER FINDINGS (retry only):
```

new_string:

```
HANDOFF NOTES (from previous work):
{handoff.md "Next session must know" + "Watch out for" bullets, or "none"}

PRIOR WORK THIS PHASE (already in the tree, built by earlier tasks):
{one line per done task in the current phase, assembled from journal.md:
"[<id>] files: <files> — exports: <exports>" — or "none yet: you are the
first task of this phase"}
If a listed export already provides something this task needs, import or
extend it — never build a parallel implementation. Re-implementing a
listed capability is a verifier FAIL, unless this task's acceptance
criteria explicitly require a separate implementation.

PRIOR VERIFIER FINDINGS (retry only):
```

- [ ] **Step 2: REPORT BACK에 exports 라인 추가**

Edit — old_string:

```
- files: <comma-separated files created/modified>
- facts: <only if a PROJECT FACTS line is wrong/missing: the correction>
```

new_string:

```
- files: <comma-separated files created/modified>
- exports: <public symbols this task added or changed for use outside it,
  module-qualified, one line (e.g. "kvtx.database.Store — set/get/delete/
  count, O(1) two-dict") — or "none">
- facts: <only if a PROJECT FACTS line is wrong/missing: the correction>
```

- [ ] **Step 3: 검증**

Run: `grep -c "PRIOR WORK THIS PHASE" skills/looprun/references/agent-prompts.md`
Expected: `1`
Run: `grep -n "^- exports:" skills/looprun/references/agent-prompts.md`
Expected: Template A REPORT BACK 안 1곳.
Run: `sh scripts/test/portability.test.sh`
Expected: `portability lint: N passed, 0 failed`

- [ ] **Step 4: Commit**

```bash
git add skills/looprun/references/agent-prompts.md
git commit -m "feat: template A — PRIOR WORK THIS PHASE input block + exports self-report"
```

---

### Task 2: Templates B·D — verifier 쪽 중복 체크

**Files:**
- Modify: `skills/looprun/references/agent-prompts.md` (Template B: 입력 블록 + check 6, Template D: 입력 블록 + correctness check 5)

**Interfaces:**
- Consumes: Task 1의 블록 헤더 문구 (동일하게 반복).
- Produces: B check 6·D correctness check 5 — Task 6(README)이 서술로 참조.

- [ ] **Step 1: Template B에 입력 블록 삽입**

Template B의 CONTESTED FINDINGS 앞. old_string (B 안에서 유일 — CHECKS (mechanical)가 뒤따르는 것으로 구분):

```
CONTESTED FINDINGS (retry only):
{contested: lines from the implementer's report, or "none"}

CHECKS (mechanical):
```

new_string:

```
CONTESTED FINDINGS (retry only):
{contested: lines from the implementer's report, or "none"}

PRIOR WORK THIS PHASE (already in the tree, built by earlier tasks):
{same block the implementer received — or "none yet"}

CHECKS (mechanical):
```

- [ ] **Step 2: Template B에 check 6 추가**

old_string:

```
5. Contested findings: for each one, re-derive the fact yourself, then
   either confirm the finding (say why the evidence doesn't hold) or drop
   it — a dropped finding must not count against this verdict. Ignore
   contests that dispute a judgment call or carry no concrete evidence.
```

new_string:

```
5. Contested findings: for each one, re-derive the fact yourself, then
   either confirm the finding (say why the evidence doesn't hold) or drop
   it — a dropped finding must not count against this verdict. Ignore
   contests that dispute a judgment call or carry no concrete evidence.
6. Prior-work reuse: if PRIOR WORK THIS PHASE lists an export that already
   provides something this task needed, the implementation must import or
   extend it. A parallel re-implementation — a class/function duplicating
   a listed capability, or scaffolding copied from it that is written but
   never read — is a FAIL naming what should have been extended, unless
   the acceptance criteria explicitly require a separate implementation.
   Block says "none yet" → skip this check.
```

- [ ] **Step 3: Template D에 입력 블록 삽입**

Template D의 YOUR LENS 앞. old_string:

```
CONTESTED FINDINGS (retry only):
{contested: lines from the implementer's report, or "none"}

YOUR LENS: {correctness | security | test-integrity}
```

new_string:

```
CONTESTED FINDINGS (retry only):
{contested: lines from the implementer's report, or "none"}

PRIOR WORK THIS PHASE (already in the tree, built by earlier tasks):
{same block the implementer received — or "none yet"}

YOUR LENS: {correctness | security | test-integrity}
```

- [ ] **Step 4: Template D correctness 렌즈에 check 5 추가**

old_string (check 4 끝과 security 렌즈 헤더 사이):

```
   that still pass without the implementation don't exercise it: FAIL,
   naming those tests. No implementation files in the list, or not a git
   repository → skip this check and say so in your note.

CHECKS — security lens (read-only, never run the test suite):
```

new_string:

```
   that still pass without the implementation don't exercise it: FAIL,
   naming those tests. No implementation files in the list, or not a git
   repository → skip this check and say so in your note.
5. Prior-work reuse: if PRIOR WORK THIS PHASE lists an export that already
   provides something this task needed, the implementation must import or
   extend it. A parallel re-implementation — a class/function duplicating
   a listed capability, or scaffolding copied from it that is written but
   never read — is a FAIL naming what should have been extended, unless
   the acceptance criteria explicitly require a separate implementation.
   Block says "none yet" → skip this check.

CHECKS — security lens (read-only, never run the test suite):
```

- [ ] **Step 5: 검증**

Run: `grep -c "PRIOR WORK THIS PHASE" skills/looprun/references/agent-prompts.md`
Expected: `5` (A 입력 헤더 1 + B 입력 헤더·check 6 본문 2 + D 입력 헤더·correctness check 5 본문 2)
Run: `awk '/## Template B/,/## Template D/' skills/looprun/references/agent-prompts.md | grep -c "^6\. Prior-work reuse"`
Expected: `1`
Run: `sh scripts/test/portability.test.sh`
Expected: 0 failed

- [ ] **Step 6: Commit**

```bash
git add skills/looprun/references/agent-prompts.md
git commit -m "feat: templates B/D — prior-work reuse check (task-layer duplication FAIL)"
```

---

### Task 3: Template C — exports 입력 + blocking 중복 check 5 (기존 5·6 → 6·7)

**Files:**
- Modify: `skills/looprun/references/agent-prompts.md` (Template C)

**Interfaces:**
- Consumes: 저널의 `- exports:` 라인 (Task 1이 정의).
- Produces: blocking check 5 — FAIL 시 기존 `offending-task`/`findings` 리포트 필드를 그대로 사용 (신규 필드 없음).

- [ ] **Step 1: TASKS COMPLETED에 exports 포함**

old_string:

```
TASKS COMPLETED: {task ids + one-line summaries from journal.md}
```

new_string:

```
TASKS COMPLETED: {task ids + one-line summaries + exports: lines from
journal.md}
```

- [ ] **Step 2: check 5 신설 + 기존 5·6 renumber**

old_string:

```
4. Cross-task scope drift: does the sum of tasks match the phase goal?
5. Structural economy (advisory — never affects the verdict): are the
   files and indirection layers this phase created proportionate to what
   it shipped? Flag files that could be merged and abstractions with a
   single caller. Do not flag seams the acceptance criteria required
   (test isolation, injected fakes).
6. Plan freshness (advisory — never affects the verdict; skip if NEXT
```

new_string:

```
4. Cross-task scope drift: does the sum of tasks match the phase goal?
5. Intra-phase duplication (affects the verdict): did a later task in
   this phase re-implement in parallel a capability an earlier task
   built — twin classes/functions doing the same job, or scaffolding
   copied from an earlier task that is written but never read (dead
   indexes, dead fields)? Judge from the exports lines and the tree.
   Exclude separate implementations the acceptance criteria explicitly
   required, and seams required for test isolation. FAIL → offending-task
   is the later task; findings name what it should have extended.
6. Structural economy (advisory — never affects the verdict): are the
   files and indirection layers this phase created proportionate to what
   it shipped? Flag files that could be merged and abstractions with a
   single caller. Do not flag seams the acceptance criteria required
   (test isolation, injected fakes).
7. Plan freshness (advisory — never affects the verdict; skip if NEXT
```

- [ ] **Step 3: 검증**

Run: `awk '/## Template C/,0' skills/looprun/references/agent-prompts.md | grep -n "^[0-9]\."`
Expected: 1–7 연속 번호, 5가 Intra-phase duplication, 6 Structural economy, 7 Plan freshness.
Run: `grep -rn "check 5\|check 6\|check 7" skills/ docs/state-format.md README.md CHANGELOG.md`
Expected: 매치 없음 (번호를 참조하는 외부 문서가 없음을 재확인).
Run: `sh scripts/test/portability.test.sh`
Expected: 0 failed

- [ ] **Step 4: Commit**

```bash
git add skills/looprun/references/agent-prompts.md
git commit -m "feat: template C — blocking intra-phase duplication check, advisories renumbered"
```

---

### Task 4: looprun SKILL.md — 조립 규칙 + 전달 지점

**Files:**
- Modify: `skills/looprun/SKILL.md` (Per-Task Cycle step 1 carries 목록, step 3 verifier 디스패치, step 4 저널링)

**Interfaces:**
- Consumes: `PRIOR WORK THIS PHASE` 블록명, 저널 `- exports:` 라인.
- Produces: 조립 규칙 (저널만 읽음, 코드는 안 읽음 — diet 유지).

- [ ] **Step 1: carries 목록에 PRIOR WORK 추가**

old_string:

```
   - carries: Project Facts, spec excerpt (only the R-ids this task
     covers), the task block from plan.md, current handoff.md notes
```

new_string:

```
   - carries: Project Facts, spec excerpt (only the R-ids this task
     covers), the task block from plan.md, current handoff.md notes,
     and the PRIOR WORK THIS PHASE block — assembled from journal.md:
     one line per done task in the current phase, its `files:` and
     `exports:` lines verbatim ("none yet" on the phase's first task;
     an old journal entry without an exports line contributes files
     only). Assembly reads the journal, never project code — the diet
     holds.
```

- [ ] **Step 2: step 3에 verifier 전달 규칙 추가**

old_string:

```
3. Dispatch VERIFICATION (fresh, never the implementer)
   - risk: light → one verifier, template B
```

new_string:

```
3. Dispatch VERIFICATION (fresh, never the implementer)
   - every verifier dispatch carries the same PRIOR WORK THIS PHASE
     block the implementer received
   - risk: light → one verifier, template B
```

- [ ] **Step 3: step 4 PASS 저널링에 exports 기록 명시**

old_string:

```
4. PASS → state.md: task done; git checkpoint commit; journal entry
   (heavy: record all three lens verdicts); next task (fresh implementer)
```

new_string:

```
4. PASS → state.md: task done; git checkpoint commit; journal entry
   including the implementer's `exports:` line (heavy: record all three
   lens verdicts); next task (fresh implementer)
```

- [ ] **Step 4: 검증**

Run: `grep -c "PRIOR WORK THIS PHASE" skills/looprun/SKILL.md`
Expected: `2`
Run: `sh scripts/test/portability.test.sh`
Expected: 0 failed

- [ ] **Step 5: Commit**

```bash
git add skills/looprun/SKILL.md
git commit -m "feat: looprun — assemble PRIOR WORK block from journal, carry to implementer and verifier"
```

---

### Task 5: state-format.md 저널 예시 + loopplan 너지

**Files:**
- Modify: `docs/state-format.md` (journal PASS 엔트리 예시)
- Modify: `skills/loopplan/SKILL.md` (Step 1 Tasks 절 끝)

**Interfaces:**
- Consumes: `- exports:` 라인 형식 (Task 1과 동일 의미).

- [ ] **Step 1: 저널 PASS 엔트리 예시에 exports 라인**

Edit `docs/state-format.md` — old_string:

```
## [1.1] attempt 1 — PASS
- implementer: <one-line summary>
- tdd-evidence: <test file>:<first-fail confirmed>
- verifier: PASS — <one-line note>
- files: <comma-separated changed files>
```

new_string:

```
## [1.1] attempt 1 — PASS
- implementer: <one-line summary>
- tdd-evidence: <test file>:<first-fail confirmed>
- verifier: PASS — <one-line note>
- files: <comma-separated changed files>
- exports: <public symbols the task added or changed for use outside it,
  module-qualified — or "none". looprun assembles the next dispatches'
  PRIOR WORK THIS PHASE block from these lines>
```

- [ ] **Step 2: loopplan Tasks 절에 extends 너지**

Edit `skills/loopplan/SKILL.md` — old_string:

```
  integration, anything touching a trust boundary). **When in doubt, tag
  heavy.**
```

new_string:

```
  integration, anything touching a trust boundary). **When in doubt, tag
  heavy.**

When a later task builds on an earlier task's output, name the dependency
in its task block (e.g. an acceptance line "extends Store from 1.1"). The
loop carries prior-task exports into every dispatch either way; naming it
at plan time removes the ambiguity that invites a parallel
re-implementation.
```

- [ ] **Step 3: 검증**

Run: `grep -n "exports" docs/state-format.md skills/loopplan/SKILL.md`
Expected: state-format 저널 예시 1곳, loopplan 너지 1곳.
Run: `sh scripts/test/portability.test.sh`
Expected: 0 failed

- [ ] **Step 4: Commit**

```bash
git add docs/state-format.md skills/loopplan/SKILL.md
git commit -m "docs: journal exports line in state format; loopplan nudge to name task dependencies"
```

---

### Task 6: README + CHANGELOG + 버전 0.14.0

**Files:**
- Modify: `README.md` ("Fresh subagent per task" 불릿, "Phase boundaries" 불릿)
- Modify: `CHANGELOG.md` (0.14.0 절 신설, 맨 위)
- Modify: `.claude-plugin/plugin.json` (`"version": "0.13.0"` → `"0.14.0"`)

- [ ] **Step 1: README fresh-agent 불릿에 carry 채널 문장 추가**

old_string:

```
- **Fresh subagent per task.** Every task gets a brand-new implementer, even if the
  previous one finished with context to spare. Workers are never reused across tasks —
  that's what keeps a bad assumption in task 2 from quietly leaking into task 5.
```

new_string:

```
- **Fresh subagent per task.** Every task gets a brand-new implementer, even if the
  previous one finished with context to spare. Workers are never reused across tasks —
  that's what keeps a bad assumption in task 2 from quietly leaking into task 5.
  Isolation isn't amnesia, though: every dispatch carries a "prior work this phase"
  block — the files and exported symbols of every finished task in the current phase,
  self-reported by implementers and assembled from the journal — with a hard contract:
  extend what exists. A parallel re-implementation is a verifier FAIL, at the task
  level first and again at the phase boundary.
```

- [ ] **Step 2: README phase-boundary 불릿에 blocking check 문장 추가**

old_string:

```
- **Phase boundaries verify in both directions.** When a phase's last task lands, a
  fresh phase verifier runs the full suite and checks the seams between tasks — pieces
  that passed in isolation still have to hold together. It also emits two advisories
```

new_string:

```
- **Phase boundaries verify in both directions.** When a phase's last task lands, a
  fresh phase verifier runs the full suite and checks the seams between tasks — pieces
  that passed in isolation still have to hold together. Intra-phase duplication — a
  later task re-implementing what an earlier task built instead of extending it — fails
  the phase and re-opens the later task. It also emits two advisories
```

- [ ] **Step 3: CHANGELOG 0.14.0 절 추가**

`# Changelog` 바로 아래, `## 0.13.0` 앞에 삽입:

```markdown
## 0.14.0 — 2026-07-11

- **Intra-phase carry — prior-task outputs reach every dispatch.** The
  kvtx dogfood run (solo-vs-loopspace A/B) showed fresh-agent isolation
  creating duplicate/dead code *between tasks of the same phase*: task
  1.2's fresh implementer, told nothing about task 1.1's `Store`, rebuilt
  it as `Database` with an orphaned `_vk` index — and the phase verifier's
  advisory-only structural check waved it through as "proportionate".
  handoff.md only exists at phase boundaries and context thresholds, so
  the task-to-task seam carried nothing. Now: implementers self-report an
  `exports:` line (journaled; the orchestrator still never reads code),
  every implementer *and* verifier dispatch carries a PRIOR WORK THIS
  PHASE block assembled from the journal's `files:`/`exports:` lines, and
  a parallel re-implementation of a listed capability is a FAIL at two
  layers — the task verifier (template B check 6 / template D correctness
  check 5) catches it first, and a new *blocking* template C check 5
  (intra-phase duplication, offending-task = the later task) backstops
  the phase. Existing advisories (structural economy, plan freshness)
  keep their wording and advisory status, renumbered to 6/7. loopplan
  gains a nudge to name task dependencies ("extends Store from 1.1") at
  decomposition time. Old journals without `exports:` lines degrade
  gracefully (files-only blocks); acceptance criteria that explicitly
  require a separate implementation are exempt from all duplication
  checks.
```

- [ ] **Step 4: plugin.json 버전 범프**

Edit `.claude-plugin/plugin.json`: `"version": "0.13.0",` → `"version": "0.14.0",`

- [ ] **Step 5: 검증**

Run: `sh scripts/test/portability.test.sh && sh scripts/test/supervise.test.sh`
Expected: 둘 다 0 failed.
Run: `grep -n "0.14.0" CHANGELOG.md .claude-plugin/plugin.json`
Expected: 각 1곳.

- [ ] **Step 6: Commit**

```bash
git add README.md CHANGELOG.md .claude-plugin/plugin.json
git commit -m "docs: changelog + bump to 0.14.0 (intra-phase carry)"
```

---

### Task 7: 최종 일관성 검토

**Files:**
- 읽기 전용 검토: 위 전 파일.

- [ ] **Step 1: 블록명·라인명 전수 grep**

Run: `grep -rn "PRIOR WORK THIS PHASE" skills/ docs/ README.md | wc -l` 후 각 매치가 설계와 일치하는지 확인:
- agent-prompts.md: A 입력 헤더, B 입력 헤더+check 본문, D 입력 헤더+check 본문 (정확히 5곳)
- SKILL.md(looprun): carries + verifier 전달 (2곳)
- state-format.md: exports 설명 안 (1곳)
- README.md: 소문자 서술형 "prior work this phase" (대문자 아님 — 산문이므로 OK)

Run: `grep -rn "exports:" skills/looprun/ docs/state-format.md | grep -v "PRIOR WORK"` — 리포트 shape(A), 저널 예시(state-format), 조립 규칙(SKILL.md), 템플릿 C 입력이 서로 같은 라인명을 쓰는지 확인.

- [ ] **Step 2: 전체 lint**

Run: `sh scripts/test/portability.test.sh`
Expected: 0 failed.

- [ ] **Step 3: 불일치 발견 시 수정 후 amend 없이 fix 커밋, 없으면 종료**

```bash
git log --oneline -7
```
Expected: Task 1–6의 커밋 6개가 보임.
