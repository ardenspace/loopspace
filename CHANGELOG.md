# Changelog

## 0.2.0 — 2026-07-03

**Breaking:** skills renamed to `loopspec`, `loopplan`, `looprun`, `loopresume`.
The short forms of the old names collided with built-in commands (`/plan`,
`/resume`), forcing the verbose `/loopspace:*` invocation. Update any saved
commands: `/spec` → `/loopspec`, `/plan` → `/loopplan`, `/run` → `/looprun`,
`/resume` → `/loopresume`.

## 0.1.0 — 2026-07-03

Initial release: `spec`, `plan`, `run`, `resume` skills and the SessionStart
resume-reminder hook.
