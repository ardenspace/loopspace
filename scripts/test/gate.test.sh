#!/bin/sh
# Test harness for scripts/gate.sh. POSIX sh. Run: sh scripts/test/gate.test.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/gate.sh"
PASS=0; FAIL=0
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
ok()   { PASS=$((PASS+1)); }

# make_lead_project -> prints a fresh temp git project with an armed
# lead-mode .loopspace (spec approved, groups G1 G2, state executing)
make_lead_project() {
  d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" config user.email test@test && git -C "$d" config user.name test
  mkdir -p "$d/.loopspace"
  {
    echo "# Loopspace State"
    echo "version: 1"
    echo "run_status: executing"
    echo "harness: claude-code"
    echo "tier: A"
    echo "mode: lead"
    echo "budget_dispatches: 10"
    echo "budget_wall_hours: 4"
    echo ""
    echo "## Project Facts"
    echo "- test: true"
    echo "- build/run: none yet"
    echo "- stack: sh"
  } > "$d/.loopspace/state.md"
  {
    echo "# Spec: toy"
    echo "version: 1"
    echo "status: approved"
    echo ""
    echo "## Requirements"
    echo "- R1: alpha"
    echo "- R2: beta"
    echo ""
    echo "## Acceptance Groups"
    echo "- G1: R1 — alpha"
    echo "- G2: R2 — beta"
  } > "$d/.loopspace/spec.md"
  printf '# Journal\nversion: 1\n' > "$d/.loopspace/journal.md"
  git -C "$d" add -A && git -C "$d" commit -qm init
  echo "$d"
}

# stub_verifier <dir> <canned-report-file> -> prints path of a stub whose
# stdin is captured to <dir>/captured.txt and whose stdout is the canned report
stub_verifier() {
  cat > "$1/stub.sh" <<EOF
#!/bin/sh
cat > "$1/captured.txt"
cat "$2"
EOF
  echo "$1/stub.sh"
}

canned_pass() {
  cat > "$1" <<'EOF'
verdict: PASS
note: all good
probes: 3 scenarios → tests/probes_gate_G1.sh; all pass
mutation: flipped compare → suite went red
EOF
}

canned_fail() {
  cat > "$1" <<'EOF'
verdict: FAIL
note: probe 2 failed
probes: 3 scenarios → tests/probes_gate_G1.sh; 1 failing — see findings
mutation: skipped after probe failure
findings:
1. R1: input "x" expected "y", got "z"
EOF
}

# ---- usage / validation ----
out="$(sh "$SCRIPT" 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && echo "$out" | grep -q "usage" && ok || fail "no-args usage (rc=$rc)"

d="$(mktemp -d)"
out="$(sh "$SCRIPT" "$d" G1 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && echo "$out" | grep -q "state.md missing" && ok || fail "missing-state (rc=$rc, $out)"

d="$(make_lead_project)"
sed 's/^mode: lead//' "$d/.loopspace/state.md" > "$d/.loopspace/state.md.t" && mv "$d/.loopspace/state.md.t" "$d/.loopspace/state.md"
out="$(sh "$SCRIPT" "$d" G1 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && echo "$out" | grep -q "mode: lead" && ok || fail "non-lead state (rc=$rc, $out)"

d="$(make_lead_project)"
out="$(sh "$SCRIPT" "$d" G9 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && echo "$out" | grep -q "not in spec" && ok || fail "unknown group (rc=$rc, $out)"

d="$(make_lead_project)"
sed 's/^run_status: executing/run_status: halted/' "$d/.loopspace/state.md" > "$d/.loopspace/state.md.t" && mv "$d/.loopspace/state.md.t" "$d/.loopspace/state.md"
out="$(sh "$SCRIPT" "$d" G1 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && echo "$out" | grep -q "not executing" && ok || fail "halted state refused (rc=$rc, $out)"

echo "gate.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
