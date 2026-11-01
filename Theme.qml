pragma Singleton
import Quickshell
import QtQuick
Singleton {
    readonly property color bg: "#05080d"
    readonly property color fg: "#aacfd1"
    readonly property color line:     Qt.rgba(fg.r, fg.g, fg.b, 0.30)
    readonly property color sep:      Qt.rgba(fg.r, fg.g, fg.b, 0.22)
    readonly property color track:    Qt.rgba(fg.r, fg.g, fg.b, 0.15)
    readonly property color graphBg:  Qt.rgba(fg.r, fg.g, fg.b, 0.05)
    readonly property color keyLine:  Qt.rgba(fg.r, fg.g, fg.b, 0.20)
    readonly property color keyOff:   Qt.rgba(fg.r, fg.g, fg.b, 0.00)
    readonly property string mono: Config.font
}
