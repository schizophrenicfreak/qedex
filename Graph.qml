import QtQuick
import QtQuick.Layouts
Canvas {
    id: c
    property var samples: []
    property real maxv: 100
    Layout.fillWidth: true
    Layout.preferredHeight: 50
    Layout.minimumHeight: 24
    onSamplesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.fillStyle = Theme.graphBg
        ctx.fillRect(0, 0, width, height)
        var n = samples.length
        if (n < 2) return
        var mx = maxv
        if (mx <= 0) { mx = 100; for (var k = 0; k < n; k++) if (samples[k] > mx) mx = samples[k] }
        var step = width / 59
        ctx.strokeStyle = Theme.fg
        ctx.lineWidth = 2
        ctx.beginPath()
        for (var i = 0; i < n; i++) {
            var x = width - (n - 1 - i) * step
            var y = height - 1 - (samples[i] / mx) * (height - 2)
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
        }
        ctx.stroke()
    }
}
