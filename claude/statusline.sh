#!/usr/bin/env bash
# Claude Code statusline. Reads session JSON on stdin, prints one line.
# Shows: model · dir · git branch+dirty · context used/limit (%) · cost · lines.
input=$(cat)

# --- pull fields with jq; fall back gracefully if a field is absent ----------
model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "?"' 2>/dev/null)
cdir=$(printf '%s' "$input"  | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)
cost=$(printf '%s' "$input"  | jq -r '.cost.total_cost_usd // empty' 2>/dev/null)
over=$(printf '%s' "$input"  | jq -r '.exceeds_200k_tokens // false' 2>/dev/null)
ts=$(printf '%s'   "$input"  | jq -r '.transcript_path // empty' 2>/dev/null)
ladd=$(printf '%s' "$input"  | jq -r '.cost.total_lines_added   // 0' 2>/dev/null)
ldel=$(printf '%s' "$input"  | jq -r '.cost.total_lines_removed // 0' 2>/dev/null)

# --- dir: $HOME -> ~, then keep last 2 path components ------------------------
disp="$cdir"
case "$disp" in
  "$HOME") disp="~" ;;
  "$HOME"/*) disp="~/${disp#"$HOME"/}" ;;
esac
ncomp=$(printf '%s' "$disp" | tr '/' '\n' | grep -c .)
if [ "$ncomp" -gt 2 ]; then
  disp=".../$(printf '%s' "$disp" | rev | cut -d/ -f1-2 | rev)"
fi

# --- git branch + dirty marker, only inside a repo ---------------------------
branch=""
if [ -n "$cdir" ] && git -C "$cdir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  b=$(git -C "$cdir" branch --show-current 2>/dev/null)
  [ -z "$b" ] && b=$(git -C "$cdir" rev-parse --short HEAD 2>/dev/null)
  dirty=""
  git -C "$cdir" diff --quiet --ignore-submodules HEAD 2>/dev/null || dirty="*"
  branch=" \033[33m \033[0m${b}${dirty}"
fi

# --- context: real tokens from the latest main-thread assistant message ------
# Context size = input + cache_creation + cache_read of the most recent turn.
# Read only the tail of the transcript so this stays fast on every render.
used=0
if [ -n "$ts" ] && [ -f "$ts" ]; then
  # -R + fromjson? parses line-by-line and skips any half-written trailing
  # line (the transcript is appended live), then we take the most recent.
  u=$(tail -n 400 "$ts" 2>/dev/null | jq -Rr '
        fromjson?
        | select(.type=="assistant" and (.isSidechain != true))
        | .message.usage
        | select(. != null)
        | (.input_tokens + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))
      ' 2>/dev/null | tail -n 1)
  [ -n "$u" ] && used="$u"
fi
case "$used" in ''|*[!0-9]*) used=0 ;; esac

# Limit: standard 200k window, or 1M once we're past it (extended window).
limit=200000
if [ "$used" -gt 200000 ] 2>/dev/null || [ "$over" = "true" ]; then limit=1000000; fi

fmtk() { awk -v n="$1" 'BEGIN{ if(n>=1000) printf "%dk", int((n+500)/1000); else printf "%d", n }'; }
limstr=$([ "$limit" -ge 1000000 ] && echo "1M" || echo "$(fmtk "$limit")")
pct=$(awk -v u="$used" -v l="$limit" 'BEGIN{ printf "%d", (l>0)? (u*100/l) : 0 }')

# Colour by how full: green <50, yellow <80, red >=80.
ccol=32
[ "$pct" -ge 50 ] && ccol=33
[ "$pct" -ge 80 ] && ccol=31
ctx=""
if [ "$used" -gt 0 ]; then
  ctx=$(printf ' \033[90m·\033[0m \033[%sm%s/%s \033[2m%d%%\033[0m' \
        "$ccol" "$(fmtk "$used")" "$limstr" "$pct")
fi

# --- 5h usage window: time left until the rolling limit resets ---------------
# Claude's usage window is a rolling 5h block that starts at your first message
# and resets 5h later. The statusline JSON doesn't expose the reset time, so we
# derive the current block's start from message timestamps across any transcript
# touched in the last ~5h, then count down. ISO-8601 UTC -> epoch in pure awk
# (mawk has no mktime) via the days-from-civil formula.
winstr=""
now=$(date +%s 2>/dev/null)
if [ -n "$now" ]; then
  rem=$(find "$HOME/.claude/projects" -name '*.jsonl' -mmin -310 -print0 2>/dev/null \
    | xargs -0 grep -ho '"timestamp":"[^"]*"' 2>/dev/null \
    | awk '
        { s=$0; gsub(/[^0-9]/," ",s); split(s,a," ")
          Y=a[1]+0;Mo=a[2]+0;D=a[3]+0;H=a[4]+0;Mi=a[5]+0;S=a[6]+0
          if(Y<2000) next
          y=(Mo<=2)?Y-1:Y; era=int(((y>=0)?y:y-399)/400); yoe=y-era*400
          mm=(Mo>2)?Mo-3:Mo+9; doy=int((153*mm+2)/5)+D-1
          doe=yoe*365+int(yoe/4)-int(yoe/100)+doy; days=era*146097+doe-719468
          print days*86400+H*3600+Mi*60+S }' \
    | sort -n \
    | awk -v now="$now" -v W=18000 '
        {ts[NR]=$1}
        END{ if(NR==0){print ""; exit}
             bs=ts[1]; for(i=2;i<=NR;i++) if(ts[i]>=bs+W) bs=ts[i]
             print bs+W-now }')
  case "$rem" in ''|*[!0-9-]*) rem="" ;; esac
  if [ -n "$rem" ]; then
    if [ "$rem" -le 0 ]; then
      # Window already elapsed — next message starts a fresh 5h block.
      winstr=$(printf ' \033[90m·\033[0m \033[32m󰅐 5h\033[0m')
    else
      wh=$((rem/3600)); wm=$(((rem%3600)/60))
      # Colour: green >2h left, yellow >30m, red final 30m.
      wcol=32
      [ "$rem" -le 7200 ] && wcol=33
      [ "$rem" -le 1800 ] && wcol=31
      if [ "$wh" -gt 0 ]; then wtxt="${wh}h ${wm}m"; else wtxt="${wm}m"; fi
      winstr=$(printf ' \033[90m·\033[0m \033[%sm󰅐 %s\033[0m' "$wcol" "$wtxt")
    fi
  fi
fi

# --- session cost ------------------------------------------------------------
coststr=""
if [ -n "$cost" ] && [ "$cost" != "null" ]; then
  coststr=$(printf ' \033[90m·\033[0m \033[90m$%.2f\033[0m' "$cost" 2>/dev/null)
fi

# --- lines added/removed this session (only if any) --------------------------
linestr=""
if [ "${ladd:-0}" -gt 0 ] 2>/dev/null || [ "${ldel:-0}" -gt 0 ] 2>/dev/null; then
  linestr=$(printf ' \033[32m+%s\033[0m\033[31m-%s\033[0m' "$ladd" "$ldel")
fi

# --- compose: model · dir · branch · context · window · cost · lines ---------
printf "\033[36m%s\033[0m \033[90m·\033[0m \033[34m%s\033[0m%b%b%b%b%b" \
  "$model" "$disp" "$branch" "$ctx" "$winstr" "$coststr" "$linestr"
