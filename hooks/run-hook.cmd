: << 'CMDBLOCK'
@echo off
REM Cross-platform polyglot wrapper for hook scripts.
REM On Windows: cmd.exe runs the batch portion, which finds and calls sh.
REM On Unix: the shell interprets this as a script (: is a no-op in sh/bash).
REM
REM Adapted from the superpowers plugin's run-hook.cmd polyglot dispatcher
REM (see docs/windows/polyglot-hooks.md in the superpowers plugin cache).
REM One difference from that pattern: superpowers hook scripts are fully
REM extensionless on disk ("session-start", no ".sh"). loopspace hook
REM scripts keep the ".sh" extension on disk (e.g. "session-start.sh") so
REM they are self-documenting and directly runnable with `sh session-start.sh`
REM for testing. To avoid Claude Code's Windows auto-detection -- which
REM prepends "bash" to any hooks.json command string containing ".sh" --
REM the *argument* passed on the hooks.json command line stays extensionless
REM ("session-start"); this dispatcher appends ".sh" itself before invoking
REM the script. Future hooks just need a matching "<name>.sh" file in this
REM directory.
REM
REM Usage: run-hook.cmd <script-name> [args...]

if "%~1"=="" (
    echo run-hook.cmd: missing script name >&2
    exit /b 1
)

set "HOOK_DIR=%~dp0"
set "SCRIPT=%HOOK_DIR%%~1.sh"

REM Try Git for Windows sh in standard locations
if exist "C:\Program Files\Git\bin\sh.exe" (
    "C:\Program Files\Git\bin\sh.exe" "%SCRIPT%" %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %ERRORLEVEL%
)
if exist "C:\Program Files (x86)\Git\bin\sh.exe" (
    "C:\Program Files (x86)\Git\bin\sh.exe" "%SCRIPT%" %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %ERRORLEVEL%
)

REM Try sh on PATH (e.g. user-installed Git Bash, MSYS2, Cygwin)
where sh >nul 2>nul
if %ERRORLEVEL% equ 0 (
    sh "%SCRIPT%" %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %ERRORLEVEL%
)

REM No sh found - exit silently rather than error
REM (plugin still works, just without SessionStart context injection)
exit /b 0
CMDBLOCK

# Unix: run the named script directly (loopspace hook scripts keep a .sh
# extension on disk; the caller passes the extensionless name).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$1"
shift
exec sh "${SCRIPT_DIR}/${SCRIPT_NAME}.sh" "$@"
