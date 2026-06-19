# WSL2 Dev Environment — dotfiles

My complete WSL2 development setup as a **one-command install**: zsh + starship, a
tmux multi-project workflow, Claude Code (custom statusline + Windows toast
notifications), the full CLI toolchain, and Neovim. Built for a fresh **WSL2
Ubuntu/Debian**.

## Install

**Starting from bare Windows (no WSL yet)?** Do [`WINDOWS-SETUP.md`](WINDOWS-SETUP.md)
first — it installs WSL + Ubuntu 24.04, then sends you here. **Already on WSL2 Ubuntu?**
Just:

```bash
git clone https://github.com/<you>/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh
```

It asks for your git name/email, then installs everything and drops the configs into
place. **Re-runnable** (skips tools you already have). Existing configs are backed up
to `*.pre-dotfiles.bak`. Tools install at their **latest** versions.

### After it finishes
1. `exec zsh` (or reopen the terminal) — loads the new shell + config.
2. From **Windows PowerShell**: `wsl --shutdown`, then reopen — applies `.wslconfig`.
3. Add your own SSH key, then run `ssha` to load it.
4. Set a **Nerd Font** in your terminal (e.g. CaskaydiaCove NF) so icons render.
5. `gh auth login` · log into Claude Code · `atuin login` (if you sync history).

## What you get

- **Shell** — zsh + starship prompt, atuin history (Ctrl-R), zoxide (`z`), fzf-tab,
  syntax highlighting, autosuggestions. Git/docker/eza aliases + functions: `mkcd`,
  `fcd`, `fkill`, `extract`, `open` (Explorer here), `o` (open in Windows app),
  `mdv` (render markdown in the terminal).
- **tmux + Claude workflow** — `work [N]` (one session per project), `ta`, `tk`,
  `tka`, `cheat`, `claude-clean`. Alt+q/w/e… switch windows, Alt+s switch projects.
  Run `cheat` after install for the full reference.
- **Claude Code** — statusline (model · dir · git · **context %** · **5h-window
  timer** · cost · ±lines) and **Windows toast notifications** when Claude needs you
  or finishes.
- **Toolchain** — Go + gopls/air/dlv/gofumpt/golangci-lint · Node (nvm LTS) +
  pnpm/yarn (corepack) + bun · Python (uv + ruff) · Neovim · lazygit/lazydocker ·
  delta · glow · ripgrep/fd/bat/eza/fzf/zoxide/yq/duf/btop · Docker (native engine) ·
  gh.
- **Neovim** — cloned from [almuiz021/nvim](https://github.com/almuiz021/nvim)
  (Kickstart-based, Go-focused).

## Auto-tuning

`.wslconfig` is sized to the host: `memory` ≈ ¾ of RAM, `processors` = all cores,
matching swap on the SSD. Tweak `C:\Users\<you>\.wslconfig` and `wsl --shutdown`.

## NOT included (by design)

Secrets and machine-local state never live in this repo: SSH keys, Claude
credentials, the gh token, the atuin sync key, and `settings.local.json`. You supply
those yourself after install.

## Layout

| Path | Installs to |
|------|-------------|
| `home/` | `~/` — `.zshrc`, `.zshenv`, `.tmux.conf`, cheatsheet |
| `config/` | `~/.config/` — starship, atuin, `shell/{claude-workflow,ssh-agent}.sh` |
| `claude/` | `~/.claude/` — `settings.json`, `statusline.sh`, `notify.sh` |
| `windows/` | `C:\wsl\claude-notify.ps1` (toast bridge) |
| `wsl/` | `.wslconfig` template (auto-tuned at install) |
| `git/` | `.gitconfig` template (name/email filled at install) |
| `optional/` | `gradle.properties` — Android JVM/OOM caps for small hosts |

> Targets **WSL2 only**. On native Linux the Windows-side steps (toasts, `.wslconfig`)
> are skipped automatically; on macOS this won't work as-is.
