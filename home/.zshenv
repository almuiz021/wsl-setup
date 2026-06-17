# ~/.zshenv — runs for every zsh (login, interactive, scripts).
# Environment + PATH only. Interactive sugar lives in ~/.zshrc.

# Dedup PATH while keeping first occurrence (Linux-native dirs win over /mnt/c).
typeset -U path PATH

path=(
  $HOME/.local/bin
  $HOME/bin
  /opt/nvim-linux-x86_64/bin
  $HOME/.cargo/bin
  $HOME/.local/opt/go/bin
  $HOME/go/bin
  $HOME/.bun/bin
  $HOME/.atuin/bin
  $path
)

# Put the default nvm Node on PATH up front, so `node`/`npm`/`pnpm`/`yarn`
# resolve to it instantly (before lazy-nvm loads in .zshrc) and beat the
# apt-installed /usr/bin/node (v18). Resolves the `default` alias to a real dir.
export NVM_DIR="$HOME/.nvm"
if [[ -r $NVM_DIR/alias/default ]]; then
  _nvm_def=$(<"$NVM_DIR/alias/default")
  _nvm_bin=(${~NVM_DIR}/versions/node/v${_nvm_def}*/bin(/Nn[-1]))
  [[ -n $_nvm_bin ]] && path=($_nvm_bin $path)
  unset _nvm_def _nvm_bin
fi
export PATH

# Editor
export EDITOR=nvim
export VISUAL=nvim

# Go
export GOPATH=$HOME/go
export GOBIN=$HOME/go/bin

# Bun
export BUN_INSTALL=$HOME/.bun

# Pager — colourful, no line-wrap chaos
export PAGER=less
export LESS='-R'
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# fzf — use fd, respect .gitignore, show hidden (but not .git)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 45% --layout=reverse --border --info=inline --preview-window=right:60%:wrap'
