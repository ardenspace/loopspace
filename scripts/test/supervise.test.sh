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
