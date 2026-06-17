# Start a single persistent ssh-agent per login. Does NOT prompt for the key
# passphrase automatically — run `ssha` when you actually need the key loaded.
SSH_ENV="$HOME/.ssh/agent.env"

_ssh_agent_start() {
  (umask 077; ssh-agent -s > "$SSH_ENV")
  . "$SSH_ENV" > /dev/null
}

# Reuse existing agent if its env file is present.
[ -f "$SSH_ENV" ] && . "$SSH_ENV" > /dev/null 2>&1

# (Re)start the agent only if it isn't reachable. No key is added here.
if ! ssh-add -l >/dev/null 2>&1; then
  if [ -z "$SSH_AUTH_SOCK" ] || ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
    _ssh_agent_start
  fi
fi
unset -f _ssh_agent_start 2>/dev/null

# On-demand key loader: `ssha` prompts for the passphrase ONCE; after that the
# agent caches it for every shell, so you won't be asked again this session.
ssha() { ssh-add "$HOME/.ssh/id_ed25519"; }
