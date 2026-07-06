---
name: loopupdate
description: Use when the user asks to update the loopspace plugin, check whether a newer loopspace version exists, or get the latest version after a release.
---

# loopupdate — Update the loopspace Plugin

Updates the installed plugin through the Claude Code plugin CLI and
reports what changed. Inherently Claude Code-specific — it manages the
Claude Code plugin cache; harness adapters don't port it.

## Steps

1. **Current version:** run `claude plugin list` and find loopspace's
   installed version. Fallback: this skill's base directory path contains
   the version number.
2. **Refresh the marketplace:** `claude plugin marketplace update loopspace`.
3. **Update:** `claude plugin update loopspace`. If the output says it is
   already up to date, report that and stop.
4. **What's new:** read `CHANGELOG.md` from the newly installed version's
   cache directory (sibling of this skill's install path, under the new
   version number) and show only the entries between the old and new
   versions, newest first — never the whole file.
5. **Run-state guard:** if `./.loopspace/state.md` exists with
   `run_status: executing`, say so explicitly: this session keeps the old
   templates until restart, and a restart mid-cycle mixes template
   versions inside one run. Recommend restarting at a stable point — the
   current task cycle finished, or a handoff written.
6. **Apply:** tell the human to restart Claude Code — the new version
   loads on the next session start. `/clear` is not enough; plugins load
   at process start.

## Errors

Any CLI step fails (marketplace missing, plugin not installed from a
marketplace, old CLI without `claude plugin`): print the manual path —
`/plugin` → loopspace → update — and stop. Never edit the plugin cache
by hand.
