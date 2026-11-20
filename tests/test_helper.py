#!/usr/bin/env python3
"""Tests for the Game Mode parts of smrgb-helper. Never touches Steam or the real config:
Steam detection/closing is stubbed and the helper is pointed at temporary copies.

    python3 -I tests/test_helper.py [path/to/a/real/localconfig.vdf]

With a path, the save is also exercised on a temporary copy of that file.
"""
import difflib, glob, importlib.machinery, importlib.util, math, os, shutil, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
HELPER = os.path.join(HERE, "..", "package", "contents", "code", "smrgb-helper")

loader = importlib.machinery.SourceFileLoader("smrgb_helper", HELPER)
spec = importlib.util.spec_from_loader("smrgb_helper", loader)
h = importlib.util.module_from_spec(spec)
loader.exec_module(h)

# Never look at, or close, the real Steam.
h.steam_running = lambda: False
h.game_running = lambda: False
h.close_steam = lambda files: (_ for _ in ()).throw(AssertionError("close_steam called"))

failures = 0


def check(cond, msg):
    global failures
    print(("PASS " if cond else "FAIL ") + msg)
    failures += 0 if cond else 1


def slot(i, r, g, b):
    return f'\t\t\t"{i}"\n\t\t\t{{\n\t\t\t\t"R"\t\t"{r}"\n\t\t\t\t"G"\t\t"{g}"\n\t\t\t\t"B"\t\t"{b}"\n\t\t\t}}\n'


SYNTHETIC = ('"UserLocalConfigStore"\n{\n\t"Other"\n\t{\n\t\t"Brightness"\t\t"0.5"\n\t}\n'
             '\t"LEDManager"\n\t{\n\t\t"9b0f7ff0"\n\t\t{\n\t\t\t"Brightness"\t\t"1"\n'
             '\t\t\t"Enabled"\t\t"1"\n\t\t\t"ColorCount"\t\t"17"\n'
             + "".join(slot(i, "0", "0.4", "1") for i in range(17)) +
             '\t\t}\n\t}\n\t"Gamescope"\n\t{\n\t}\n}\n')   # no Effect/Speed, no SteamOS block


def run_save_on(src_text, label):
    d = tempfile.mkdtemp()
    try:
        path = os.path.join(d, "userdata", "1", "config", "localconfig.vdf")
        os.makedirs(os.path.dirname(path))
        open(path, "w", encoding="utf-8").write(src_text)
        h.CONFIG_GLOB = os.path.join(d, "userdata", "*", "config", "localconfig.vdf")

        design = {"colours": [[i * 15, 255 - i * 15, 240] for i in range(17)],
                  "effect": "breath", "enabled": 1, "scale": 9, "delay": 7}
        res = h.save(design)
        after = open(path, encoding="utf-8").read()
        saved = res["saved"]
        expected = [[h.level_to_steam(v)[0] for v in c] for c in design["colours"]]
        check(saved["colours"] == expected, f"{label}: colours read back as Game Mode would show them")
        check(saved["effect"] == "breath" and saved["scale"] == 9 and saved["delay"] == 7,
              f"{label}: effect/brightness/speed read back ({saved['effect']}, {saved['scale']}, {saved['delay']})")
        check(h.get_key(after[h.find_block(after, "SteamOS")[0]:], "SeparaeLEDColors") == "1",
              f"{label}: separate colours switched on")
        check(after.count("{") == after.count("}"), f"{label}: braces balanced")
        check(len(res["backups"]) == 1 and open(res["backups"][0], encoding="utf-8").read() == src_text,
              f"{label}: backup is identical to the original")
        # Only LED-related lines may change.
        changed = [l for l in difflib.unified_diff(src_text.splitlines(), after.splitlines(), lineterm="", n=0)
                   if l[:1] in "+-" and not l.startswith(("+++", "---"))]
        allowed = ('"R"', '"G"', '"B"', '"Brightness"', '"Effect"', '"Speed"', '"Enabled"',
                   '"SteamOS"', '"SeparaeLEDColors"', '{', '}')
        odd = [l for l in changed if not l[1:].strip().startswith(allowed)]
        check(not odd, f"{label}: only LED settings changed ({len(changed)} lines)" + (f" unexpected: {odd[:3]}" if odd else ""))
        # Other "Brightness" keys elsewhere in the file must be untouched.
        if label == "synthetic":
            check('"Other"\n\t{\n\t\t"Brightness"\t\t"0.5"' in after, f"{label}: unrelated keys untouched")
        # Saving again must not pile up more than BACKUPS_KEPT backups.
        for _ in range(h.BACKUPS_KEPT + 2):
            import time; time.sleep(1.01)
            h.save(design)
        n = len(glob.glob(path + ".smrgb-backup-*"))
        check(n == h.BACKUPS_KEPT, f"{label}: old backups pruned to {h.BACKUPS_KEPT} (found {n})")
    finally:
        shutil.rmtree(d)


# --- conversion model ---
check(all(v not in h.REACHABLE for v in range(228, 255)), "levels 228-254 are unreachable in Game Mode")
check(all(h.steam_to_level(float(s)) == lvl for lvl, s in h.REACHABLE.items()),
      "every stored value converts back to its level")
check(h.level_to_steam(240)[0] == 227 and h.level_to_steam(250)[0] == 255, "unreachable levels snap to nearest")
check(all(math.floor(255 * float(h.scale_to_brightness(s)) ** 2.2) == s for s in range(256)),
      "every brightness_scale 0-255 round-trips through Steam's Brightness")
check(h.steam_to_level(0.972820) == 255, "the stored candy-cane white (0.972820) shows as 255")

run_save_on(SYNTHETIC, "synthetic")
if len(sys.argv) > 1:
    run_save_on(open(sys.argv[1], encoding="utf-8").read(), "real-copy")

print("\n" + ("ALL PASSED" if failures == 0 else f"{failures} FAILED"))
sys.exit(1 if failures else 0)
