// SPDX-FileCopyrightText: 2026 Tom Harrison
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick

// Blended preview of how the strip actually looks (see README "Preview model"):
// each LED is quantised to the levels its brightness allows, its light spreads with the
// measured glow kernel, neighbours add linearly, and the result is sRGB-encoded.
Canvas {
    id: pv

    property var cols: []          // hardware order (index 0 = rightmost)
    property int scale: 255
    property bool rainbow: false

    onColsChanged: requestPaint()
    onScaleChanged: requestPaint()
    onRainbowChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function glow(d) {
        return Math.exp(-(Math.sqrt(d * d + 0.4096) - 0.64) / 0.68);
    }

    function encode(v) {
        v = Math.max(0, Math.min(1, v));
        const s = v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055;
        return Math.round(s * 255);
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const W = Math.floor(width), H = height, n = cols.length;
        if (n === 0 || W <= 0) {
            return;
        }
        if (rainbow) {
            for (let x = 0; x < W; x++) {
                ctx.fillStyle = Qt.hsva(x / W, 1, 1, 1);
                ctx.fillRect(x, 0, 1, H);
            }
            return;
        }
        const p = Math.floor(scale * 100 / 255);
        const maxLevel = Math.floor(255 * p / 100);
        const lin = [];
        for (let pos = 0; pos < n; pos++) {
            const c = cols[n - 1 - pos];
            lin.push(maxLevel > 0 ? c.map(v => Math.floor(v * p / 100) / maxLevel) : [0, 0, 0]);
        }
        // Normalise to the total glow at the middle of the strip, so the ends dim naturally.
        let norm = 0;
        for (let i = 0; i < n; i++) {
            norm += glow(n / 2 - (i + 0.5));
        }
        for (let x = 0; x < W; x++) {
            const sx = (x + 0.5) / W * n;
            let r = 0, g = 0, b = 0;
            for (let i = 0; i < n; i++) {
                const w = glow(sx - (i + 0.5));
                r += w * lin[i][0];
                g += w * lin[i][1];
                b += w * lin[i][2];
            }
            ctx.fillStyle = "rgb(" + encode(r / norm) + "," + encode(g / norm) + "," + encode(b / norm) + ")";
            ctx.fillRect(x, 0, 1, H);
        }
    }
}
