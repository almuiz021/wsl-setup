#!/usr/bin/env bash
# Background refresher for the statusline's weekly + fable segments.
# Pulls the SAME data the /usage command shows, from GET /api/oauth/usage, so
# the numbers match /usage exactly. It's fast (~0.5s) but still runs detached +
# cached so the statusline never blocks. Single-flight via a lock dir.
#
# The OAuth token is handed to curl via a config on stdin (-K -) so it never
# appears in argv / `ps`, and is never written to disk or logged.
set -u

CACHE="$HOME/.claude/.usage-cache"
LOCK="$HOME/.claude/.usage-cache.lock"
CREDS="$HOME/.claude/.credentials.json"

# Take the single-flight lock (clear a dead one after 2 min).
if [ -d "$LOCK" ]; then
  age=$(( $(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || echo 0) ))
  [ "$age" -gt 120 ] && rmdir "$LOCK" 2>/dev/null
fi
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

TOKEN=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS" 2>/dev/null)
[ -z "$TOKEN" ] && exit 0

resp=$(printf 'url = "https://api.anthropic.com/api/oauth/usage"\nheader = "Authorization: Bearer %s"\nheader = "anthropic-beta: oauth-2025-04-20"\nheader = "anthropic-version: 2023-06-01"\n' "$TOKEN" \
       | curl -s --max-time 8 -K - 2>/dev/null)
[ -z "$resp" ] && exit 0

# Extract the same three gauges /usage shows. weekly_scoped(Fable) may be absent
# once the promo ends -> FAB_PCT comes back empty and the segment just hides.
# Pipe-delimited so an empty middle field is preserved.
vals=$(printf '%s' "$resp" | jq -r '
  def pct: if type=="number" then floor else "" end;
  (.limits // []) as $l
  | (($l | map(select(.kind=="weekly_all"))   | .[0].percent) // .seven_day.utilization) as $wk
  | (($l | map(select(.kind=="weekly_scoped"
        and ((.scope.model.display_name // "") | ascii_downcase == "fable")))
        | .[0].percent))                                                                 as $fab
  | (($l | map(select(.kind=="session"))      | .[0].percent) // .five_hour.utilization) as $sess
  | "\($wk|pct)|\($fab|pct)|\($sess|pct)"
' 2>/dev/null)

WK_PCT=$(printf '%s' "$vals"   | cut -d'|' -f1)
FAB_PCT=$(printf '%s' "$vals"  | cut -d'|' -f2)
SESS_PCT=$(printf '%s' "$vals" | cut -d'|' -f3)

# Require a valid weekly number; otherwise keep the last good cache (e.g. on a
# 401 after token rotation, or a transient network error).
case "$WK_PCT" in ''|*[!0-9]*) exit 0 ;; esac

{
  echo "TS=$(date +%s)"
  echo "WK_PCT=$WK_PCT"
  echo "FAB_PCT=$FAB_PCT"
  echo "SESS_PCT=$SESS_PCT"
} > "$CACHE.tmp" 2>/dev/null && mv "$CACHE.tmp" "$CACHE" 2>/dev/null
