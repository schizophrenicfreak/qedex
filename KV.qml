import QtQuick
import QtQuick.Layouts
RowLayout {
    id: r
    property string k: ""
    property string v: ""
    Layout.fillWidth: true
    Text { text: r.k; color: Theme.fg; opacity: 0.6; font { family: Theme.mono; pixelSize: 10 } }
    Item { Layout.fillWidth: true }
    Text { text: r.v; color: Theme.fg; elide: Text.ElideLeft; Layout.maximumWidth: 150; font { family: Theme.mono; pixelSize: 10 } }
}
