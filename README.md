# tubestat

A shell script that displays London Underground (TFL) line disruptions on a Linux terminal with color-coded output.

## Overview

`tubestat` is a bash-based monitoring tool that fetches real-time disruption information for specified London Underground lines from the TFL API and displays them on a terminal with visual styling. When disruptions are detected, they are displayed with color coding matching each tube line. When there are no disruptions, the screen remains blank.

## Files

- **tubestat.sh** - Main shell script that fetches and displays disruption information
- **lines.txt** - Configuration file specifying which tube lines to monitor

## Configuration: lines.txt Format

The `lines.txt` file contains shell variable definitions that specify which London Underground lines to monitor.

### Entry Format

Each entry in `lines.txt` should be a shell variable assignment in one of these formats:

```
TUBELINES='Mode/tube,line1,line2,line3'
TUBELINES='Line/district,central,piccadilly,northern'
```

### Format Specification

- **Variable name**: Must be `TUBELINES`
- **Value**: A single-quoted string containing:
  - **First part** (mode/type): Either `Mode/` or `Line/` followed by a classification type
    - Examples: `Mode/tube`, `Mode/overground`, `Line/` (for specific line names)
  - **Subsequent parts**: Comma-separated list of line or mode names to monitor
    - Valid line names: `central`, `piccadilly`, `northern`, `district`, etc.
    - No spaces between values

### Examples

Monitor specific tube lines by name:
```bash
TUBELINES='Line/district,central,piccadilly,northern'
```

Monitor by transport mode:
```bash
TUBELINES='Mode/tube,overground'
```

You can comment out entries (prefix with `#`) to disable monitoring without deleting them:
```bash
#TUBELINES='Mode/tube,overground'
```

## How It Works

1. Reads the `TUBELINES` variable from `lines.txt`
2. Queries the TFL API endpoint: `https://api.tfl.gov.uk/$TUBELINES/Disruption`
3. Extracts disruption descriptions using `jq`
4. Displays disruptions with color coding:
   - **Piccadilly**: White text on blue background
   - **Central**: White text on red background
   - **Northern**: Black text on white background
   - **District**: Black text on green background
   - **Other**: White text on black background
5. Disruptions remain visible for ~1 minute (28 seconds + overhead)
6. Checks for new disruptions every 30 seconds when none exist

## Requirements

- `bash` shell
- `curl` - for API requests
- `jq` - for JSON parsing
- `setterm` - for terminal control
- Access to the TFL API

## Usage

```bash
./tubestat.sh
```

The script runs continuously, polling the TFL API for disruptions. Press `Ctrl+C` to exit.

## Notes

- This script uses terminal control features that work on Linux TTY consoles
- The script attempts to control screen blanking and brightness (requires appropriate permissions or `sudoers` configuration)
- All disruptions on the same line are deduplicated and sorted before display