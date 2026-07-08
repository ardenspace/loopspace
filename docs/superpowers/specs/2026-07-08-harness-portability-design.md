# 하니스 이식성 설계 — 중립 코어 + 어댑터 팩

날짜: 2026-07-08
상태: 초안 (사용자 리뷰 대기)

## 요약

loopspace를 Claude Code 전용에서 하니스 중립으로 전환한다. 스킬 본문을
하니스 중립으로 리라이트하고(중립 코어), 하니스별 차이는 `harnesses/`
아래 프로필 1장씩으로 격리한다(어댑터 팩). 품질은 하니스 능력에 따라
tier로 점진 degrade하되, 어느 tier로 돈 런인지 state.md와 report.md에
명시한다. 핵심 원칙 한 줄:

> **막지 않되, 속이지 않는다** — 어떤 하니스/모델에서든 돌아가게 하고,
> 대신 보증 강도를 결과물에 정직하게 찍는다.

백로그 7번("다른 하니스 지원") 착수에 해당한다. 원래 "구체적 런이 생길
때까지 보류" 수요 게이트 뒤였고, 이 설계 대화(2026-07-08)가 그 수요
신호로 게이트를 해제했다. 멀티-phase dogfood 게이트를 앞지르는 착수라는
점은 인지된 트레이드오프다.

## 배경과 문제

1. **락인.** 파이프라인 전체가 Claude Code에서만 실행 가능하다. 상태
   포맷은 선행 감사(2026-07-06)에서 하니스 중립이 확인됐지만, 실행
   주체(스킬 디스패치, 서브에이전트)는 전부 Claude Code 프리미티브다.
2. **백로그 7번의 리프트 경고.** "어댑터는 포맷 변환이 아니라 사실상
   looprun 재작성"이라 적혀 있었다. 본 설계는 이를 재작성이 아니라
   **tier 분기 한 겹 + 프로필 파일들**로 줄인다 — 서브에이전트 의존을
   스킬 본문에서 빼내 프로필로 위임하면, 스킬은 "fresh agent를 띄워라
   (방법은 프로필)"만 말하면 된다.
3. **1급 페르소나 (대화에서 확정):**
   - **Codex-only 유저** — Claude Code를 전혀 쓰지 않음. `codex exec`
     서브프로세스가 fresh agent 디스패치를 대체해 Tier A급 실행 가능.
   - **로컬 LLM-only 유저** — OpenCode 등 + Ollama 백엔드. 하니스는
     문제없고 모델 능력이 변수 → tier와 모델명을 결과물에 기록.
   - 보조 로컬 LLM 혼합 편성 — 역할별 모델 라우팅(프로필에 선언).

## 확정 결정 (대화에서 합의됨)

| # | 결정 | 근거 |
|---|---|---|
| C1 | 접근은 A안(중립 코어 + 어댑터 팩), C안(단일 러너 문서)은 A의 최하위 폴백으로 흡수 | superpowers 플러그인이 검증한 패턴(references/codex-tools.md 등). B안(외부 오케스트레이터 CLI)은 오버엔지니어링 — 단 supervise.sh의 LOOPSPACE_RESUME_CMD seam으로 그 방향을 막지 않는다. |
| C2 | 서브에이전트 프리미티브 없는 하니스는 점진적 품질(tier) | 풀 파리티 온리(지원 폭 좁아짐)와 외부 오케스트레이터(리프트 큼)를 기각. |
| C3 | Cursor/Antigravity 프로필은 v1 제외 | IDE 하니스라 검증 비용 큼. PROFILE-SPEC이 있으면 후속/커뮤니티가 1장 추가로 확장 가능한 구조가 우선. |
| C4 | 설치 자동화 스크립트 v1 제외 | 하니스별 수동 설치 1페이지로 충분. 스크립트는 수요 보고 결정. |
| C5 | 로컬 모델 능력 하한은 강제하지 않고 권장으로만 문서화 | 막지 않되 속이지 않는다 — 실행은 허용, tier/모델 기록으로 보증 강도를 명시. |

## 구조

```
skills/            # 중립 코어 — Claude Code 표현 제거, tier 분기 추가
harnesses/         # NEW: 어댑터 팩
  PROFILE-SPEC.md  #   프로필이 답해야 하는 질문 목록
  claude-code.md   #   현행 동작을 프로필 형식으로 명문화 (기준점)
  codex.md         #   codex exec 서브프로세스 디스패치 → Tier A급
  opencode.md      #   서브에이전트 시스템 + 로컬 모델 백엔드
  generic.md       #   자기완결 러너 문서 (스킬 시스템 없는 하니스용 폴백, Tier C)
docs/harness-support.md  # 하니스별 설치 1페이지 + tier 매트릭스 + 업데이트 경로
```

프로필은 스킬이 런타임에 읽어야 하므로 설치 시 스킬과 함께 배치된다 —
Claude Code는 플러그인 안에 이미 포함되고, 타 하니스는 각 설치 문서가
스킬과 해당 프로필을 같이 복사하도록 안내한다.

## PROFILE-SPEC — 프로필 1장이 답해야 하는 5가지

1. **Fresh agent 디스패치 방법** — 전용 툴 / 서브프로세스(`codex exec`
   류) / 불가. 불가면 Tier C.
2. **병렬 실행 가능 여부** — 리뷰어 패널(loopspec·loopplan·loopnext
   3렌즈, looprun heavy 검증 2웨이브)용.
3. **스킬 설치 경로** — 이 하니스에서 loopspec/looprun 등을 명령으로
   노출하는 방법 (예: Codex `~/.codex/prompts/`).
4. **컨텍스트 리셋 + resume** — `/clear` 상당물, headless resume 명령
   (supervise.sh `LOOPSPACE_RESUME_CMD`에 꽂을 값).
5. **역할별 모델 라우팅** — 혼합 편성 선언 자리 + 역할별 권장 최소
   능력. 특히 검증자/리뷰어에 약한 모델을 쓸 때의 보증 약화를 명시.

## Capability Tier

| Tier | 조건 | 동작 |
|---|---|---|
| A | fresh dispatch + 병렬 | 현행 그대로 (풀 파이프라인) |
| B | fresh dispatch만 (병렬 불가) | 패널·웨이브를 순차 디스패치 — 보증 동일, 시간만 증가 |
| C | 단일 컨텍스트뿐 | 역할 교대: 컨텍스트 단절 선언("지금부터 검증자, 구현 과정 기억은 무시") 후 같은 절차 수행 — 실행되되 보증 물러짐 |

- 런 시작(loopspec) 또는 resume(loopresume) 시 하니스 프로필을 읽고
  `state.md`에 `harness:` / `tier:` 기록.
- report.md에 tier + 하니스/모델 명시.
- 런 도중 하니스 전환: state의 `harness:` 갱신, tier가 바뀌면 journal에
  한 줄. 상태 포맷이 이미 중립이므로 추가 기계 없음 — 전환 가능성 자체가
  이 설계의 부수 이점(예: Codex로 시작한 런을 Claude Code에서 resume).
- Tier C의 구조적 한계(검증자가 구현 컨텍스트에 오염될 수 있음)는 제거
  불가 → report의 tier 표기로 정직하게 커버.

## 스킬 중립화 리라이트 — 변경 목록

- looprun/loopspec/loopplan/loopnext: "서브에이전트 디스패치" 표현을
  "fresh agent 디스패치 (방법은 하니스 프로필)"로 치환. looprun per-task
  cycle과 각 패널 절차에 Tier B(순차)/C(역할 교대) 분기 블록 추가.
- looprun/references/agent-prompts.md: 프롬프트가 이미 self-contained
  (대화 컨텍스트 무가정)이므로 무수정.
- report.md 템플릿의 "Re-run /looprun after resolving." → "resume the
  run ..."으로 중립화 (선행 감사가 찾은 유일한 포맷 누수).
- loopresume: 시작 절차에 "하니스 프로필 확인 → state의 harness/tier
  대조" 추가.
- loopupdate: Claude Code 전용 명시 유지(이미 스킬에 적혀 있음). 타
  하니스 업데이트 경로(git pull 기반)는 harness-support.md에 기재.
- loopsupervise/supervise.sh: 무수정. 프로필의 headless 명령을
  RESUME_CMD에 꽂는 사용법만 harness-support.md에 문서화.
- state-format.md: `harness:` / `tier:` 필드 추가를 명세에 반영.

## 테스트

- **portability lint**: `scripts/test`에 스킬 파일에서 Claude Code 전용
  표현(예: "Task tool", "Claude Code" 등)이 허용 목록(loopupdate,
  claude-code.md 프로필 등) 밖에서 검출되면 실패하는 grep 체크 추가 —
  향후 회귀 방지.
- 기존 테스트 무회귀 (`scripts/test`).

## v1 범위와 acceptance

**범위:** 중립 코어 리라이트 + PROFILE-SPEC + 프로필 4장
(claude-code/codex/opencode/generic) + docs/harness-support.md +
portability lint. 제외: Cursor/Antigravity 프로필(C3), 설치 자동화
스크립트(C4), 외부 오케스트레이터(C1).

**acceptance:**
1. Codex CLI에서 소형 스펙 하나로 미니 런 1회 완주 (dogfood) — tier가
   state/report에 올바르게 기록될 것.
2. Claude Code에서 기존 테스트 + 미니 런 무회귀 (Tier A로 기록되고 현행
   동작과 동일).
3. portability lint가 스킬 전체를 통과.

**기록:** 착수 시 backlog 7번에 게이트 해제 사유(본 설계 대화)와 본 스펙
링크를 남긴다.
