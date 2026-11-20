import QtQuick
import QtTest
import "../package/contents/ui"

Item {
    width: 700; height: 700

    QtObject {
        id: fakeHw
        property bool loaded: true
        property bool available: true
        property bool writable: true
        property string error: ""
        property var colours: Array.from({length: 17}, (_, i) => [i * 10, 50, 100])
        property string effect: "manual"
        property int scale: 255
        property int delay: 10
        signal stateLoaded()
        function apply(c) {}
    }

    Editor { id: ed; hw: fakeHw; anchors.fill: parent }

    TestCase {
        name: "Gradient"
        when: windowShown
        function test_typeThenSwitchChip() {
            ed.selected = [0, 1, 2, 3, 4];
            ed.mode = "gradient";
            wait(50);
            const r = findChild(ed, "rSpin"), c0 = findChild(ed, "chip0"), c1 = findChild(ed, "chip1");
            verify(r && c0 && c1, "found controls");
            console.warn("start before", JSON.stringify(ed.gradStart), "end", JSON.stringify(ed.gradEnd));
            mouseClick(c0);
            mouseClick(r.contentItem);
            r.contentItem.selectAll();
            keyClick(Qt.Key_2); keyClick(Qt.Key_0); keyClick(Qt.Key_0);
            console.warn("after typing: text", r.contentItem.text, "value", r.value, "gradStart", JSON.stringify(ed.gradStart), "focus", r.contentItem.activeFocus);
            mouseClick(c1);
            console.warn("after clicking End: gradStart", JSON.stringify(ed.gradStart), "gradEnd", JSON.stringify(ed.gradEnd), "target", ed.gradTarget, "spin text", r.contentItem.text);
            mouseClick(c0);
            console.warn("after clicking Start: spin value", r.value, "text", r.contentItem.text);
            compare(ed.gradStart[0], 200);
        }
    }
}
