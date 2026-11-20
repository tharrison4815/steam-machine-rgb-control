# KDE Store listing

Text to paste into the KDE Store product form. Keep it in sync with each release.

Published at https://www.opendesktop.org/p/2382283/ (version 1.0.0, 20 Nov 2026).

## Name

Steam Machine RGB Control

## Summary (one line)

Customise the Steam Machine's front LED strip from Desktop Mode: per-LED colours, gradients, effects and shareable designs.

## Description

Control the Steam Machine's front light strip from Desktop Mode, with more freedom than Game Mode's
settings.

**Features**

- Set each of the 17 LEDs individually, with a colour picker, hex codes or RGB values.
- Select several LEDs at once (Shift-click for a range, Ctrl-click to add or remove) and fill them with one colour or a gradient.
- A live preview shows how the colours blend on the real strip, based on measurements of the hardware.
- Effects: Solid, Breathe, Patrol and Rainbow, with speed and brightness controls.
- Built-in designs (Valve blue, Candy cane, Synthwave, Christmas zones, Warm white), plus your own saved presets.
- Share codes: copy a short code for your design and send it to a friend, who can paste it in to get the same colours.
- Undo and redo.
- Save your design so it stays after restarting and in Game Mode too.

**How saving works**

Changes show on the strip straight away but are temporary: SteamOS puts your saved design back whenever Steam
starts. Click **Save** to keep a design. If Steam is running it closes for a moment while saving (close any game
first), and you can reopen it with one click afterwards.

Every colour you pick is adjusted to the nearest one Game Mode can reproduce, so your design looks the same
everywhere.

**Requirements**

- A Steam Machine running SteamOS (Desktop Mode, KDE Plasma 6).
- Set the Front Lights once in Game Mode (Settings → Customization) before using **Save**, so Steam has
  saved LED settings to update.

**Notes**

Not affiliated with or endorsed by Valve. The boot colour (shown while the machine starts up) can't be changed,
because Steam resets it every time it starts.

Source code, bug reports and suggestions: https://github.com/tharrison4815/steam-machine-rgb-control

## Changelog for 1.0.0

First release.

## Other form fields

- **Category:** Plasma 6 Applets (Desktop Extensions › KDE Plasma Extensions › Plasma 6 Extensions › Plasma 6 Applets)
- **Licence:** GPL-2.0-or-later (GPLv2+)
- **Source / homepage link:** https://github.com/tharrison4815/steam-machine-rgb-control
- **File:** `dist/steam-machine-rgb-control-1.0.0.plasmoid` (build with `python3 tools/build-plasmoid.py`)
- **Version:** 1.0.0
- **Screenshots:** `docs/screenshots/editor.png` (main image), then `docs/screenshots/gradient.png`
