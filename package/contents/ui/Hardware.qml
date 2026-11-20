import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Talks to the Python helper. Live edits are coalesced and sent at most every ~40 ms.
Item {
    id: hw

    property bool loaded: false
    property bool available: false
    property bool writable: true
    property string error: ""
    property int count: 17

    // Last state read from the strip (hardware index order: 0 = rightmost LED)
    property var colours: []
    property string effect: "manual"
    property int enabled: 1
    property int scale: 9
    property int delay: 10

    // The design Steam will restore (as hardware values), or {available: false, reason}
    property var saved: null
    // Boot colour {colour: [r,g,b], scale}
    property var startup: null
    property bool steamRunning: false

    property bool saving: false

    signal stateLoaded()
    signal saveFinished(var result)      // {ok, error?, steamWasRunning?}

    readonly property string helperPath: Qt.resolvedUrl("../code/smrgb-helper").toString().replace(/^file:\/\//, "")

    property int _seq: 0
    property var _pending: ({})
    property var _kinds: ({})            // tag -> "state" | "apply" | "save"

    function _shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function _run(kind, cmd, arg) {
        _seq += 1;
        const tag = String(_seq);
        _kinds[tag] = kind;
        exec.connectSource("python3 " + _shellQuote(helperPath) + " " + cmd + " " + _shellQuote(arg) + " " + tag);
    }

    function refresh() {
        _run("state", "state", "-");
    }

    // changes: any of {colours, effect, enabled, scale, delay, startup_colour, startup_scale}
    function apply(changes) {
        for (const k in changes) {
            _pending[k] = changes[k];
        }
        flushTimer.restart();
    }

    // design: {colours, effect, enabled, scale, delay}. Closes Steam if it's running.
    function save(design) {
        if (saving) {
            return;
        }
        saving = true;
        _run("save", "save", JSON.stringify(design));
    }

    Timer {
        id: flushTimer
        interval: 40
        onTriggered: {
            const json = JSON.stringify(hw._pending);
            hw._pending = {};
            hw._run("apply", "apply", json);
        }
    }

    function _takeState(out) {
        hw.available = out.available;
        if (!out.available) {
            hw.error = out.error || "LED strip not found";
            return false;
        }
        hw.writable = out.writable;
        hw.count = out.count;
        hw.colours = out.colours;
        hw.effect = out.effect;
        hw.enabled = out.enabled;
        hw.scale = out.scale;
        hw.delay = out.delay;
        if (out.startup !== undefined) {
            hw.startup = out.startup;
        }
        return true;
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            let out = null;
            try {
                out = JSON.parse(data["stdout"]);
            } catch (e) {
                out = { ok: false, error: "Helper failed: " + (data["stderr"] || data["stdout"] || e) };
            }
            const kind = hw._kinds[out.tag] || "apply";
            delete hw._kinds[out.tag];

            if (kind === "save") {
                hw.saving = false;
                if (out.ok) {
                    hw.saved = out.saved;
                    hw.steamRunning = false;
                }
                hw.saveFinished(out);
                return;
            }
            if (!out.ok) {
                hw.error = out.error;
                if (kind === "state") {
                    hw.loaded = true;
                }
                return;
            }
            hw.error = "";
            const ok = hw._takeState(out);
            // Only a refresh replaces the editor's state; apply results are just confirmation.
            if (kind === "state") {
                hw.saved = out.saved || null;
                hw.steamRunning = !!out.steamRunning;
                hw.loaded = true;
                if (ok) {
                    hw.stateLoaded();
                }
            }
        }
    }
}
