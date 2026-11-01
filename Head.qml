import QtQuick
import QtQuick.Layouts
RowLayout {
    id: r
    property string t: ""
    property string v: ""
    Layout.fillWidth: true
    Text { text: r.t; color: Theme.fg; opacity: 0.85; font { family: Theme.mono; pixelSize: 11; letterSpacing: 1 } }
    Item { Layout.fillWidth: true }
    Text { text: r.v; color: Theme.fg; elide: Text.ElideLeft; Layout.maximumWidth: 150; font { family: Theme.mono; pixelSize: 11 } }
}
