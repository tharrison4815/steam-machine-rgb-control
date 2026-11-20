# Steam Machine RGB Control

A KDE Plasma 6 widget for customising the Steam Machine's front LED strip from Desktop Mode, with
the option to save your design so Game Mode uses it too.

> Status: in development. All planned features are implemented; Save for Game Mode and the boot
> colour still need testing on the device. Not yet packaged for the KDE Store.
> This README is the working spec.

## Why

SteamOS only exposes the light bar's settings in Game Mode, and there the colour pickers are
hue-only sliders (no white, pastels or dark shades). This widget gives full RGB control from the
desktop, shows an accurate preview of how colours blend on the real strip, and makes designs
easy to share.

## Distribution

- Packaged as a Plasma 6 widget (plasmoid) on the KDE Store, so it appears in Discover under
  *Plasma Addons*.
- Not a Flatpak: Flatpak apps can't write to `/sys`, and SteamOS Manager has no LED D-Bus API.
  If Valve adds one, a Flatpak becomes possible later.

## Features

### Form
- Taskbar/system-tray icon; clicking opens the editor popup.
- The same widget can be placed on the desktop for a larger, always-visible editor.

### Strip editor
- 17 swatches shown left → right as seen from the front (hardware index 16 is leftmost).
- Selection: click, shift-click (range), ctrl-click (multi).
- **Blended preview** row under the swatches showing how the strip will actually look
  (see *Preview model*).
- Undo / redo. Edits apply to the strip live.

### Colour panel (acts on the selection)
- Colour picker plus hex (`#rrggbb`) and R/G/B entry, all kept in sync.
- **Solid**: set every selected LED to one colour.
- **Gradient**: start and end colour (default: current colours at the ends of the selection),
  filled across the selected LEDs only, including non-contiguous selections.

### Colours dropdown
- Built-in presets (colours only):
  - Candy cane
  - Synthwave
  - Christmas zones
  - Warm white
  - Valve blue (default)
- **My presets**: save the current design.
- Shows "Custom" once you edit.

### Effect dropdown (independent of colours)
- Solid, Breathe, Patrol, Rainbow: the same four as Game Mode.
- Speed slider for everything except Solid.
- Rainbow greys out the colour editor (colours are kept).
- Hidden driver effects (`normal`, `factory`, `demo`, `off`) are deliberately not offered:
  they duplicate the four above.

### Brightness
- One slider for the whole strip. Per-LED dimming is done through the colours.
- Shows how many colour levels the current brightness allows (see *Quantisation*).

### Share codes
- Colours only (not effect or brightness).
- Format: `SMLED1:` + unpadded base64url(version byte `1`, 17 × RGB in hardware index order, CRC-8
  (polynomial 0x07) of the preceding bytes): always 78 characters. Whitespace is ignored when pasting.
- Copy / Paste buttons; a broken code shows an error and changes nothing.
- Built-in presets and saved presets use the same format internally.

### Save for Game Mode
- Explains that Steam must be closed, refuses if a game is running, closes Steam, waits until it
  has fully exited and finished writing its config, then backs up, writes and verifies
  `localconfig.vdf`. Never starts Steam by itself: afterwards it offers a **Reopen Steam** button,
  which opens `steam://open/main` through the normal desktop launcher (like the app menu).
- Backups are written next to the file as `localconfig.vdf.smrgb-backup-<timestamp>`; the newest 5
  are kept.
- Sets Steam's "separate colours" option on when colours differ.
- Converts colours to the nearest value Game Mode can reproduce, and warns when they'll look
  different.
- An **"Unsaved"** indicator appears when the live strip differs from the saved design, because
  Steam re-applies its saved LED settings whenever it starts (Desktop Mode too).

### Advanced
- Boot/startup colour and brightness (`multi_intensity_startup`, `brightness_startup`): not
  available in Game Mode, and likely stored in firmware. Behind a warning.

## Hardware reference

Measured on the device; details and raw data live in the author's notes.

### sysfs
- 17 LEDs: `/sys/class/leds/valve-leds[0..16]`, owned by the logged-in user, so no root is needed.
  Index 0 is on the **right**.
- Per LED: `multi_intensity` (`R G B`, 0–255), `effect`, `enabled`, `delay` (0–20),
  `brightness_scale`.

### Quantisation (exact)
- Real brightness: `p = floor(brightness_scale × 100 / 255)`, a whole percentage from 0 to 100.
- Per channel: `level = floor(value × p / 100)`. Each level is an equal step of light.
- `brightness_scale` 0–2 means off.
- At `brightness_scale` 9 (Game Mode slider ≈ 23%) there are only 8 levels per channel; at 255
  (slider 100%) you get the full 0–255.

### Game Mode storage
- Settings live in `~/.local/share/Steam/userdata/<id>/config/localconfig.vdf`, under
  `"LEDManager"` → `"<device hash>"`, plus `"SteamOS"` → `"SeparaeLEDColors"` (Valve's spelling).
- Colour slots `"0"`–`"16"` use 0–1 floats. Steam converts a stored value `v` like this:
  - if `v ≥ 0.95` the result is 255;
  - otherwise `q = round(v × 255)` and the result is `floor(255 × (q/255)^2.2)`.
  - This means values 228–254 are unreachable.
- Speed: `delay = round(20 × (1 − Speed))`.
- Brightness `B` (0–1) maps to `brightness_scale = floor(255 × B^2.2)`: 1 gives 255 (full 0–255
  colour depth), 0.2258 gives 9 (8 levels per channel).

### Preview model
- Light from neighbouring LEDs adds linearly.
- Glow kernel relative to the LED centre, with `d` in LED spacings:
  `exp(-(sqrt(d² + 0.64²) − 0.64) / 0.68)`.
  That gives 0.78 at 0.5 spacing, 0.45 at 1, 0.12 at 2 and 0.03 at 3.
- Preview colour at position `x` = Σ wᵢ(x) · linearᵢ / Σ wᵢ(x), with each LED quantised to its real
  levels, then sRGB-encoded. The strip dims towards its ends.

## Gotchas for developers and testers

- **Stay in Game Mode for at least 90 seconds per visit.** SteamOS's `steam-short-session-tracker`
  reinstalls Steam from an old OS copy after three Game Mode sessions shorter than 60 seconds in a row.
- Never edit `localconfig.vdf` while Steam is running: Steam rewrites it on exit.
- Don't launch Steam from scripts; let the user reopen it.

## Planned architecture

- **Plasma 6 plasmoid (QML):**
  - `contents/ui/`: the editor UI, preview rendering and share-code handling.
  - `contents/code/steam-machine-rgb-helper` (Python 3, standard library only): reads and writes
    sysfs, and handles the Save-for-Game-Mode flow, called through Plasma5Support's executable
    data source.
- No background service; the widget only acts while you use it.
