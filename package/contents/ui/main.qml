// SPDX-FileCopyrightText: 2026 Tom Harrison
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    // In the system tray, Active keeps the icon visible instead of tucked into the "^" overflow.
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
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
