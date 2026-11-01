pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: cfg

    readonly property var defaults: ({
        font: "monospace",
        sound: true,
        side_width: 250,
        bottom_height: 250,
        location: { name: "HOME", lat: 51.4779, lon: -0.0015 },
        terminal: ["kitty", "-e"],
        file_manager: ["yazi"],
        folders: ["Documents", "Downloads", "Pictures", "Music", "Videos", ".config", "Desktop", "Projects"]
    })

    FileView {
        id: file
        path: Quickshell.shellPath("config.json")
        blockLoading: true
    }

    readonly property var c: {
        var user = {}
        try { user = JSON.parse(file.text()) } catch (e) { console.warn("Config: no usable config.json, using defaults") }
        var out = Object.assign({}, defaults, user)
        out.location = Object.assign({}, defaults.location, user.location || {})
        return out
    }

    readonly property string font: c.font
    readonly property bool sound: c.sound
    readonly property int side_width: c.side_width
    readonly property int bottom_height: c.bottom_height
    readonly property var location: c.location
    readonly property var terminal: c.terminal
    readonly property var file_manager: c.file_manager
    readonly property var folders: c.folders
}
