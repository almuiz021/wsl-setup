# ~/.zshrc — interactive zsh config. Built for a WSL2 main dev box.
# Stack focus: Go (backend), Node/TS (frontend), Python.

# atuin's installer adds this; keep it (puts ~/.atuin/bin on PATH).
[ -f "$HOME/.atuin/bin/env" ] && . "$HOME/.atuin/bin/env"

# ── History ───────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS EXTENDED_HISTORY INC_APPEND_HISTORY

# ── Shell behaviour ─────────────────────────────────────────────────────────
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS INTERACTIVE_COMMENTS NO_BEEP GLOB_DOTS
bindkey -e

# ── Completion system ───────────────────────────────────────────────────────
fpath=($HOME/.zsh/plugins/zsh-completions/src $fpath)
autoload -Uz compinit
# Docker Desktop leaves a dangling _docker symlink in the system completion dir
# when it isn't running, which makes compinit print a harmless "no such file"
# warning. Silencing compinit's stderr suppresses it. Fine on a single-user box;
# to fix it properly instead, run: sudo rm /usr/share/zsh/vendor-completions/_docker
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then compinit -i 2>/dev/null; else compinit -C -i 2>/dev/null; fi

zstyle ':completion:*' menu no
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath 2>/dev/null || ls -1 $realpath'
zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat --color=always --line-range :100 $realpath 2>/dev/null || eza -1 --color=always $realpath 2>/dev/null'
zstyle ':fzf-tab:*' switch-group ',' '.'

# ── Plugins (order matters: fzf-tab after compinit, syntax-hl last) ──────────
[[ -f $HOME/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh ]] && source $HOME/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh
if [[ -f $HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source $HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# ── Tool integrations ───────────────────────────────────────────────────────
# nvm: lazy-load to keep shell startup fast (~0.3s saved). The real nvm.sh is
# sourced the first time you call node/npm/npx/nvm/pnpm/yarn/corepack. The
# active node version's bin is already on PATH (via ~/.zshenv), so plain
# `node`/`npm` work instantly without triggering the load.
export NVM_DIR="$HOME/.nvm"
_load_nvm() {
  unset -f nvm node npm npx pnpm yarn corepack 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
# Only shim `nvm` itself; node/npm/etc resolve via PATH already. `nvm use` etc.
# still triggers the full load on demand.
nvm() { _load_nvm; nvm "$@"; }

if command -v fzf >/dev/null; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [ -f /usr/share/doc/fzf/examples/completion.zsh ]   && source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

command -v zoxide   >/dev/null && eval "$(zoxide init zsh)"
command -v direnv   >/dev/null && eval "$(direnv hook zsh)"
command -v starship >/dev/null && eval "$(starship init zsh)"
command -v atuin    >/dev/null && eval "$(atuin init zsh)"  # up-arrow + Ctrl-R both open atuin
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
[ -f "$HOME/.config/shell/ssh-agent.sh" ] && source "$HOME/.config/shell/ssh-agent.sh"

# ── Aliases ─────────────────────────────────────────────────────────────────
alias vi='nvim'
alias vim='nvim'
alias cr='code -r'
alias ls='eza --group-directories-first --icons=auto'
alias l='eza -1 --icons=auto'
alias la='eza -a --group-directories-first --icons=auto'
alias ll='eza -lah --group-directories-first --icons=auto --git'
alias lt='eza --tree --level=2 --icons=auto'
alias llt='eza --tree --level=4 --icons=auto'
alias catp='bat'
alias mkdir='mkdir -p'
command -v duf  >/dev/null && alias df='duf'
command -v btop >/dev/null && alias top='btop'
alias cls='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git commit -m'
alias gco='git checkout'
alias gsw='git switch'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gp='git push'
alias gpl='git pull'
alias gb='git branch'
alias lg='lazygit'
alias ld='lazydocker'
alias d='docker'
alias dc='docker compose'
alias py='python3'
alias venv='uv venv && source .venv/bin/activate'

# ── Functions ───────────────────────────────────────────────────────────────
mkcd() { mkdir -p "$1" && cd "$1"; }
fcd()  { local d; d=$(fd --type d --hidden --exclude .git | fzf) && cd "$d"; }
fkill(){ local pid; pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}') && [ -n "$pid" ] && kill -${1:-9} $pid; }
extract() {
  case "$1" in
    *.tar.bz2) tar xjf "$1";; *.tar.gz) tar xzf "$1";; *.tar.xz) tar xJf "$1";;
    *.tbz2) tar xjf "$1";; *.tgz) tar xzf "$1";; *.tar) tar xf "$1";;
    *.bz2) bunzip2 "$1";; *.gz) gunzip "$1";; *.zip) unzip "$1";; *.rar) unrar x "$1";;
    *.7z) 7z x "$1";; *.Z) uncompress "$1";; *) echo "extract: unknown type '$1'";;
  esac
}

# Windows interop (WSL) — move between Linux and Windows without VSCode.
# open [path]  → Windows File Explorer at a WSL path (default: current dir).
#                Drag/paste Windows files into the window to copy them into ~.
#                (|| true hides explorer.exe's harmless non-zero exit code.)
open() { explorer.exe "$(wslpath -w "${1:-.}")" >/dev/null 2>&1 || true; }
# o <file|url> → open a file or URL in its default Windows app (wraps wslview).
o() { wslview "$@"; }

# mdv <file.md> — render a markdown file in the terminal, same look as `cheat`
# (glow → bat → cat fallback). Tip: `glow -p file.md` for a scrollable pager.
mdv() {
  local f="$1"
  [ -f "$f" ] || { echo "mdv: file not found: ${f:-<none>}"; return 1; }
  if command -v glow >/dev/null;   then glow "$f"
  elif command -v bat >/dev/null;  then bat --style=plain "$f"
  else cat "$f"; fi
}

# ── Syntax highlighting (MUST be last) ──────────────────────────────────────
if [[ -f $HOME/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source $HOME/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# >>> Flutter / Android SDK (optional — only active if installed under ~/sdk) >>>
if [[ -d "$HOME/sdk/flutter" ]]; then
  export JAVA_HOME="$HOME/sdk/jdk17"
  export ANDROID_HOME="$HOME/Android/Sdk"
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
  export PATH="$HOME/sdk/flutter/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$JAVA_HOME/bin:$PATH"
fi
# <<< Flutter / Android SDK <<<


# Claude multi-repo workflow (work, claude-clean)
[[ -f ~/.config/shell/claude-workflow.sh ]] && source ~/.config/shell/claude-workflow.sh

# ssh-agent is handled by ~/.config/shell/ssh-agent.sh (sourced above).
# Key loads on demand: `ssha`, or automatically on first ssh use
# (AddKeysToAgent yes in ~/.ssh/config). Don't add ssh-add here — it
# prompts for the passphrase in every new shell.
