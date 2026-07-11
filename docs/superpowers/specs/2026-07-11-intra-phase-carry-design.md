# Intra-phase carry 설계 — 이전 태스크 산출물 전달 + 중복 재구현 강제

작성: 2026-07-11. 근거 사례: kvtx-trial (3회차 도그푸드, solo-vs-loopspace A/B).

## 요약

fresh-agent-per-task 격리가 같은 phase 안의 태스크 사이에서 중복/dead
code를 만든다. 원인은 격리 자체가 아니라 **전달 채널의 부재**: handoff.md는
phase-boundary/context-threshold에만 쓰이므로 태스크-간(intra-phase)
경계에는 이전 태스크가 무엇을 만들었는지 아무것도 전달되지 않는다.

수리는 세 조각:

1. **exports 자가보고** — implementer 리포트에 `exports:` 라인 신설.
   orchestrator diet(코드를 읽지 않음)를 지키면서 공개 심볼 정보를 확보.
2. **PRIOR WORK THIS PHASE 블록** — orchestrator가 저널의 현재-phase done
   태스크들의 `files:`+`exports:`로 조립해 implementer·verifier 디스패치에
   주입. "재사용/확장하라, 병렬 재구현 금지" 계약 포함.
3. **양층 강제** — 태스크 verifier(템플릿 B의 체크, 템플릿 D correctness
   렌즈)가 중복 재구현을 FAIL로 잡는 1차 강제 + 템플릿 C(phase verifier)에
   좁은 blocking 항목을 백스톱으로 추가. 기존 structural-economy(check 5)는
   advisory 그대로 유지.

## 배경과 문제 (kvtx 증거)

- Task 1.1 fresh agent가 `Store`(_kv+_vk two-dict, O(1)) 작성.
- Task 1.2 fresh agent는 1.1의 존재를 모른 채 `Database`를 통째 재구현.
  `_vk`는 쓰기만 되고 어디서도 읽히지 않음(dead index), `count()`는 O(n).
- 1.2 디스패치가 받은 코드베이스 정보 = Project Facts뿐. handoff.md는
  phase 1 verified 커밋(`616f29e`)에서, 즉 1.2가 끝난 뒤 처음 생성됨.
- plan.md Planning notes에 "transactions layer over the base store" 의도가
  있었으나 템플릿 A는 task block만 나른다 — 의도는 기록됐는데 채널이 없었음.
- 검증도 절반만: dead `Store`는 correctness 렌즈가 spec-concern(advisory)으로
  두 번 잡았지만 강제력이 없었고, dead `_vk`는 아무도 못 잡음 — phase
  verifier의 structure-note는 판단에 필요한 정보(1.1 요약 "two-dict design
  for O(1)" + files)를 손에 들고도 "proportionate" 판정. check 5의
  체크리스트(merge 가능 파일 / single-caller 추상화)에 '태스크-간 병렬 중복
  구현' 항목이 없었기 때문 — **정보 부족이 아니라 프레이밍 문제**.

## 확정 결정

1. **강제 지점: 양층** (추천안 채택 — 사용자 미확답, 뒤집기 가능).
   태스크층이 1차: kvtx라면 1.2 attempt 1이 FAIL하고 retry implementer가
   "extend Store" finding을 받아 고쳤을 지점. retry 메커니즘이 이미 있으니
   새 루프가 필요 없다. phase층은 백스톱: 태스크 verifier는 태스크 하나만
   보므로 놓칠 수 있고, phase verifier만이 태스크들의 합을 본다.
2. **범위: intra-phase만.** PRIOR WORK 블록은 현재 phase의 done 태스크만
   담는다. payload가 phase 크기로 유계 — diet 유지. cross-phase 중복은
   이번 범위 밖 (아래 보류 참조).
3. **exports는 자가보고, 검증 안 함.** verifier에 exports 정확성 검증
   규칙을 추가하지 않는다 (verify-heavy 원칙의 예외지만, 검증 비용 대비
   오류 피해가 작음). 단, exports 라인은 reuse 체크(B-6/D-5/C-5)의
   verdict 판정 입력이기도 하므로 — "정보만 약화"가 아니다 — 체크 문구가
   라인이 아니라 트리에서 실제 제공 여부를 확인하고 판정하라고 명시한다.
   과대보고된 export가 다음 태스크의 정당한 구현을 false FAIL시키는
   경로를 닫는 보강 (2026-07-11 리뷰 후속).
4. **기존 advisory는 그대로.** check 5 structural-economy와 spec-concern
   채널은 문구도 지위도 불변. blocking 항목은 별도 신설 — advisory 채널이
   "사실 반쯤 blocking"이 되는 오염을 피한다.
5. **contested 채널 재사용.** implementer가 중복 판정에 반박할 때(예: "그
   심볼은 X를 제공하지 않음") 기존 contested-findings 경로를 그대로 쓴다.
   새 메커니즘 없음.

## 메커니즘

### exports: 라인 (템플릿 A REPORT BACK)

```
- exports: <이 태스크가 추가/변경한 공개 심볼, 모듈 경로 포함, 한 줄 —
  태스크 밖에서 쓰라고 만든 클래스/함수/상수만. 없으면 "none">
```

예: `exports: kvtx.database.Store (set/get/delete/count — O(1) two-dict)`.
저널 PASS 엔트리에 `- exports:` 라인으로 기록된다 (state-format.md 갱신).

### PRIOR WORK THIS PHASE 블록 (신규 디스패치 입력)

orchestrator가 journal.md에서 현재 phase의 done 태스크들의 `files:` +
`exports:` 라인을 그대로 모아 조립한다. 코드를 읽지 않는다.

```
PRIOR WORK THIS PHASE (already in the tree, built by earlier tasks):
{[<id>] files: <...> — exports: <...>, 태스크당 한 줄.
 phase 첫 태스크면 "none yet — you are the first task of this phase"}
```

implementer(A) 쪽 계약 문구: 이 심볼들이 이미 제공하는 기능이 필요하면
import/확장하라. 병렬 재구현은 verifier FAIL이다 — 단, 이 태스크의
acceptance criteria가 명시적으로 별도 구현을 요구하는 경우는 예외.

verifier(B/D correctness) 쪽 체크 문구: PRIOR WORK 블록의 심볼이 이미
제공하는 기능을 이 태스크가 import/확장 대신 병렬 재구현했으면 FAIL.
acceptance criteria가 별도 구현을 명시하면 예외. 블록이 "none yet"이면
스킵.

### 템플릿 C — blocking 백스톱 (신규 check, advisory 아님)

기존 structural-economy(advisory)는 문구 불변. 신규 check는 **check 5**로
verdict-영향 체크(1–4) 뒤에 삽입하고 기존 advisory 둘은 6·7로 밀림 —
check 번호를 참조하는 곳은 템플릿 밖에 없음을 확인함(grep):

- Intra-phase duplication (**affects the verdict**): 이 phase의 나중
  태스크가 앞 태스크가 만든 기능을 import/확장 대신 병렬 재구현했는지 —
  같은 일을 하는 평행 클래스/함수, 옮겨 왔지만 읽히지 않는 스캐폴딩(dead
  index/필드 포함). FAIL 시 offending-task = 나중 태스크, findings에 무엇을
  확장해야 하는지 명시. acceptance criteria가 별도 구현을 요구한 경우와
  테스트 격리용 seam은 제외.

TASKS COMPLETED 입력에 태스크별 `exports:`도 포함시켜 판단 근거를 준다.

### looprun SKILL.md — carries 목록과 조립 규칙

- Per-Task Cycle의 carries 목록(현 4종)에 PRIOR WORK 블록 추가 + "저널의
  현재-phase done 태스크 files/exports로 조립, 코드는 읽지 않음" 규칙.
- verifier 디스패치(step 3)에도 같은 블록 전달.
- retry·diversity-burst 디스패치도 동일 (같은 템플릿 A라 자동).
- Tier B/C: 프롬프트가 동일하므로 무변경. 하니스 프로필 무변경.

### loopplan 너지 (작은 조각)

태스크 분해 가이드에 한 줄: 나중 태스크가 앞 태스크의 산출물 위에 쌓이면
task block에 명시하라 (예: "extends Store from 1.1"). 강제 아님 — carry
채널이 주 방어선이고 이건 plan 품질 너지.

## 변경 목록

| 파일 | 변경 |
|---|---|
| `skills/looprun/references/agent-prompts.md` | 템플릿 A: PRIOR WORK 입력 블록 + 계약 문구 + REPORT BACK `exports:` 라인. 템플릿 B: PRIOR WORK 입력 + 중복 체크(번호 추가). 템플릿 D: PRIOR WORK 입력 + correctness 렌즈 체크 추가. 템플릿 C: TASKS COMPLETED에 exports 포함 + blocking 중복 check 신설 |
| `skills/looprun/SKILL.md` | carries 목록에 PRIOR WORK + 조립 규칙, verifier 디스패치에 전달, 저널 엔트리에 exports 기록 |
| `docs/state-format.md` | journal PASS 엔트리 예시에 `- exports:` 라인 |
| `skills/loopplan/SKILL.md` | 태스크 분해 가이드 한 줄 (extends 명시 너지) |
| `CHANGELOG.md`, `.claude-plugin/plugin.json` | 0.14.0 |
| `README.md` | 해당 절 있으면 갱신 (구현 시 확인) |

## 엣지 케이스

- **phase 첫 태스크**: 블록 = "none yet" — verifier 체크 스킵.
- **re-plan 분할 태스크(2.3a/b)**: 저널의 done 엔트리 기준 조립이라 자연 처리.
- **비코드 태스크**(설정/문서): `exports: none` — files는 여전히 블록에 실림.
- **burst candidate**: 트리가 마지막 checkpoint로 리셋돼도 이전 태스크는
  커밋돼 있으므로 PRIOR WORK은 그대로 유효.
- **구식 저널**(pre-0.14 run 재개): done 엔트리에 exports가 없으면 files만으로
  블록을 조립하고 exports 자리는 생략 — 파싱 실패로 죽지 않는다.
- **implementer 반박**: contested 채널로 처리, 새 메커니즘 없음.

## v1 범위와 acceptance

- 위 변경 목록이 전부. handoff.md 계약, loopspec, loopnext, 하니스 프로필,
  supervisor는 손대지 않는다.
- acceptance: kvtx spec 그대로 재런했을 때 (a) 1.2 implementer가 Store를
  확장하거나, (b) 재구현 시 태스크 verifier가 FAIL을 내고 retry에서
  교정되거나, (c) 둘 다 뚫려도 phase verifier가 offending-task 1.2로 FAIL —
  세 층 중 하나에서 반드시 걸린다. 실검증은 다음 도그푸드 런.
- 리포 자체 검증: 기존 lint/체크 스크립트가 있으면 통과 (구현 시 확인).

## 보류 (이번 범위 밖)

- **cross-phase 중복**: handoff.md에 누적 "Code inventory" 섹션을 추가하는
  안이 자연스러운 확장이나, handoff 계약 변경 + 누적 크기 문제가 있어 보류.
  intra-phase 수리 후 도그푸드에서 cross-phase 사례가 실제로 나오면 채택.
- **exports 검증**: verifier가 exports 정확성을 확인하는 규칙 — 비용 대비
  이득이 작아 보류.
