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

# ---- PASS path ----
d="$(make_lead_project)"; canned_pass "$d/report.txt"
stub="$(stub_verifier "$d" "$d/report.txt")"
echo "code" > "$d/impl.txt"
out="$(LOOPSPACE_GATE_CMD="sh $stub" sh "$SCRIPT" "$d" G1 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || fail "pass rc (rc=$rc, $out)"
grep -q '^## \[gate G1\] verdict: PASS' "$d/.loopspace/gates.md" && ok || fail "pass ledger entry"
grep -q '^## \[gate G1\] opened' "$d/.loopspace/gates.md" && ok || fail "opened ledger entry"
git -C "$d" log --oneline | grep -q "gate G1 verified" && ok || fail "verified commit"
git -C "$d" log --oneline | grep -q "gate G1 candidate" && ok || fail "candidate commit"
[ -z "$(git -C "$d" status --porcelain | grep -v gates.md)" ] && ok || fail "tree committed on PASS"
grep -q '^- commit: ' "$d/.loopspace/gates.md" && ok || fail "commit line in ledger"

# ---- prompt assembly ----
grep -q "^MODE: G1$" "$d/captured.txt" && ok || fail "prompt MODE"
grep -q "FULL SPEC:" "$d/captured.txt" && grep -q "R1: alpha" "$d/captured.txt" && ok || fail "prompt spec"
grep -q "GATE LEDGER SO FAR:" "$d/captured.txt" && ok || fail "prompt ledger"
grep -q "checkpoint gate of a lead-mode loopspace run" "$d/captured.txt" && ok || fail "prompt template text"
grep -q "test: true" "$d/captured.txt" && ok || fail "prompt project facts"

# ---- FAIL path ----
d="$(make_lead_project)"; canned_fail "$d/report.txt"
stub="$(stub_verifier "$d" "$d/report.txt")"
out="$(LOOPSPACE_GATE_CMD="sh $stub" sh "$SCRIPT" "$d" G1 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || fail "fail rc (rc=$rc)"
echo "$out" | grep -q 'expected "y", got "z"' && ok || fail "findings echoed"
grep -q '^## \[gate G1\] verdict: FAIL' "$d/.loopspace/gates.md" && ok || fail "fail ledger entry"
grep -q '^- finding: 1\.' "$d/.loopspace/gates.md" && ok || fail "findings in ledger"
git -C "$d" log --oneline | grep -q "gate G1 verified" && fail "no verified commit on FAIL" || ok

# ---- error path: no parseable verdict ----
d="$(make_lead_project)"
printf 'API error: overloaded\n' > "$d/report.txt"
stub="$(stub_verifier "$d" "$d/report.txt")"
out="$(LOOPSPACE_GATE_CMD="sh $stub" sh "$SCRIPT" "$d" G1 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && ok || fail "no-verdict rc (rc=$rc)"
grep -q '^## \[gate G1\] error — no parseable verdict' "$d/.loopspace/gates.md" && ok || fail "error ledger entry"
grep -q 'verdict: FAIL' "$d/.loopspace/gates.md" && fail "error must not be a FAIL" || ok

# ---- a genuinely failing commit is an infra error, not a silent no-op ----
d="$(make_lead_project)"; canned_pass "$d/report.txt"
stub="$(stub_verifier "$d" "$d/report.txt")"
mkdir -p "$d/.git/hooks" && printf '#!/bin/sh\nexit 1\n' > "$d/.git/hooks/pre-commit" && chmod +x "$d/.git/hooks/pre-commit"
echo "dirty" > "$d/lead-work.txt"
out="$(LOOPSPACE_GATE_CMD="sh $stub" sh "$SCRIPT" "$d" G1 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && ok || fail "commit-fail rc (rc=$rc, $out)"
grep -q 'candidate commit failed' "$d/.loopspace/gates.md" && ok || fail "commit-fail ledger entry"
[ -f "$d/captured.txt" ] && fail "verifier must not run without candidate commit" || ok

# ---- trailing whitespace after the verdict still parses ----
d="$(make_lead_project)"
printf 'verdict: PASS \nnote: trailing space\nprobes: p\nmutation: m\n' > "$d/report.txt"
stub="$(stub_verifier "$d" "$d/report.txt")"
out="$(LOOPSPACE_GATE_CMD="sh $stub" sh "$SCRIPT" "$d" G1 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok || fail "trailing-space verdict (rc=$rc, $out)"

# ---- consecutive-FAIL halt (3rd FAIL on same gate) ----
d="$(make_lead_project)"; canned_fail "$d/report.txt"
stub="$(stub_verifier "$d" "$d/report.txt")"
LOOPSPACE_GATE_CMD="sh $stub" sh "$SCRIPT" "$d" G1 >/dev/null 2>&1
LOOPSPACE_GATE_CMD="sh $stub" sh "$SCRIPT" "$d" G1 >/dev/null 2>&1
out="$(LOOPSPACE_GATE_CMD="sh $stub" sh "$SCRIPT" "$d" G1 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && ok || fail "halt rc (rc=$rc, $out)"
grep -q '^trigger: gate-stall' "$d/.loopspace/report.md" && ok || fail "report trigger"
grep -q '^last_verified_gate: none' "$d/.loopspace/report.md" && ok || fail "report last gate"
grep -q '^run_status: halted' "$d/.loopspace/state.md" && ok || fail "halted state"
git -C "$d" log --oneline | grep -q "halted — gate G1 stalled" && ok || fail "halt commit"

# ---- a PASS resets the FAIL count ----
d="$(make_lead_project)"
canned_fail "$d/fail.txt"; canned_pass "$d/pass.txt"
stubf="$(stub_verifier "$d" "$d/fail.txt")"
LOOPSPACE_GATE_CMD="sh $stubf" sh "$SCRIPT" "$d" G1 >/dev/null 2>&1
LOOPSPACE_GATE_CMD="sh $stubf" sh "$SCRIPT" "$d" G1 >/dev/null 2>&1
cat > "$d/stub2.sh" <<EOF
#!/bin/sh
cat > /dev/null
cat "$d/pass.txt"
EOF
LOOPSPACE_GATE_CMD="sh $d/stub2.sh" sh "$SCRIPT" "$d" G1 >/dev/null 2>&1
out="$(LOOPSPACE_GATE_CMD="sh $stubf" sh "$SCRIPT" "$d" G1 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && ok || fail "PASS resets fail count (rc=$rc — a halt means it didn't reset)"

# ---- fails on different gates never pool ----
d="$(make_lead_project)"; canned_fail "$d/report.txt"
stub="$(stub_verifier "$d" "$d/report.txt")"
LOOPSPACE_GATE_CMD="sh $stub" sh "$SCRIPT" "$d" G1 >/dev/null 2>&1
LOOPSPACE_GATE_CMD="sh $stub" sh "$SCRIPT" "$d" G1 >/dev/null 2>&1
out="$(LOOPSPACE_GATE_CMD="sh $stub" sh "$SCRIPT" "$d" G2 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && ok || fail "per-gate fail isolation (rc=$rc)"

# ---- verified-commit failure leaves no phantom PASS ----
d="$(make_lead_project)"; canned_pass "$d/report.txt"
stub="$(stub_verifier "$d" "$d/report.txt")"
cat > "$d/.git/hooks/pre-commit" <<'HOOK'
#!/bin/sh
c=0; [ -f .hookcount ] && c=$(cat .hookcount)
c=$((c+1)); echo "$c" > .hookcount
[ "$c" -ge 2 ] && exit 1
exit 0
HOOK
chmod +x "$d/.git/hooks/pre-commit"
echo "dirty" > "$d/lead-work.txt"
out="$(LOOPSPACE_GATE_CMD="sh $stub" sh "$SCRIPT" "$d" G1 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && ok || fail "verified-commit-fail rc (rc=$rc, $out)"
grep -q 'verified commit failed' "$d/.loopspace/gates.md" && ok || fail "verified-fail ledger error line"
grep -q '^## \[gate G1\] verdict: PASS' "$d/.loopspace/gates.md" && fail "phantom PASS recorded" || ok

# ---- PASS path leaves a fully clean tree (ledger follow-up commit) ----
d="$(make_lead_project)"; canned_pass "$d/report.txt"
stub="$(stub_verifier "$d" "$d/report.txt")"
echo "code" > "$d/impl.txt"
out="$(LOOPSPACE_GATE_CMD="sh $stub" sh "$SCRIPT" "$d" G1 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok || fail "pass-clean rc (rc=$rc)"
[ -z "$(git -C "$d" status --porcelain)" ] && ok || fail "tree fully clean after PASS"
git -C "$d" log --oneline | grep -q "gate G1 ledger" && ok || fail "ledger follow-up commit"

echo "gate.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
