# Final Verification + Implementer Continuity — Implementation Plan

**Goal:** looprun(thick 모드)을 사용자가 그린 그림과 100% 일치시키는 두 갭을
메운다. A = 런 전체가 끝난 뒤 전 범위 최종 검증(0.18.0). B = 구현자를
태스크마다 버리지 않고 phase 경계/컨텍스트 한계까지 유지(0.19.0).

**배경:** 2026-07-26 대화. 사용자의 목표 그림을 현행 looprun과 대조한 결과
10개 항목 중 9개가 이미 구현돼 있었고(스펙 렌즈 검증, phase/task 구조,
태스크별·phase별 검증, 신선한 검증자, heavy 3렌즈 패널, 30% 규칙,
in-flight 태스크까지만 하고 핸드오프), 남은 갭이 이 둘이다. 전면 재작성은
기각 — 현행 코드에는 실패를 겪고 붙인 장치들(구현자 테스트를 증거로 안 받는
probe, 변이 스팟체크, 패널 만장일치, 크래시 복구)이 있어 새로 짜면 그 상처가
없는 상태로 되돌아간다.

**Spec:** 없음(이 파일이 계약). 근거 문서 =
`~/code/ornith-loopspace-experiments/DECISION-per-phase-implementer.md`

---

## Global Constraints

- 스킬 본문(`skills/**/*.md`)에 `subagent`, `task tool`, `AskUserQuestion`
  단어 금지 — portability lint가 잡는다
  (`scripts/test/portability.test.sh`). "fresh agent", "dispatch",
  "verifier" 어휘를 쓴다.
- 기존 파일 문체 유지: 영어 본문, 줄바꿈 ~72자, 하이픈 불릿.
- 기존 advisory(structural economy, plan freshness, spec-concern)의 문구·
  지위 불변. 신설 blocking check와 섞지 않는다.
- 각 태스크 끝: `sh scripts/test/portability.test.sh` 통과 확인 후 커밋.
- lead 모드(`skills/looplead/`, `scripts/gate.sh`)는 A·B 어느 쪽도 건드리지
  않는다. 설계를 참고할 뿐이다.

---

# A — 최종 전체 검증 (0.18.0)

## 현행과 갭

마지막 phase 검증자는 이미 스펙 전문을 받고, probe 범위(`COVERED SO FAR`)도
마지막 phase에선 사실상 전 범위다(`agent-prompts.md:310`). 갭은 "없음"이
아니라 **얇음**:

- 요구 시나리오가 최소 3개뿐 — 제품 전체를 훑기엔 적다
- 프롬프트가 "이 phase가 잘 붙었나"를 묻지 "이 제품이 다 됐나"를 안 묻는다
- 완결성 확인이 없다 — 어떤 요구사항이 아무 태스크에도 안 담겼는지 아무도
  안 본다

lead 모드의 최종 게이트(`skills/looplead/references/gate-verifier.md:60-72`,
`scripts/gate.sh:100-106`)에 이 셋이 다 있다. 설계를 가져온다.

## 비용 설계 (중요 — 그대로 구현할 것)

태스크 30개 런의 디스패치는 70~130회다. 최종 검증자는 런당 1회이므로 증가분
자체는 1% 안쪽이다. 줄일 지점은 횟수가 아니라 **헛되이 부르는 것**과
**중복 작업**이다. 세 가지를 설계에 박는다:

1. **기계 확인이 먼저, 디스패치는 그 다음.** 완결성 검사는 파일 읽기만으로
   되므로 오케스트레이터가 직접 한다. 여기서 걸리면 검증자를 부르지 않는다.
   (`gate.sh:100`의 "mechanical pre-check before spending a verifier call"
   패턴.)
2. **phase probe를 다시 만들지 않는다.** phase 검증자가 만든 probe 파일은
   이미 커밋돼 전체 스위트에 들어 있다(`SKILL.md:276`). 최종 검증자는
   **phase를 가로지르는 시나리오만** 새로 만든다.
3. **변이 스팟체크도 교차 동작만.** phase 안쪽 동작은 그 경계에서 이미 했다.

**기각한 절감안:** 마지막 phase 경계와 최종 검증을 하나로 합치기. 한 번을
통째로 아끼지만, 마지막 phase 코드가 자기 검증을 받기 전에 전체 판정을 하게
되어 FAIL의 귀속이 흐려진다(마지막 phase 버그 vs 전체 통합 버그). 1~3으로
충분히 아꼈다.

---

### Task A1: Template E — Final Verifier

**Files:** Modify `skills/looprun/references/agent-prompts.md` (Template D
뒤에 신설)

**입력 블록**
- `PROJECT FACTS` — state.md 블록
- `FULL SPEC` — spec.md 전문
- `PHASES COMPLETED` — phase 번호 + acceptance 라인 + 각 `[phase N]
  verified` 저널 항목의 note 한 줄
- `ALL REQUIREMENTS` — plan.md 전 태스크 `covers:`의 합집합

**CHECKS (순서 고정 — 1은 어떤 테스트 파일도 열기 전에)**
1. 교차 시나리오 도출: FULL SPEC만 보고 **phase 경계를 가로지르는** 시나리오
   최소 3개. 한 phase가 단독으로 소유하지 않는 상호작용만. 각 phase 내부
   시나리오는 이미 커밋된 phase probe가 커버하므로 **재도출 금지**(명시할 것).
2. 실행: 파일 하나 `tests/probes_final.*`(프로젝트 테스트 관례), 이전 라운드
   파일 대체. 실패 시 FAIL — finding에 입력·스펙 라인·실제 결과.
3. 전체 스위트 green.
4. 변이 스팟체크(git 저장소만): phase를 가로지르는 동작 2~3개, `git checkout
   -- <file>`로 즉시 복원, 리포트 작성 전 복원 완료.
5. 제품 수준 완결성 판정: 스펙이 요구한 것을 실제로 다 하는가 — 트리와 자기
   probe로 판단하고, 구현자가 쓴 스위트는 증거로 삼지 않는다.

**REPORT BACK:** `verdict` / `note` / `probes` / `mutation` /
`offending-task`(FAIL 시) / `findings`(FAIL 시) / `spec-concern`(advisory)

- [ ] Template E 작성
- [ ] `sh scripts/test/portability.test.sh` 통과
- [ ] commit

---

### Task A2: looprun — Final Verification 절 신설 + step 4 배선

**Files:** Modify `skills/looprun/SKILL.md`

**A2-1. `## Final Verification` 절 신설** (Phase Boundary 절과 Context
Threshold 절 사이)

트리거: 마지막 phase의 boundary가 PASS했을 때. 즉 현행 step 3의 "마지막
phase면 새 브랜치 만들지 말고 step 4로" 경로가 이 절을 먼저 통과한다.

1. **기계 사전 확인 (디스패치 없음, 오케스트레이터가 직접)**
   - spec.md `## Requirements`의 모든 R-id가 plan.md 어느 태스크의 `covers:`
     에든 등장하는가
   - 모든 phase에 `[phase N] verified` 저널 항목이 있는가
   - (git) `git status`가 깨끗한가
   위반 → 검증자를 부르지 않는다. 누락 커버리지는 re-plan 경로, 누락 boundary
   는 Phase Boundary를 먼저 돌린다(0번 debts와 같은 자가치유 성격).
2. **최종 검증자 디스패치**(fresh, template E)
3. **FAIL** → `offending-task`가 per-task cycle에 재진입(findings 동반).
   **최대 3라운드**, 4번째 FAIL은 halt — `report.md`, trigger `final-stall`.
4. **PASS** → 저널 `[final] verified`(검증자의 `probes:`/`mutation:`/
   `spec-concern:` 라인 그대로 첨부), 커밋
   `loopspace: final verification passed`, 그 다음 step 4.

**A2-2. step 4 수정** — `run_status: complete`는 최종 검증 PASS 이후에만
쓴다. 완료 리포트에 최종 검증의 `probes:`/`mutation:` 한 줄을 포함한다.

- [ ] Final Verification 절 작성
- [ ] step 4 수정
- [ ] portability lint 통과
- [ ] commit

---

### Task A3: 상태 파일 포맷

**Files:** Modify `docs/state-format.md`

- 395행 trigger 목록에 `final-stall` 추가
- `[phase N] verified` 저널 항목 옆에 `[final] verified` 형식 추가
- 저널 예시 갱신

- [ ] 편집
- [ ] portability lint 통과
- [ ] commit

---

### Task A4: 릴리즈

**Files:** `CHANGELOG.md`, `.claude-plugin/plugin.json`, `README.md`

- [ ] CHANGELOG 0.18.0 항목 (why → what, 기존 릴리즈 문체 유지)
- [ ] plugin.json `version: 0.18.0`
- [ ] README에 최종 검증 한 줄
- [ ] 전체 테스트 (`portability`, `gate`, `supervise`) 통과
- [ ] commit

---

### Task A5: looplead 딱지 (A와 함께 출하)

판단: **삭제하지 않는다.** 근거 — (1) `loopresume`/`loopspec`/`supervise.sh`/
`state-format.md`에 배선이 들어가 있어 제거 비용이 A·B 작업보다 크다,
(2) 0.17.0이 2026-07-15 릴리즈로 11일밖에 안 됐다, (3) A가 그 최종 게이트
설계를 빌려 쓰고 있다, (4) A·B 어느 쪽과도 충돌하지 않아 유지 비용이 0에
가깝다. 혼란은 삭제가 아니라 라벨로 푼다.

- [ ] `skills/looplead/SKILL.md` description 첫머리에 실험 단계 표시
- [ ] README에 "어느 모드를 쓰나" 한 문단 — 기본은 looprun, looplead는 실험
- [ ] 재검토 조건 기록: lead가 값어치를 하는지 재는 실험을 하거나, 접거나 —
      2026-10월까지 둘 중 하나가 없으면 그때 삭제 판단

---

# B — 구현자 연속성 (0.19.0, 별도 계획으로 확정)

A 출하 후 착수. 여기는 스케치이며, 착수 시점에 자체 계획 파일로 확정한다.

**바꾸는 것:** `SKILL.md:19`의 "Fresh agent per task, never reused" →
"구현자는 phase 경계 또는 컨텍스트 한계까지 유지. 검증자는 언제나 새로,
절대 구현자가 아님."

**교체 시점 4가지**
- phase 끝 — 무조건(기존 phase 브랜치·phase 검증자 경계와 정렬)
- 컨텍스트 임계 — 구현자 리포트에 `context:` 한 줄 추가, 임계 시 선제 교체
- 같은 태스크 2차 FAIL — 1차는 같은 구현자(맥락 보존이 목적), 2차는 새 눈
- 손잡이 소실(세션 리셋·크래시·미지원 하네스) — 현행 fresh 경로로 자동 폴백

**하네스 계약:** `PROFILE-SPEC.md`에 선택 항목 `## Continuation` 신설 —
"이미 디스패치한 에이전트에 후속 메시지를 보내 다음 리포트를 받을 수 있는가".
Tier(A/B/C)는 건드리지 않는다. 프로필 4개에 답을 채운다(claude-code: 가능 /
codex·opencode·generic: 불가).

**유지하는 것:** PRIOR WORK THIS PHASE 블록(검증자·교체·복구용). 에이전트
핸들은 state.md에 기록하지 않는다 — 세션 리셋이 자연 폴백이 된다.

**위험:** 중간. 폴백이 곧 현행 동작이라 최악의 경우 원상복귀.

**측정 의무:** 첫 실런에서 토큰·벽시계·재시도 횟수를 기록해 현행과 비교한다.
악화되면 되돌린다.
