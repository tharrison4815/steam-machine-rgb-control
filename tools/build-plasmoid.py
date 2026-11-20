#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Tom Harrison
# SPDX-License-Identifier: GPL-2.0-or-later
"""Build the .plasmoid file (a zip of package/) for the KDE Store.

    python3 tools/build-plasmoid.py      ->  dist/steam-machine-rgb-control-<version>.plasmoid

The archive is reproducible (fixed timestamps, sorted entries) and keeps the helper executable.
"""
import json, os, stat, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PKG = os.path.join(ROOT, "package")
SKIP_DIRS = {"__pycache__"}
SKIP_SUFFIXES = (".pyc", "~", ".swp")


def main():
    meta = json.load(open(os.path.join(PKG, "metadata.json"), encoding="utf-8"))
    version = meta["KPlugin"]["Version"]
    os.makedirs(os.path.join(ROOT, "dist"), exist_ok=True)
    out = os.path.join(ROOT, "dist", f"steam-machine-rgb-control-{version}.plasmoid")

    files = []
    for d, dirs, names in os.walk(PKG):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS)
        for n in sorted(names):
            if not n.endswith(SKIP_SUFFIXES):
                files.append(os.path.join(d, n))

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for path in files:
            rel = os.path.relpath(path, PKG)
            info = zipfile.ZipInfo(rel, date_time=(2026, 1, 1, 0, 0, 0))
            mode = 0o755 if os.stat(path).st_mode & stat.S_IXUSR else 0o644
            info.external_attr = (stat.S_IFREG | mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, open(path, "rb").read())

    print(f"{out}  ({len(files)} files, {os.path.getsize(out)} bytes, version {version})")


if __name__ == "__main__":
    sys.exit(main())
