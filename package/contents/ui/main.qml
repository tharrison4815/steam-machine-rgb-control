// SPDX-FileCopyrightText: 2026 Tom Harrison
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    Plasmoid.icon: "color-management"
    toolTipMainText: "Steam Machine RGB Control"
    toolTipSubText: hardware.error !== "" ? hardware.error : "Click to edit the front LED strip"

    Hardware {
        id: hardware
    }

    fullRepresentation: Editor {
        hw: hardware
    }

    // Re-read the strip each time the editor opens: Steam or another tool may have changed it.
    onExpandedChanged: {
        if (root.expanded) {
            hardware.refresh();
        }
    }

    Component.onCompleted: hardware.refresh()
}
