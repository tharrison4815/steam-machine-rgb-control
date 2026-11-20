.pragma library

// Built-in colour presets, hardware order (index 0 = rightmost LED).

function rep(rgb, n) {
    const out = [];
    for (let i = 0; i < n; i++) {
        out.push(rgb.slice());
    }
    return out;
}

function hex(list) {
    return list.map(h => {
        const n = parseInt(h.slice(1), 16);
        return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
    });
}

const RED = [255, 0, 0];
const CREAM = [255, 240, 230];

const builtins = [
    {
        name: "Valve blue",
        cols: rep([1, 90, 255], 17)
    },
    {
        name: "Candy cane",
        cols: [].concat(rep(RED, 4), rep(CREAM, 3), rep(RED, 3), rep(CREAM, 3), rep(RED, 4))
    },
    {
        name: "Synthwave",
        cols: hex(["#00ffad", "#00ddb2", "#02bdb6", "#06a1bb", "#0c87bf", "#136fc5", "#1d5acb", "#2947cf",
                   "#3737d5", "#4729d9", "#5a1ddf", "#6f13ff", "#870cff", "#a106ff", "#bd02ff", "#dd00ff", "#ff00ff"])
    },
    {
        // Wide blocks so the colours stay distinct through the diffuser.
        name: "Christmas zones",
        cols: [].concat(rep([255, 0, 0], 5), [[0, 0, 0]], rep([255, 150, 60], 5), [[0, 0, 0]], rep([0, 255, 0], 5))
    },
    {
        name: "Warm white",
        cols: rep([255, 150, 60], 17)
    }
];
