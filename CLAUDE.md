# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`tubestat` is a bash script that polls the TFL API for London Underground disruptions and displays them on a Linux TTY console with color-coded output. It is designed to run as a kiosk-style monitor (screen blanks when no disruptions, displays colored alerts when disruptions exist).

## Running the Script

```bash
./tubestat.sh
```

Press `Ctrl+C` to exit. No build step required.

## Dependencies

- `curl` — fetches disruption data from the TFL API
- `jq` — parses JSON responses
- `setterm` — controls terminal blanking, cursor, and colors (Linux TTY only; does not work in terminal emulators)
- `sudo /usr/local/bin/bright` and `sudo /usr/local/bin/dim` — external scripts for screen brightness control (must exist on the host system)

## Configuration

Edit `lines.txt` to control which tube lines are monitored. The file is sourced as shell, so the `TUBELINES` variable must be a valid shell assignment:

```bash
TUBELINES='Line/district,central,piccadilly,northern'
# or
TUBELINES='Mode/tube,overground'
```

The value is used directly in the TFL API URL: `https://api.tfl.gov.uk/$TUBELINES/Disruption`.

## Known Issues / Quirks

- `tubestat.sh` line 12 hardcodes the path to `lines.txt` as `/home/marcusc/git/pylearn/lines.txt` rather than using a relative or repository-local path. This must be updated if the script is run on a different system or from a different location.
- `setterm` color/blank commands only work on a real Linux virtual console (TTY), not inside terminal emulators like GNOME Terminal or tmux.
- The `bright`/`dim` commands require `sudo` — the invoking user needs passwordless sudo access for those specific binaries.
