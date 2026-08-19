import QtQuick
import qs.Commons
import qs.Ui

// What is running, and what it is costing.
//
// A process in a plain list is a title and a chip, which is enough to identify
// a file and not nearly enough to decide whether to kill something. The
// question being asked here is comparative: of the things running, which one is
// the problem. That is a question about numbers, and a list where the numbers
// are buried in a subtitle cannot answer it.
//
// So the numbers get a column of their own, and only one of them per row is
// drawn loudly. A process is expensive in one way at a time: either it is
// spinning a core, or it is holding memory. Whichever is the larger fraction of
// what the machine has leads at reading size; the other drops to the caption
// beneath it. Four numbers at equal weight is a spreadsheet, and nobody scans a
// spreadsheet.
//
// The bar under the numbers is the same fraction again, and it is the thing
// actually being scanned: a row that costs nothing draws no bar at all, so the
// shape of the answer is visible before a single digit has been read. Colour
// joins in only at the top of the range, because a list where every row is red
// has no warning left in it.
//
// The dot on the left says whether this is something the user opened or
// something that is merely running. A filled dot has a window, and that row
// also shows the window's title rather than its command line and offers to go
// and look at it, since half the reason anyone types `kill:` is that they could
// not find the thing.
//
// Rows carry:
//   pid user own cpu cpuLive mem memShare age count stopped
//   windowed winTitle winClass workspace windows cmd
//   machine { cpu, memUsed, memTotal, procs, matched }   on the first row only
Column {
  // The card cannot hold a view that draws past its own height, and every view
  // here computes that height from its content. Clipping at the root is what
  // makes a wrong sum a short answer rather than rows spilling over the footer.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property var head: launcher.rows.length > 0 ? launcher.rows[0] : null
  readonly property var machine: (view.head && view.head.machine) ? view.head.machine : ({})

  readonly property int gutter: Style.space(18)
  readonly property int headerHeight: Style.space(40)
  readonly property int rowHeight: Style.space(50)
  // Wide enough for "1.5G" over "0.6% · 2d 4h" at caption size.
  readonly property int costWidth: Style.space(108)
  // The pid column. Seven digits is the whole of /proc/sys/kernel/pid_max on a
  // 64-bit machine, so this never has to elide.
  readonly property int pidWidth: Style.space(50)

  function bytes(n) {
    var b = Number(n || 0)
    if (b >= 1073741824) {
      var g = b / 1073741824
      return (g >= 10 ? Math.round(g) : g.toFixed(1)) + "G"
    }
    if (b >= 1048576) return Math.round(b / 1048576) + "M"
    return Math.max(1, Math.round(b / 1024)) + "K"
  }

  // One decimal below ten, none above. "43.7%" reads as precision the number
  // does not have, and the extra digit costs the column its alignment.
  function pct(v) {
    var c = Number(v || 0)
    if (c >= 10) return Math.round(c) + "%"
    return c.toFixed(1) + "%"
  }

  function ago(seconds) {
    var s = Math.max(0, Number(seconds || 0))
    if (s < 60) return Math.floor(s) + "s"
    if (s < 3600) return Math.floor(s / 60) + "m"
    if (s < 86400) {
      var h = Math.floor(s / 3600)
      var m = Math.floor((s % 3600) / 60)
      return m > 0 ? h + "h " + m + "m" : h + "h"
    }
    var d = Math.floor(s / 86400)
    var hh = Math.floor((s % 86400) / 3600)
    return hh > 0 ? d + "d " + hh + "h" : d + "d"
  }

  readonly property int shownRows: {
    var n = view.launcher.rows.length
    if (view.maxHeight <= 0) return n
    var room = view.maxHeight - view.headerHeight - Style.space(12)
    return Math.max(1, Math.min(n, Math.floor(room / view.rowHeight)))
  }

  spacing: 0

  // The machine, once, above everything. Every number below is a fraction of
  // these two and means nothing without them: 1.5G is either most of the box or
  // a rounding error, and only the total says which.
  Item {
    width: view.width
    height: view.headerHeight

    Text {
      anchors.left: parent.left
      anchors.leftMargin: view.gutter
      anchors.verticalCenter: parent.verticalCenter
      // The count that matters is how many were found, not how many fit. A
      // list capped at twelve with nothing saying so reads as the whole truth.
      text: {
        var shown = view.launcher.rows.length
        var matched = Number(view.machine.matched || shown)
        var noun = view.machine.bare === false ? " matching" : " running"
        if (matched > shown) return shown + " of " + matched + noun
        return matched + noun
      }
      color: Qt.darker(view.launcher.foreground, 1.8)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
    }

    Row {
      anchors.right: parent.right
      anchors.rightMargin: view.gutter
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(14)

      // Hidden rather than shown as zero on the first run after a pause, when
      // there is no earlier sample to difference against. A load figure that is
      // wrong is worse than one that is missing.
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: Number(view.machine.cpu !== undefined ? view.machine.cpu : -1) >= 0
        text: "cpu " + view.pct(view.machine.cpu)
        color: Qt.darker(view.launcher.foreground, 1.8)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: Number(view.machine.memTotal || 0) > 0
        text: view.bytes(view.machine.memUsed) + " of " + view.bytes(view.machine.memTotal)
        color: Qt.darker(view.launcher.foreground, 1.8)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  ListView {
    id: list
    width: view.width
    height: view.shownRows * view.rowHeight
    clip: true
    focus: false
    interactive: true
    currentIndex: view.launcher.selectedIndex
    highlightMoveDuration: 0
    model: view.launcher.rows

    delegate: Item {
      id: entry

      required property var modelData
      required property int index

      readonly property bool selected: index === view.launcher.selectedIndex
      readonly property bool windowed: modelData.windowed === true
      readonly property real cpu: Number(modelData.cpu || 0)
      readonly property real share: Number(modelData.memShare || 0)

      // Which of the two costs this row is about. Both are already fractions of
      // the whole machine, so they compare directly: a core is a core and the
      // memory share is of MemTotal. Memory wins ties, because a process
      // holding a gigabyte at rest is the more common reason to be here.
      readonly property bool cpuLeads: (entry.cpu / 100) > entry.share
      readonly property real fraction: Math.max(0, Math.min(1,
        entry.cpuLeads ? entry.cpu / 100 : entry.share))

      // Two thresholds, not a gradient. Accent means "this is the row you came
      // for"; urgent means "this is a runaway". Everything else stays the
      // colour of ordinary text so those two keep their meaning.
      readonly property color costColor: {
        if (entry.fraction >= 0.6) return Color.urgent
        if (entry.fraction >= 0.2) return Color.accent
        return entry.selected ? view.launcher.selectedText : view.launcher.foreground
      }

      width: list.width
      height: view.rowHeight

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        anchors.topMargin: Style.space(2)
        anchors.bottomMargin: Style.space(2)
        radius: Style.cornerRadius
        color: entry.selected ? view.launcher.selectedBackground : "transparent"
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: view.launcher.select(entry.index)
        onClicked: view.launcher.activate(entry.modelData)
      }

      // The pid, in a column of its own. It is the least interesting number on
      // the row and the one most often needed verbatim, which is exactly what a
      // quiet left-hand column is for.
      Text {
        id: pid
        anchors.left: parent.left
        anchors.leftMargin: view.gutter
        anchors.verticalCenter: parent.verticalCenter
        width: view.pidWidth
        horizontalAlignment: Text.AlignRight
        text: String(entry.modelData.pid || "")
        color: Qt.darker(view.launcher.foreground, 2.6)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }

      // Filled means it has a window. Drawn rather than set in a font, because
      // a glyph that is missing from the user's font is a blank row and there
      // is nothing else on the line that carries this.
      Rectangle {
        id: dot
        anchors.left: pid.right
        anchors.leftMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(7)
        height: width
        radius: width / 2
        color: entry.windowed ? Color.accent : "transparent"
        border.width: entry.windowed ? 0 : Math.max(1, Style.space(1))
        border.color: Qt.darker(view.launcher.foreground, 2.6)
      }

      Column {
        anchors.left: dot.right
        anchors.leftMargin: Style.space(12)
        anchors.right: cost.left
        anchors.rightMargin: Style.space(14)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        // The name takes what the chips leave, rather than a fixed allowance.
        // A guessed reserve is wrong in both directions: it truncates a long
        // name on a row with no chips, and it still overlaps on a row with
        // three of them.
        Item {
          width: parent.width
          height: nameText.implicitHeight

          Text {
            id: nameText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - chips.width - Style.space(8))
            text: String(entry.modelData.title || "")
            color: entry.selected ? view.launcher.selectedText : view.launcher.foreground
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.subtitle
            elide: Text.ElideRight
          }

          Row {
            id: chips
            anchors.left: nameText.right
            anchors.leftMargin: Style.space(8)
            anchors.verticalCenter: nameText.verticalCenter
            spacing: Style.space(6)

            // How many processes are folded into this row. Without it, a
            // chrome row reading 3G looks like one process with a leak rather
            // than forty tabs, and the two want different responses.
            Chip {
              anchors.verticalCenter: parent.verticalCenter
              visible: Number(entry.modelData.count || 1) > 1
              text: "×" + Number(entry.modelData.count || 1)
              foreground: view.launcher.foreground
              fontFamily: view.launcher.fontFamily
            }

            // Only when it is not yours, because then Terminate will quietly
            // do nothing and the row needs to say why before it is pressed.
            Chip {
              anchors.verticalCenter: parent.verticalCenter
              visible: entry.modelData.own === false
              text: String(entry.modelData.user || "")
              accented: true
              tint: Color.urgent
              foreground: view.launcher.foreground
              fontFamily: view.launcher.fontFamily
            }

            // A suspended job is not hung, it is waiting, and killing it is
            // usually the wrong move. Worth a word on the two rows a year
            // where it applies, and worth nothing on every other row.
            Chip {
              anchors.verticalCenter: parent.verticalCenter
              visible: entry.modelData.stopped === true
              text: "stopped"
              foreground: view.launcher.foreground
              fontFamily: view.launcher.fontFamily
            }
          }
        }

        // What the thing is. For something with a window that is the window's
        // own title, which is what the user would recognise; for anything else
        // it is the command line, which is all there is.
        Text {
          width: parent.width
          text: {
            var m = entry.modelData
            if (!entry.windowed) return String(m.cmd || m.subtitle || "")
            var t = String(m.winTitle || m.winClass || "")
            var extra = String(m.winClass || "")
            var ws = String(m.workspace || "")
            if (ws !== "") extra = extra === "" ? "workspace " + ws : extra + "  ·  workspace " + ws
            var n = Number(m.windows || 0)
            if (n > 1) extra = extra + "  ·  " + n + " windows"
            return extra === "" ? t : t + "  ·  " + extra
          }
          color: Qt.darker(view.launcher.foreground, 2.1)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      // The cost column: one number at reading size, its companion and the age
      // under it, and the same fraction again as a bar.
      Item {
        id: cost
        anchors.right: parent.right
        anchors.rightMargin: view.gutter
        anchors.verticalCenter: parent.verticalCenter
        width: view.costWidth
        height: view.rowHeight

        Text {
          id: lead
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: Style.space(9)
          text: entry.cpuLeads ? view.pct(entry.cpu) : view.bytes(entry.modelData.mem)
          color: entry.costColor
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: entry.fraction >= 0.2
        }

        Text {
          id: companion
          anchors.right: parent.right
          anchors.top: lead.bottom
          anchors.topMargin: Style.space(2)
          text: {
            var other = entry.cpuLeads
              ? view.bytes(entry.modelData.mem)
              : view.pct(entry.cpu)
            return other + "  ·  " + view.ago(entry.modelData.age)
          }
          color: Qt.darker(view.launcher.foreground, 2.3)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        // Nothing under a twentieth of the machine draws a bar. A row of stubs
        // beside every idle process is noise, and the bars are only worth
        // having if their presence already means something.
        // Hung from the text above rather than from the bottom of the row. At
        // a larger font the two met in the middle and the bar drew through the
        // digits, which reads as a rendering fault rather than as a meter.
        Rectangle {
          id: track
          anchors.right: parent.right
          anchors.top: companion.bottom
          anchors.topMargin: Style.space(5)
          visible: entry.fraction >= 0.05
          width: parent.width
          height: Math.max(1, Style.space(2))
          radius: height / 2
          color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                         view.launcher.foreground.b, 0.12)

          Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(Style.space(2), parent.width * entry.fraction)
            height: parent.height
            radius: parent.radius
            color: entry.costColor
          }
        }
      }
    }
  }

  Item {
    width: view.width
    height: Style.space(12)
  }
}
