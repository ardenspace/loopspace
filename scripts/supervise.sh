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
#   LOOPSPACE_MAX_RESTARTS  absolute ceiling on resume launches per invocation,
#                           regardless of progress (default 50)
#   LOOPSPACE_STALL_TIMEOUT seconds of unchanged state.md/journal.md while the
#                           resume process is still alive before it is killed
#                           for a fresh restart (default 3600; 0 disables).
#                           Catches sessions that hang without dying — a live
#                           process never reaches the exit-time progress check.
#                           A long-running implementer attempt can legitimately
#                           go quiet for a while, so keep this generous: a
#                           false kill costs one restart (crash recovery
#                           absorbs it); a missed hang costs hours.
#   LOOPSPACE_MAX_FASTFAIL  consecutive sessions that exit nonzero within
#                           LOOPSPACE_FASTFAIL_SECS before the supervisor stops
#                           (default 3; 0 disables). Catches a dead/overloaded
#                           LLM backend: such sessions can still touch the
#                           journal, so the no-progress check never trips, and
#                           blind restarts would burn LOOPSPACE_MAX_RESTARTS
#                           against a backend that answers nothing. A healthy
#                           session (rc=0, or one that ran long) resets the
#                           counter; stall kills are not counted.
#   LOOPSPACE_FASTFAIL_SECS what counts as a fast exit, in seconds (default 60)
#
# Notes:
#   - The Telegram bot token appears in curl's argv, so it is visible in `ps`
#     to other users on shared machines. Acceptable under the same
#     container/dedicated-machine assumption --dangerously-skip-permissions
#     already requires; use a dedicated machine if that matters.
#   - LOOPSPACE_RESUME_CMD runs with CWD = the project directory (this script
#     cd's there), so relative paths in it resolve against the project, not
#     the terminal you launched from.
set -u

trap 'echo "supervise: interrupted" >&2; exit 130' INT TERM

PROJECT="${1:-.}"
MAX_NOPROGRESS="${LOOPSPACE_MAX_NOPROGRESS:-2}"
MAX_RESTARTS="${LOOPSPACE_MAX_RESTARTS:-50}"
STALL_TIMEOUT="${LOOPSPACE_STALL_TIMEOUT:-3600}"
MAX_FASTFAIL="${LOOPSPACE_MAX_FASTFAIL:-3}"
FASTFAIL_SECS="${LOOPSPACE_FASTFAIL_SECS:-60}"
RESUME_CMD="${LOOPSPACE_RESUME_CMD:-claude -p '/loopresume' --dangerously-skip-permissions}"

case "$MAX_NOPROGRESS" in
  ''|*[!0-9]*)
    echo "supervise: LOOPSPACE_MAX_NOPROGRESS must be a positive integer (got '$MAX_NOPROGRESS')" >&2
    exit 1 ;;
  0)
    echo "supervise: LOOPSPACE_MAX_NOPROGRESS must be >= 1 (got 0)" >&2
    exit 1 ;;
esac

case "$MAX_RESTARTS" in
  ''|*[!0-9]*)
    echo "supervise: LOOPSPACE_MAX_RESTARTS must be a positive integer (got '$MAX_RESTARTS')" >&2
    exit 1 ;;
  0)
    echo "supervise: LOOPSPACE_MAX_RESTARTS must be >= 1 (got 0)" >&2
    exit 1 ;;
esac

case "$STALL_TIMEOUT" in
  ''|*[!0-9]*)
    echo "supervise: LOOPSPACE_STALL_TIMEOUT must be a non-negative integer of seconds (got '$STALL_TIMEOUT')" >&2
    exit 1 ;;
esac

case "$MAX_FASTFAIL" in
  ''|*[!0-9]*)
    echo "supervise: LOOPSPACE_MAX_FASTFAIL must be a non-negative integer (got '$MAX_FASTFAIL')" >&2
    exit 1 ;;
esac

case "$FASTFAIL_SECS" in
  ''|*[!0-9]*)
    echo "supervise: LOOPSPACE_FASTFAIL_SECS must be a non-negative integer of seconds (got '$FASTFAIL_SECS')" >&2
    exit 1 ;;
esac

cd "$PROJECT" 2>/dev/null || { echo "supervise: cannot cd to '$PROJECT'" >&2; exit 1; }
STATE=".loopspace/state.md"

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

read_status() {
  sed -n 's/^run_status:[[:space:]]*//p' "$STATE" 2>/dev/null | head -n 1 | tr -d '\r'
}

progress_sig() {
  { cat "$STATE" 2>/dev/null
    wc -l 2>/dev/null < .loopspace/journal.md
  } | cksum
}

kill_tree() {
  # kill a process and all its descendants (the RESUME_CMD subshell plus
  # whatever harness process it spawned); POSIX sh has no process groups
  # here, so walk the tree via pgrep -P (macOS and Linux both have it)
  for _kt_child in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$_kt_child"; done
  kill -9 "$1" 2>/dev/null
}

prev_sig=""
noprogress=0
restarts=0
torn=0
fastfail=0

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
      torn=0
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
      if [ "$restarts" -ge "$MAX_RESTARTS" ]; then
        notify "run exceeded LOOPSPACE_MAX_RESTARTS ($MAX_RESTARTS) — stopping ($PROJECT)"
        exit 1
      fi
      restarts=$((restarts + 1))
      session_start="$(date +%s)"
      stall_killed=0
      # eval so quoted args in RESUME_CMD parse correctly; SC2086 intentional
      if [ "$STALL_TIMEOUT" -gt 0 ]; then
        # run the session in the background and watch for a live hang: a
        # process that keeps running while state.md/journal.md never change
        # (the exit-time progress check below can never see it)
        eval "$RESUME_CMD" &
        session_pid=$!
        stall_sig="$(progress_sig)"
        stall_since="$(date +%s)"
        while kill -0 "$session_pid" 2>/dev/null; do
          sleep 2
          s="$(progress_sig)"
          if [ "$s" != "$stall_sig" ]; then
            stall_sig="$s"
            stall_since="$(date +%s)"
          fi
          if [ $(( $(date +%s) - stall_since )) -ge "$STALL_TIMEOUT" ]; then
            notify "session stalled — no state/journal change for ${STALL_TIMEOUT}s with the process still alive; killing it for a fresh restart ($PROJECT)"
            kill_tree "$session_pid"
            stall_killed=1
            break
          fi
        done
        wait "$session_pid" 2>/dev/null
        session_rc=$?
      else
        eval "$RESUME_CMD"
        session_rc=$?
      fi
      session_dur=$(( $(date +%s) - session_start ))
      echo "supervise: session exited rc=$session_rc after ${session_dur}s (restart $restarts/$MAX_RESTARTS)"
      if [ "$MAX_FASTFAIL" -gt 0 ] && [ "$stall_killed" -eq 0 ] \
         && [ "$session_rc" -ne 0 ] && [ "$session_dur" -lt "$FASTFAIL_SECS" ]; then
        fastfail=$((fastfail + 1))
        if [ "$fastfail" -ge "$MAX_FASTFAIL" ]; then
          notify "run FAILING FAST — $fastfail consecutive error exits in under ${FASTFAIL_SECS}s each; LLM backend or harness likely down ($PROJECT)"
          exit 1
        fi
      else
        fastfail=0
      fi
      ;;
    spec|planning)
      notify "run_status='$status' — not an executing run, exiting ($PROJECT)"
      exit 1 ;;
    *)
      # Unknown/empty status can be a torn read (claude died mid-rewrite of
      # state.md). Retry once before treating it as fatal.
      if [ "$torn" -eq 0 ]; then
        torn=1
        echo "supervise: unrecognized run_status '${status:-<none>}' — possible torn write, retrying once" >&2
        sleep 3
      else
        notify "run_status='${status:-<none>}' — not an executing run, exiting ($PROJECT)"
        exit 1
      fi ;;
  esac
done
