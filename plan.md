# Plan: Fancy Terminal Output for tubestat

## Context

The current `tubestat.sh` script uses basic `setterm` color swaps (foreground/background only) to display TfL disruptions. The user wants fancier terminal output — better visual design while keeping the same Linux TTY-compatible approach, the same TfL API data source, and the same kiosk-style behavior (screen blanks when no disruptions).

## Intended Outcome

A visually polished output with:
- A header showing the script title and live clock
- Each disruption rendered as a colored bordered card using box-drawing characters
- Expanded tube line color mappings (beyond the current 4 lines)
- Bold line names; blinking indicator for "Severe" disruptions
- A footer showing last-updated time
- Text wrapping for long disruption messages
- The hardcoded path bug fixed (currently points to `/home/marcusc/git/pylearn/lines.txt`; changed to use `lines.txt` from the tubestat repo itself)

## Layout Design

```
  TUBE STATUS MONITOR                           Wed 18 Feb 18:42:01
  ═══════════════════════════════════════════════════════════════

  ┌── PICCADILLY ────────────────────────────────────────────────┐
  │ ⚠ SEVERE delays between Finsbury Park and Cockfosters due to │
  │ a signal failure                                             │
  └──────────────────────────────────────────────────────────────┘

  ┌── CENTRAL ───────────────────────────────────────────────────┐
  │ Minor delays                                                  │
  └──────────────────────────────────────────────────────────────┘

  Last updated: 18:42:01
```

Each card uses the line's brand color as background (with appropriate foreground contrast).

## Implementation Details

### File to modify
- `tubestat.sh` — rewrite in place

### Key changes

1. **Fix hardcoded path** (line 12) — use `lines.txt` from the tubestat repo itself:
   ```bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   . "$SCRIPT_DIR/lines.txt"
   ```

2. **Terminal dimensions** — use `tput cols` and `tput lines` to dynamically adapt layout. Card width = `cols - 4`. Text wraps at `cols - 8` using `fold -s -w`.

3. **ANSI escape codes** instead of `setterm` for colors (setterm is still used for blanking/cursor control, which is its real strength):
   - Colors via `\033[40m` – `\033[47m` (8 standard bg colors)
   - Bold via `\033[1m`
   - Blink via `\033[5m`
   - Reset via `\033[0m`

4. **Expanded line color map** (bash associative array):
   | Line | BG | FG |
   |---|---|---|
   | central | red (41) | white (37) |
   | piccadilly | blue (44) | white (37) |
   | northern | white (47) | black (30) |
   | district | green (42) | white (37) |
   | jubilee | cyan (46) | black (30) |
   | victoria | cyan (46) | white (37) |
   | circle | yellow (43) | black (30) |
   | bakerloo | yellow (43) | black (30) |
   | metropolitan | magenta (45) | white (37) |
   | hammersmith-city | magenta (45) | black (30) |
   | elizabeth | magenta (45) | white (37) |
   | overground | yellow (43) | black (30) |
   | dlr | cyan (46) | black (30) |
   | default | black (40) | white (37) |

5. **Card drawing function** `draw_card(line_name, text)`:
   - Sets background color for the whole card
   - Draws `┌── LINE NAME ──...──┐` top border (padded to card width)
   - Wraps and indents disruption text, pads each row to card width
   - Draws `└──...──┘` bottom border
   - Adds blink + `⚠ SEVERE` prefix if message contains "Severe" (case-insensitive)

6. **Screen draw function** `draw_screen()`:
   - Clears screen with `printf '\033[H\033[2J'`
   - Prints header with title (bold) + right-aligned timestamp
   - Draws `═` separator line the full width
   - Iterates sorted unique disruptions and calls `draw_card` for each
   - Prints footer with last-updated time

7. **Display loop timing** — keep existing logic:
   - Disruptions present: display then sleep in 2-second increments for ~60s total
   - No disruptions: `setterm --term linux --blank=force` + sleep 30s

8. **Trap/cleanup** — unchanged: restore brightness, cursor, blank settings, remove tmpfile

### Reading disruption data

Keep the current pattern `cat $tfile | sort -u | while read line rest` which splits the first word as tube line name and the rest as the message. The new code will uppercase the line name for display in the card header using `${line^^}`.

## Verification

1. Run `bash -n tubestat.sh` — check for syntax errors
2. Run `./tubestat.sh` in a Linux TTY console — confirm:
   - Header shows title and clock
   - Disruption cards render with correct colors and borders
   - Screen blanks when no disruptions are present
   - Ctrl+C restores terminal state cleanly
3. Optionally test with a mock `$tfile` containing sample TfL disruption text to verify card rendering without needing live API disruptions
