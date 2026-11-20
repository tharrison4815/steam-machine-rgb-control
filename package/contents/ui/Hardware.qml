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

    signal stateLoaded()

    readonly property string helperPath: Qt.resolvedUrl("../code/smrgb-helper").toString().replace(/^file:\/\//, "")

    property int _seq: 0
    property var _pending: ({})
    property string _refreshTag: ""

    function _run(args) {
        _seq += 1;
        exec.connectSource("python3 '" + helperPath + "' " + args + " " + _seq);
        return String(_seq);
    }

    function refresh() {
        _refreshTag = _run("state -");
    }

    // changes: any of {colours, effect, enabled, scale, delay}
    function apply(changes) {
        for (const k in changes) {
            _pending[k] = changes[k];
        }
        flushTimer.restart();
    }

    Timer {
        id: flushTimer
        interval: 40
        onTriggered: {
            const json = JSON.stringify(hw._pending);
            hw._pending = {};
            hw._run("apply '" + json + "'");
        }
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            let out;
            try {
                out = JSON.parse(data["stdout"]);
            } catch (e) {
                hw.error = "Helper failed: " + (data["stderr"] || data["stdout"] || e);
                return;
            }
            if (!out.ok) {
                hw.error = out.error;
                return;
            }
            hw.error = "";
            hw.available = out.available;
            if (!out.available) {
                hw.error = out.error || "LED strip not found";
                hw.loaded = true;
                return;
            }
            hw.writable = out.writable;
            hw.count = out.count;
            hw.colours = out.colours;
            hw.effect = out.effect;
            hw.enabled = out.enabled;
            hw.scale = out.scale;
            hw.delay = out.delay;
            // Only a refresh replaces the editor's state; apply results are just confirmation.
            if (out.tag === hw._refreshTag) {
                hw.loaded = true;
                hw.stateLoaded();
            }
        }
    }
}
