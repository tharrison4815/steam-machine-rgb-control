import QtQuick
import QtTest
import "../package/contents/ui"
import "../package/contents/ui/colour.js" as C
import "../package/contents/ui/presets.js" as Presets

Item {
    width: 700; height: 1400

    QtObject {
        id: fakeHw
        property bool loaded: true
        property bool available: true
        property bool writable: true
        property string error: ""
        property var colours: Presets.builtins[1].cols       // candy cane
        property string effect: "manual"
        property int scale: 9
        property int delay: 16
        property var saved: null
        property bool steamRunning: true
        property bool saving: false
        property var lastSave: null
        signal stateLoaded()
        signal saveFinished(var result)
        signal steamChecked()
        property int steamChecks: 0
        function checkSteam() { steamChecks++; steamChecked(); }
        function apply(c) {}
        function refresh() {}
        function save(d) { lastSave = d; }
    }

    Editor { id: ed; hw: fakeHw; width: parent.width }

    TestCase {
        name: "GameMode"
        when: windowShown

        function initTestCase() {
            fakeHw.stateLoaded();
        }

        // Levels the helper (Python) says Game Mode can produce; regenerate if the model changes.
        readonly property var helperReachable: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 77, 78, 79, 80, 81, 82, 84, 85, 86, 87, 88, 90, 91, 92, 93, 95, 96, 97, 99, 100, 101, 103, 104, 105, 107, 108, 109, 111, 112, 114, 115, 117, 118, 119, 121, 122, 124, 125, 127, 128, 130, 131, 133, 135, 136, 138, 139, 141, 142, 144, 146, 147, 149, 151, 152, 154, 156, 157, 159, 161, 162, 164, 166, 168, 169, 171, 173, 175, 176, 178, 180, 182, 184, 186, 187, 189, 191, 193, 195, 197, 199, 201, 203, 205, 207, 209, 211, 213, 215, 217, 219, 221, 223, 225, 227, 255]

        function test_conversionMatchesHelper() {
            compare(JSON.stringify(C.reachable), JSON.stringify(helperReachable));
            for (let v = 0; v < 256; v++) {
                let best = helperReachable[0];
                for (const r of helperReachable)
                    if (Math.abs(r - v) < Math.abs(best - v)) best = r;
                compare(C.toGameMode(v), best, "level " + v);
            }
        }

        // Everything the editor shows or sets is a colour Game Mode can reproduce.
        function test_coloursSnapToGameMode() {
            // Loaded from the strip: candy cane's cream 255,240,230 is shown as Game Mode shows it
            compare(JSON.stringify(ed.cols[4]), JSON.stringify([255, 227, 227]));
            compare(ed.presetList[ed.presetIndex].name, "Candy cane", "still recognised as the preset");
            ed.selected = [0];
            ed.mode = "solid";
            ed.setPanel([255, 240, 240], "");
            compare(JSON.stringify(ed.current), JSON.stringify([255, 227, 227]), "picked colour snapped");
            // Arrow up from 227 jumps to the next reachable level instead of sticking
            const r = findChild(ed, "gSpin");
            ed.steppedChannel(1, 228, r);
            compare(ed.current[1], 255, "step up");
            ed.steppedChannel(1, 254, r);
            compare(ed.current[1], 227, "step down");
            compare(r.value, 227, "box shows the snapped value");
            // Gradients only produce reachable values
            ed.selected = [0, 1, 2, 3, 4, 5, 6, 7, 8];
            ed.mode = "gradient";
            ed.gradStart = [255, 255, 255];
            ed.gradEnd = [0, 0, 0];
            ed.applyGradient("");
            verify(ed.cols.every(c => c.every(v => C.toGameMode(v) === v)), "gradient snapped");
            ed.mode = "solid";
            ed.applyColours(Presets.builtins[1].cols);
            ed.selected = [];
        }

        function test_unsavedIndicator() {
            fakeHw.saved = { available: true, colours: ed.gmCols, effect: "manual", scale: 9, delay: 16, enabled: 1 };
            verify(!ed.unsaved, "matches what Steam has saved");
            fakeHw.saved = { available: true, colours: ed.gmCols, effect: "manual", scale: 9, delay: 3, enabled: 1 };
            verify(!ed.unsaved, "speed is ignored for Solid");
            fakeHw.saved = { available: true, colours: ed.gmCols, effect: "manual", scale: 12, delay: 16, enabled: 1 };
            verify(ed.unsaved, "brightness differs");
            fakeHw.saved = { available: false, reason: "no settings" };
            verify(!ed.unsaved && !ed.saveAvailable, "nothing to compare with");
        }

        // The popup grows away from the panel, so any height change while editing shifts the
        // picker under the mouse. The save area must keep the same height in every state.
        function test_heightStableWhileEditing() {
            ed.selected = [0, 1];
            fakeHw.saved = { available: true, colours: ed.gmCols, effect: "manual", scale: 9, delay: 16, enabled: 1 };
            wait(50);
            const h0 = ed.implicitHeight;
            fakeHw.saved = { available: true, colours: ed.gmCols, effect: "manual", scale: 12, delay: 16, enabled: 1 };
            wait(50);
            compare(ed.implicitHeight, h0, "unsaved");
            ed.setPanel([255, 230, 230], "picker");
            wait(50);
            compare(ed.implicitHeight, h0, "after an edit");
            fakeHw.saving = true;
            wait(50);
            compare(ed.implicitHeight, h0, "saving");
            fakeHw.saving = false;
            ed.saveResult = { ok: true, steamWasRunning: true };
            wait(50);
            compare(ed.implicitHeight, h0, "saved, Steam closed");
            ed.setPanel([255, 0, 0], "picker");
            verify(ed.saveResult !== null, "Reopen Steam survives an edit");
            ed.saveResult = null;
            ed.selected = [];
            wait(50);
            compare(ed.implicitHeight, h0, "nothing selected");
            ed.flash("copied");
            wait(50);
            compare(ed.implicitHeight, h0, "copied feedback");
        }

        function test_saveButtonFlow() {
            const refreshesBefore = fakeHw.steamChecks;
            ed.undoStack = [{ cols: ed.cols, effect: "manual", scale: 9, delay: 16 }];
            fakeHw.saved = { available: true, colours: ed.gmCols, effect: "manual", scale: 12, delay: 16, enabled: 1 };
            // Steam closed: no dialog, saves straight away
            fakeHw.steamRunning = false;
            fakeHw.lastSave = null;
            ed.requestSave();
            verify(fakeHw.lastSave !== null, "saved without asking");
            compare(fakeHw.steamChecks, refreshesBefore + 1, "asked the helper about Steam");
            compare(ed.undoStack.length, 1, "undo history kept");
            // Steam running: ask first, don't save yet
            fakeHw.steamRunning = true;
            fakeHw.lastSave = null;
            ed.requestSave();
            verify(fakeHw.lastSave === null, "not saved before confirming");
            const dlg = ed.data.find(d => d && d.title === "Save");
            verify(dlg && dlg.visible, "confirmation shown");
            dlg.close();
            wait(300);
        }

        function test_saveSendsDesign() {
            fakeHw.saved = { available: true, colours: ed.gmCols, effect: "manual", scale: 12, delay: 16, enabled: 1 };
            ed.startSave();
            compare(JSON.stringify(fakeHw.lastSave.colours), JSON.stringify(ed.cols));
            compare(fakeHw.lastSave.scale, 9);
            fakeHw.saveFinished({ ok: true, steamWasRunning: true });
            verify(ed.saveResult.ok);
        }
    }
}
