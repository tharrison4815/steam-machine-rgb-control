.pragma library

function clamp(v) {
    v = Math.round(Number(v));
    return isNaN(v) ? 0 : Math.max(0, Math.min(255, v));
}

function toHex(rgb) {
    return "#" + rgb.map(v => clamp(v).toString(16).padStart(2, "0")).join("");
}

// Accepts "#rrggbb" or "rrggbb"; returns [r,g,b] or null
function fromHex(text) {
    const m = /^#?([0-9a-fA-F]{6})$/.exec(String(text).trim());
    if (!m) {
        return null;
    }
    const n = parseInt(m[1], 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function toQt(rgb) {
    return Qt.rgba(clamp(rgb[0]) / 255, clamp(rgb[1]) / 255, clamp(rgb[2]) / 255, 1);
}

function fromQt(c) {
    return [clamp(c.r * 255), clamp(c.g * 255), clamp(c.b * 255)];
}

function copy(cols) {
    return cols.map(c => [c[0], c[1], c[2]]);
}

function same(a, b) {
    return a[0] === b[0] && a[1] === b[1] && a[2] === b[2];
}

// --- Steam-compatible brightness/speed mappings (see README "Hardware reference") ---

// Steam Brightness slider (0..1) -> brightness_scale
function brightnessToScale(b) {
    return Math.floor(255 * Math.pow(Math.max(0, Math.min(1, b)), 2.2));
}

// brightness_scale -> nearest slider position
function scaleToBrightness(s) {
    return Math.pow(Math.max(0, Math.min(255, s)) / 255, 1 / 2.2);
}

// Distinct output levels per colour channel at a given brightness_scale (including "off")
function levelsForScale(s) {
    const p = Math.floor(s * 100 / 255);
    return Math.floor(255 * p / 100) + 1;
}

function speedToDelay(speed) {
    return Math.round(20 * (1 - Math.max(0, Math.min(1, speed))));
}

function delayToSpeed(d) {
    return 1 - Math.max(0, Math.min(20, d)) / 20;
}
