#!/bin/sh
# loopspace SessionStart hook.
# Fast and silent when the project has no loopspace run; otherwise remind
# the session that an unfinished run exists. Always exit 0 — a hook must
# never break session start.

[ -f ".loopspace/state.md" ] || exit 0

status=$(sed -n 's/^run_status:[[:space:]]*//p' .loopspace/state.md | head -n 1 | tr -d '\r')

case "$status" in
  ""|complete) exit 0 ;;
esac

printf 'This project has an unfinished loopspace run (run_status: %s). ' "$status"
printf 'Run /loopresume — it reports status first, then continues the run.\n'
exit 0
