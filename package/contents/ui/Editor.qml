import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "colour.js" as C
import "share.js" as Share
import "presets.js" as Presets

// The strip editor. Positions (pos) are visual, left to right as seen from the front;
// colours (cols) are stored in hardware order, where index 0 is the rightmost LED.
ColumnLayout {
    id: ed

    required property var hw

    Layout.preferredWidth: Kirigami.Units.gridUnit * 32
    Layout.minimumWidth: Kirigami.Units.gridUnit * 30
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight
    // Also cap it, so the popup shrinks again when sections are hidden
    Layout.maximumHeight: implicitHeight
    spacing: Kirigami.Units.largeSpacing

    property var cols: []
    property string effect: "manual"
    property int scale: 9
    property int delay: 10

    property var selected: []
    property int anchor: -1

    property var undoStack: []
    property var redoStack: []
    property string lastMerge: ""
    property double lastMergeTime: 0

    // Colour panel: "solid" sets every selected LED; "gradient" fills them from start to end.
    property string mode: "solid"
    property var gradStart: [0, 0, 0]
    property var gradEnd: [0, 0, 0]
    property int gradTarget: 0          // 0 = editing start colour, 1 = end colour

    property string shareError: ""
    property string shareInfo: ""

    readonly property int n: cols.length
    readonly property var current: mode === "gradient" ? (gradTarget === 0 ? gradStart : gradEnd)
                                 : selected.length > 0 ? cols[hwIndex(selected[0])] : [0, 0, 0]
    readonly property bool coloursEditable: effect !== "rainbow" && selected.length > 0

    // ---- Game Mode ----
    // What Game Mode would actually show for the current colours (it can't reproduce every level)
    readonly property var gmCols: cols.map(c => c.map(C.toGameMode))
    readonly property int gmDiffCount: cols.filter(c => !C.same(c, c.map(C.toGameMode))).length
    readonly property bool saveAvailable: !!(hw.saved && hw.saved.available)
    readonly property bool unsaved: saveAvailable && n > 0 && !(
        sameCols(gmCols, hw.saved.colours) && effect === hw.saved.effect && scale === hw.saved.scale
        && (effect === "manual" || delay === hw.saved.delay) && hw.saved.enabled === 1)
    property bool confirmingSave: false
    property var saveResult: null        // last save's result, shown until the next edit or save

    readonly property var effects: [
        { text: "Solid", value: "manual" },
        { text: "Breathe", value: "breath" },
        { text: "Patrol", value: "patrol" },
        { text: "Rainbow", value: "rainbow" }
    ]

    function hwIndex(pos) {
        return n - 1 - pos;
    }

    // ---- loading / syncing ----

    function load() {
        cols = C.copy(hw.colours);
        effect = hw.effect;
        scale = hw.scale;
        delay = hw.delay;
        undoStack = [];
        redoStack = [];
        if (selected.length === 0 || selected.some(p => p >= n)) {
            selected = [];
            anchor = -1;
        }
        syncControls();
    }

    function sameCols(a, b) {
        return !!a && !!b && a.length === b.length && a.every((c, i) => C.same(c, b[i]));
    }

    function startSave() {
        commitEdits();
        confirmingSave = false;
        saveResult = null;
        hw.save({ colours: cols, effect: effect, enabled: 1, scale: scale, delay: delay });
    }

    Connections {
        target: ed.hw
        function onSaveFinished(result) {
            ed.saveResult = result;
        }
    }

    function syncControls() {
        effectBox.currentIndex = Math.max(0, effects.findIndex(e => e.value === effect));
        speedSlider.value = C.delayToSpeed(delay);
        brightSlider.value = C.scaleToBrightness(scale);
    }

    Connections {
        target: ed.hw
        function onStateLoaded() {
            ed.load();
        }
    }

    Component.onCompleted: {
        rebuildPresets();
        if (hw.loaded) {
            load();
        }
    }

    // ---- undo / redo ----

    function snapshot() {
        return { cols: C.copy(cols), effect: effect, scale: scale, delay: delay };
    }

    function restore(s) {
        cols = C.copy(s.cols);
        effect = s.effect;
        scale = s.scale;
        delay = s.delay;
        syncControls();
        hw.apply({ colours: cols, effect: effect, scale: scale, delay: delay });
    }

    // Call before changing anything. Consecutive changes with the same mergeKey
    // (e.g. one slider drag) become a single undo step.
    function record(mergeKey) {
        const now = Date.now();
        if (mergeKey && mergeKey === lastMerge && now - lastMergeTime < 1500) {
            lastMergeTime = now;
            return;
        }
        saveResult = null;
        undoStack = undoStack.concat([snapshot()]).slice(-200);
        redoStack = [];
        lastMerge = mergeKey || "";
        lastMergeTime = now;
    }

    function undo() {
        if (undoStack.length === 0) {
            return;
        }
        redoStack = redoStack.concat([snapshot()]);
        const s = undoStack[undoStack.length - 1];
        undoStack = undoStack.slice(0, -1);
        lastMerge = "";
        restore(s);
    }

    function redo() {
        if (redoStack.length === 0) {
            return;
        }
        undoStack = undoStack.concat([snapshot()]);
        const s = redoStack[redoStack.length - 1];
        redoStack = redoStack.slice(0, -1);
        lastMerge = "";
        restore(s);
    }

    // ---- selection ----

    function isSelected(pos) {
        return selected.indexOf(pos) >= 0;
    }

    function clickLed(pos, mods) {
        if ((mods & Qt.ShiftModifier) && anchor >= 0) {
            const range = [];
            for (let p = Math.min(anchor, pos); p <= Math.max(anchor, pos); p++) {
                range.push(p);
            }
            const base = (mods & Qt.ControlModifier) ? selected.filter(p => range.indexOf(p) < 0) : [];
            selected = base.concat(range).sort((a, b) => a - b);
        } else if (mods & Qt.ControlModifier) {
            selected = isSelected(pos) ? selected.filter(p => p !== pos)
                                       : selected.concat([pos]).sort((a, b) => a - b);
            anchor = pos;
        } else {
            selected = [pos];
            anchor = pos;
        }
    }

    function selectAll() {
        const all = [];
        for (let p = 0; p < n; p++) {
            all.push(p);
        }
        selected = all;
    }

    // ---- editing ----

    function setSelected(rgb, mergeKey) {
        if (!coloursEditable) {
            return;
        }
        record(mergeKey);
        const c = C.copy(cols);
        for (const p of selected) {
            c[hwIndex(p)] = [C.clamp(rgb[0]), C.clamp(rgb[1]), C.clamp(rgb[2])];
        }
        cols = c;
        hw.apply({ colours: cols });
    }

    // Typed-but-uncommitted hex/RGB values are only applied when the field loses focus.
    // Clicks on swatches and chips don't take focus, so call this first: it commits the
    // pending value to whatever the panel is editing *before* the click changes the target.
    function commitEdits() {
        ed.forceActiveFocus();
    }

    // Typing in a Red/Green/Blue box applies on every keystroke (no Enter or focus change needed).
    function typedChannel(channel, text) {
        const v = parseInt(text, 10);
        if (isNaN(v)) {
            return;                       // empty box while typing: wait for a number
        }
        const rgb = current.slice();
        rgb[channel] = C.clamp(v);
        if (rgb[channel] !== current[channel]) {
            setPanel(rgb, "type" + channel);
        }
    }

    // Colour from the picker / hex / RGB fields
    function setPanel(rgb, mergeKey) {
        if (mode === "gradient") {
            if (gradTarget === 0) {
                gradStart = rgb.slice();
            } else {
                gradEnd = rgb.slice();
            }
            applyGradient("grad" + gradTarget + mergeKey);
        } else {
            setSelected(rgb, mergeKey);
        }
    }

    function resetGradientEnds() {
        if (selected.length > 0) {
            gradStart = cols[hwIndex(selected[0])].slice();
            gradEnd = cols[hwIndex(selected[selected.length - 1])].slice();
        }
    }

    // Fills the selected LEDs (left to right), skipping unselected ones.
    function applyGradient(mergeKey) {
        if (!coloursEditable) {
            return;
        }
        record(mergeKey);
        const c = C.copy(cols);
        const m = selected.length;
        for (let k = 0; k < m; k++) {
            const t = m > 1 ? k / (m - 1) : 0;
            c[hwIndex(selected[k])] = [0, 1, 2].map(j => Math.round(gradStart[j] + (gradEnd[j] - gradStart[j]) * t));
        }
        cols = c;
        hw.apply({ colours: cols });
    }

    function swapGradient() {
        const a = gradStart;
        gradStart = gradEnd;
        gradEnd = a;
        applyGradient("");
    }

    onSelectedChanged: resetGradientEnds()
    onModeChanged: resetGradientEnds()

    // Replace all colours at once (presets, share codes)
    function applyColours(newCols) {
        record("");
        cols = C.copy(newCols);
        hw.apply({ colours: cols });
        resetGradientEnds();
    }

    // ---- presets ----

    function userPresets() {
        try {
            const list = JSON.parse(Plasmoid.configuration.userPresets);
            return Array.isArray(list) ? list : [];
        } catch (e) {
            return [];
        }
    }

    // Combined list: built-ins first, then the user's saved presets (stored as share codes).
    property var presetList: []
    function rebuildPresets() {
        const list = Presets.builtins.map(p => ({ name: p.name, cols: p.cols, user: false }));
        for (const u of userPresets()) {
            const d = Share.decode(u.code);
            if (d.cols) {
                list.push({ name: u.name, cols: d.cols, user: true });
            }
        }
        presetList = list;
    }

    Connections {
        target: Plasmoid.configuration
        function onUserPresetsChanged() {
            ed.rebuildPresets();
        }
    }

    readonly property int presetIndex: {
        const code = n > 0 ? Share.encode(cols) : "";
        // Prefer a user preset with the same colours (so it can be deleted), else a built-in.
        let found = -1;
        for (let i = 0; i < presetList.length; i++) {
            if (Share.encode(presetList[i].cols) === code && (found < 0 || presetList[i].user)) {
                found = i;
            }
        }
        return found;
    }

    function savePreset(name) {
        name = name.trim();
        if (name === "") {
            return;
        }
        const list = userPresets().filter(u => u.name !== name);
        list.push({ name: name, code: Share.encode(cols) });
        Plasmoid.configuration.userPresets = JSON.stringify(list);
    }

    function deletePreset(name) {
        Plasmoid.configuration.userPresets = JSON.stringify(userPresets().filter(u => u.name !== name));
    }

    // ---- share codes (clipboard via a hidden text field) ----

    TextEdit {
        id: clip
        visible: false
    }

    function copyCode() {
        clip.text = Share.encode(cols);
        clip.selectAll();
        clip.copy();
        shareError = "";
        shareInfo = "Copied: " + clip.text;
    }

    function pasteCode() {
        clip.text = "";
        clip.paste();
        const d = Share.decode(clip.text);
        if (d.error) {
            shareError = d.error;
            shareInfo = "";
            return;
        }
        shareError = "";
        shareInfo = "Pasted colours from share code.";
        applyColours(d.cols);
    }

    onCurrentChanged: {
        if (!hexField.activeFocus) {
            hexField.text = C.toHex(current);
        }
        rSpin.value = current[0];
        gSpin.value = current[1];
        bSpin.value = current[2];
        if (!picker.dragging) {
            picker.setFromRgb(current);
        }
    }

    Shortcut {
        sequences: [StandardKey.Undo]
        onActivated: ed.undo()
    }
    Shortcut {
        sequences: [StandardKey.Redo]
        onActivated: ed.redo()
    }
    Shortcut {
        sequences: [StandardKey.SelectAll]
        onActivated: ed.selectAll()
    }

    // ================= UI =================

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        type: Kirigami.MessageType.Error
        text: ed.hw.error
        visible: ed.hw.error !== ""
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        type: Kirigami.MessageType.Warning
        text: "The LED files aren't writable by your user, so changes can't be applied."
        visible: ed.hw.loaded && ed.hw.available && !ed.hw.writable
    }

    // ---- header: title + undo/redo ----
    RowLayout {
        Layout.fillWidth: true
        Kirigami.Heading {
            Layout.fillWidth: true
            level: 3
            text: "Front LED strip"
        }
        PlasmaComponents3.ToolButton {
            icon.name: "edit-undo"
            enabled: ed.undoStack.length > 0
            onClicked: { ed.commitEdits(); ed.undo(); }
            PlasmaComponents3.ToolTip.text: "Undo"
            PlasmaComponents3.ToolTip.visible: hovered
        }
        PlasmaComponents3.ToolButton {
            icon.name: "edit-redo"
            enabled: ed.redoStack.length > 0
            onClicked: { ed.commitEdits(); ed.redo(); }
            PlasmaComponents3.ToolTip.text: "Redo"
            PlasmaComponents3.ToolTip.visible: hovered
        }
    }

    // ---- swatches ----
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: 3
            Repeater {
                model: ed.n
                delegate: ColumnLayout {
                    id: cell
                    required property int index
                    readonly property bool sel: ed.isSelected(index)
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 2

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2.2
                        radius: 3
                        color: C.toQt(ed.cols[ed.hwIndex(cell.index)] || [0, 0, 0])
                        opacity: ed.effect === "rainbow" ? 0.4 : 1
                        border.width: cell.sel ? 2 : 1
                        border.color: cell.sel ? Kirigami.Theme.highlightColor
                                               : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                                         Kirigami.Theme.textColor.b, 0.3)
                        MouseArea {
                            anchors.fill: parent
                            onClicked: mouse => { ed.commitEdits(); ed.clickLed(cell.index, mouse.modifiers); }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 3
                        radius: 1
                        color: cell.sel ? Kirigami.Theme.highlightColor : "transparent"
                    }
                }
            }
        }

        Preview {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.2
            cols: ed.cols
            scale: ed.scale
            rainbow: ed.effect === "rainbow"
        }

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: ed.selected.length === 0 ? "Click an LED to edit its colour. Shift-click selects a range, Ctrl-click adds or removes."
                                               : ed.selected.length + " of " + ed.n + " selected"
                opacity: 0.7
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
            }
            PlasmaComponents3.ToolButton {
                text: "All"
                onClicked: { ed.commitEdits(); ed.selectAll(); }
            }
            PlasmaComponents3.ToolButton {
                text: "None"
                enabled: ed.selected.length > 0
                onClicked: { ed.commitEdits(); ed.selected = []; }
            }
        }
    }

    // ---- colours dropdown, saving, share codes ----
    RowLayout {
        Layout.fillWidth: true

        PlasmaComponents3.Label { text: "Colours" }
        PlasmaComponents3.ComboBox {
            id: presetBox
            Layout.fillWidth: true
            model: ed.presetList.map(p => p.user ? p.name + "  (mine)" : p.name)
            currentIndex: ed.presetIndex
            displayText: ed.presetIndex >= 0 ? ed.presetList[ed.presetIndex].name : "Custom"
            onActivated: index => ed.applyColours(ed.presetList[index].cols)
        }
        PlasmaComponents3.ToolButton {
            icon.name: "document-save"
            onClicked: {
                saveRow.visible = true;
                nameField.text = ed.presetIndex >= 0 && ed.presetList[ed.presetIndex].user ? ed.presetList[ed.presetIndex].name : "";
                nameField.forceActiveFocus();
            }
            PlasmaComponents3.ToolTip.text: "Save these colours as a preset"
            PlasmaComponents3.ToolTip.visible: hovered
        }
        PlasmaComponents3.ToolButton {
            icon.name: "edit-delete"
            visible: ed.presetIndex >= 0 && ed.presetList[ed.presetIndex].user
            onClicked: ed.deletePreset(ed.presetList[ed.presetIndex].name)
            PlasmaComponents3.ToolTip.text: "Delete this saved preset"
            PlasmaComponents3.ToolTip.visible: hovered
        }
        PlasmaComponents3.ToolButton {
            icon.name: "edit-copy"
            text: "Copy code"
            enabled: ed.n > 0
            onClicked: ed.copyCode()
            PlasmaComponents3.ToolTip.text: "Copy a share code for these colours"
            PlasmaComponents3.ToolTip.visible: hovered
        }
        PlasmaComponents3.ToolButton {
            icon.name: "edit-paste"
            text: "Paste code"
            enabled: ed.n > 0
            onClicked: ed.pasteCode()
            PlasmaComponents3.ToolTip.text: "Apply colours from a share code on the clipboard"
            PlasmaComponents3.ToolTip.visible: hovered
        }
    }

    RowLayout {
        id: saveRow
        Layout.fillWidth: true
        visible: false
        PlasmaComponents3.TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "Preset name"
            onAccepted: saveButton.clicked()
        }
        PlasmaComponents3.Button {
            id: saveButton
            text: "Save"
            enabled: nameField.text.trim() !== ""
            onClicked: {
                ed.savePreset(nameField.text);
                saveRow.visible = false;
            }
        }
        PlasmaComponents3.Button {
            text: "Cancel"
            onClicked: saveRow.visible = false
        }
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        type: Kirigami.MessageType.Error
        text: ed.shareError
        visible: ed.shareError !== ""
        showCloseButton: true
        onVisibleChanged: if (!visible) ed.shareError = ""
    }
    PlasmaComponents3.Label {
        Layout.fillWidth: true
        visible: ed.shareInfo !== ""
        text: ed.shareInfo
        elide: Text.ElideRight
        opacity: 0.7
        font: Kirigami.Theme.smallFont
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    // ---- colour panel mode ----
    RowLayout {
        Layout.fillWidth: true
        enabled: ed.coloursEditable
        visible: ed.selected.length > 0

        PlasmaComponents3.ToolButton {
            text: "Solid"
            checkable: true
            checked: ed.mode === "solid"
            onClicked: { ed.commitEdits(); ed.mode = "solid"; }
        }
        PlasmaComponents3.ToolButton {
            text: "Gradient"
            checkable: true
            checked: ed.mode === "gradient"
            onClicked: { ed.commitEdits(); ed.mode = "gradient"; }
        }

        Item { Layout.fillWidth: true }

        // Gradient end colours: click one to edit it with the picker
        Repeater {
            model: ed.mode === "gradient" ? 2 : 0
            delegate: RowLayout {
                id: chip
                required property int index
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents3.Label { text: chip.index === 0 ? "Start" : "End" }
                Rectangle {
                    objectName: "chip" + chip.index
                    implicitWidth: Kirigami.Units.gridUnit * 2
                    implicitHeight: Kirigami.Units.gridUnit * 1.3
                    radius: 3
                    color: C.toQt(chip.index === 0 ? ed.gradStart : ed.gradEnd)
                    border.width: ed.gradTarget === chip.index ? 2 : 1
                    border.color: ed.gradTarget === chip.index ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { ed.commitEdits(); ed.gradTarget = chip.index; }
                    }
                }
            }
        }
        PlasmaComponents3.ToolButton {
            visible: ed.mode === "gradient"
            icon.name: "exchange-positions"
            onClicked: { ed.commitEdits(); ed.swapGradient(); }
            PlasmaComponents3.ToolTip.text: "Swap start and end"
            PlasmaComponents3.ToolTip.visible: hovered
        }
    }

    // ---- colour panel ----
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing
        enabled: ed.coloursEditable
        visible: ed.selected.length > 0

        ColourPicker {
            id: picker
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            Layout.preferredHeight: Kirigami.Units.gridUnit * 9
            onPicked: rgb => ed.setPanel(rgb, "picker")
        }

        GridLayout {
            Layout.alignment: Qt.AlignTop
            columns: 2
            columnSpacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label { text: "Hex" }
            PlasmaComponents3.TextField {
                id: hexField
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                font.family: "monospace"
                validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{0,6}/ }
                // Apply as soon as six hex digits are typed
                onTextEdited: {
                    const rgb = C.fromHex(text);
                    if (rgb && !C.same(rgb, ed.current)) {
                        ed.setPanel(rgb, "hex");
                    }
                }
                onEditingFinished: {
                    const rgb = C.fromHex(text);
                    if (rgb) {
                        ed.setPanel(rgb, "");
                    }
                    text = C.toHex(ed.current);
                }
            }

            PlasmaComponents3.Label { text: "Red" }
            PlasmaComponents3.SpinBox {
                id: rSpin
                objectName: "rSpin"
                from: 0; to: 255; editable: true
                Connections {
                    target: rSpin.contentItem
                    function onTextEdited() {
                        ed.typedChannel(0, rSpin.contentItem.text);
                    }
                }
                onValueModified: ed.setPanel([value, ed.current[1], ed.current[2]], "r")
            }
            PlasmaComponents3.Label { text: "Green" }
            PlasmaComponents3.SpinBox {
                id: gSpin
                objectName: "gSpin"
                from: 0; to: 255; editable: true
                Connections {
                    target: gSpin.contentItem
                    function onTextEdited() {
                        ed.typedChannel(1, gSpin.contentItem.text);
                    }
                }
                onValueModified: ed.setPanel([ed.current[0], value, ed.current[2]], "g")
            }
            PlasmaComponents3.Label { text: "Blue" }
            PlasmaComponents3.SpinBox {
                id: bSpin
                objectName: "bSpin"
                from: 0; to: 255; editable: true
                Connections {
                    target: bSpin.contentItem
                    function onTextEdited() {
                        ed.typedChannel(2, bSpin.contentItem.text);
                    }
                }
                onValueModified: ed.setPanel([ed.current[0], ed.current[1], value], "b")
            }
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    // ---- effect / speed / brightness ----
    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: Kirigami.Units.largeSpacing

        PlasmaComponents3.Label { text: "Effect" }
        PlasmaComponents3.ComboBox {
            id: effectBox
            Layout.columnSpan: 2
            model: ed.effects
            textRole: "text"
            onActivated: index => {
                const v = ed.effects[index].value;
                if (v !== ed.effect) {
                    ed.record("");
                    ed.effect = v;
                    ed.hw.apply({ effect: v });
                }
            }
        }

        PlasmaComponents3.Label {
            text: "Speed"
            enabled: ed.effect !== "manual"
        }
        PlasmaComponents3.Slider {
            id: speedSlider
            Layout.fillWidth: true
            enabled: ed.effect !== "manual"
            from: 0; to: 1; stepSize: 0.05
            onMoved: {
                ed.record("speed");
                ed.delay = C.speedToDelay(value);
                ed.hw.apply({ delay: ed.delay });
            }
        }
        PlasmaComponents3.Label {
            text: Math.round(speedSlider.value * 100) + "%"
            enabled: ed.effect !== "manual"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5
        }

        PlasmaComponents3.Label { text: "Brightness" }
        PlasmaComponents3.Slider {
            id: brightSlider
            Layout.fillWidth: true
            from: 0; to: 1; stepSize: 0.01
            onMoved: {
                ed.record("bright");
                ed.scale = C.brightnessToScale(value);
                ed.hw.apply({ scale: ed.scale });
            }
        }
        PlasmaComponents3.Label {
            text: Math.round(brightSlider.value * 100) + "%"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5
        }

        Item { width: 1; height: 1 }
        PlasmaComponents3.Label {
            Layout.columnSpan: 2
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            text: ed.scale <= 2 ? "The strip is off at this brightness."
                                : C.levelsForScale(ed.scale) + " colour levels per channel at this brightness"
                                  + (C.levelsForScale(ed.scale) < 32 ? ": gradients will look stepped." : ".")
        }
    }

    Kirigami.Separator {
        Layout.fillWidth: true
    }

    // ================= Save for Game Mode =================
    RowLayout {
        Layout.fillWidth: true

        Kirigami.Icon {
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
            source: !ed.saveAvailable ? "dialog-information" : ed.unsaved ? "emblem-warning" : "emblem-ok-symbolic"
        }
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: !ed.hw.saved ? "Checking Game Mode settings…"
                : !ed.saveAvailable ? ed.hw.saved.reason
                : ed.unsaved ? "<b>Unsaved.</b> Steam will put back its saved design the next time it starts (including at login)."
                : "Game Mode uses this design."
        }
        PlasmaComponents3.Button {
            text: "Save for Game Mode…"
            icon.name: "document-save"
            visible: ed.saveAvailable
            enabled: !ed.hw.saving && !ed.confirmingSave
            onClicked: {
                ed.commitEdits();
                ed.saveResult = null;
                ed.confirmingSave = true;
                ed.hw.refresh();          // up-to-date "is Steam running?"
            }
        }
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        type: Kirigami.MessageType.Warning
        visible: ed.unsaved && ed.gmDiffCount > 0 && ed.effect !== "rainbow"
        text: (ed.gmDiffCount === 1 ? "1 LED uses a colour" : ed.gmDiffCount + " LEDs use colours")
              + " Game Mode can't show exactly (usually very light tints). Saving uses the nearest colour it can show."
        actions: [
            Kirigami.Action {
                text: "Preview Game Mode colours"
                icon.name: "view-preview"
                onTriggered: ed.applyColours(ed.gmCols)
            }
        ]
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        type: Kirigami.MessageType.Information
        visible: ed.confirmingSave && !ed.hw.saving
        text: ed.hw.steamRunning
              ? "Steam has to close while saving, because it overwrites its settings when it exits. "
                + "Saving will close Steam now (close any game first), save the design, and then you can reopen Steam."
              : "Steam is closed, so the design will be saved straight away."
        actions: [
            Kirigami.Action {
                text: ed.hw.steamRunning ? "Close Steam and save" : "Save"
                icon.name: "document-save"
                onTriggered: ed.startSave()
            },
            Kirigami.Action {
                text: "Cancel"
                icon.name: "dialog-cancel"
                onTriggered: ed.confirmingSave = false
            }
        ]
    }

    RowLayout {
        visible: ed.hw.saving
        PlasmaComponents3.BusyIndicator {
            implicitWidth: Kirigami.Units.iconSizes.medium
            implicitHeight: Kirigami.Units.iconSizes.medium
            running: ed.hw.saving
        }
        PlasmaComponents3.Label {
            text: ed.hw.steamRunning ? "Waiting for Steam to close, then saving…" : "Saving…"
        }
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: ed.saveResult !== null
        type: ed.saveResult && ed.saveResult.ok ? Kirigami.MessageType.Positive : Kirigami.MessageType.Error
        showCloseButton: true
        onVisibleChanged: if (!visible) ed.saveResult = null
        text: !ed.saveResult ? ""
              : !ed.saveResult.ok ? ed.saveResult.error
              : ed.saveResult.steamWasRunning ? "Saved. Steam is closed: reopen it when you're ready."
              : "Saved. Game Mode will use this design."
        actions: [
            Kirigami.Action {
                text: "Reopen Steam"
                icon.name: "steam"
                visible: !!(ed.saveResult && ed.saveResult.ok && ed.saveResult.steamWasRunning)
                // Opens Steam through its normal desktop launcher, like the app menu does
                onTriggered: Qt.openUrlExternally("steam://open/main")
            }
        ]
    }
}
