#!/bin/sh
# gate.sh — checkpoint gate for a loopspace lead-mode run.
#
# The only writer of .loopspace/gates.md, the only source of checkpoint
# commits, and the only path to run_status: complete in lead mode. The lead
# agent calls it when it believes an acceptance group is done; a
# cross-lineage verifier (Claude CLI by default) derives its own probes
# from the spec, runs them plus a mutation spot-check, and this script
# records the verdict mechanically.
#
# Usage: sh gate.sh <project-dir> <group-id>    checkpoint gate (e.g. G2)
#        sh gate.sh <project-dir> --final       completion gate
#
# Env:
#   LOOPSPACE_GATE_CMD      verifier command; prompt on stdin, report on
#                           stdout (default: claude -p --dangerously-skip-permissions)
#   LOOPSPACE_GATE_TIMEOUT  seconds before the verifier is killed
#                           (default 2400; keep it below the supervisor's
#                           LOOPSPACE_STALL_TIMEOUT; 0 disables)
#   LOOPSPACE_GATE_MAX_FAIL consecutive FAILs on one gate before the run
#                           halts (default 3)
#
# Exit: 0 PASS · 1 FAIL (findings on stdout) · 2 run halted (report.md
#       written) · 3 error — bad usage, missing/invalid state, verifier
#       timeout or unparseable output. Errors are never recorded as FAILs,
#       so an API outage cannot burn the gate's FAIL budget.
set -u

PROJECT="${1:-}"
GATE="${2:-}"
GATE_CMD="${LOOPSPACE_GATE_CMD:-claude -p --dangerously-skip-permissions}"
GATE_TIMEOUT="${LOOPSPACE_GATE_TIMEOUT:-2400}"
MAX_FAIL="${LOOPSPACE_GATE_MAX_FAIL:-3}"

[ -n "$PROJECT" ] && [ -n "$GATE" ] || { echo "usage: sh gate.sh <project-dir> <group-id | --final>" >&2; exit 3; }
case "$GATE_TIMEOUT" in ''|*[!0-9]*)
  echo "gate: LOOPSPACE_GATE_TIMEOUT must be a non-negative integer (got '$GATE_TIMEOUT')" >&2; exit 3 ;;
esac
case "$MAX_FAIL" in ''|0|*[!0-9]*)
  echo "gate: LOOPSPACE_GATE_MAX_FAIL must be a positive integer (got '$MAX_FAIL')" >&2; exit 3 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../skills/looplead/references/gate-verifier.md"

cd "$PROJECT" 2>/dev/null || { echo "gate: cannot cd to '$PROJECT'" >&2; exit 3; }
STATE=".loopspace/state.md"
SPEC=".loopspace/spec.md"
LEDGER=".loopspace/gates.md"

[ -f "$STATE" ] || { echo "gate: $STATE missing — not a loopspace run" >&2; exit 3; }
[ -f "$SPEC" ]  || { echo "gate: $SPEC missing" >&2; exit 3; }
[ -f "$TEMPLATE" ] || { echo "gate: verifier template missing at $TEMPLATE" >&2; exit 3; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "gate: lead mode requires a git repository" >&2; exit 3; }

field() { sed -n "s/^$1:[[:space:]]*//p" "$2" 2>/dev/null | head -n 1 | tr -d '\r'; }

[ "$(field mode "$STATE")" = "lead" ] \
  || { echo "gate: state.md has no 'mode: lead' — gates only run in lead mode" >&2; exit 3; }
status="$(field run_status "$STATE")"
[ "$status" = "executing" ] \
  || { echo "gate: run_status is '${status:-<none>}', not executing" >&2; exit 3; }
[ "$(field status "$SPEC")" = "approved" ] \
  || { echo "gate: spec.md is not approved" >&2; exit 3; }

# group ids from "## Acceptance Groups": lines "- G1: R1, R2 — name" -> "G1"
spec_groups() {
  awk '/^## Acceptance Groups/{f=1;next} /^## /{f=0} f && /^- G[0-9]+:/{sub(/^- /,"");sub(/:.*/,"");print}' "$SPEC"
}
groups="$(spec_groups)"
[ -n "$groups" ] || { echo "gate: spec.md has no '## Acceptance Groups' section" >&2; exit 3; }

if [ "$GATE" != "--final" ]; then
  echo "$groups" | grep -qx "$GATE" \
    || { echo "gate: group '$GATE' not in spec.md Acceptance Groups" >&2; exit 3; }
fi
gid="$GATE"
[ "$GATE" = "--final" ] && gid="final"

[ -f "$LEDGER" ] || printf '# Gates\nversion: 1\n' > "$LEDGER"
ledger() { printf '%s\n' "$1" >> "$LEDGER"; }
group_passed() { grep -q "^## \[gate $1\] verdict: PASS" "$LEDGER"; }
set_status() {
  sed "s/^run_status:.*/run_status: $1/" "$STATE" > "$STATE.gate.tmp" && mv "$STATE.gate.tmp" "$STATE"
}
# FAIL verdicts for this gate since its last PASS verdict
consecutive_fails() {
  grep "^## \[gate $1\] verdict:" "$LEDGER" | awk '/PASS/{n=0;next} /FAIL/{n++} END{print n+0}'
}
kill_tree() {
  for _kt_child in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$_kt_child"; done
  kill -9 "$1" 2>/dev/null
}

# ---- final gate: mechanical pre-check before spending a verifier call ----
if [ "$gid" = "final" ]; then
  missing=""
  for g in $groups; do group_passed "$g" || missing="$missing $g"; done
  if [ -n "$missing" ]; then
    ledger "## [gate final] blocked $(date +%Y-%m-%d) — ungated groups:$missing"
    echo "gate: final blocked — ungated groups:$missing"
    exit 1
  fi
fi

# ---- candidate commit: never let the verifier's mutation-restore touch
# uncommitted lead work ----
ledger "## [gate $gid] opened $(date -u +%Y-%m-%dT%H:%M:%SZ)"
git add -A
if [ -n "$(git status --porcelain)" ]; then
  git commit -q -m "loopspace: gate $gid candidate" 2>/dev/null || {
    ledger "## [gate $gid] error — candidate commit failed; refusing to run the verifier on an unprotected tree"
    echo "gate: candidate commit failed — fix the repo (hooks? signing?) and re-run" >&2
    exit 3
  }
fi

# ---- assemble prompt, run verifier (watchdogged in a later block) ----
prompt_file="$(mktemp)"
out_file="$(mktemp)"
trap 'rm -f "$prompt_file" "$out_file"' EXIT
{
  cat "$TEMPLATE"
  echo ""
  echo "MODE: $gid"
  echo ""
  echo "PROJECT FACTS:"
  awk '/^## Project Facts/{f=1;next} /^## /{f=0} f' "$STATE"
  echo ""
  echo "GATE LEDGER SO FAR:"
  cat "$LEDGER"
  echo ""
  echo "FULL SPEC:"
  cat "$SPEC"
} > "$prompt_file"

# eval so quoted args in GATE_CMD parse correctly (same seam as supervise.sh)
if [ "$GATE_TIMEOUT" -gt 0 ]; then
  eval "$GATE_CMD" < "$prompt_file" > "$out_file" 2>&1 &
  vpid=$!
  waited=0
  while kill -0 "$vpid" 2>/dev/null; do
    sleep 2
    waited=$((waited + 2))
    if [ "$waited" -ge "$GATE_TIMEOUT" ]; then
      kill -0 "$vpid" 2>/dev/null || break  # finished during the sleep — take its verdict
      kill_tree "$vpid"
      ledger "## [gate $gid] error — verifier timeout after ${GATE_TIMEOUT}s"
      echo "gate: verifier timed out after ${GATE_TIMEOUT}s" >&2
      exit 3
    fi
  done
  wait "$vpid" 2>/dev/null
  vrc=$?
else
  eval "$GATE_CMD" < "$prompt_file" > "$out_file" 2>&1
  vrc=$?
fi

verdict="$(sed -n 's/^verdict:[[:space:]]*//p' "$out_file" | tail -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//')"
case "$verdict" in
  PASS|FAIL) ;;
  *)
    ledger "## [gate $gid] error — no parseable verdict (rc=$vrc)"
    echo "gate: verifier returned no parseable verdict (rc=$vrc); output tail:" >&2
    tail -n 20 "$out_file" >&2
    exit 3 ;;
esac

report_line() { sed -n "s/^$1:[[:space:]]*/- $1: /p" "$out_file" | head -n 1 | tr -d '\r'; }
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ "$verdict" = "PASS" ]; then
  if [ "$gid" = "final" ]; then
    # the ONLY writer of run_status: complete — the lead cannot declare done
    set_status complete
    commit_msg="loopspace: run complete — final gate PASS"
  else
    commit_msg="loopspace: gate $gid verified"
  fi
  git add -A
  if [ -n "$(git status --porcelain)" ]; then
    git commit -q -m "$commit_msg" 2>/dev/null || {
      # completion must not stand without its commit — roll the flip back
      [ "$gid" = "final" ] && set_status executing
      ledger "## [gate $gid] error — verified commit failed after PASS; verdict not recorded, re-run the gate"
      echo "gate: verified commit failed after PASS — fix the repo and re-run the gate" >&2
      exit 3
    }
  fi
  {
    echo "## [gate $gid] verdict: PASS — $now"
    report_line note
    report_line probes
    report_line mutation
    echo "- commit: $(git rev-parse --short HEAD 2>/dev/null)"
  } >> "$LEDGER"
  git add .loopspace/gates.md
  git commit -q -m "loopspace: gate $gid ledger" 2>/dev/null || true
  echo "gate: $gid PASS"
  exit 0
fi

# FAIL
{
  echo "## [gate $gid] verdict: FAIL — $now"
  report_line note
  report_line probes
  report_line mutation
  sed -n '/^findings:/,$p' "$out_file" | sed '1d' | sed 's/^/- finding: /' | tr -d '\r'
} >> "$LEDGER"
echo "gate: $gid FAIL"
sed -n '/^findings:/,$p' "$out_file"
n="$(consecutive_fails "$gid")"
if [ "$n" -ge "$MAX_FAIL" ]; then
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  last_pass="$(grep '^## \[gate .*\] verdict: PASS' "$LEDGER" | tail -n 1 | sed 's/^## \[gate \([^]]*\)\].*/\1/')"
  {
    echo "# Halt Report"
    echo "version: 1"
    echo "written: $(date +%Y-%m-%d)"
    echo "trigger: gate-stall"
    echo "harness: $(field harness "$STATE")"
    echo "tier: $(field tier "$STATE")"
    echo "current_branch: $branch"
    echo "last_verified_gate: ${last_pass:-none}"
    echo ""
    echo "## Progress"
    grep '^## \[gate' "$LEDGER" | sed 's/^## /- /'
    echo ""
    echo "## Blocker"
    echo "Gate $gid failed $n consecutive times. Latest findings:"
    sed -n '/^findings:/,$p' "$out_file"
    echo ""
    echo "## Options"
    echo "- A: fix the findings (interactively or by resuming the lead) and re-gate"
    echo "- B: the findings reveal a spec problem — amend via /loopnext"
    echo "- C: abandon the run; merge nothing"
    echo ""
    echo "## Awaiting"
    echo "Human decision. Resume the run after resolving."
  } > .loopspace/report.md
  set_status halted
  git add .loopspace
  git commit -q -m "loopspace: halted — gate $gid stalled" 2>/dev/null || true
  echo "gate: $gid failed $n consecutive times — run halted (report.md written)"
  exit 2
fi
exit 1
