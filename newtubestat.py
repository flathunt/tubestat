#!/usr/bin/env python3

import json
import os
import random
import signal
import subprocess
import sys
import textwrap
import time
import traceback
import urllib.request
from datetime import datetime
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
CARD_W = 60

ESC = '\033'
RESET = f'{ESC}[0m'
BOLD  = f'{ESC}[1m'
BLINK = f'{ESC}[5m'

LINE_COLORS = {
    'central':          (41, 37),
    'piccadilly':       (44, 37),
    'northern':         (47, 30),
    'district':         (42, 37),
    'jubilee':          (46, 30),
    'victoria':         (46, 37),
    'circle':           (43, 30),
    'bakerloo':         (43, 30),
    'metropolitan':     (45, 37),
    'hammersmith-city': (45, 30),
    'elizabeth':        (45, 37),
    'overground':       (43, 30),
    'dlr':              (46, 30),
}
DEFAULT_COLOR = (40, 37)


def goto(row, col):
    return f'{ESC}[{row};{col}f'


def get_color(key):
    bg, fg = LINE_COLORS.get(key.lower(), DEFAULT_COLOR)
    return f'{ESC}[{bg}m{ESC}[{fg}m'


def card_height(text):
    lines = textwrap.wrap(text, width=CARD_W - 4) or ['']
    return len(lines) + 2  # top border + content lines + bottom border


def draw_card(key, text, row, col):
    text_w = CARD_W - 4
    color = get_color(key)
    label = key.upper()

    # Top border: ┌── LABEL ──...──┐
    top_right = '─' * max(0, CARD_W - len(label) - 8)
    out = goto(row, col) + color + f'┌── {BOLD}{label}{RESET}{color} ──{top_right}┐' + RESET

    lines = textwrap.wrap(text, width=text_w) or ['']
    severe = 'severe' in text.lower()
    _, fg = LINE_COLORS.get(key.lower(), DEFAULT_COLOR)

    for i, line in enumerate(lines):
        if i == 0 and severe:
            prefix = f'{BLINK}{ESC}[{fg}m⚠ SEVERE{RESET}{color}  '
            prefix_vis = 11
        else:
            prefix = ''
            prefix_vis = 0
        pad = ' ' * max(0, text_w - len(line) - prefix_vis)
        out += goto(row + 1 + i, col) + color + f'│ {prefix}{line}{pad} │' + RESET

    # Bottom border
    out += goto(row + len(lines) + 1, col) + color + '└' + '─' * (CARD_W - 2) + '┘' + RESET

    sys.stdout.write(out)


def overlaps(r1, c1, h1, r2, c2, h2):
    """True if the two cards overlap (with a 1-row vertical gap)."""
    return (r1 + h1 > r2 and r1 < r2 + h2 + 1 and
            c1 + CARD_W > c2 and c1 < c2 + CARD_W)


def terminal_size():
    try:
        sz = os.get_terminal_size()
        return sz.lines, sz.columns
    except OSError:
        return 24, 80


def draw_screen(disruptions):
    scr_lines, scr_cols = terminal_size()
    now = datetime.now().strftime('%a %d %b %H:%M:%S')

    sys.stdout.write('\033[H\033[2J')

    # Build items: one card per disruption, plus a timestamp card
    items = [(desc.split()[0].lower() if desc.split() else 'unknown', desc)
             for desc in sorted(set(disruptions))]
    items.append(('updated', f'Last updated: {now}'))
    random.shuffle(items)

    # Random placement with collision detection across the full screen
    placed = []

    for key, text in items:
        h = card_height(text)

        max_row = scr_lines - h
        max_col = scr_cols - CARD_W

        if max_row < 1 or max_col < 1:
            continue

        pos = None
        for _ in range(100):
            r = random.randint(1, max_row)
            c = random.randint(1, max_col)
            if not any(overlaps(r, c, h, pr, pc, ph) for pr, pc, ph in placed):
                pos = (r, c)
                break

        if pos:
            r, c = pos
            placed.append((r, c, h))
            draw_card(key, text, r, c)

    sys.stdout.flush()


def load_tubelines():
    lines_file = SCRIPT_DIR / 'lines.txt'
    with open(lines_file) as f:
        for line in f:
            line = line.strip()
            if line.startswith('TUBELINES=') and not line.startswith('#'):
                return line[len('TUBELINES='):].strip("'\"")
    raise RuntimeError('TUBELINES not found in lines.txt')


def fetch_disruptions(tubelines):
    url = f'https://api.tfl.gov.uk/{tubelines}/Disruption'
    req = urllib.request.Request(url, headers={'User-Agent': 'curl/7.88'})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.load(resp)
        return [item['description'] for item in data if 'description' in item]
    except Exception:
        return []


def setterm(*args):
    subprocess.run(['setterm', '--term', 'linux', *args], stderr=subprocess.DEVNULL)


def cleanup(sig=None, frame=None):
    subprocess.run(['sudo', '/usr/local/bin/bright'], stderr=subprocess.DEVNULL)
    setterm('--cursor', 'on')
    setterm('--blank', '1')
    setterm('--blank=poke')
    sys.stdout.write('\033[0m')
    sys.exit(0)


def draw_status(msg):
    """Show a single centred message — keeps the screen alive so the user
    can tell the script is running rather than hung."""
    scr_lines, scr_cols = terminal_size()
    sys.stdout.write('\033[H\033[2J')
    col = max(1, (scr_cols - len(msg)) // 2)
    row = scr_lines // 2
    sys.stdout.write(f'\033[{row};{col}f{msg}')
    sys.stdout.flush()


def main():
    signal.signal(signal.SIGINT, cleanup)

    subprocess.run(['sudo', '/usr/local/bin/dim'], stderr=subprocess.DEVNULL)
    setterm('--cursor', 'off')

    while True:
        draw_status('Checking TFL status...')

        try:
            tubelines = load_tubelines()
            disruptions = fetch_disruptions(tubelines)
        except Exception as e:
            with open('/tmp/newtubestat.log', 'a') as f:
                f.write(f'{datetime.now()}: {traceback.format_exc()}\n')
            draw_status(f'Error: {e}  — retrying in 30s')
            time.sleep(30)
            continue

        if disruptions:
            setterm('--blank=poke')
            setterm('--blank', '0')
            draw_screen(disruptions)
            time.sleep(60)
        else:
            setterm('--blank=force')
            time.sleep(30)


if __name__ == '__main__':
    main()
