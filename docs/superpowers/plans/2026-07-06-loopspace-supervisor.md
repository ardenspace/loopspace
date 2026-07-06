# Headless Supervisor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an opt-in headless supervisor that restarts an unattended loopspace run across context thresholds and crashes, notifies on halt/complete, and never auto-restarts a halt.

**Architecture:** A POSIX `sh` loop (`scripts/supervise.sh`) reads `.loopspace/state.md`'s `run_status` and, while `executing`, launches a fresh `claude -p "/loopresume"` process per iteration — process death is the context clear, so no `/clear` is needed. A front-door skill (`/loopsupervise`) checks preconditions in-session and prints the one-liner to paste in another terminal. Nothing in the existing loop (looprun, loopresume, state.md format) changes.

**Tech Stack:** POSIX `sh` (runs natively on macOS/Linux, and under Git Bash on Windows — same `sh.exe` the plugin's `run-hook.cmd` already assumes), `curl` for optional Telegram notification, `sed`/`wc`/`cksum` for state parsing. Skill authored in Markdown like the other four skills.

## Global Constraints

Every task's requirements implicitly include this section. Values copied verbatim from the design spec (`docs/superpowers/specs/2026-07-06-loopspace-supervisor-design.md`):

- **POSIX `sh` only** — no bash-isms (`[[ ]]`, arrays, `function` keyword). The script must run under `/bin/sh` (dash on Linux, Git Bash `sh.exe` on Windows).
- **Do not modify** `looprun`, `loopresume`, or `state.md`/state-format. The supervisor only *reads* existing state files. Format/skill immutability is the design's core.
- **`.loopspace/` is git-tracked** — never write secrets (Telegram token) into it. Config comes from env vars only.
- **halt never auto-restarts** — `run_status: halted` means "notify and exit," never relaunch.
- **Notify failure must not kill the loop** — a failed `curl` logs and continues.
- **The interactive `/clear` handoff stays mandatory** — supervisor is a separate opt-in path, not a replacement for it.
- **Version bump is minor** — `0.10.0` → `0.11.0` (new feature).
- **Harness-swap seam** — the resume command lives in one overridable variable (`LOOPSPACE_RESUME_CMD`) defaulting to the `claude` invocation, so a future harness is a one-line swap (backlog item 7 alignment). This same seam is how tests inject a mock.

---

## File Structure

- `scripts/supervise.sh` (create) — the supervisor loop. One responsibility: read state, dispatch on `run_status`, restart while executing.
- `scripts/test/supervise.test.sh` (create) — self-contained sh test harness. Sets up temp project dirs, injects a mock resume command via `LOOPSPACE_RESUME_CMD`, asserts exit codes / messages / restart counts.
- `skills/loopsupervise/SKILL.md` (create) — front-door skill: precondition checks + one-liner output.
- `README.md` (modify) — add a supervisor subsection after the 30% handoff bullet; note it's opt-in.
- `CHANGELOG.md` (modify) — `0.11.0` entry.
- `.claude-plugin/plugin.json:4` (modify) — version `0.10.0` → `0.11.0`.
- `docs/backlog-2026-07-05.md` (modify) — mark item 6 v1 shipped; record interactive-relaxation candidate rejected.

Tasks 2–4 build `scripts/supervise.sh` incrementally with the test harness growing alongside. Each task ends with green tests for its slice.

---

## Task 1: Spike — verify headless assumptions

**Files:** none (records a finding; may adjust the `LOOPSPACE_RESUME_CMD` default chosen in Task 2).

This gates everything: the whole design rests on `claude -p "/loopresume"` actually running the skill and the process exiting at the context threshold. Verify before building.

- [ ] **Step 1: Confirm the `claude` CLI is present and headless works at all**

Run: `claude -p "reply with the single word OK" --output-format text`
Expected: prints `OK` (or similar) and exits 0. If `claude` is not found, stop — the supervisor cannot work without it; report to the user.

- [ ] **Step 2: Confirm a slash command works as the `-p` prompt**

In a throwaway git dir with an existing `.loopspace/` run (or the toy-project used for dogfood), run:
`claude -p "/loopresume" --dangerously-skip-permissions`
Expected: the session runs the loopresume skill (reports run position) and the **process exits** rather than hanging.

- [ ] **Step 3: Record the finding and pick the resume-command default**

- If Step 2 works → Task 2's `LOOPSPACE_RESUME_CMD` default is
  `claude -p '/loopresume' --dangerously-skip-permissions`.
- If the slash command is NOT interpreted → fall back to a natural-language prompt that names the skill, e.g.
  `claude -p 'Run the loopresume skill and continue the loopspace run.' --dangerously-skip-permissions`, and use that as the default instead.
Append the outcome (one line) to the design spec under a new `## Spike result` heading so the decision is durable.

- [ ] **Step 4: Commit the recorded finding**

```bash
git add docs/superpowers/specs/2026-07-06-loopspace-supervisor-design.md
git commit -m "docs: supervisor spike — headless resume verified"
```

---

## Task 2: supervise.sh — state read + terminal-status dispatch

**Files:**
- Create: `scripts/supervise.sh`
- Test: `scripts/test/supervise.test.sh`

**Interfaces:**
- Consumes: `.loopspace/state.md` (`run_status:` line, same `sed` pattern as `hooks/session-start.sh`).
- Produces: `scripts/supervise.sh` usable as `sh supervise.sh <project-dir>`; env seams `LOOPSPACE_RESUME_CMD`, `LOOPSPACE_MAX_NOPROGRESS`, `LOOPSPACE_TG_BOT_TOKEN`, `LOOPSPACE_TG_CHAT_ID`. This task delivers the non-executing branches (missing state, `complete`, `halted`, other); Tasks 3–4 add `notify` body and the `executing` loop.

- [ ] **Step 1: Write the failing test harness with terminal-status cases**

Create `scripts/test/supervise.test.sh`:

```sh
#!/bin/sh
# Test harness for scripts/supervise.sh. POSIX sh. Run: sh scripts/test/supervise.test.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/supervise.sh"
PASS=0; FAIL=0
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
ok()   { PASS=$((PASS+1)); }

# make_project <run_status> -> prints a fresh temp project dir with .loopspace/state.md
make_project() {
  d="$(mktemp -d)"
  mkdir -p "$d/.loopspace"
  {
    echo "# Loopspace State"
    echo "version: 1"
    echo "run_status: $1"
    echo ""
    echo "## Tasks"
    echo "| id | status | attempts | risk |"
    echo "|----|--------|----------|------|"
    echo "| 1.1 | pending | 0 | light |"
  } > "$d/.loopspace/state.md"
  printf '# Journal\nversion: 1\n' > "$d/.loopspace/journal.md"
  echo "$d"
}

# ---- missing state ----
d="$(mktemp -d)"
out="$(sh "$SCRIPT" "$d" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -qi "no loopspace run" && ok || fail "missing-state (rc=$rc, out=$out)"

# ---- complete ----
d="$(make_project complete)"
out="$(sh "$SCRIPT" "$d" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && echo "$out" | grep -qi "complete" && ok || fail "complete (rc=$rc, out=$out)"

# ---- halted ----
d="$(make_project halted)"
out="$(sh "$SCRIPT" "$d" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && echo "$out" | grep -qi "halted" && ok || fail "halted (rc=$rc, out=$out)"

# ---- non-executing (spec) ----
d="$(make_project spec)"
out="$(sh "$SCRIPT" "$d" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -qi "not an executing run" && ok || fail "spec (rc=$rc, out=$out)"

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `sh scripts/test/supervise.test.sh`
Expected: FAIL — `scripts/supervise.sh` does not exist yet (`sh: ...supervise.sh: No such file or directory`).

- [ ] **Step 3: Write supervise.sh with the terminal-status branches**

Create `scripts/supervise.sh`:

```sh
#!/bin/sh
# supervise.sh — headless supervisor for an unattended loopspace run.
#
# Restarts the run across context thresholds and crashes by launching a fresh
# `claude -p "/loopresume"` each iteration: the process dying IS the context
# clear, so no interactive /clear is needed. Notifies on halt/complete via
# Telegram (opt-in); never auto-restarts a halt.
#
# Usage: sh supervise.sh <project-dir>
# Optional env:
#   LOOPSPACE_TG_BOT_TOKEN / LOOPSPACE_TG_CHAT_ID  Telegram notifications (both required to enable)
#   LOOPSPACE_RESUME_CMD    command to resume the run (harness-swap seam; default below)
#   LOOPSPACE_MAX_NOPROGRESS  restarts with no progress before giving up (default 2)
set -u

PROJECT="${1:-.}"
MAX_NOPROGRESS="${LOOPSPACE_MAX_NOPROGRESS:-2}"
RESUME_CMD="${LOOPSPACE_RESUME_CMD:-claude -p '/loopresume' --dangerously-skip-permissions}"

cd "$PROJECT" 2>/dev/null || { echo "supervise: cannot cd to '$PROJECT'" >&2; exit 1; }
STATE=".loopspace/state.md"

notify() {
  echo "supervise: $1"
}

read_status() {
  sed -n 's/^run_status:[[:space:]]*//p' "$STATE" 2>/dev/null | head -n 1 | tr -d '\r'
}

prev_sig=""
noprogress=0

while :; do
  if [ ! -f "$STATE" ]; then
    echo "supervise: no loopspace run in '$PROJECT' ($STATE missing)" >&2
    exit 1
  fi
  status="$(read_status)"
  case "$status" in
    complete)
      notify "run complete — $PROJECT"
      exit 0 ;;
    halted)
      notify "run HALTED — decision needed (see .loopspace/report.md)"
      exit 0 ;;
    executing)
      # filled in Task 4
      echo "supervise: executing branch not yet implemented" >&2
      exit 2 ;;
    *)
      notify "run_status='${status:-<none>}' — not an executing run, exiting ($PROJECT)"
      exit 1 ;;
  esac
done
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `sh scripts/test/supervise.test.sh`
Expected: `PASS=4 FAIL=0`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/supervise.sh scripts/test/supervise.test.sh
git commit -m "feat: supervise.sh terminal-status dispatch"
```

---

## Task 3: notify() — Telegram when configured, stdout otherwise

**Files:**
- Modify: `scripts/supervise.sh` (replace the `notify()` body)
- Test: `scripts/test/supervise.test.sh` (add a Telegram case with a `curl` shim)

**Interfaces:**
- Consumes: env `LOOPSPACE_TG_BOT_TOKEN`, `LOOPSPACE_TG_CHAT_ID`.
- Produces: `notify(msg)` always echoes to stdout; additionally POSTs to the Telegram Bot API when both env vars are set. A `curl` failure logs to stderr and returns success (never aborts the caller).

- [ ] **Step 1: Add the failing Telegram test**

Append to `scripts/test/supervise.test.sh`, before the final `echo "----"`:

```sh
# ---- telegram notify on complete (curl shimmed onto PATH) ----
d="$(make_project complete)"
shim="$(mktemp -d)"
cat > "$shim/curl" <<'SHIM'
#!/bin/sh
# record every arg, one per line, to the capture file
for a in "$@"; do echo "$a"; done >> "$CURL_CAPTURE"
SHIM
chmod +x "$shim/curl"
cap="$(mktemp)"
out="$(CURL_CAPTURE="$cap" PATH="$shim:$PATH" \
       LOOPSPACE_TG_BOT_TOKEN=TESTTOKEN LOOPSPACE_TG_CHAT_ID=12345 \
       sh "$SCRIPT" "$d" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] \
  && grep -q "api.telegram.org/botTESTTOKEN/sendMessage" "$cap" \
  && grep -q "12345" "$cap" \
  && ok || fail "telegram-notify (rc=$rc, cap=$(cat "$cap"))"

# ---- no telegram env => no curl call, still exits 0 ----
d="$(make_project complete)"
cap="$(mktemp)"
out="$(CURL_CAPTURE="$cap" PATH="$shim:$PATH" sh "$SCRIPT" "$d" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ ! -s "$cap" ] && ok || fail "no-telegram-env (rc=$rc, cap=$(cat "$cap"))"
```

- [ ] **Step 2: Run the test to verify the Telegram case fails**

Run: `sh scripts/test/supervise.test.sh`
Expected: FAIL on `telegram-notify` (current `notify` only echoes; the capture file stays empty).

- [ ] **Step 3: Replace the notify() body**

In `scripts/supervise.sh`, replace the whole `notify()` function with:

```sh
notify() {
  msg="$1"
  echo "supervise: $msg"
  if [ -n "${LOOPSPACE_TG_BOT_TOKEN:-}" ] && [ -n "${LOOPSPACE_TG_CHAT_ID:-}" ]; then
    curl -s -m 15 \
      "https://api.telegram.org/bot${LOOPSPACE_TG_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${LOOPSPACE_TG_CHAT_ID}" \
      --data-urlencode "text=loopspace: ${msg}" >/dev/null 2>&1 \
      || echo "supervise: telegram notify failed (continuing)" >&2
  fi
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `sh scripts/test/supervise.test.sh`
Expected: `PASS=6 FAIL=0`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/supervise.sh scripts/test/supervise.test.sh
git commit -m "feat: supervise.sh optional Telegram notify"
```

---

## Task 4: supervise.sh — executing restart loop + no-progress guard

**Files:**
- Modify: `scripts/supervise.sh` (add `progress_sig()`; replace the `executing)` branch)
- Test: `scripts/test/supervise.test.sh` (add restart + stuck cases with a mock resume command)

**Interfaces:**
- Consumes: `LOOPSPACE_RESUME_CMD` (invoked via `eval` each restart), `.loopspace/state.md` `## Tasks` table + `.loopspace/journal.md` line count for the progress signature.
- Produces: while `executing`, computes a progress signature; if it is identical for `MAX_NOPROGRESS` consecutive restarts, notifies "STUCK" and exits 1; otherwise runs `LOOPSPACE_RESUME_CMD` and re-reads state. Terminal statuses are handled by the loop head from Task 2.

- [ ] **Step 1: Add failing restart + stuck tests**

Append to `scripts/test/supervise.test.sh`, before the final `echo "----"`:

```sh
# ---- executing: resume advances state to complete after 3 restarts ----
d="$(make_project executing)"
mock="$(mktemp)"
cat > "$mock" <<MOCK
#!/bin/sh
# mock resume: append a journal line each call; flip to complete on the 3rd.
c="$d/.loopspace/count"
n=\$(cat "\$c" 2>/dev/null || echo 0); n=\$((n+1)); echo "\$n" > "\$c"
echo "## [1.\$n] attempt 1 — PASS" >> "$d/.loopspace/journal.md"
if [ "\$n" -ge 3 ]; then
  sed -i.bak 's/^run_status: .*/run_status: complete/' "$d/.loopspace/state.md"
fi
MOCK
chmod +x "$mock"
out="$(LOOPSPACE_RESUME_CMD="sh $mock" sh "$SCRIPT" "$d" 2>&1)"; rc=$?
calls="$(cat "$d/.loopspace/count" 2>/dev/null || echo 0)"
[ "$rc" -eq 0 ] && [ "$calls" -eq 3 ] && echo "$out" | grep -qi "complete" \
  && ok || fail "executing-restart (rc=$rc, calls=$calls, out=$out)"

# ---- executing: no progress => STUCK after MAX_NOPROGRESS restarts ----
d="$(make_project executing)"
mock="$(mktemp)"
cat > "$mock" <<MOCK
#!/bin/sh
# mock resume that never changes state (stuck)
c="$d/.loopspace/count"
n=\$(cat "\$c" 2>/dev/null || echo 0); echo "\$((n+1))" > "\$c"
MOCK
chmod +x "$mock"
out="$(LOOPSPACE_MAX_NOPROGRESS=2 LOOPSPACE_RESUME_CMD="sh $mock" sh "$SCRIPT" "$d" 2>&1)"; rc=$?
calls="$(cat "$d/.loopspace/count" 2>/dev/null || echo 0)"
[ "$rc" -eq 1 ] && [ "$calls" -eq 2 ] && echo "$out" | grep -qi "stuck" \
  && ok || fail "executing-stuck (rc=$rc, calls=$calls, out=$out)"
```

Note for the implementer: `sed -i.bak` in the first mock is the BSD/GNU-portable in-place form (macOS `sed` requires the backup suffix argument); Git Bash and Linux accept it too. The mock is test scaffolding, not shipped code.

- [ ] **Step 2: Run the test to verify it fails**

Run: `sh scripts/test/supervise.test.sh`
Expected: FAIL on `executing-restart` and `executing-stuck` — the `executing)` branch still prints "not yet implemented" and exits 2.

- [ ] **Step 3: Add progress_sig() and implement the executing branch**

In `scripts/supervise.sh`, add this function next to `read_status()`:

```sh
progress_sig() {
  { sed -n '/^## Tasks/,$p' "$STATE" 2>/dev/null
    wc -l < .loopspace/journal.md 2>/dev/null
  } | cksum
}
```

Then replace the `executing)` case body (the two "not yet implemented" lines) with:

```sh
    executing)
      sig="$(progress_sig)"
      if [ "$sig" = "$prev_sig" ]; then
        noprogress=$((noprogress + 1))
        if [ "$noprogress" -ge "$MAX_NOPROGRESS" ]; then
          notify "run STUCK — no progress across $MAX_NOPROGRESS restarts ($PROJECT)"
          exit 1
        fi
      else
        noprogress=0
      fi
      prev_sig="$sig"
      # eval so quoted args in RESUME_CMD parse correctly; SC2086 intentional
      eval "$RESUME_CMD"
      ;;
```

- [ ] **Step 4: Run the test to verify all pass**

Run: `sh scripts/test/supervise.test.sh`
Expected: `PASS=8 FAIL=0`, exit 0.

- [ ] **Step 5: Guard against an infinite-loop bug in CI (safety re-run)**

Run: `( sh scripts/test/supervise.test.sh & p=$!; sleep 30; kill "$p" 2>/dev/null ) ; wait`
Expected: the suite finishes well under 30s and prints `PASS=8 FAIL=0`. If it is killed at 30s, a branch is looping without a terminal exit — fix before committing. (Portable stand-in for `timeout`, which macOS lacks by default.)

- [ ] **Step 6: Commit**

```bash
git add scripts/supervise.sh scripts/test/supervise.test.sh
git commit -m "feat: supervise.sh executing restart loop + no-progress guard"
```

---

## Task 5: /loopsupervise skill — front door

**Files:**
- Create: `skills/loopsupervise/SKILL.md`

**Interfaces:**
- Consumes: `.loopspace/state.md` (`run_status`), the skill's own install path (to locate `scripts/supervise.sh`), env presence of `LOOPSPACE_TG_*`.
- Produces: an in-session precondition check and a printed one-liner the user pastes into another terminal. No test cycle (Markdown skill); the deliverable is the reviewed skill file.

- [ ] **Step 1: Write the skill**

Create `skills/loopsupervise/SKILL.md`:

```markdown
---
name: loopsupervise
description: Use when the user wants to run a loopspace run unattended (overnight/headless) so context-threshold handoffs happen automatically without typing /clear. Prints a one-liner to launch the supervisor in another terminal. Not for the normal interactive run.
---

# loopsupervise — Launch the Headless Supervisor

The supervisor restarts an unattended run across context thresholds and
crashes: each `claude -p "/loopresume"` is a fresh process, so process death
is the context clear — no `/clear` needed. It is an **opt-in power-user
path**. The normal interactive run keeps its manual `/clear` + `/loopresume`
handoff; this does not replace it. The supervisor lives at
`scripts/supervise.sh` in this plugin; this skill only checks preconditions
and prints the command to launch it elsewhere.

## Steps

1. **Precondition — a run exists and is executing.** Read
   `./.loopspace/state.md`. `run_status` must be `executing`.
   - Missing `.loopspace/state.md` → no run here; suggest `/loopspec` to
     start one. Stop.
   - `halted` → the run needs a human decision first; summarize
     `report.md`, tell them to resolve it with `/looprun`, then re-run
     `/loopsupervise`. The supervisor never auto-resumes a halt. Stop.
   - `spec` / `planning` → not an executing run yet; point to `/loopplan`
     or `/looprun`. Stop.
   - `complete` → nothing to supervise. Stop.
2. **Permission warning (loud).** The supervisor runs `claude` headless with
   `--dangerously-skip-permissions`. Tell the user plainly: only run it on a
   container, a dedicated machine, or a repo whose automatic execution they
   trust. This is the price of an unattended loop.
3. **Telegram check.** If `LOOPSPACE_TG_BOT_TOKEN` and
   `LOOPSPACE_TG_CHAT_ID` are both set in the environment, say notifications
   are on. Otherwise explain: without them the supervisor logs halt/complete
   to stdout only; to get phone alerts, prefix the command with both vars.
4. **Print the launch one-liner.** Resolve the absolute path to
   `scripts/supervise.sh` from this skill's base directory (sibling of
   `skills/`), and the target project's absolute path. Print exactly one
   pasteable line for another terminal:

   ```
   sh "<plugin-root>/scripts/supervise.sh" "<project-abs-path>"
   ```

   With Telegram, show the env-prefixed form instead:

   ```
   LOOPSPACE_TG_BOT_TOKEN=… LOOPSPACE_TG_CHAT_ID=… sh "<plugin-root>/scripts/supervise.sh" "<project-abs-path>"
   ```

   Tell the user to run it in a **separate** terminal (not this session), and
   that it will restart the run until it completes or halts, then notify.
   Do not launch it from inside this session (nohup lifetime and permission
   prompts get tangled).

## What the supervisor does (so you can explain it)

- `executing` → process died at the context threshold or crashed → relaunch.
- `complete` → notify, exit.
- `halted` → notify "decision needed," exit. Never auto-resume.
- No progress across restarts (default 2) → notify "stuck," exit.
```

- [ ] **Step 2: Sanity-check the skill file parses**

Run: `sed -n '1,12p' skills/loopsupervise/SKILL.md`
Expected: frontmatter with `name: loopsupervise` and a `description:` line, matching the shape of the other skills' frontmatter (`sed -n '1,4p' skills/looprun/SKILL.md` for comparison).

- [ ] **Step 3: Commit**

```bash
git add skills/loopsupervise/SKILL.md
git commit -m "feat: /loopsupervise skill — headless supervisor front door"
```

---

## Task 6: Docs + version bump

**Files:**
- Modify: `.claude-plugin/plugin.json:4`
- Modify: `CHANGELOG.md` (new top entry)
- Modify: `README.md` (supervisor subsection)
- Modify: `docs/backlog-2026-07-05.md` (item 6 status)

**Interfaces:** none (documentation + metadata). Deliverable: consistent version + user-facing docs describing the opt-in path.

- [ ] **Step 1: Bump the version**

In `.claude-plugin/plugin.json`, change line 4 from `"version": "0.10.0",` to `"version": "0.11.0",`.

- [ ] **Step 2: Add the CHANGELOG entry**

Insert directly after the `# Changelog` header line, above `## 0.10.0`:

```markdown
## 0.11.0 — 2026-07-06

- **Headless supervisor (opt-in, backlog item 6 v1).** A new `/loopsupervise`
  skill and `scripts/supervise.sh` let an unattended run restart itself across
  context thresholds and crashes: each `claude -p "/loopresume"` is a fresh
  process, so process death is the context clear — no `/clear` to type. The
  supervisor reads only `.loopspace/state.md` (`run_status`): `executing`
  relaunches, `complete`/`halted` notify and exit, and a halt is **never**
  auto-resumed (its whole meaning is "await a human"). A no-progress guard
  stops after two restarts that change nothing. Optional Telegram alerts fire
  on halt/complete when `LOOPSPACE_TG_BOT_TOKEN` and `LOOPSPACE_TG_CHAT_ID`
  are set; otherwise it logs to stdout. Nothing in the existing loop changed —
  looprun, loopresume, and the state format are untouched; the supervisor is a
  read-only control layer. The interactive run keeps its mandatory `/clear`
  handoff; the supervisor is a separate path for truly unattended (overnight)
  runs and assumes a container/dedicated machine (`--dangerously-skip-permissions`).
```

- [ ] **Step 3: Add the README supervisor subsection**

In `README.md`, immediately after the "30% context handoff." bullet (ends `...you have to do it.`, around line 151), add:

```markdown

**Unattended runs (opt-in).** That 30% handoff is a real manual step — fine
when you're at the keyboard, impossible overnight. For truly unattended runs
there's `/loopsupervise`: it prints a one-liner you run in a separate
terminal, and a small shell supervisor (`scripts/supervise.sh`) relaunches the
run each time it hits the threshold or crashes — a fresh `claude -p
"/loopresume"` process is its own clear, so nothing needs typing. It notifies
you (Telegram, or stdout) only at the moments that matter: the run completes,
or it halts and needs your decision — a halt is never auto-resumed. This is a
power-user path that runs `claude` with `--dangerously-skip-permissions`, so
it assumes a container or a machine you trust; the normal interactive flow and
its manual handoff are unchanged.
```

- [ ] **Step 4: Update the backlog item 6 status**

In `docs/backlog-2026-07-05.md`, update the item 6 row in the priority summary table (line ~24) to append ` — v1 구현 완료 (0.11.0, supervise.sh + /loopsupervise)` after the existing status text, and add a closing paragraph at the end of section 6 (after the "후속 결정 2건" block):

```markdown

**v1 구현 완료 (2026-07-06, 0.11.0):** `scripts/supervise.sh`(POSIX sh) +
`skills/loopsupervise` 배포. 확정 결정 V1~V5 전부 반영 — sh 정본(Mac
네이티브 + Windows Git Bash), 텔레그램 env opt-in, `--dangerously-skip-permissions`
전제, 무진전 2회 가드, halt=알림+exit. looprun/loopresume/state.md 무수정
(읽기 전용 제어 계층). 인터랙티브 경로 `/clear` 필수 유지 — **인터랙티브
경로 완화 후보는 기각**(사용자 결정: /clear 안내 필수 유지). halt 답장 자동
주입은 v2.
```

- [ ] **Step 5: Verify version consistency and run the full test suite once more**

Run: `grep -n '0.11.0' .claude-plugin/plugin.json CHANGELOG.md && sh scripts/test/supervise.test.sh`
Expected: version shows in both files; test suite prints `PASS=8 FAIL=0`.

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin/plugin.json CHANGELOG.md README.md docs/backlog-2026-07-05.md
git commit -m "docs: supervisor 0.11.0 — README, CHANGELOG, backlog item 6 v1 done"
```

---

## Self-Review

**Spec coverage** (against `2026-07-06-loopspace-supervisor-design.md`):
- `scripts/supervise.sh` loop + run_status dispatch → Tasks 2, 4 ✅
- `progress_sig` / no-progress guard (V4) → Task 4 ✅
- `notify` Telegram opt-in via env (V2) → Task 3 ✅
- `/loopsupervise` front door + preconditions + one-liner → Task 5 ✅
- Permission warning / `--dangerously-skip-permissions` (V3) → Task 5 step 2, default in Task 2 ✅
- halt = notify + exit, never auto-restart (V5) → Task 2 (`halted)` branch), Task 5 ✅
- sh-only, Mac + Windows-via-Git-Bash (V1) → Global Constraints, all sh tasks ✅
- looprun/loopresume/state.md untouched → no task modifies them ✅
- Harness-swap seam (item 7) → `LOOPSPACE_RESUME_CMD` in Task 2 ✅
- Headless-assumption verification → Task 1 spike ✅
- Docs/version/backlog → Task 6 ✅
- v1 non-goals (halt-reply injection, .ps1 twin, Agent SDK) → excluded, no tasks ✅

**Placeholder scan:** the `…` in Task 5's one-liner and README are illustrative env-value placeholders shown to the *user*, not plan gaps; every code/test step contains complete content. No TBD/TODO in shipped code.

**Type/name consistency:** `notify` / `read_status` / `progress_sig` names, env var names (`LOOPSPACE_RESUME_CMD`, `LOOPSPACE_MAX_NOPROGRESS`, `LOOPSPACE_TG_BOT_TOKEN`, `LOOPSPACE_TG_CHAT_ID`), and exit codes (0 complete/halted, 1 stuck/non-executing/missing, 2 unimplemented-in-Task-2-only) are consistent across Tasks 2–5 and the tests. Test count grows 4 → 6 → 8 across Tasks 2–4.
