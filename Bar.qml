import QtQuick
import QtQuick.Layouts
Rectangle {
    id: b
    property real frac: 0
    Layout.fillWidth: true
    Layout.preferredHeight: 6
    color: Theme.track
    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: b.width * Math.max(0, Math.min(1, b.frac))
        color: Theme.fg
        Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    }
}
