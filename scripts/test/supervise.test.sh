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

# ---- non-numeric MAX_NOPROGRESS => fail fast, no infinite loop ----
d="$(make_project executing)"
out="$(LOOPSPACE_MAX_NOPROGRESS=abc LOOPSPACE_RESUME_CMD="true" sh "$SCRIPT" "$d" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -qi "integer" && ok || fail "max-noprogress-nonnumeric (rc=$rc, out=$out)"

# ---- executing: resume flips to halted on 1st call => never auto-resumed ----
d="$(make_project executing)"
mock="$(mktemp)"
cat > "$mock" <<MOCK
#!/bin/sh
# mock resume: flip run_status to halted on the very first call.
c="$d/.loopspace/count"
n=\$(cat "\$c" 2>/dev/null || echo 0); n=\$((n+1)); echo "\$n" > "\$c"
sed -i.bak 's/^run_status: .*/run_status: halted/' "$d/.loopspace/state.md"
MOCK
chmod +x "$mock"
out="$(LOOPSPACE_RESUME_CMD="sh $mock" sh "$SCRIPT" "$d" 2>&1)"; rc=$?
calls="$(cat "$d/.loopspace/count" 2>/dev/null || echo 0)"
[ "$rc" -eq 0 ] && [ "$calls" -eq 1 ] && echo "$out" | grep -qi "halted" \
  && ok || fail "halt-mid-supervision (rc=$rc, calls=$calls, out=$out)"

# ---- executing: always-progress resume => absolute restart ceiling stops it ----
d="$(make_project executing)"
mock="$(mktemp)"
cat > "$mock" <<MOCK
#!/bin/sh
# mock resume: always makes progress (journal grows), never finishes.
# Safety escape: flip to complete after 10 calls so a missing ceiling cannot
# hang the suite (assertion still fails RED: rc=0, calls=10).
c="$d/.loopspace/count"
n=\$(cat "\$c" 2>/dev/null || echo 0); n=\$((n+1)); echo "\$n" > "\$c"
echo "## [1.\$n] attempt 1 — PASS" >> "$d/.loopspace/journal.md"
if [ "\$n" -ge 10 ]; then
  sed -i.bak 's/^run_status: .*/run_status: complete/' "$d/.loopspace/state.md"
fi
MOCK
chmod +x "$mock"
out="$(LOOPSPACE_MAX_RESTARTS=3 LOOPSPACE_RESUME_CMD="sh $mock" sh "$SCRIPT" "$d" 2>&1)"; rc=$?
calls="$(cat "$d/.loopspace/count" 2>/dev/null || echo 0)"
[ "$rc" -eq 1 ] && [ "$calls" -eq 3 ] && echo "$out" | grep -qi "MAX_RESTARTS" \
  && ok || fail "restart-ceiling (rc=$rc, calls=$calls, out=$out)"

# ---- non-numeric MAX_RESTARTS => fail fast, no launch ----
d="$(make_project executing)"
out="$(LOOPSPACE_MAX_RESTARTS=abc LOOPSPACE_RESUME_CMD="true" sh "$SCRIPT" "$d" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -qi "integer" && ok || fail "max-restarts-nonnumeric (rc=$rc, out=$out)"

# ---- executing: session hangs alive without progress => stall kill, then STUCK ----
d="$(make_project executing)"
mock="$(mktemp)"
cat > "$mock" <<MOCK
#!/bin/sh
# mock resume that hangs: counts the call, then sleeps far past the test's
# stall timeout without ever touching state/journal. The supervisor must
# kill it (and this sleep) instead of waiting forever.
c="$d/.loopspace/count"
n=\$(cat "\$c" 2>/dev/null || echo 0); echo "\$((n+1))" > "\$c"
sleep 300
MOCK
chmod +x "$mock"
out="$(LOOPSPACE_STALL_TIMEOUT=2 LOOPSPACE_MAX_NOPROGRESS=2 LOOPSPACE_RESUME_CMD="sh $mock" sh "$SCRIPT" "$d" 2>&1)"; rc=$?
calls="$(cat "$d/.loopspace/count" 2>/dev/null || echo 0)"
[ "$rc" -eq 1 ] && [ "$calls" -eq 2 ] \
  && echo "$out" | grep -qi "stalled" && echo "$out" | grep -qi "stuck" \
  && ok || fail "stall-kill (rc=$rc, calls=$calls, out=$out)"

# ---- non-numeric STALL_TIMEOUT => fail fast ----
d="$(make_project executing)"
out="$(LOOPSPACE_STALL_TIMEOUT=abc LOOPSPACE_RESUME_CMD="true" sh "$SCRIPT" "$d" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -qi "integer" && ok || fail "stall-timeout-nonnumeric (rc=$rc, out=$out)"

# ---- STALL_TIMEOUT=0 disables the watcher; foreground path still completes ----
d="$(make_project executing)"
mock="$(mktemp)"
cat > "$mock" <<MOCK
#!/bin/sh
sed -i.bak 's/^run_status: .*/run_status: complete/' "$d/.loopspace/state.md"
MOCK
chmod +x "$mock"
out="$(LOOPSPACE_STALL_TIMEOUT=0 LOOPSPACE_RESUME_CMD="sh $mock" sh "$SCRIPT" "$d" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && echo "$out" | grep -qi "complete" && ok || fail "stall-timeout-disabled (rc=$rc, out=$out)"

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
