#!/bin/bash
# Two-line status line for Claude Code (macOS, needs jq).
# https://github.com/amirhp-com/claude-code-statusline
#
# STATUSLINE_CALENDAR  gregorian (default) or jalali: calendar of the plan end date
input=$(cat)
dir="$HOME/.claude/state"
mkdir -p "$dir"
if echo "$input" | jq -e '.rate_limits.seven_day.used_percentage' >/dev/null 2>&1; then
  echo "$input" | jq -c '{seven_day: .rate_limits.seven_day, five_hour: .rate_limits.five_hour, saved_at: now}' > "$dir/usage-latest.json.tmp" && mv "$dir/usage-latest.json.tmp" "$dir/usage-latest.json"
fi

E=$'\033'
R="${E}[0m"
W="${E}[38;5;255m"
D="${E}[38;5;243m"
SEP="  ${E}[38;5;240m│${R}  "
GREEN=40 BLUE=39 PURPLE=141 YELLOW=214 ORANGE=166 RED=196

len() { printf '%s' "$1" | sed "s/${E}\\[[0-9;]*m//g" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '; }
pad() { [ "$1" -gt 0 ] && printf '%*s' "$1" ''; }
paint() { printf '%s[38;5;%sm%s%s' "$E" "$1" "$2" "$R"; }
white_digits() { sed -E "s/[0-9]+/${E}[1;38;5;231m&${R}/g"; }

# shade <percent> <base color>: warning colors from 70%
shade() {
  if [ "$1" -ge 90 ]; then echo $RED
  elif [ "$1" -ge 80 ]; then echo $ORANGE
  elif [ "$1" -ge 70 ]; then echo $YELLOW
  else echo "$2"
  fi
}

# bar <percent> <color> <width>
bar() {
  local i n on="" off=""
  n=$(( ($1 * $3 + 50) / 100 ))
  [ "$1" -gt 0 ] && [ "$n" -eq 0 ] && n=1
  [ "$n" -gt "$3" ] && n=$3
  for (( i = 0; i < $3; i++ )); do
    if [ "$i" -lt "$n" ]; then on="${on}━"; else off="${off}━"; fi
  done
  printf '%s%s' "$(paint "$2" "$on")" "$(paint 238 "$off")"
}

# time left, fixed-width units so rows line up
left() {
  local s=$(( $1 - $(date +%s) ))
  [ "$s" -lt 0 ] && s=0
  local d=$(( s / 86400 )) h=$(( s % 86400 / 3600 )) m=$(( s % 3600 / 60 ))
  if [ "$d" -gt 0 ]; then printf '%dd %2dh %02dm' "$d" "$h" "$m"
  elif [ "$h" -gt 0 ]; then printf '%dh %02dm' "$h" "$m"
  else printf '%dm' "$m"
  fi
}

dur() {
  local s=$(( $1 / 1000 ))
  local h=$(( s / 3600 )) m=$(( s % 3600 / 60 ))
  if [ "$h" -gt 0 ]; then echo "${h}h ${m}m"
  elif [ "$m" -gt 0 ]; then echo "${m}m"
  else echo "${s}s"
  fi
}

num() {
  awk -v n="$1" 'BEGIN{ if (n>=1000000) { v=sprintf("%.1f", n/1000000); sub(/\.0$/, "", v); printf "%sM", v } else if (n>=1000) printf "%.0fk", n/1000; else printf "%d", n }'
}

# date of a timestamp in the chosen calendar
plan_date() {
  if [ "${STATUSLINE_CALENDAR:-gregorian}" != jalali ]; then date -r "$1" '+%Y-%m-%d'; return; fi
  local y m d gy days jy jm jd g
  g=(0 31 59 90 120 151 181 212 243 273 304 334)
  read -r y m d <<< "$(date -r "$1" '+%Y %-m %-d')"
  gy=$y; [ "$m" -gt 2 ] && gy=$(( y + 1 ))
  days=$(( 355666 + 365 * y + (gy + 3) / 4 - (gy + 99) / 100 + (gy + 399) / 400 + d + g[m - 1] ))
  jy=$(( -1595 + 33 * (days / 12053) )); days=$(( days % 12053 ))
  jy=$(( jy + 4 * (days / 1461) )); days=$(( days % 1461 ))
  if [ "$days" -gt 365 ]; then jy=$(( jy + (days - 1) / 365 )); days=$(( (days - 1) % 365 )); fi
  if [ "$days" -lt 186 ]; then jm=$(( 1 + days / 31 )); jd=$(( 1 + days % 31 ))
  else jm=$(( 7 + (days - 186) / 30 )); jd=$(( 1 + (days - 186) % 30 )); fi
  printf '%04d/%02d/%02d' "$jy" "$jm" "$jd"
}

# Claude Code does not report the plan's end date: it is read from
# ~/.claude/state/subscription-ends (one Gregorian date, YYYY-MM-DD).
# The bar is the part of the one-month period before that date already used.
# Sets plan1 (date) and plan2 (bar + days left); both stay empty without a date.
plan1="" plan2=""
plan() {
  local day end start today n c=$PURPLE pct text
  day=$(head -1 "$dir/subscription-ends" 2>/dev/null | tr -d '[:space:]')
  [ -n "$day" ] || return
  end=$(date -j -f '%Y-%m-%d %H:%M:%S' "$day 12:00:00" +%s 2>/dev/null) || return
  start=$(date -r "$end" -v-1m +%s)
  today=$(date -j -f '%Y-%m-%d %H:%M:%S' "$(date +%Y-%m-%d) 12:00:00" +%s)
  plan1="Plan ends  ${D}$(plan_date "$end")${R}"
  n=$(( (end - today + 43200) / 86400 ))
  pct=$(( (today - start) * 100 / (end - start) ))
  [ "$pct" -lt 0 ] && pct=0
  if [ "$n" -le 3 ]; then c=$RED; elif [ "$n" -le 7 ]; then c=$YELLOW; fi
  if [ "$end" -lt "$today" ]; then text="ended?" pct=100
  elif [ "$n" -eq 0 ]; then text="today"
  else text="${n}d"
  fi
  plan2="$(bar "$pct" "$c" $(( 20 - ${#text} )))"
  if [ "$c" -eq $PURPLE ]; then plan2="$plan2 $(echo "$text" | white_digits)"; else plan2="$plan2 $(paint "$c" "$text")"; fi
}

# live rate_limits; before the first reply of a session, the last saved ones
limits=$(echo "$input" | jq -c '.rate_limits // empty' 2>/dev/null)
[ -n "$limits" ] || limits=$(cat "$dir/usage-latest.json" 2>/dev/null)
pct_of() { echo "$limits" | jq -r ".$1.used_percentage // empty | floor" 2>/dev/null; }
reset_of() { echo "$limits" | jq -r ".$1.resets_at // empty | floor" 2>/dev/null; }
h5=$(pct_of five_hour); h5r=$(reset_of five_hour)
wk=$(pct_of seven_day); wkr=$(reset_of seven_day)
# window already over: it is back to 0 until Claude reports the next one
if [ -n "$h5r" ] && [ "$h5r" -le "$(date +%s)" ]; then h5=0; h5r=""; fi
if [ -n "$wkr" ] && [ "$wkr" -le "$(date +%s)" ]; then wk=0; wkr=""; fi
pct_text() { if [ -n "$1" ]; then paint "$(shade "$1" "$2")" "$1%"; else printf '–'; fi; }
timer() { [ -n "$1" ] && left "$1" | white_digits; }

model=$(echo "$input" | jq -r '.model.id')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
wall=$(echo "$input" | jq -r '.cost.total_duration_ms // empty | floor')
api=$(echo "$input" | jq -r '.cost.total_api_duration_ms // empty | floor')
eval "$(echo "$input" | jq -r '
  "ctxp=\(if .context_window.used_percentage then (.context_window.used_percentage|floor) else "" end | @sh)",
  "ctxt=\(.context_window.total_input_tokens // "" | @sh)",
  "ctxs=\(.context_window.context_window_size // "" | @sh)",
  "hit=\(if .prompt_cache.hit_ratio then (.prompt_cache.hit_ratio*100|floor) else "" end | @sh)"
' 2>/dev/null)"
effort=$(echo "$input" | jq -r '.effort.level // empty')
case "$effort" in
  low) ec=245 ;;
  medium) ec=45 ;;
  high) ec=33 ;;
  xhigh) ec=135 ;;
  max) ec=201 ;;
  *) ec=255 ;;
esac

[ -n "$effort" ] && effort=" $(paint $ec "$effort")"
ctx=""
if [ -n "$ctxp$ctxs" ]; then
  ctx="Context  $(paint "$(shade "${ctxp:-0}" $GREEN)" "${ctxp:-0}%")"
  [ -n "$ctxt" ] && [ -n "$ctxs" ] && ctx="$ctx ${D}$(num "$ctxt")/$(num "$ctxs")${R}"
fi
[ -n "$hit" ] && hit="Cache    ${W}${hit}%${R}"
[ -n "$wall" ] && wall="Session  ${W}$(dur "$wall")${R}"
[ -n "$api" ] && api="API      ${W}$(dur "$api")${R}"

# add <gap> <upper> <lower> [r]: one grid column, both rows padded to one width
row1="" row2=""
add() {
  local a b w
  a=$(len "$2"); b=$(len "$3"); w=$(( a > b ? a : b ))
  [ "$w" -eq 0 ] && return
  [ -n "$row1" ] && { row1="$row1$1"; row2="$row2$1"; }
  if [ "$4" = r ]; then
    row1="$row1$(pad $(( w - a )))$2"; row2="$row2$(pad $(( w - b )))$3"
  else
    row1="$row1$2$(pad $(( w - a )))"; row2="$row2$3$(pad $(( w - b )))"
  fi
}

add "$SEP" "$W$model$R$effort" "Cost ${W}\$$(printf '%.2f' "$cost")${R}"
add "$SEP" "$ctx" "$hit"
add "$SEP" "$wall" "$api"
left1=$row1 left2=$row2

row1="" row2=""
plan
add "$SEP" "$plan1" "$plan2"
add "$SEP" "5-Hour" "Weekly"
add "  " "$(pct_text "$h5" $GREEN)" "$(pct_text "$wk" $BLUE)" r
add "  " "$(timer "$h5r")" "$(timer "$wkr")" r
add "  " "$(bar "${h5:-0}" "$(shade "${h5:-0}" $GREEN)" 12)" "$(bar "${wk:-0}" "$(shade "${wk:-0}" $BLUE)" 12)"

# push the right block to the edge (Claude Code keeps 4 columns for itself)
gap=$(( ${COLUMNS:-0} - 4 - $(len "$left1") - $(len "$row1") ))
[ "$gap" -lt 3 ] && gap=3
printf '%s%s%s\n' "$left1" "$(pad "$gap")" "$row1"
printf '%s%s%s\n' "$left2" "$(pad "$gap")" "$row2"
exit 0
