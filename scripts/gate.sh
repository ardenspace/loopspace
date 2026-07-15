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
