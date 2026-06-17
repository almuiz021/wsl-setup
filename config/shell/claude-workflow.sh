# ── Multi-window Claude workflow ─────────────────────────────────────────────
# Reusable for ANY project. No hardcoded paths.
#
# Practice: one window = one Claude session. Launch where the task lives —
#   inside a module for focused work, at the parent for cross-module work.

# work [N] — open a tmux session (named after the current folder) with N windows,
# all opened in the CURRENT directory. Default N=1.
#   $ cd ~/path/to/project && work 3
# Re-running attaches the existing session (and tops up to N windows if more
# are requested). Switch windows with Alt+q/w/e/… (see ~/.tmux.conf).
work() {
  command -v tmux >/dev/null || { echo "tmux not installed"; return 1; }
  local n="${1:-1}"
  case "$n" in (*[!0-9]*|'') echo "usage: work [number-of-windows]"; return 1;; esac
  [ "$n" -lt 1 ] && n=1
  [ "$n" -gt 10 ] && n=10

  local root name s
  root="$PWD"
  name="$(basename "$root")"
  s="${name//[.:]/-}"                       # tmux forbids . and : in names

  if ! tmux has-session -t "$s" 2>/dev/null; then
    tmux new-session -d -s "$s" -c "$root"   # window 1
  fi
  # Top up to N windows, all rooted at the launch dir.
  while [ "$(tmux list-windows -t "$s" 2>/dev/null | wc -l)" -lt "$n" ]; do
    tmux new-window -t "$s" -c "$root"
  done

  tmux select-window -t "$s:1"
  if [ -n "$TMUX" ]; then tmux switch-client -t "$s"; else tmux attach -t "$s"; fi
}

# ta [name] — attach to a tmux session (most recent if no name).
ta() {
  if [ -n "$1" ]; then tmux attach -t "$1"; else tmux attach; fi
}

# cheat — print the tmux + Claude cheat sheet (rendered if `bat`/`glow` exist).
cheat() {
  local f="$HOME/tmux-claude-cheatsheet.md"
  [ -f "$f" ] || { echo "cheat sheet not found at $f"; return 1; }
  if command -v glow >/dev/null;   then glow "$f"
  elif command -v bat >/dev/null;  then bat --style=plain "$f"
  else cat "$f"; fi
}

# tk [name] — kill ONE tmux session (default: prompt-pick if no name given).
#   tk my-api
tk() {
  if [ -z "$1" ]; then
    echo "Sessions:"; tmux ls 2>/dev/null | sed 's/^/  /'
    echo "usage: tk <session-name>"; return 1
  fi
  tmux kill-session -t "$1" 2>&1 && echo "killed session: $1 ✅"
}

# tka — kill ALL tmux sessions EXCEPT the one you're currently attached to.
# (Your Claude conversations are on disk and unaffected.)
tka() {
  local cur
  cur=$(tmux display-message -p '#S' 2>/dev/null)
  tmux ls 2>/dev/null | cut -d: -f1 | while read -r s; do
    [ "$s" = "$cur" ] && continue
    tmux kill-session -t "$s" && echo "killed: $s"
  done
  echo "kept current session: ${cur:-（none）} ✅"
}

# claude-clean — stop ALL background workers + spare pool, clear stale triggers.
# Use when idle RAM creeps up, or you see "worker crashed — respawning" spam.
# Saved conversations are NOT touched (they live on disk; resume any time).
claude-clean() {
  echo "Stopping background daemon + spare workers…"
  claude daemon stop --any 2>/dev/null || true
  local n
  n=$(find "$HOME/.claude/jobs" -name recap.trigger -print -delete 2>/dev/null | wc -l)
  echo "Cleared ${n// /} stale trigger(s)."
  echo "Done. Live sessions are unaffected; reopen with: claude --resume"
}
