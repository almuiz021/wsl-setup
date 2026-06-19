# Windows-side setup — from bare Windows to this dev env

Do these **once on Windows first**, then the one-command installer takes over inside
Ubuntu. Total time ~15–20 min (mostly downloads).

> Requires Windows 10 (22H2+) or Windows 11, and virtualization enabled (it usually
> is; if `wsl --install` errors about virtualization, enable it in BIOS).

---

## 1. Install WSL + Ubuntu 24.04

Open **PowerShell as Administrator** (Start → type *PowerShell* → right-click → *Run as
administrator*) and run:

```powershell
wsl --install -d Ubuntu-24.04
```

This enables WSL2 and installs **Ubuntu 24.04 LTS** (the exact version this setup uses).
If `wsl` already exists but the distro isn't installed, the same command just adds it.

**Reboot if it asks you to.** After reboot, Ubuntu finishes installing and opens a
window asking you to create a **UNIX username and password** — pick any (lowercase, no
spaces). This password is what `sudo` will ask for.

> Already have WSL but want a clean Ubuntu 24.04? Run `wsl --install -d Ubuntu-24.04`
> (adds it alongside others). To start fully fresh later: `wsl --unregister Ubuntu-24.04`
> ⚠️ deletes that distro's files — back up first.

Verify (in PowerShell):
```powershell
wsl -l -v        # should list  Ubuntu-24.04   Running/Stopped   2
```

## 2. (Recommended) Windows Terminal + a Nerd Font

- Install **Windows Terminal** from the Microsoft Store (skip if you're on Win11 — it's
  built in). Open Ubuntu from its dropdown.
- Install a **Nerd Font** so prompt/file icons render (otherwise you get little boxes):
  download e.g. **CaskaydiaCove Nerd Font** from <https://www.nerdfonts.com>, install the
  `.ttf` files, then in Windows Terminal: *Settings → Ubuntu-24.04 → Appearance → Font
  face → CaskaydiaCove NF*.

## 3. Update Ubuntu, install git

Open the **Ubuntu** terminal (from Windows Terminal's dropdown or Start menu) and run:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git
```

## 4. Clone the dotfiles and run the installer

```bash
git clone https://github.com/almuiz021/wsl-setup ~/dotfiles
cd ~/dotfiles
./install.sh
```

The installer does everything else: zsh + starship, the tmux/Claude workflow, the full
toolchain (Go, Node, Python, Docker, nvim, …), Claude Code config, Windows toast
notifications, and an auto-tuned `.wslconfig`. It will ask for your git name/email and
your sudo password.

## 5. Apply the WSL tuning + finish

From **PowerShell** (so the new `.wslconfig` takes effect):
```powershell
wsl --shutdown
```
Reopen Ubuntu, then inside it:
```bash
exec zsh                 # or just open a fresh tab
```

That's it. Type `cheat` for the tmux + Claude workflow reference.

### Personal bits to add yourself (never shipped in the repo)
- **SSH key:** `ssh-keygen -t ed25519 -C "you@example.com"` → add the `.pub` to GitHub →
  `ssha` to load it.
- **GitHub CLI:** `gh auth login`
- **Claude Code:** launch `claude` and log in.
- **Install Claude Code** if not present: `npm i -g @anthropic-ai/claude-code`
  (Node is set up by the installer).
