# tmux + Claude — Ops Cheat Sheet

## The mental model (read once, everything clicks)

```
Windows Terminal  =  a window on screen — closing it loses NOTHING
        │
   tmux SERVER    =  background process holding all sessions
        │            survives terminal close • DIES on reboot / WSL shutdown
   tmux SESSION   =  one PROJECT     (my-api, project-b)   ← Alt+s switches
        │
   tmux WINDOW    =  one tab/module  (backend, app, frontend)     ← Alt+q/w/e switches
        │
   claude         =  runs inside a window. Conversation saved to DISK,
                     separately, under ~/.claude/projects/ — survives EVERYTHING
```

**Two things are saved independently:**
- **tmux sessions** → in RAM. Survive closing a terminal. **Lost on reboot/WSL shutdown.**
- **Claude conversations** → on disk. Survive reboot, shutdown, everything. Always resumable.

So even after a reboot wipes your tmux layout, **no Claude work is lost** — you just
rebuild the windows and `claude --resume` inside each.

---

# 📐 THE FRAMEWORK — long-running, multi-project work

You work on **project-a** (backend, app, frontend) and **project-b** (backend, web),
over many days, and want to return to the SAME setup each morning.

The trick: **a project's identity is its FOLDER, not its tmux session.** tmux
layout is disposable (rebuild in seconds); Claude chats are permanent (per folder).
So your job each morning is just: recreate the windows, resume Claude in each.

### Worked example — project-a (3 modules) + project-b (2 modules)

#### ▶ DAY 1 — starting from zero
```bash
# Project 1: project-a — 3 windows (one per module)
cd ~/projects/my-api
work 3
#   Alt+q → window 1 → `cd backend  && claude`
#   Alt+w → window 2 → `cd customer-app && claude`
#   Alt+e → window 3 → `cd admin-web  && claude`

# Project 2: project-b — 2 windows
cd ~/projects/my-app
work 2
#   Alt+q → window 1 → `claude`   (already in my-app)
#   Alt+w → window 2 → `cd ../other-module && claude`

# hop between projects anytime:  Alt+s
```
> Tip: launch Claude from the **module folder** for focused work; from the
> **project root** only when a task spans modules (it can read across folders then).

#### ▶ DURING THE DAY
```
Alt+q/w/e …   switch modules (windows)
Alt+s         switch project (session)
Alt+c         new window in current folder
/exit         close a finished Claude chat (it's saved anyway)
```

#### ▶ END OF DAY (EOD) — keep everything
You have two choices:

**A) Not rebooting tonight (just closing the laptop/terminal):**
```
Ctrl-b d         # detach — or just close the terminal. Same effect.
```
Everything stays alive in the background. Tomorrow = one `tmux attach`. Easiest.

**B) Rebooting / shutting down WSL:**
tmux sessions will be gone (RAM only), so just note WHICH folders you had open.
Your Claude chats are safe on disk regardless. (Optional: in each Claude window
type `/exit` first for a clean close — not required, chats save automatically.)

#### ▶ NEXT DAY — resume the same setup

**If you did NOT reboot (case A):**
```bash
tmux ls                 # see your sessions still running
tmux attach -t my-api    # …or just `ta` (alias below)
# everything is exactly as you left it, Claude included. Done.
```

**If you DID reboot (case B):** rebuild the layout (~30 sec), resume Claude in each:
```bash
cd ~/projects/my-api && work 3
#   Alt+q → `cd backend  && claude --resume`   ← pick yesterday's chat
#   Alt+w → `cd customer-app && claude --resume`
#   Alt+e → `cd admin-web  && claude --resume`
cd ~/projects/my-app && work 2
#   Alt+q → `claude --resume`
```
`claude --resume` lists that folder's past conversations → pick the one from
yesterday. `claude -c` skips the picker and grabs the most recent.

---

## ✅ The short TODO version

**START (day 1):** per project → `cd <project>` → `work N` → in each window `cd <module> && claude`

**SWITCH:** `Alt+q/w/e…` windows · `Alt+s` projects

**EOD:**
- not rebooting → `Ctrl-b d` (or close terminal). Done.
- rebooting → nothing required; chats are safe. Note your folders.

**NEXT DAY:**
- didn't reboot → `tmux attach -t <project>` (or `ta`). Back instantly.
- rebooted → `cd <project> && work N` → in each window `claude --resume` (or `-c`).

**Rule of thumb:** *tmux = disposable layout, rebuild freely. Claude = permanent, always `--resume`.*

---

# 🟢 Opening / adding

| I want to… | Do this |
|---|---|
| Start a project (N windows) | `cd <project>` then `work 3`  (default `work` = 1) |
| Add ANOTHER project | `cd <other>` then `work 2` (new session, switches to it) |
| Add a window to current project | `Alt+c` |
| Rename current window | `Alt+,` |

# 🔵 Switching (no prefix — Alt only)

| Key | Action |
|---|---|
| `Alt+q w e r t y u i o p` | window **1–10** |
| `Alt+s` | switch **project** |
| `Ctrl-b d` | detach (leave everything running) |
| `Ctrl-b r` | reload tmux config after editing it |

(`Alt+1..9` deliberately NOT bound — reserved for Windows shortcuts.)

# 🔴 Closing — what dies vs survives

| Action | Command | Dies | Survives |
|---|---|---|---|
| Close Claude chat | `/exit` or `Ctrl-d` | claude process | chat on disk ✅ |
| Detach tmux | `Ctrl-b d` | nothing | all ✅ |
| Close a window | `exit` at shell | that tab | rest ✅ |
| Kill ONE project | `tk <name>` | that session | other projects + disk chats ✅ |
| Kill ALL but current | `tka` | other sessions | current + disk chats ✅ |
| Kill all tmux | `tmux kill-server` | all sessions | disk chats ✅ |
| Close terminal (X) | — | just the view | tmux + chats ✅ |

# 🟡 Getting back

```bash
tmux ls                       # list running sessions
tmux attach -t <name>   (ta)  # re-attach
# inside the right folder:
cd <project> && claude -c        # continue most recent chat
cd <project> && claude --resume  # pick from all past chats
```
> Resume from the SAME folder you started in. Wrong folder → "No conversation
> found" (data isn't lost, you're just looking in the wrong place).

# 🧹 Maintenance

```bash
claude-clean      # stop bg workers + spare pool, clear stale triggers (RAM fix)
```
Run when RAM creeps up or you see `worker crashed — respawning`. Never touches chats.

---

## Your commands & aliases

| Command | Does |
|---|---|
| `work [N]` | open/attach a session named after current folder, N windows |
| `tk <name>` | kill one tmux session |
| `tka` | kill all tmux sessions except the current |
| `ta [name]` | attach (most recent, or named) |
| `claude-clean` | sweep background Claude workers + stale triggers |
| `cheat` | print this sheet |

## Where everything lives

| Thing | Path |
|---|---|
| Claude conversations | `~/.claude/projects/<encoded-folder>/<id>.jsonl` |
| Background jobs | `~/.claude/jobs/<id>/` |
| tmux config | `~/.tmux.conf` |
| work / tk / tka / claude-clean | `~/.config/shell/claude-workflow.sh` |
| This sheet | `~/tmux-claude-cheatsheet.md` |
