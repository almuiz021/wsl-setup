#!/usr/bin/env bash
# Claude Code -> Windows toast bridge (WSL2).
# Called by Notification and Stop hooks. Reads the hook JSON on stdin and pops
# a native Windows toast via a small PowerShell script on the C: drive.
#
# Hook JSON fields we use:
#   .hook_event_name  -> "Notification" | "Stop"
#   .message          -> Notification text (permission prompt / idle waiting)
#   .cwd              -> working dir, shown as context

PS1='C:\wsl\claude-notify.ps1'
PWSH='/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe'
[ -x "$PWSH" ] || PWSH="$(command -v powershell.exe)"

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
msg=$(printf '%s'   "$input" | jq -r '.message // empty'         2>/dev/null)
cwd=$(printf '%s'   "$input" | jq -r '.cwd // empty'             2>/dev/null)
proj=$(basename "${cwd:-$PWD}")

case "$event" in
  Notification)
    title="Claude needs you · $proj"
    body="${msg:-Waiting for your input}"
    ;;
  Stop)
    title="Claude is done · $proj"
    body="Finished responding — your turn."
    ;;
  *)
    title="Claude Code · $proj"
    body="${msg:-Update}"
    ;;
esac

# Fire and forget; never block the hook. One tag per event so repeats replace
# rather than stack up.
"$PWSH" -NoProfile -ExecutionPolicy Bypass -File "$PS1" \
  -Title "$title" -Message "$body" -ToastTag "claude-$event" >/dev/null 2>&1 &

exit 0
