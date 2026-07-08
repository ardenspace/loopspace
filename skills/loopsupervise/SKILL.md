---
name: loopsupervise
description: Use when the user wants to run a loopspace run unattended (overnight/headless) so context-threshold handoffs happen automatically without typing /clear. Prints a one-liner to launch the supervisor in another terminal. Not for the normal interactive run.
---

# loopsupervise — Launch the Headless Supervisor

The supervisor restarts an unattended run across context thresholds and
crashes: each `claude -p "/loopresume"` is a fresh process, so process death
is the context clear — no `/clear` needed. It is an **opt-in power-user
path**. The normal interactive run keeps its manual `/clear` + `/loopresume`
handoff; this does not replace it. The supervisor lives at
`scripts/supervise.sh` in this plugin; this skill only checks preconditions
and prints the command to launch it elsewhere. On a non-Claude-Code
harness, the same supervisor drives the run through
`LOOPSPACE_RESUME_CMD` — set it to the headless resume command in your
harness profile (`../../harnesses/`).

## Steps

1. **Precondition — a run exists and is executing.** Read
   `./.loopspace/state.md`. `run_status` must be `executing`.
   - Missing `.loopspace/state.md` → no run here; suggest `/loopspec` to
     start one. Stop.
   - `halted` → the run needs a human decision first; summarize
     `report.md`, tell them to resolve it with `/looprun`, then re-run
     `/loopsupervise`. The supervisor never auto-resumes a halt. Stop.
   - `spec` / `planning` → not an executing run yet; point to `/loopplan`
     or `/looprun`. Stop.
   - `complete` → nothing to supervise. Stop.
2. **Permission warning (loud).** The supervisor runs `claude` headless with
   `--dangerously-skip-permissions`. Tell the user plainly: only run it on a
   container, a dedicated machine, or a repo whose automatic execution they
   trust. This is the price of an unattended loop.
3. **Telegram check.** If `LOOPSPACE_TG_BOT_TOKEN` and
   `LOOPSPACE_TG_CHAT_ID` are both set in the environment, say notifications
   are on. Otherwise explain: without them the supervisor logs halt/complete
   to stdout only; to get phone alerts, prefix the command with both vars.
4. **Print the launch one-liner.** Resolve the absolute path to
   `scripts/supervise.sh` from this skill's base directory (sibling of
   `skills/`), and the target project's absolute path. Print exactly one
   pasteable line for another terminal:

   ```
   sh "<plugin-root>/scripts/supervise.sh" "<project-abs-path>"
   ```

   With Telegram, show the env-prefixed form instead:

   ```
   LOOPSPACE_TG_BOT_TOKEN=… LOOPSPACE_TG_CHAT_ID=… sh "<plugin-root>/scripts/supervise.sh" "<project-abs-path>"
   ```

   Tell the user to run it in a **separate** terminal (not this session), and
   that it will restart the run until it completes or halts, then notify.
   Do not launch it from inside this session (nohup lifetime and permission
   prompts get tangled).

## What the supervisor does (so you can explain it)

- `executing` → process died at the context threshold or crashed → relaunch.
- `complete` → notify, exit.
- `halted` → notify "decision needed," exit. Never auto-resume.
- No progress across restarts (default 2) → notify "stuck," exit.
- Absolute restart ceiling (`LOOPSPACE_MAX_RESTARTS`, default 50) → notify and
  exit before launching again, even if every restart shows progress.
