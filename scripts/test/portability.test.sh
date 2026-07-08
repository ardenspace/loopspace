#!/bin/sh
# Portability lint: the skill core must stay harness-neutral.
# POSIX sh. Run: sh scripts/test/portability.test.sh
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
ok()   { PASS=$((PASS+1)); }

# 1) Harness-specific terms are banned in skill bodies.
#    Allowlist: skills/loopupdate (Claude Code-only by design).
hits="$(find "$ROOT/skills" -name '*.md' ! -path '*/loopupdate/*' \
  -exec grep -niE 'subagent|task tool' {} + 2>/dev/null)" || true
if [ -n "${hits:-}" ]; then
  fail "harness-specific terms in the neutral core:
$hits"
else ok; fi

# 2) The report template must not require a slash command to resume.
if grep -q 'Re-run /looprun' "$ROOT/docs/state-format.md"; then
  fail "state-format.md report template still says 'Re-run /looprun'"
else ok; fi

# 3) Every harness profile answers PROFILE-SPEC's required questions.
found_profile=0
for f in "$ROOT"/harnesses/*.md; do
  base="$(basename "$f")"
  [ "$base" = "PROFILE-SPEC.md" ] && continue
  found_profile=1
  for field in 'id:' 'tier:' 'verified:' '## Dispatch' '## Parallelism' '## Install' '## Reset & Resume' '## Model Routing'; do
    if grep -qF "$field" "$f"; then ok; else fail "$base missing '$field'"; fi
  done
done
[ "$found_profile" -eq 1 ] || fail "no harness profiles found in harnesses/"

echo "portability lint: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
