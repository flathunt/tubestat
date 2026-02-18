#!/bin/bash
#set -xv

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tfile=/tmp/tubestatus.$$

trap "sudo /usr/local/bin/bright ; setterm --term linux --cursor on 2>/dev/null ; setterm --term linux --blank 1 2>/dev/null ; setterm --term linux --blank=poke 2>/dev/null ; printf '\033[0m' ; rm -f $tfile ; exit" 2

# ANSI escape helpers
ESC='\033'
RESET="${ESC}[0m"
BOLD="${ESC}[1m"
BLINK="${ESC}[5m"

# Fixed card box width (from ┌ to ┐ inclusive)
CARD_W=60

# Map line names to ANSI bg/fg codes
declare -A LINE_BG LINE_FG
LINE_BG[central]=41;        LINE_FG[central]=37
LINE_BG[piccadilly]=44;     LINE_FG[piccadilly]=37
LINE_BG[northern]=47;       LINE_FG[northern]=30
LINE_BG[district]=42;       LINE_FG[district]=37
LINE_BG[jubilee]=46;        LINE_FG[jubilee]=30
LINE_BG[victoria]=46;       LINE_FG[victoria]=37
LINE_BG[circle]=43;         LINE_FG[circle]=30
LINE_BG[bakerloo]=43;       LINE_FG[bakerloo]=30
LINE_BG[metropolitan]=45;   LINE_FG[metropolitan]=37
LINE_BG["hammersmith-city"]=45; LINE_FG["hammersmith-city"]=30
LINE_BG[elizabeth]=45;      LINE_FG[elizabeth]=37
LINE_BG[overground]=43;     LINE_FG[overground]=30
LINE_BG[dlr]=46;            LINE_FG[dlr]=30
LINE_BG[default]=40;        LINE_FG[default]=37

# draw_card KEY TEXT START_ROW START_COL
draw_card() {
  local key="$1"
  local text="$2"
  local row="$3"
  local col="$4"

  # text_w: inner width (│ + space + text + space + │ = CARD_W, so text_w = CARD_W - 4)
  local text_w=$(( CARD_W - 4 ))

  local key_lower
  key_lower=$(echo "$key" | tr '[:upper:]' '[:lower:]')
  local bg=${LINE_BG[$key_lower]:-${LINE_BG[default]}}
  local fg=${LINE_FG[$key_lower]:-${LINE_FG[default]}}

  local color="${ESC}[${bg}m${ESC}[${fg}m"
  local label="${key^^}"
  local label_len=${#label}

  # Top border: ┌── LABEL ──...──┐  total = CARD_W
  # breakdown: ┌(1) ──(2) space(1) label space(1) ──(2) top_right ┐(1) = label+8+top_right = CARD_W
  local top_right_len=$(( CARD_W - label_len - 8 ))
  if [ "$top_right_len" -lt 0 ]; then top_right_len=0; fi
  local top_right
  top_right=$(printf '─%.0s' $(seq 1 $top_right_len))
  printf "\033[${row};${col}f${color}┌── ${BOLD}${label}${RESET}${color} ──${top_right}┐${RESET}"
  row=$(( row + 1 ))

  # Severe prefix
  local prefix=""
  local prefix_vis=0
  if echo "$text" | grep -qi "severe"; then
    prefix="${BLINK}${ESC}[${fg}m⚠ SEVERE${RESET}${color}  "
    prefix_vis=11  # visible chars: "⚠ SEVERE  "
  fi

  # Wrap and draw content lines
  local wrapped
  wrapped=$(echo "$text" | fold -s -w "$text_w")

  local first_line=true
  while IFS= read -r wline; do
    local vlen=${#wline}
    if $first_line && [ -n "$prefix" ]; then
      local adj_pad=$(( text_w - vlen - prefix_vis ))
      if [ "$adj_pad" -lt 0 ]; then adj_pad=0; fi
      local adj_padding
      adj_padding=$(printf '%*s' "$adj_pad" '')
      printf "\033[${row};${col}f${color}│ ${prefix}${wline}${adj_padding} │${RESET}"
      first_line=false
    else
      local pad=$(( text_w - vlen ))
      if [ "$pad" -lt 0 ]; then pad=0; fi
      local padding
      padding=$(printf '%*s' "$pad" '')
      printf "\033[${row};${col}f${color}│ ${wline}${padding} │${RESET}"
    fi
    row=$(( row + 1 ))
  done <<< "$wrapped"

  # Bottom border: └──...──┘  total = CARD_W
  local bottom_len=$(( CARD_W - 2 ))
  local bottom
  bottom=$(printf '─%.0s' $(seq 1 $bottom_len))
  printf "\033[${row};${col}f${color}└${bottom}┘${RESET}"
}

draw_screen() {
  local disruptions_file="$1"
  local scr_cols scr_lines
  scr_cols=$(tput cols 2>/dev/null || echo 80)
  scr_lines=$(tput lines 2>/dev/null || echo 24)
  local now
  now=$(date '+%a %d %b %H:%M:%S')
  local title="TUBE STATUS MONITOR"

  # Clear screen
  printf '\033[H\033[2J'

  # Header line 1: title + right-aligned clock
  local gap=$(( scr_cols - ${#title} - ${#now} - 2 ))
  if [ "$gap" -lt 1 ]; then gap=1; fi
  local spacer
  spacer=$(printf '%*s' "$gap" '')
  printf "\033[1;1f  ${BOLD}${title}${RESET}${spacer}${now}"

  # Separator line 2
  local sep
  sep=$(printf '═%.0s' $(seq 1 $(( scr_cols - 2 )) ))
  printf "\033[2;1f  ${sep}"

  # Cards at random positions
  sort -u "$disruptions_file" | while IFS= read -r desc; do
    local line_key
    line_key=$(echo "$desc" | awk '{print tolower($1)}')

    # Calculate card height: wrapped lines + top border + bottom border
    local text_w=$(( CARD_W - 4 ))
    local wrapped_lines
    wrapped_lines=$(echo "$desc" | fold -s -w "$text_w" | wc -l)
    local card_h=$(( wrapped_lines + 2 ))

    # Random position: rows 3..(scr_lines - card_h), cols 1..(scr_cols - CARD_W)
    local max_row=$(( scr_lines - card_h ))
    local max_col=$(( scr_cols - CARD_W ))
    if [ "$max_row" -lt 3 ]; then max_row=3; fi
    if [ "$max_col" -lt 1 ]; then max_col=1; fi

    local rand_row=$(( RANDOM % (max_row - 2) + 3 ))
    local rand_col=$(( RANDOM % max_col + 1 ))

    draw_card "$line_key" "$desc" "$rand_row" "$rand_col"
  done

  # Footer at bottom of screen
  printf "\033[${scr_lines};1f  Last updated: ${now}"
}

setterm --term linux --blank=force 2>/dev/null
sudo /usr/local/bin/dim
setterm --term linux --cursor off 2>/dev/null

while :
do
  . "$SCRIPT_DIR/lines.txt"
  curl https://api.tfl.gov.uk/$TUBELINES/Disruption 2>/dev/null \
    | jq -r '.[] | .description' > "$tfile"

  if [ -s "$tfile" ]; then
    setterm --term linux --blank=poke 2>/dev/null
    setterm --term linux --blank 0 2>/dev/null

    draw_screen "$tfile"

    i=1
    while [ "$i" -lt 30 ]; do
      sleep 2
      i=$(( i + 1 ))
    done
  else
    setterm --term linux --blank=force 2>/dev/null
    sleep 30
  fi
done
