import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "bo.cpu-meter"

  // Percent busy since the previous sample, from /proc/stat's aggregate line.
  property int usage: 0
  property real lastBusy: -1
  property real lastTotal: -1

  function sample(line) {
    var parts = line.trim().split(/\s+/)
    if (parts.length < 5 || parts[0] !== "cpu") return

    var total = 0
    for (var i = 1; i < parts.length; i++) total += parseFloat(parts[i])
    var idle = parseFloat(parts[4]) + (parts.length > 5 ? parseFloat(parts[5]) : 0)
    var busy = total - idle

    if (root.lastTotal >= 0 && total > root.lastTotal) {
      root.usage = Math.round(100 * (busy - root.lastBusy) / (total - root.lastTotal))
    }

    root.lastBusy = busy
    root.lastTotal = total
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statProc
    command: ["head", "-1", "/proc/stat"]
    stdout: StdioCollector {
      onStreamFinished: root.sample(text)
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statProc.running) statProc.running = true
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍛"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: "CPU " + root.usage + "%"
    onPressed: if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
  }
}
