# loopnext 설계 — run 사이의 스펙 버전업 반복

날짜: 2026-07-08
상태: 초안 (사용자 리뷰 대기)

## 요약

`/loopnext`는 완료된 loopspace run과 다음 run 사이의 인간 touchpoint다.
사람의 사용 피드백과 저널에 쌓인 시스템 관측(structure-note,
spec-concern)을 받아 스펙을 버전업(amendment)하고, 델타 plan을 확정한 뒤,
실행은 기존 `/looprun`에 그대로 넘긴다. 핵심 원칙 한 줄:

> **spec은 run 안에서는 얼어 있고, run 사이에서는 버전업된다.**

이로써 파이프라인이 폭포수(스펙 1회 확정 → 완주)에서 반복(작은 스펙 →
MVP → 사용 → 수정 스펙 → 델타 run → …)으로 바뀐다. looprun의 "Never
modify spec.md"는 run 내부 규칙이므로 무손상이다.

## 배경과 문제

1. **얼어붙은 스펙 = 폭포수.** 50태스크짜리 스펙을 사전에 완벽하게 쓰는
   건 불가능하다. 사람은 백지 명세는 못해도 존재하는 물건 비판은 잘한다
   — "써 보니 이게 아니네"는 물건이 있어야만 나오는 정보다. 현행
   파이프라인은 이 정보가 나온 뒤의 경로가 없다.
2. **structure-note에 소비처가 없다.** 백로그 3번이 심은 구조 경제성
   advisory는 저널에 기록만 되고, 읽고 행동하는 접점이 정의돼 있지 않다.
3. **run 생명주기 공백.** loopspec 가드는 기존 run을 만나면 "archive or
   abort"를 *묻지만*, archive 절차 자체가 state-format에 없다. 완료된
   run 위에 다음 run을 얹는 흐름이 미정의다.

loopspace는 원래 feature 단위 파이프라인이므로 "실전 프로젝트 = 작은 run
여러 번"이 맞는 사용법인데, run과 run을 잇는 명령이 없어서 그 사용법이
실제로는 막혀 있었다. loopnext가 그 이음새다.

## 확정 결정 (대화에서 합의됨)

| # | 결정 | 근거 |
|---|---|---|
| C1 | 이름은 `loopnext` | looprefactor는 "행동 보존"이라는 확립된 의미와 충돌(행동 변경 포함 기능), loopedit은 loopupdate와 혼동 여지. pslog의 어휘 규율(workflow/refactor 구분)과 정합. `looprefactor`는 진짜 동작-보존 리팩토링 run을 나중에 만들 때를 위해 예약. |
| C2 | 범위는 통합형 | 행동 변경(스펙 수정)과 구조 정리(structure-note 소비)를 한 명령으로. 인터뷰가 두 입력을 함께 받아 하나의 델타 plan으로 — 검증 기계는 어차피 태스크 종류를 구분하지 않는다. |
| C3 | spec 델타 + plan 델타를 한 명령이 커버 | 델타가 작은데 touchpoint를 두 명령으로 쪼개면 의식(ceremony)만 는다. 명령은 하나, 내부 승인 게이트는 두 번(amendment 승인, plan 승인). |
| C4 | 실행은 기존 `/looprun`, **실행 로직 무수정** | looprun 관점에서 run 2는 그냥 "승인된 spec + 승인된 plan"이다. run 번호를 알 필요가 없다. 유일한 예외는 완료 리포트의 안내 1줄(아래 V6) — 브랜치/디스패치/검증 로직은 0줄. |
| C5 | phase 경계 체크포인트(`--checkpoint`)는 포함하지 않음 | 백로그 5번에서 이미 결정된 사안 — advisory(spec-concern) 채택, 체크포인트는 "advisory로 부족하다는 관측이 쌓일 때만"이라는 게이트 뒤. 그 관측은 아직 없다. 이 기능에 묶어 부활시키지 않는다. |
| C6 | 검증 강도는 델타에도 동일 | "수정이니까 대충"은 없다. 델타 태스크도 첫 run과 같은 기계(fresh 구현자, 리스크 티어, 렌즈 패널, 저널, 체크포인트 커밋)를 탄다. |

## 명령 플로우

```
전제: .loopspace/ 존재, spec.md status: approved, state.md run_status: complete

0. ancestor 검사 (git 프로젝트만)
   - run N-1의 결과 코드가 현재 HEAD 아래에 있는지 기계 검증:
     state.md(아직 archive 전이라 살아 있음)의 current_branch를
     `git rev-parse`로 SHA 해석 → `git merge-base --is-ancestor <sha> HEAD`
   - 브랜치가 삭제된 경우 폴백: `git log --grep "loopspace: run complete
     — <slug>"`로 HEAD 이력에서 완료 커밋 탐색
   - 둘 다 실패 → 정지: "run N-1을 머지하거나 그 브랜치를 체크아웃한 뒤
     다시 실행"을 안내. 이 검사가 없으면 run 1 브랜치를 머지하지 않고
     main에 서서 loopnext를 돌렸을 때 델타 plan("MVP가 존재한다" 전제)이
     MVP 없는 트리 위에 지어진다 — loopspec의 stale-branch 질문은 "옛
     브랜치가 남아있다"를 잡지 "발밑에 run N-1이 없다"를 잡지 못한다.
1. 입력 수집
   - 저널의 직전 run 섹션에서 structure-note / spec-concern 라인 추출
   - 사람에게 시스템 후보를 채택/기각으로 제시 (한 번에 하나씩)
   - 사람의 자체 변경 요청 수집 — loopspec과 같은 인터뷰 규율
     (한 메시지 한 질문, 추측 금지, testable 수준까지 구체화)
   - **빈손 종료:** advisory 채택 0건 + 사람의 변경 요청 0건이면 run을
     개봉하지 않고 그대로 종료한다 — "뭐가 쌓였나 보기만 하는" 탐색적
     실행이 안전해진다.
2. run 개봉 + Amendment 초안
   - **먼저 직전 run을 archive** (plan.md, state.md 최종 스냅샷,
     handoff.md, **그리고 spec.md 스냅샷** → `.loopspace/archive/run-<N-1>/`)
     하고 새 header-only state.md(`run: N`, `run_status: spec`)를 쓴다 —
     loopspec과 같은 원칙: 드래프트가 시작되는 순간부터 크래시가 재개
     가능한 마커를 디스크에 남긴다. 이 시점 이후의 중단은 loopnext가
     이어받는다. spec.md 스냅샷은 아래 abort 경로의 원복 재료다 — git
     원복은 비git 프로젝트에서 쓸 수 없으므로 archive가 균일한 재료가
     된다.
   - spec.md를 직접 수정 (포맷은 아래 Amendment 절): status를 draft로
     내리고 R-id 추가/개정/폐기 + Amendment Log 기입
3. 델타 검증 패널 (축소판, 아래 참조) → 수렴 루프 최대 3라운드
4. 인간 승인 게이트 #1 — amendment 승인 → spec.md status: approved
   - **abort 경로 (전면 기각):** 사람이 amendment를 통째로 기각하면
     archive/run-<N-1>/에서 원복한다 — spec.md 스냅샷 복원(approved
     상태 그대로), plan.md/state.md/handoff.md를 제자리로, run N의
     header-only state.md 삭제, archive/run-<N-1>/ 제거. 결과는
     "loopnext를 돌리기 전과 완전히 동일한 상태"다. 이 절이 없으면
     기각된 드래프트가 림보에 남아 loopresume이 영원히 loopnext로
     라우팅한다.
5. 델타 plan 초안
   - loopplan의 규칙(리스크 태깅 기준, gold-plating 감사, 태그 정직성
     체크)을 참조로 재사용, 새 plan.md 작성
6. 인간 승인 게이트 #2 — plan 승인
7. run 확정 마무리
   - 저널에 run 헤더 기입, 브랜치 생성, 체크포인트 커밋 (archive와
     state.md는 2단계에서 이미 처리됨)
8. /looprun 제안하고 종료
```

전제조건이 안 맞으면 올바른 스킬을 안내하고 정지한다: `executing`/
`halted` → looprun, spec 없음 → loopspec, `planning` → loopplan.
loopnext 자신이 중단된 경우(state.md `run: N≥2` + `run_status: spec`
또는 `planning`)는 loopnext가 이어받는다 — loopspec의 draft 재개
의미론과 동일.

## 파일 생명주기 **[거부권 V1]**

`.loopspace/` 파일을 두 부류로 나눈다:

- **영속 (run을 넘어 삶):** `spec.md` (amendment로 버전업),
  `journal.md` (run 헤더로 구분하며 계속 append — "전체 변경 이력이
  검증 기록과 함께 남는다"의 실체)
- **run 단위 (loopnext가 archive):** `plan.md`, `state.md`(최종 스냅샷),
  `handoff.md`(있으면). `report.md`는 complete 상태에선 존재하지 않음
  (halt 전용, halt-resume이 삭제).

Archive 위치: `.loopspace/archive/run-<N>/` — loopnext 2단계(amendment
드래프트 직전)에서 직전 run의 파일을 이동한 뒤 새 `state.md`를 쓴다.
사람이 amendment 승인 전에 이탈해도 상태는 "재개 가능한 loopnext 드래프트"
이지 유실이 아니다. state-format.md에 이 절차와
디렉토리를 추가해 loopspec 가드의 "archive"가 처음으로 정의된 절차를
갖게 된다.

state.md에 헤더 필드 `run: 2` 추가 (부재 = run 1, 기존 run과 하위호환).
파일 포맷 버전은 1 유지 — 전부 additive 변경이고, 기존 소비자는 모르는
헤더 라인을 무시한다.

## Amendment 포맷 **[거부권 V2]**

원칙: **요구사항 본문은 in-place 수정, 이력은 로그로.** looprun이
디스패치마다 "이 태스크가 커버하는 R-id의 스펙 발췌"를 실어 나르므로,
Requirements 섹션은 항상 현재 진실이어야 한다. 버전별 사본을 두면 발췌
로직이 복잡해진다.

spec.md 변경:

```markdown
# Spec: <project name>
version: 1
status: approved
spec_version: 2            # 신규 필드, 부재 = 1

## Requirements
- R1: <불변 — 그대로>
- R3: <개정 — 같은 R-id 유지, 본문만 교체> (revised in v2)
- R5: [dropped in v2] <원문 유지, 취소선 의미의 마커만>
- R8: <신규 — 번호는 이어서> (added in v2)

## Amendment Log                # 신규 섹션, append-only
### v2 — <YYYY-MM-DD>, approved by human
- R8 added: <한 줄 근거> (origin: human feedback)
- R3 revised: <한 줄 근거> (origin: spec-concern [2.4])
- R5 dropped: <한 줄 근거> (origin: structure-note phase 2)
```

규칙:
- `version:`(파일 포맷 버전)과 `spec_version:`(내용 버전)은 다른 축이다
  — state-format.md에 이 구분을 명시하고 필드 주석을 단다.
- 인라인 마커는 **최신 것 하나만** 남는다: R3가 v2와 v4에서 개정되면
  본문 마커는 `(revised in v4)`뿐이고, 전체 이력은 Amendment Log가
  담당한다. 마커가 버전마다 누적되지 않는다.
- 개정된 요구사항은 **R-id를 유지**한다. 저널의 과거 검증 기록이
  참조하는 R3는 "당시의 R3"이고, Amendment Log가 버전을 해소한다.
- 폐기된 R-id는 삭제하지 않고 마커만 단다 — 번호 구멍이 설명되고 과거
  참조가 깨지지 않는다. 폐기 R-id는 재사용 금지.
- 신규 R-id는 기존 번호를 이어서 증가.
- Lens 섹션들(Company/User/Engineer/Designer)은 델타가 건드리는 경우에만
  in-place 갱신.
- Amendment Log의 각 항목은 origin(human feedback / structure-note /
  spec-concern)을 명시 — advisory 파이프라인이 실제로 소비됐는지 나중에
  감사 가능.

## 델타 검증 패널 **[거부권 V3]**

loopspec의 6렌즈 패널 대신 amendment 전용 3렌즈 고정:

1. **coherence** — amendment가 개정되지 않은 요구사항들·이미 구현된
   동작과 모순되지 않는가 (델타 전용 렌즈, 신규). **입력 정의:**
   amendment 디프(바뀐 R-id들과 Amendment Log 항목), 전체 spec.md,
   직전 run의 journal 섹션(무엇이 어떻게 구현·검증됐는지), 그리고
   현재 코드베이스 read-only 접근. 프롬프트는
   `references/`에 신규 작성 — 입력이 스펙에 정의돼 있어야 구현 때
   즉흥이 되지 않는다.
2. **adversarial** — red team (loopspec 패널에서 재사용)
3. **verifiability** — 개정/신규 R-id가 testable한가 (재사용)

company/user/designer 렌즈는 별도 리뷰어를 띄우지 않는다 — 그 관점의
질문은 1단계 인터뷰에서 해당되는 경우 사람에게 직접 묻는다. 근거:
델타의 제품 방향 판단은 이미 사람이 (물건을 써 보고) 내린 상태라,
백지 스펙 때와 달리 패널이 대신 검토할 공백이 작다. 수렴 루프는
loopspec과 동일 (blocking → 수정 → 재패널, 최대 3라운드).

## 델타 plan과 저널 연속성 **[거부권 V4]**

- 새 plan.md는 기존 포맷 그대로, phase/task 번호는 run 안에서 1부터.
  run 간 태스크 id 충돌(run 1의 1.1 vs run 2의 1.1)은 저널의 run 헤더가
  스코프를 가른다.
- journal.md에 run 경계 헤더 추가:

```markdown
# ── Run 2 — opened <YYYY-MM-DD> (spec v2) ──
## [loopnext] run 2 opened
- amendment: <한 줄 요약, spec_version>
- adopted advisories: <채택된 structure-note/spec-concern 요약 또는 none>
```

- 이후 looprun의 저널 엔트리는 수정 없이 그대로 이 섹션 아래에 쌓인다.

## 브랜치 전략 **[거부권 V5]**

run N(≥2)의 슬러그를 `<slug>-v<N>`으로 한다:

- `run_branch: loopspace/<slug>-v2/run`
- looprun은 slug를 run_branch에서 읽어 phase 브랜치를
  `loopspace/<slug>-v2/phase-<P>`로 파생 — **looprun 무수정으로 기존
  브랜치 로직이 그대로 동작**하는 게 이 방식의 채택 이유다.
- base_branch = amendment 승인 시점의 checked-out 브랜치 — 단, 플로우
  0단계의 ancestor 검사를 통과한 HEAD여야 한다. "사람이 서 있는 곳에서
  fork"는 그 자체로는 run N-1의 코드가 발밑에 있음을 보장하지 않기
  때문이다. 나머지는 loopspec과 같은 규칙(working tree 클린 확인,
  stale 브랜치 질문 포함).

## 타 스킬 영향 (정직한 목록)

| 파일 | 변경 | 규모 |
|---|---|---|
| `skills/loopnext/` | 신규 스킬 + references | 본체 |
| `docs/state-format.md` | archive 절차, `run:`/`spec_version:` 필드, Amendment Log, 저널 run 헤더 | 중간 |
| `skills/loopspec/SKILL.md` | 가드에 한 줄: `run_status: complete`면 `/loopnext` 안내 | 1줄 |
| `skills/loopresume/SKILL.md` | 라우팅에 한 줄: `run: N≥2` + `spec`/`planning`이면 `/loopnext` 안내 | 1줄 |
| `skills/looprun/SKILL.md` | 완료 리포트에 "/loopnext로 다음 사이클" 안내 1줄 — 실행 로직은 무변경 | 1줄 |
| `README.md` | 파이프라인 다이어그램에 사이클 추가, FAQ | 소 |

**[V6 — 확정: 넣는다]** 사용자가 "/loopnext가 존재한다"를 알아야 하는
순간이 정확히 run 완료 리포트를 읽는 순간이다. README는 그 순간을
놓친 사람을 위한 백업. "looprun 무수정"의 실질 가치는 브랜치/디스패치/
검증 로직에 있고, 리포트 문구 1줄은 그 가치를 건드리지 않는다.

## 비목표

- run **도중** 스펙 변경 — 없음. "Never modify spec.md"는 그대로.
- phase 경계 인간 체크포인트 — 백로그 5번 게이트 유지 (C5).
- halted run의 처리 — halt-resume 경로가 담당, loopnext는 complete 전용.
- 검증 경량화 "MVP 모드" — verify-heavy는 델타에도 동일 (C6).
- 다중 하니스 — 백로그 7번 수요 게이트 그대로.
- **advisory "보류" 상태 — 의도적 제외.** 1단계의 채택/기각 이분법에서
  "이번엔 아니고 나중에"는 기각으로 소실된다 (저널은 run 단위로 읽으므로
  run 3의 loopnext는 run 1의 보류 항목을 못 본다). `deferred` 마커를
  저널에 남겨 다음 loopnext가 재제시하는 확장이 가능하지만, v1은
  이분법으로 시작한다 — 보류 수요가 실제로 관측되면 그때 추가한다
  (운영 원칙: 관측 안 된 실패 모드에 미리 비용을 붙이지 않는다).

## 리스크와 완화

- **spec.md 비대화** (amendment 누적): Requirements는 in-place라 크기가
  선형으로 늘지 않는다. Amendment Log만 자라는데, 발췌 대상이 아니라
  디스패치 컨텍스트를 오염시키지 않는다.
- **plan 승인의 의미 희석** ("어차피 다음 run에서 고치지"): touchpoint가
  늘어난 게 아니라 run 단위가 작아진 것 — 각 run 안의 계약(승인 후 동결,
  re-plan 경로 유일)은 무손상.
- **archive 마이그레이션**: 기존 완료 run(archive 디렉토리 없는 상태)에서
  loopnext를 처음 돌리는 경우가 곧 마이그레이션 — loopnext 7단계가
  처리하므로 별도 마이그레이션 불요.

## 다음 단계

1. 사용자 리뷰 — 특히 거부권 V1~V6.
2. 백로그에 10번 항목으로 등재 (ledger 규율 유지).
3. 구현 플랜 작성 → 구현. 경로는 착수 시 선택 — 권고는 superpowers
   플로우: 산출물이 마크다운 스킬/문서라 런타임 표면이 없어, looprun의
   TDD 계약(실패 테스트 먼저, 증거 필수)을 태우면 의례적 테스트로
   계약이 형식화된다. 리포 선례도 플러그인 자신은 superpowers SDD.
   loopnext의 진짜 dogfood는 완성된 loopnext를 실제 제품 사이클에 쓰는
   것이며, 그것이 백로그 7/8/9가 기다리는 멀티-phase dogfood와 겹친다.
