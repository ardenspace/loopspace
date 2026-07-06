# Design: headless supervisor — 무인 런 자동 재기동 (백로그 6번)

작성 2026-07-06. 백로그 `docs/backlog-2026-07-05.md` 6번의 v1 구현 설계.
전제 검증(compaction이 오케스트레이터 규율을 깨지 않음)은 toy-project
simple-todo 런에서 완료됨. 이 문서는 그 뒤의 구현 결정을 확정한다.

## 문제

현행 loopspace 런에서 사람이 손대는 유일한 지점은 **30% 컨텍스트 임계
핸드오프**다 — looprun이 `handoff.md`를 쓰고 턴을 끝내며 "`/clear` 후
`/loopresume`을 쳐라"라고 안내하면, 사람이 그 두 명령을 직접 타이핑한다.
Claude Code 세션은 자기 컨텍스트를 스스로 비울 수 없으므로(하니스 제약)
인터랙티브 경로에서는 이 수동 단계가 불가피하고, **그대로 필수로 남긴다.**

하지만 **진짜 무인 런**(터미널을 안 보는 밤샘 실행)은 이 수동 핸드오프가
불가능하다. 사람이 자고 있으면 임계에서 런이 멈춰 선다. supervisor는 이
경우에만 쓰는 별개의 opt-in 파워유저 경로다.

## 핵심 통찰: 헤드리스에는 `/clear`가 없다

`/clear` 댄스는 런이 인터랙티브 터미널 세션 **하나**에 살기 때문에 존재한다.
`claude -p "/loopresume"`는 매 호출이 **새 프로세스 = 새 컨텍스트** —
프로세스 종료가 곧 클리어다. 그래서 supervisor는 "클리어"를 할 필요가 없다.
프로세스를 새로 띄우는 것으로 충분하다.

```
프로세스 시작 → /loopresume → 태스크 사이클 여러 번 → 30% 임계 →
  handoff.md 작성 → 턴 종료 → 프로세스 사망
        ↑                                              ↓
        └──── supervisor: run_status=executing 감지 → 재기동 ────┘
```

looprun의 임계 핸드오프는 `run_status: executing`을 유지한 채 handoff.md만
쓴다. 그래서 **"프로세스 사망 + executing" = 재기동**으로 판별이 끝난다.
크래시도 같은 신호로 수렴하고(loopresume이 어차피 크래시 복구 담당),
**state.md 포맷은 수정 불요, looprun 스킬도 한 줄 안 고친다.**

## 구성 요소 2개

### ① `scripts/supervise.sh` — POSIX sh, ~90줄

무인 재기동 루프. 플러그인 repo 안에 배포된다(별도 배포물 아님 —
`hooks/session-start.sh`가 선례). 인터페이스: `sh supervise.sh <project-dir>`.

의사코드:

```sh
PROJECT=${1:-.}; cd "$PROJECT" || exit 1
STATE=.loopspace/state.md
MAX_NOPROGRESS=2
prev_sig=""; noprogress=0

while :; do
  [ -f "$STATE" ] || { echo "no loopspace run in $PROJECT"; exit 1; }
  status=$(sed -n 's/^run_status:[[:space:]]*//p' "$STATE" | head -n1 | tr -d '\r')

  case "$status" in
    complete)
      notify "✅ loopspace run complete — $PROJECT"; exit 0 ;;
    halted)
      notify "⛔ loopspace HALTED — decision needed (.loopspace/report.md)"; exit 0 ;;
    spec|planning|"")
      notify "⚠️ run_status=$status — not an executing run, supervisor exiting"; exit 1 ;;
    executing)
      sig=$(progress_sig)
      if [ "$sig" = "$prev_sig" ]; then
        noprogress=$((noprogress + 1))
        if [ "$noprogress" -ge "$MAX_NOPROGRESS" ]; then
          notify "⚠️ loopspace STUCK — no progress across ${MAX_NOPROGRESS} restarts"; exit 1
        fi
      else
        noprogress=0
      fi
      prev_sig=$sig
      claude -p "/loopresume" --dangerously-skip-permissions   # 종료까지 블록
      ;;
  esac
done
```

보조 함수:

- `progress_sig` — 재기동 사이 진전 여부 판별용 시그니처. `state.md`의
  `## Tasks` 테이블 이하 + `journal.md`의 줄 수를 이어붙여 `cksum`(POSIX)에
  통과시킨 값. current_task 이동·태스크 상태 전진·저널 성장 중 어느 하나라도
  있으면 시그니처가 바뀐다. 2회 연속 동일 → 무진전으로 판정.
- `notify` — 텔레그램 알림. `LOOPSPACE_TG_BOT_TOKEN`과
  `LOOPSPACE_TG_CHAT_ID`가 둘 다 설정돼 있을 때만 Telegram Bot API에 `curl`
  한 줄(`sendMessage`). 둘 중 하나라도 없으면 stdout에 프린트만 하고 조용히
  넘어간다(알림은 opt-in). curl/네트워크 실패는 supervisor를 죽이지 않는다 —
  실패해도 로그만 남기고 루프 계속.

`run_status` 분기 판정:

| status | 의미 | supervisor 동작 |
|---|---|---|
| `executing` | 도는 중 (임계로 프로세스만 죽음, 또는 크래시) | **재기동** ✅ |
| `complete` | 다 끝남 | 완료 알림 → exit 0 |
| `halted` | 사람 결정 대기 | **재기동 금지**, 알림만 → exit 0 ⛔ |
| `spec`/`planning`/없음 | 실행 런 아님 | 알림 → exit 1 |

### ② `/loopsupervise` 스킬 — 앞문

세션 안에서 전제조건만 확인하고 **딴 터미널에 붙여넣을 한 줄을 출력**한다.
세션 안에서 `nohup` 자동 실행은 하지 않는다 — 수명 관계·권한 프롬프트가
꼬인다.

절차:
1. 전제조건 확인: `.loopspace/state.md` 존재, `run_status`가 `executing`
   (아니면 왜 supervisor가 부적합한지 설명하고 멈춤 — halt면 먼저 `/looprun`
   으로 풀라고, spec/planning이면 아직 실행 단계 아니라고).
2. 텔레그램 env 유무 확인 후 안내(설정돼 있으면 "알림 켜짐", 없으면 "알림
   없이 stdout만 — 켜려면 이 두 env를 앞에 붙여라").
3. **권한 경고를 크게** 출력: supervisor는 `--dangerously-skip-permissions`로
   무인 실행하므로 컨테이너/전용 머신, 또는 자동 실행을 신뢰하는 repo에서만
   돌려라.
4. 스킬 자기 설치 경로로 `supervise.sh` 절대 경로를 구성해 붙여넣을 한 줄
   출력:
   ```
   LOOPSPACE_TG_BOT_TOKEN=… LOOPSPACE_TG_CHAT_ID=… \
     sh "<plugin-root>/scripts/supervise.sh" "<project-abs-path>"
   ```
   (텔레그램 안 쓰면 env 접두어 없이.)

## 확정된 설계 결정 (거부권 검토 완료)

| # | 결정 | 선택 | 근거 |
|---|---|---|---|
| V1 | 플랫폼 | **sh 정본만.** Mac(주력)은 네이티브, Windows 회사 서버는 Git Bash(`run-hook.cmd`가 이미 전제)에서 실행. `.ps1` 트윈 v1 제외 | 무인 밤샘 런은 본래 컨테이너/전용머신 개념. sh 하나가 두 환경 커버. 폴리글롯 트윈은 순수 Windows(Git Bash 없음) 수요가 생길 때 |
| V2 | 텔레그램 설정 | **env var** (`LOOPSPACE_TG_BOT_TOKEN`/`_CHAT_ID`), opt-in. 없으면 stdout | `.loopspace/`는 git 추적 대상 → 토큰을 상태 파일에 못 넣음. env가 유일하게 안전 |
| V3 | 권한 | **`--dangerously-skip-permissions`** 전제, 스킬이 크게 경고 | 무인 헤드리스가 권한 프롬프트에서 막히면 무의미. "컨테이너/전용머신/신뢰 repo" 전제 명시 |
| V4 | 무진전 임계 | **2회 연속** 동일 시그니처 → 정지+알림 | 백로그 "N회 무진전 가드" 구체화. 무한 재기동 방지 |
| V5 | halt 처리 | **알림 + exit** (사람이 `/looprun`으로 풀고 원하면 재실행) | "halt는 절대 자동 재기동 금지" 무손상. 답장 주입 자동화는 v2 |

## 가드 (구현 시 필수)

- **halt 자동 재기동 절대 금지** — halt의 의미(사람 결정 대기)가 죽는다.
  v1은 알림만.
- **무진전 가드** — 위 V4. 무한 재기동 방지.
- **권한** — V3. 스킬이 경고를 출력하고 사람이 판단.
- **알림 실패 격리** — curl/네트워크 실패가 supervisor 루프를 죽이면 안 됨.
- **인터랙티브 경로 무손상** — looprun의 30% 임계 `/clear` 수동 핸드오프는
  그대로 필수. supervisor는 별개 opt-in 경로이지 인터랙티브 경로의 대체가
  아니다.

## 명시적 비목표 (v1 아웃)

- **halt 답장 자동 주입** — 텔레그램 답장을 `claude -p "/looprun — 결정: …"`
  로 주입하는 것은 v2.
- **`.ps1`/폴리글롯 Windows 네이티브 트윈** — Git Bash 없는 순수 Windows
  수요가 관측될 때까지 보류(V1).
- **looprun/loopresume/state.md 수정** — supervisor는 기존 상태 파일을
  읽기만 한다. 포맷·스킬 무수정이 설계의 핵심.
- **Agent SDK 사용** — SDK는 Claude 전용이라 백로그 7번(다중 하니스)과
  부정합. 셸 + CLI 명령 스왑이 하니스 중립.

## 7번(다중 하니스)과의 관계

supervisor는 하니스 중립적인 유일한 제어 계층이 된다. 아는 것은 실행
명령(`claude -p …` vs 미래의 `codex exec …`)과 `.loopspace/` 상태 파일뿐 —
하니스 교체는 launch command 한 줄 스왑. looprun 스킬 로직 포팅(7번의 진짜
리프트)과는 무관한 계층이다. v1은 `claude` CLI로 하드코딩하되, 실행 명령을
스크립트 상단 변수로 빼 미래 스왑 지점을 남긴다.

## 정당성 (검증된 방식인가)

헤드리스는 Claude Code 공식 표면이다 — 공식 문서 "Run Claude Code
programmatically", 자동화 전용 플래그(`--allowedTools`,
`--dangerously-skip-permissions`, `--output-format`), Anthropic 자체 GitHub
Action도 헤드리스 구동. 비공식 뒷문이 아니다.

## 구현 전 검증할 가정 (플랜 1단계)

- **`claude -p "/loopresume"`가 슬래시 명령을 실제로 실행하는가.** 헤드리스
  모드에서 `-p` 프롬프트로 넘긴 슬래시 명령이 스킬로 해석되는지 확인.
  안 되면 대안: `-p "Run the loopresume skill and continue the run"` 같은
  자연어 프롬프트, 또는 `--append-system-prompt`로 스킬 강제. 이 검증이
  통과해야 나머지가 성립하므로 구현 첫 스텝으로 둔다.
- **임계 핸드오프 후 프로세스가 실제로 종료되는가.** looprun이 30%에서 턴을
  끝내면 `claude -p`가 exit하는지(무한 대기 안 하는지) 확인.

## 배포/버전

- `scripts/supervise.sh` 신규 파일 1개.
- `skills/loopsupervise/SKILL.md` 신규 스킬 1개.
- README에 supervisor 문단 추가(opt-in 파워유저 경로임을 명시, 인터랙티브
  기본 흐름은 그대로임을 강조).
- CHANGELOG 엔트리 + VERSION bump(minor — 새 기능).
- 백로그 6번 상태 갱신, 인터랙티브 경로 완화 후보는 기각으로 기록.
