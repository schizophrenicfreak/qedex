//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property bool soundOn: true
    property string lastBatS: ""
    property bool lowWarned: false
    function play(name) {
        if (!soundOn) return
        Quickshell.execDetached(["sh", "-c", "f=/usr/share/sounds/freedesktop/stereo/" + name + ".oga; pw-play \"$f\" 2>/dev/null || paplay \"$f\" 2>/dev/null"])
    }
    Component.onCompleted: play("service-login")
    onStChanged: {
        var s = st.bat_s
        if (lastBatS !== "" && s !== lastBatS) {
            if (s === "DISCHARGING") play("power-unplug")
            else if (lastBatS === "DISCHARGING") play("power-plug")
        }
        lastBatS = s
        if (st.bat >= 0 && st.bat <= 15 && s === "DISCHARGING") {
            if (!lowWarned) { lowWarned = true; play("dialog-warning") }
        } else if (st.bat > 20 || s !== "DISCHARGING") lowWarned = false
    }
    property string query: ""
    property var pressed: ({})
    readonly property var stDefaults: ({ cpu: 0, memu: 0, memt: 1, uptime: "-", host: "-", procs: "", down: 0, up: 0, bat: -1, bat_s: "-",
        cpu_t: 0, gpu_u: 0, gpu_t: 0, gpu_mu: 0, gpu_mt: 1, gpu_mperc: 0, gpu_p: 0 })
    property var st: stDefaults
    property var plane: ({ call: "...", type: "-", reg: "-", alt: "-", spd: "-", hdg: "-", dist: "-", brg: "-", when: "..." })
    property var iss: ({ lat: "-", lon: "-", alt: "-", vel: "-", over: "-", dist: "-", view: "-", vis: "-", map: "", state: "..." })
    property var cpuH: []
    property var gpuH: []
    property var downH: []
    property var upH: []
    function push(a, v) { var b = a.slice(-59); b.push(Number(v) || 0); return b }

    readonly property var rows: [
        ["ESC","1","2","3","4","5","6","7","8","9","0","-","=","BACK"],
        ["TAB","Q","W","E","R","T","Y","U","I","O","P","[","]","ENTER"],
        ["CAPS","A","S","D","F","G","H","J","K","L",";"],
        ["SHIFT","Z","X","C","V","B","N","M",",",".","/","SHIFT"],
        ["CTRL","FN","SPACE","ALT GR","CTRL"]
    ]
    readonly property var dirs: ["Documents","Downloads","Pictures","Music","Videos",".config","Desktop","Projects"]

    SystemClock { id: clock; precision: SystemClock.Seconds }
    SystemClock { id: dayClock; precision: SystemClock.Hours }

    Process {
        command: ["python3", root.home + "/.config/quickshell/edex/stats.py"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    var d = Object.assign({}, root.stDefaults, JSON.parse(data))
                    root.st = d
                    root.cpuH = root.push(root.cpuH, d.cpu)
                    root.gpuH = root.push(root.gpuH, d.gpu_u)
                    root.downH = root.push(root.downH, d.down)
                    root.upH = root.push(root.upH, d.up)
                } catch (e) {}
            }
        }
    }
    Process {
        command: ["python3", root.home + "/.config/eww/scripts/keys.py"]
        running: true
        stdout: SplitParser { onRead: data => { try { root.pressed = JSON.parse(data) } catch (e) {} } }
    }
    Process {
        id: planeProc
        command: [root.home + "/.config/eww/scripts/plane.sh"]
        stdout: StdioCollector { onStreamFinished: { try { root.plane = JSON.parse(text) } catch (e) {} } }
    }
    Timer { interval: 20000; running: true; repeat: true; triggeredOnStart: true; onTriggered: planeProc.running = true }
    Process {
        id: issProc
        command: [root.home + "/.config/eww/scripts/iss.py"]
        stdout: StdioCollector { onStreamFinished: { try { root.iss = JSON.parse(text) } catch (e) {} } }
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: issProc.running = true }

    IpcHandler {
        target: "launcher"
        function focus(): void { leftWin.searching = true; search.forceActiveFocus() }
    }

    ScriptModel {
        id: appModel
        values: {
            var q = root.query.toLowerCase()
            return [...DesktopEntries.applications.values]
                .filter(a => !a.noDisplay && a.name.toLowerCase().includes(q))
                .sort((a, b) => (b.name.toLowerCase().startsWith(q) - a.name.toLowerCase().startsWith(q)) || a.name.localeCompare(b.name))
        }
    }

    // ---------------- LEFT ----------------
    PanelWindow {
        id: leftWin
        property bool searching: false
        anchors { top: true; bottom: true; left: true }
        implicitWidth: 250
        exclusiveZone: 250
        color: Theme.bg
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "edex-left"
        WlrLayershell.keyboardFocus: searching ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

        Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: 1; color: Theme.line }

        ColumnLayout {
            anchors { fill: parent; margins: 12 }
            NumberAnimation on opacity { from: 0; to: 1; duration: 500; easing.type: Easing.OutCubic }
            spacing: 8

            Text { text: Qt.formatDateTime(clock.date, "HH : mm : ss"); color: Theme.fg; font { family: Theme.mono; pixelSize: 26; letterSpacing: 1 } }
            Sep {}
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                KV { k: "DATE"; v: Qt.formatDate(clock.date, "ddd dd MMM yyyy") }
                KV { k: "UPTIME"; v: root.st.uptime }
                KV { k: "HOST"; v: root.st.host }
            }
            Sep {}
            Head { t: "CPU USAGE"; v: Math.round(root.st.cpu) + "%  " + root.st.cpu_t + "°C" }
            Graph { samples: root.cpuH; maxv: 100; Layout.preferredHeight: 60 }
            Sep {}
            Head { t: "MEMORY"; v: (root.st.memu / 1073741824).toFixed(1) + " / " + (root.st.memt / 1073741824).toFixed(1) + " GiB" }
            Bar { frac: root.st.memu / root.st.memt }
            Sep {}
            Head { t: "BATTERY"; v: root.st.bat < 0 ? "N/A" : root.st.bat + "%  " + root.st.bat_s }
            Bar { frac: Math.max(root.st.bat, 0) / 100 }
            Sep {}
            Head { t: "GPU"; v: root.st.gpu_u + "%  " + root.st.gpu_t + "°C" }
            Graph { samples: root.gpuH; maxv: 100 }
            Bar { frac: root.st.gpu_mperc / 100 }
            KV { k: "VRAM"; v: root.st.gpu_mu + " / " + root.st.gpu_mt + " MiB" }
            KV { k: "POWER"; v: root.st.gpu_p + " W" }
            Sep {}
            Head { t: "TOP PROCESSES" }
            Text {
                Layout.fillWidth: true
                text: root.st.procs
                color: Theme.fg
                clip: true
                maximumLineCount: 6
                font { family: Theme.mono; pixelSize: 10 }
            }
            Sep {}
            Head { t: "APPLICATIONS" }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                color: "transparent"
                border { width: 1; color: search.activeFocus ? Theme.fg : Theme.line }
                TextInput {
                    id: search
                    anchors { fill: parent; margins: 5 }
                    color: Theme.fg
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    font { family: Theme.mono; pixelSize: 11 }
                    onTextChanged: root.query = text
                    onActiveFocusChanged: if (!activeFocus) leftWin.searching = false
                    Keys.onReturnPressed: {
                        if (appModel.values.length > 0) { appModel.values[0].execute() }
                        text = ""; leftWin.searching = false; focus = false
                    }
                    Keys.onEscapePressed: { text = ""; leftWin.searching = false; focus = false }
                }
            }
            ListView {
                id: lv
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: appModel
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: lv.width
                    height: 24
                    color: rma.containsMouse ? Theme.fg : "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                        spacing: 8
                        IconImage {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            implicitSize: 18
                            source: Quickshell.iconPath(row.modelData.icon || "application-x-executable")
                        }
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            elide: Text.ElideRight
                            color: rma.containsMouse ? Theme.bg : Theme.fg
                            font { family: Theme.mono; pixelSize: 10 }
                        }
                    }
                    MouseArea {
                        id: rma
                        anchors.fill: parent
		        hoverEnabled: true
			onClicked: row.modelData.execute()
                    }
                }
            }
        }
    }

    // ---------------- RIGHT ----------------
    PanelWindow {
        id: rightWin
        anchors { top: true; bottom: true; right: true }
        implicitWidth: 250
        exclusiveZone: 250
        color: Theme.bg
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "edex-right"

        Rectangle { anchors { top: parent.top; bottom: parent.bottom; left: parent.left } width: 1; color: Theme.line }

        ColumnLayout {
            anchors { fill: parent; margins: 12 }
            NumberAnimation on opacity { from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }
            spacing: 8

            Head { t: "CALENDAR" }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDate(dayClock.date, "MMMM yyyy").toUpperCase()
                color: Theme.fg
                font { family: Theme.mono; pixelSize: 10; letterSpacing: 1 }
            }
            DayOfWeekRow {
                Layout.fillWidth: true
                locale: Qt.locale("en_US")
                delegate: Text {
                    horizontalAlignment: Text.AlignHCenter
                    text: model.shortName
                    color: Theme.fg
                    opacity: 0.6
                    font { family: Theme.mono; pixelSize: 9 }
                }
            }
            MonthGrid {
                id: grid
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                month: dayClock.date.getMonth()
                year: dayClock.date.getFullYear()
                locale: Qt.locale("en_US")
                delegate: Item {
                    Rectangle {
                        anchors { fill: parent; margins: 1 }
                        color: (model.today && model.month === grid.month) ? Theme.fg : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: model.day
                        color: (model.today && model.month === grid.month) ? Theme.bg : Theme.fg
                        opacity: model.month === grid.month ? 1 : 0.3
                        font { family: Theme.mono; pixelSize: 10 }
                    }
                }
            }
            Sep {}
            Head { t: "TRAY" }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                spacing: 10
                Repeater {
                    model: SystemTray.items
                    delegate: Item {
                        id: ti
                        required property var modelData
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                        IconImage { anchors.fill: parent; source: ti.modelData.icon }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) ti.modelData.activate()
                                else if (mouse.button === Qt.MiddleButton) ti.modelData.secondaryActivate()
                                else if (ti.modelData.hasMenu) {
                                    var p = ti.mapToItem(null, 0, ti.height)
                                    ti.modelData.display(rightWin, p.x, p.y)
                                }
                            }
                        }
                    }
                }
            }
            Sep {}
            Head { t: "NEAREST PLANE FROM HOME"; v: root.plane.when }
            Text { text: root.plane.call; color: Theme.fg; font { family: Theme.mono; pixelSize: 16; letterSpacing: 1 } }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                KV { k: "TYPE"; v: root.plane.type }
                KV { k: "REG"; v: root.plane.reg }
                KV { k: "ALT"; v: root.plane.alt }
                KV { k: "SPEED"; v: root.plane.spd }
                KV { k: "HEADING"; v: root.plane.hdg }
                KV { k: "DISTANCE"; v: root.plane.dist }
                KV { k: "BEARING"; v: root.plane.brg }
            }
            Sep {}
            Head { t: "ISS TRACKER"; v: root.iss.state }
            Text { text: root.iss.map; color: Theme.fg; opacity: 0.8; font { family: Theme.mono; pixelSize: 9 } }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                KV { k: "LAT"; v: root.iss.lat }
                KV { k: "LON"; v: root.iss.lon }
                KV { k: "ALT"; v: root.iss.alt }
                KV { k: "SPEED"; v: root.iss.vel }
                KV { k: "OVER"; v: root.iss.over }
                KV { k: "FROM YOU"; v: root.iss.dist }
                KV { k: "IN VIEW"; v: root.iss.view }
                KV { k: "LIGHT"; v: root.iss.vis }
            }
            Sep {}
            Head { t: "↓ DOWN"; v: root.st.down + " KB/s" }
            Graph { samples: root.downH; maxv: 0 }
            Head { t: "↑ UP"; v: root.st.up + " KB/s" }
            Graph { samples: root.upH; maxv: 0 }
        }
    }

    // ---------------- BOTTOM ----------------
    PanelWindow {
        anchors { bottom: true; left: true; right: true }
        implicitHeight: 250
        exclusiveZone: 250
        color: Theme.bg
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "edex-bottom"

        Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 1; color: Theme.line }

        RowLayout {
            anchors { fill: parent; margins: 12 }
            NumberAnimation on opacity { from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic }
            spacing: 14

            ColumnLayout {
                Layout.preferredWidth: 470
                Layout.maximumWidth: 470
                Layout.fillWidth: false
                Layout.fillHeight: true
                spacing: 8
                Head { t: "FILESYSTEM" }
                Sep {}
                GridLayout {
                    columns: 4
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    rowSpacing: 6
                    columnSpacing: 6
                    Repeater {
                        model: root.dirs
                        delegate: Rectangle {
                            id: tile
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: ma.containsMouse ? Theme.fg : "transparent"
                            border { width: 1; color: Theme.line }
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 44
                                    Layout.preferredHeight: 34
                                    Rectangle { x: 0; y: 0; width: 18; height: 9; color: "transparent"; border { width: 2; color: ma.containsMouse ? Theme.bg : Theme.fg } }
                                    Rectangle { x: 0; y: 7; width: 44; height: 27; color: "transparent"; border { width: 2; color: ma.containsMouse ? Theme.bg : Theme.fg } }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: tile.modelData
                                    color: ma.containsMouse ? Theme.bg : Theme.fg
                                    font { family: Theme.mono; pixelSize: 10 }
                                }
                            }
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { root.play("message-new-instant"); Quickshell.execDetached(["kitty", "-e", "yazi", root.home + "/" + tile.modelData]) }
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Theme.sep }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 700
                Layout.minimumWidth: 500
                spacing: 4
                Repeater {
                    model: root.rows
                    delegate: RowLayout {
                        id: rl
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4
                        Repeater {
                            model: rl.modelData
                            delegate: Rectangle {
                                id: key
                                required property string modelData
                                readonly property bool on: root.pressed[modelData] === 1
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1
                                color: on ? Theme.fg : Qt.rgba(0.667, 0.812, 0.82, 0)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                border { width: 1; color: on ? Theme.fg : Qt.rgba(0.667, 0.812, 0.82, 0.2) }
                                Text {
                                    anchors.centerIn: parent
                                    text: key.modelData
                                    color: key.on ? Theme.bg : Theme.fg
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    font { family: Theme.mono; pixelSize: 12 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
