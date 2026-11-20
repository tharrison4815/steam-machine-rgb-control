// SPDX-FileCopyrightText: 2026 Tom Harrison
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "colour.js" as C

// Inline HSV picker (a dialog would close the Plasma popup). Saturation/value square + hue bar.
RowLayout {
    id: picker

    property real hue: 0
    property real sat: 1
    property real val: 1
    readonly property bool dragging: svArea.pressed || hueArea.pressed

    signal picked(var rgb)

    spacing: Kirigami.Units.smallSpacing

    function setFromRgb(rgb) {
        const c = C.toQt(rgb);
        if (c.hsvHue >= 0) {     // greys have no hue: keep the last one
            hue = c.hsvHue;
        }
        if (c.hsvValue > 0) {    // black has no saturation: keep the last one
            sat = c.hsvSaturation;
        }
        val = c.hsvValue;
    }

    function pickNow() {
        picked(C.fromQt(Qt.hsva(hue, sat, val, 1)));
    }

    Rectangle {
        id: sv
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 3
        color: Qt.hsva(picker.hue, 1, 1, 1)

        Rectangle {
            anchors.fill: parent
            radius: 3
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "white" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: 3
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: "black" }
            }
        }
        Rectangle {
            width: 12; height: 12; radius: 6
            x: picker.sat * sv.width - width / 2
            y: (1 - picker.val) * sv.height - height / 2
            color: "transparent"
            border.width: 2
            border.color: picker.val > 0.5 ? "black" : "white"
        }
        MouseArea {
            id: svArea
            anchors.fill: parent
            function track(mouse) {
                picker.sat = Math.max(0, Math.min(1, mouse.x / width));
                picker.val = Math.max(0, Math.min(1, 1 - mouse.y / height));
                picker.pickNow();
            }
            onPressed: mouse => { picker.forceActiveFocus(); track(mouse); }
            onPositionChanged: mouse => track(mouse)
        }
    }

    Rectangle {
        id: hueBar
        Layout.preferredWidth: Kirigami.Units.gridUnit
        Layout.fillHeight: true
        radius: 3
        gradient: Gradient {
            GradientStop { position: 0 / 6; color: "#ff0000" }
            GradientStop { position: 1 / 6; color: "#ffff00" }
            GradientStop { position: 2 / 6; color: "#00ff00" }
            GradientStop { position: 3 / 6; color: "#00ffff" }
            GradientStop { position: 4 / 6; color: "#0000ff" }
            GradientStop { position: 5 / 6; color: "#ff00ff" }
            GradientStop { position: 6 / 6; color: "#ff0000" }
        }
        Rectangle {
            width: parent.width + 4; height: 4; x: -2
            y: picker.hue * hueBar.height - 2
            color: "white"
            border.color: "black"
        }
        MouseArea {
            id: hueArea
            anchors.fill: parent
            function track(mouse) {
                picker.hue = Math.max(0, Math.min(0.999, mouse.y / height));
                picker.pickNow();
            }
            onPressed: mouse => { picker.forceActiveFocus(); track(mouse); }
            onPositionChanged: mouse => track(mouse)
        }
    }
}
