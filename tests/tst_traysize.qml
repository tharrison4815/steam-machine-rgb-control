// SPDX-FileCopyrightText: 2026 Tom Harrison
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Layouts
import QtTest
import org.kde.kirigami as Kirigami
import "../package/contents/ui"
import "../package/contents/ui/presets.js" as Presets

// The system tray shows every widget in a fixed 24 x 24 grid-unit popup, title bar included.
// The editor must fit in what's left without scrolling or clipping.
Item {
    id: root
    // Space the tray leaves for the widget (measured on Plasma 6.7: about 424 x 384 px at 18 px/gu)
    readonly property real trayW: Kirigami.Units.gridUnit * 23.5
    readonly property real trayH: Kirigami.Units.gridUnit * 21.3
    width: trayW; height: trayH

    Rectangle { anchors.fill: parent; color: Kirigami.Theme.backgroundColor }

    QtObject {
        id: fakeHw
        property bool loaded: true
        property bool available: true
        property bool writable: true
        property string error: ""
        property var colours: Presets.builtins[2].cols       // synthwave
        property string effect: "manual"
        property int scale: 255
        property int delay: 6
        property var saved: ({ available: true, colours: Presets.builtins[2].cols, effect: "manual",
                               scale: 255, delay: 6, enabled: 1 })
        property bool steamRunning: true
        property bool saving: false
        signal stateLoaded()
        signal saveFinished(var result)
        signal steamChecked()
        function checkSteam() { steamChecked(); }
        function apply(c) {}
        function refresh() {}
        function save(d) {}
    }

    Editor { id: ed; hw: fakeHw; anchors.fill: parent }

    TestCase {
        name: "TraySize"
        when: windowShown

        function initTestCase() {
            fakeHw.stateLoaded();
        }

        function test_fits() {
            verify(ed.implicitHeight <= root.trayH, "height " + ed.implicitHeight + " > " + root.trayH);
            verify(ed.Layout.minimumWidth <= root.trayW, "min width");
            ed.selected = [0];
            ed.mode = "gradient";
            ed.selected = [0, 1, 2, 3, 4, 5, 6, 7];
            waitForRendering(ed);
            verify(ed.implicitHeight <= root.trayH, "gradient height " + ed.implicitHeight);
            // Every control sits inside the popup
            for (const name of ["rSpin", "gSpin", "bSpin", "chip1"]) {
                const c = findChild(ed, name);
                const p = c.mapToItem(root, c.width, c.height);
                verify(p.x <= root.trayW + 0.5 && p.y <= root.trayH + 0.5, name + " clipped at " + p.x + "," + p.y);
            }
        }
    }
}
