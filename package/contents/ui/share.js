.pragma library

// Share codes: "SMLED1:" + base64url(version byte, 17 x RGB in hardware order, CRC-8).
// Colours only. Built-in and saved presets use the same format.

const PREFIX = "SMLED1:";
const VERSION = 1;
const COUNT = 17;
const ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

function crc8(bytes) {
    let c = 0;
    for (const b of bytes) {
        c ^= b;
        for (let i = 0; i < 8; i++) {
            c = (c & 0x80) ? ((c << 1) ^ 0x07) & 0xff : (c << 1) & 0xff;
        }
    }
    return c;
}

function toBase64url(bytes) {
    let out = "";
    for (let i = 0; i < bytes.length; i += 3) {
        const k = Math.min(3, bytes.length - i);
        const n = (bytes[i] << 16) | ((bytes[i + 1] || 0) << 8) | (bytes[i + 2] || 0);
        out += ALPHA[(n >> 18) & 63] + ALPHA[(n >> 12) & 63];
        if (k > 1) out += ALPHA[(n >> 6) & 63];
        if (k > 2) out += ALPHA[n & 63];
    }
    return out;
}

function fromBase64url(text) {
    const bytes = [];
    let buf = 0, bits = 0;
    for (const ch of text) {
        const v = ALPHA.indexOf(ch);
        if (v < 0) {
            return null;
        }
        buf = (buf << 6) | v;
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            bytes.push((buf >> bits) & 255);
            buf &= (1 << bits) - 1;
        }
    }
    return bytes;
}

// cols: [[r,g,b] x 17] in hardware order
function encode(cols) {
    const bytes = [VERSION];
    for (const c of cols) {
        bytes.push(c[0] & 255, c[1] & 255, c[2] & 255);
    }
    bytes.push(crc8(bytes));
    return PREFIX + toBase64url(bytes);
}

// Returns { cols } or { error }
function decode(text) {
    const s = String(text).replace(/\s+/g, "");
    if (s.slice(0, PREFIX.length).toUpperCase() !== PREFIX) {
        return { error: "That isn't an LED share code (it should start with " + PREFIX + ")." };
    }
    const bytes = fromBase64url(s.slice(PREFIX.length));
    if (!bytes || bytes.length !== 1 + COUNT * 3 + 1) {
        return { error: "That share code is incomplete or damaged." };
    }
    if (bytes[0] !== VERSION) {
        return { error: "That share code was made by a newer version of this widget." };
    }
    if (crc8(bytes.slice(0, -1)) !== bytes[bytes.length - 1]) {
        return { error: "That share code is damaged (checksum mismatch). Try copying it again." };
    }
    const cols = [];
    for (let i = 0; i < COUNT; i++) {
        cols.push([bytes[1 + i * 3], bytes[2 + i * 3], bytes[3 + i * 3]]);
    }
    return { cols: cols };
}
