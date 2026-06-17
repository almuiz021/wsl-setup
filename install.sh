#!/usr/bin/env bash
# ============================================================================
#  WSL2 dev-environment bootstrap
#  One command sets up the whole workflow: zsh + starship, tmux multi-project
#  flow, Claude Code (statusline + Windows toasts), the CLI toolchain, and nvim.
#
#    git clone <repo> ~/dotfiles && cd ~/dotfiles && ./install.sh
#
#  Target: a fresh WSL2 Ubuntu/Debian. Re-runnable (skips installed tools).
#  Tools install at LATEST versions. No secrets are ever part of this repo.
# ============================================================================
set -uo pipefail
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=()

c()    { printf '\033[%sm%s\033[0m' "$1" "$2"; }
log()  { printf '\n%s %s\n' "$(c '1;36' '==>')" "$1"; }
ok()   { printf '   %s %s\n'  "$(c '1;32' '✓')" "$1"; }
warn() { printf '   %s %s\n'  "$(c '1;33' '!')" "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
try()  { "$@" || { warn "step failed: $*"; FAILED+=("$*"); }; }

mkdir -p "$HOME/.local/bin" "$HOME/.config"
export PATH="$HOME/.local/bin:$PATH"

# --- sanity ----------------------------------------------------------------
have apt-get || { echo "This installer needs apt (Debian/Ubuntu). Aborting."; exit 1; }
IS_WSL=0; grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1
[ "$IS_WSL" = 1 ] || warn "Not running under WSL — Windows-side steps will be skipped."

# --- 1. apt base -----------------------------------------------------------
log "Base packages via apt (you'll be asked for your sudo password)"
sudo apt-get update -y
sudo apt-get install -y \
  zsh tmux git curl wget unzip tar build-essential pkg-config ca-certificates \
  gnupg jq ripgrep fd-find bat fzf btop less direnv python3 python3-venv
have fdfind && ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"   # Debian names
have batcat && ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
ok "apt base done"

# --- helper: install a single binary from a GitHub release -----------------
install_release() {   # <owner/repo> <asset-regex> <binary-name>
  local repo="$1" pat="$2" bin="$3" url tmp f
  have "$bin" && { ok "$bin (present)"; return 0; }
  url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
        | grep -oE '"browser_download_url"[^,]*' | cut -d'"' -f4 \
        | grep -iE "$pat" | head -1)
  [ -n "$url" ] || { warn "$bin: no matching release asset"; FAILED+=("$bin"); return 1; }
  tmp=$(mktemp -d)
  curl -fsSL "$url" -o "$tmp/a" || { warn "$bin: download failed"; rm -rf "$tmp"; FAILED+=("$bin"); return 1; }
  case "$url" in
    *.tar.gz|*.tgz) tar -xzf "$tmp/a" -C "$tmp" ;;
    *.zip)          unzip -qo "$tmp/a" -d "$tmp" ;;
    *.deb)          sudo dpkg -i "$tmp/a" >/dev/null 2>&1; rm -rf "$tmp"; have "$bin" && ok "$bin" || { warn "$bin"; FAILED+=("$bin"); }; return 0 ;;
    *)              cp "$tmp/a" "$tmp/$bin" ;;
  esac
  f=$(find "$tmp" -type f -name "$bin" 2>/dev/null | head -1)
  [ -n "$f" ] && { install -m755 "$f" "$HOME/.local/bin/$bin"; ok "$bin"; } \
              || { warn "$bin: binary not found in archive"; FAILED+=("$bin"); }
  rm -rf "$tmp"
}

# --- 2. official curl|sh installers ----------------------------------------
log "Prompt + shell tools (starship, zoxide, atuin, uv, bun)"
have starship || try bash -c 'curl -sS https://starship.rs/install.sh | sh -s -- -y'
have zoxide   || try bash -c 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'
have atuin    || try bash -c "curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh"
have uv       || try bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
have bun      || try bash -c 'curl -fsSL https://bun.sh/install | bash'

# --- 3. node via nvm (+ corepack pnpm/yarn) --------------------------------
log "Node (nvm LTS) + corepack"
[ -d "$HOME/.nvm" ] || try bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash'
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
  nvm install --lts >/dev/null 2>&1 && nvm alias default 'lts/*' >/dev/null 2>&1 && ok "node $(node -v 2>/dev/null)"
  corepack enable >/dev/null 2>&1 && ok "corepack (pnpm/yarn)"
fi

# --- 4. Go (latest) + go tools ---------------------------------------------
if ! have go && [ ! -x "$HOME/.local/opt/go/bin/go" ]; then
  log "Go (latest)"
  GOVER=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)
  if [ -n "$GOVER" ] && curl -fsSL "https://go.dev/dl/${GOVER}.linux-amd64.tar.gz" -o /tmp/go.tgz; then
    rm -rf "$HOME/.local/opt/go"; mkdir -p "$HOME/.local/opt"
    tar -C "$HOME/.local/opt" -xzf /tmp/go.tgz && ok "$GOVER"
  else warn "go download failed"; FAILED+=("go"); fi
fi
if [ -x "$HOME/.local/opt/go/bin/go" ]; then
  export PATH="$HOME/.local/opt/go/bin:$HOME/go/bin:$PATH"
  log "Go tools (gopls/air/dlv/gofumpt/golangci-lint)"
  for p in golang.org/x/tools/gopls@latest github.com/air-verse/air@latest \
           github.com/go-delve/delve/cmd/dlv@latest mvdan.cc/gofumpt@latest \
           github.com/golangci/golangci-lint/cmd/golangci-lint@latest; do
    go install "$p" >/dev/null 2>&1 || warn "go install $p failed"
  done
  ok "go tools"
fi

# --- 5. Python tooling -----------------------------------------------------
have uv && { uv tool install ruff >/dev/null 2>&1 && ok "ruff (via uv)" || true; }

# --- 6. Neovim (latest release) → /opt -------------------------------------
if ! have nvim; then
  log "Neovim"
  if curl -fsSL https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz -o /tmp/nvim.tgz; then
    sudo rm -rf /opt/nvim-linux-x86_64 && sudo tar -C /opt -xzf /tmp/nvim.tgz && ok "neovim"
  else warn "neovim download failed"; FAILED+=("nvim"); fi
fi

# --- 7. eza (apt repo) -----------------------------------------------------
if ! have eza; then
  log "eza"
  sudo mkdir -p /etc/apt/keyrings
  if wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null; then
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
    sudo apt-get update -y && sudo apt-get install -y eza && ok "eza" || { warn "eza install failed"; FAILED+=("eza"); }
  else warn "eza repo key failed"; FAILED+=("eza"); fi
fi

# --- 8. GitHub CLI (apt repo) ----------------------------------------------
if ! have gh; then
  log "GitHub CLI"
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -y && sudo apt-get install -y gh && ok "gh" || { warn "gh failed"; FAILED+=("gh"); }
fi

# --- 9. release binaries (delta, lazygit, lazydocker, glow, yq, duf) -------
log "Release binaries"
install_release dandavison/delta         'x86_64-unknown-linux-gnu\.tar\.gz$' delta
install_release jesseduffield/lazygit     'Linux_x86_64\.tar\.gz$'             lazygit
install_release jesseduffield/lazydocker  'Linux_x86_64\.tar\.gz$'             lazydocker
install_release charmbracelet/glow        'Linux_x86_64\.tar\.gz$'             glow
install_release mikefarah/yq              'yq_linux_amd64$'                    yq
install_release muesli/duf                'linux_x86_64\.tar\.gz$'             duf

# --- 10. Docker engine (native, inside WSL) --------------------------------
if ! have docker; then
  log "Docker engine (native)"
  try bash -c 'curl -fsSL https://get.docker.com | sh'
  sudo usermod -aG docker "$USER" 2>/dev/null && ok "added $USER to docker group (re-login to apply)"
  sudo systemctl enable --now docker >/dev/null 2>&1 || true
fi

# --- 11. zsh plugins -------------------------------------------------------
log "zsh plugins"
mkdir -p "$HOME/.zsh/plugins"
clone() { [ -d "$2" ] || git clone --depth=1 "$1" "$2" >/dev/null 2>&1; }
clone https://github.com/zsh-users/zsh-autosuggestions     "$HOME/.zsh/plugins/zsh-autosuggestions"
clone https://github.com/zsh-users/zsh-syntax-highlighting "$HOME/.zsh/plugins/zsh-syntax-highlighting"
clone https://github.com/zsh-users/zsh-completions         "$HOME/.zsh/plugins/zsh-completions"
clone https://github.com/Aloxaf/fzf-tab                    "$HOME/.zsh/plugins/fzf-tab"
ok "plugins cloned"

# --- 12. drop in configs ---------------------------------------------------
log "Installing configs (existing files backed up to *.pre-dotfiles.bak)"
place() { [ -e "$2" ] && cp -a "$2" "$2.pre-dotfiles.bak" 2>/dev/null; mkdir -p "$(dirname "$2")"; cp "$1" "$2"; }
place "$DOTFILES/home/.zshrc"                     "$HOME/.zshrc"
place "$DOTFILES/home/.zshenv"                    "$HOME/.zshenv"
place "$DOTFILES/home/.tmux.conf"                 "$HOME/.tmux.conf"
place "$DOTFILES/home/tmux-claude-cheatsheet.md"  "$HOME/tmux-claude-cheatsheet.md"
place "$DOTFILES/config/starship.toml"            "$HOME/.config/starship.toml"
place "$DOTFILES/config/atuin/config.toml"        "$HOME/.config/atuin/config.toml"
place "$DOTFILES/config/shell/claude-workflow.sh" "$HOME/.config/shell/claude-workflow.sh"
place "$DOTFILES/config/shell/ssh-agent.sh"       "$HOME/.config/shell/ssh-agent.sh"
place "$DOTFILES/claude/settings.json"            "$HOME/.claude/settings.json"
place "$DOTFILES/claude/statusline.sh"            "$HOME/.claude/statusline.sh"
place "$DOTFILES/claude/notify.sh"                "$HOME/.claude/notify.sh"
chmod +x "$HOME/.claude/statusline.sh" "$HOME/.claude/notify.sh" "$HOME/.config/shell/"*.sh 2>/dev/null
ok "shell / tmux / claude configs"

# global gitignore + gitconfig from template
mkdir -p "$HOME/.config/git"
[ -f "$HOME/.config/git/ignore" ] || printf '%s\n' '.DS_Store' '*.swp' 'node_modules/' '.venv/' '__pycache__/' > "$HOME/.config/git/ignore"
if [ ! -f "$HOME/.gitconfig" ] || ! grep -q '@' "$HOME/.gitconfig" 2>/dev/null; then
  read -rp "   Git user.name : "  GIT_NAME
  read -rp "   Git user.email: " GIT_EMAIL
  sed -e "s|__GIT_NAME__|${GIT_NAME}|" -e "s|__GIT_EMAIL__|${GIT_EMAIL}|" \
      "$DOTFILES/git/gitconfig.template" > "$HOME/.gitconfig"
  ok "~/.gitconfig"
else
  warn "~/.gitconfig exists — left as-is (template in git/gitconfig.template)"
fi

# --- 13. nvim config -------------------------------------------------------
[ -d "$HOME/.config/nvim" ] || { log "Neovim config"; try git clone --depth=1 https://github.com/almuiz021/nvim "$HOME/.config/nvim"; }

# --- 14. Windows side (WSL only): toast script + auto-tuned .wslconfig ------
if [ "$IS_WSL" = 1 ]; then
  log "Windows-side (toast script + .wslconfig)"
  mkdir -p /mnt/c/wsl 2>/dev/null && cp "$DOTFILES/windows/claude-notify.ps1" /mnt/c/wsl/claude-notify.ps1 2>/dev/null && ok 'C:\wsl\claude-notify.ps1'
  WINHOME=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" 2>/dev/null)
  if [ -n "$WINHOME" ] && [ -d "$WINHOME" ]; then
    if [ -f "$WINHOME/.wslconfig" ]; then
      warn ".wslconfig exists — left as-is (template in wsl/wslconfig.template)"
    else
      TOTAL_GB=$(( ( $(awk '/MemTotal/{print $2}' /proc/meminfo) + 1048575) / 1048576 ))
      MEM=$(( TOTAL_GB * 3 / 4 )); [ "$MEM" -lt 2 ] && MEM=2
      CPUS=$(powershell.exe -NoProfile -Command '(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors' 2>/dev/null | tr -d '\r')
      case "$CPUS" in ''|*[!0-9]*) CPUS=$(nproc) ;; esac
      sed -e "s/__WSL_MEMORY__/${MEM}/" -e "s/__WSL_PROCESSORS__/${CPUS}/" -e "s/__WSL_SWAP__/${MEM}/" \
          "$DOTFILES/wsl/wslconfig.template" > "$WINHOME/.wslconfig"
      ok ".wslconfig (memory=${MEM}GB, processors=${CPUS}, swap=${MEM}GB)"
    fi
  else warn "couldn't resolve Windows home — skipped .wslconfig"; fi
fi

# --- 15. default shell -----------------------------------------------------
if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  log "Default shell → zsh"
  chsh -s "$(command -v zsh)" && ok "zsh set (effective next login)" || warn "chsh failed — run: chsh -s \$(command -v zsh)"
fi

# --- done ------------------------------------------------------------------
log "Done!"
[ ${#FAILED[@]} -gt 0 ] && warn "Review these steps: ${FAILED[*]}"
cat <<'EOF'

   Next steps:
     1. exec zsh          (or reopen the terminal) — loads zsh + new config
     2. wsl --shutdown    (from Windows PowerShell) → reopen — applies .wslconfig
     3. add your SSH key, then run  ssha  to load it (keys are never shipped)
     4. set a Nerd Font in your terminal (e.g. CaskaydiaCove NF) for icons
     5. gh auth login  ·  log into Claude Code  ·  atuin login (if you sync)

   Type  cheat  for the tmux + Claude workflow reference.  🎉
EOF
