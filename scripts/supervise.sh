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

case "$MAX_NOPROGRESS" in
  ''|*[!0-9]*)
    echo "supervise: LOOPSPACE_MAX_NOPROGRESS must be a positive integer (got '$MAX_NOPROGRESS')" >&2
    exit 1 ;;
  0)
    echo "supervise: LOOPSPACE_MAX_NOPROGRESS must be >= 1 (got 0)" >&2
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
  { sed -n '/^## Tasks/,$p' "$STATE" 2>/dev/null
    wc -l < .loopspace/journal.md 2>/dev/null
  } | cksum
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
    *)
      notify "run_status='${status:-<none>}' — not an executing run, exiting ($PROJECT)"
      exit 1 ;;
  esac
done
