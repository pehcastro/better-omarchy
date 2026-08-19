import QtQuick
import qs.Commons
import qs.Ui

// Containers as a panel of machines, not as a list of them.
//
// The first attempt at this was a row per container with a state dot, a band
// heading and a right-hand column of figures. It was still a list: everything
// was full width, everything was one line tall, and the only way to compare two
// containers was to read both. The correct answer to "what is this box doing"
// is a picture you take in at once, so this is a grid of tiles, two across at
// the width the launcher runs at and one across when the card is narrow.
//
// Inside a tile, in the order you read it:
//   a coloured edge down the left, which is the state and the only place the
//   state is stated; the name, large, with its uptime kept quiet at the right;
//   the image and, only when it has something to say, health; two meters; and
//   the published ports as chips you can press.
//
// The meters are the reason this is worth building. A percentage is a number
// nobody does arithmetic with, so 15% and 90% should not both be four
// characters of the same grey. Each meter has a denominator that is named
// rather than assumed: memory against the container's own cap when it was
// given one and against the host when it was not, CPU against its quota or
// against every core the machine has. `docker stats` calls one busy core 100%,
// so a tile with no quota on a sixteen core box fills its bar at 1600.
//
// A stopped tile has no meters and no ports, because it has neither. It gets a
// dimmer face, a grey edge and one line saying how it ended. Zeros in a meter
// would make it look like a running container doing nothing, which is the one
// thing it is not.
//
// Above the grid, four stat tiles: how many are up, what they are costing in
// CPU and memory, and how many are failing. The last one stays quiet at zero.
//
// Rows carry:
//   name cid full image status band health restarts exitCode oom since
//   project service
//   ports    [ { host, container, proto, addr, label, web, url, exec } ]
//   cpu cpuFull cpuFullText
//   mem memBytes memPct memCap memCapText
//   hostCores hostMem
// The cpu and mem fields are absent until the sampler has run; see
// omacast-docker for why they arrive a beat late rather than costing a second.
Item {
  // The card cannot hold a view that draws past its own height, and every view
  // here computes that height from its content. Clipping at the root is the one
  // thing that makes a wrong sum a short answer rather than tiles spilling over
  // the footer and onto the wallpaper.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property int gutter: Style.space(12)
  // A tile plus the gutter that follows it. Below this a tile cannot hold a
  // name, a meter and its reading without eliding all three, so the grid drops
  // to a single column instead of shrinking further.
  //
  // One token rather than a tile width plus a gutter, because the launcher has
  // to compute this same number to know how far Up and Down travel, and two
  // Style.space() calls that should sum to a third can disagree by a pixel at
  // a non-integer scale. A pixel is enough to put the two of them on different
  // column counts, which shows up as arrow keys skipping a tile.
  readonly property int minTile: Style.space(280)
  readonly property int columns: Math.max(1, Math.floor((width - gutter) / minTile))
  readonly property int tileWidth: Math.max(
    Style.space(120),
    Math.floor((width - gutter * (columns + 1)) / columns))
  readonly property int tileHeight: Style.space(144)
  readonly property int statHeight: Style.space(70)

  // How many whole tile rows fit under the stats. Whole rows only: a tile cut
  // through the middle at the bottom edge reads as a fault, not as "there is
  // more".
  readonly property int tileRows: {
    var wanted = Math.ceil(view.launcher.rows.length / view.columns)
    if (view.maxHeight <= 0) return wanted
    var room = view.maxHeight - view.statHeight - view.gutter * 2
    return Math.max(1, Math.min(wanted, Math.floor((room + view.gutter) / (view.tileHeight + view.gutter))))
  }

  implicitHeight: view.launcher.rows.length === 0
    ? 0
    : view.statHeight + view.gutter
      + view.tileRows * view.tileHeight + (view.tileRows - 1) * view.gutter
      + view.gutter

  function ago(seconds) {
    var s = Number(seconds || 0)
    if (s <= 0) return ""
    if (s < 60) return Math.floor(s) + "s"
    if (s < 3600) return Math.floor(s / 60) + "m"
    if (s < 86400) return Math.floor(s / 3600) + "h"
    if (s < 2592000) return Math.floor(s / 86400) + "d"
    return Math.floor(s / 2592000) + "mo"
  }

  function human(bytes) {
    var n = Number(bytes || 0)
    if (n >= 1073741824) return (Math.round(n / 1073741824 * 10) / 10) + "GiB"
    if (n >= 1048576) return Math.round(n / 1048576) + "MiB"
    if (n >= 1024) return Math.round(n / 1024) + "KiB"
    return Math.round(n) + "B"
  }

  // Left and right through a grid. The launcher hands arrow keys to whichever
  // view is on screen if that view offers this, which is what makes moving
  // sideways between two columns possible at all; without it the only travel
  // is one tile at a time in reading order.
  function nudge(delta) {
    view.launcher.move(delta)
  }

  // Open a port, copy an address, whatever the script decided this chip means.
  // Dismiss first, for the same reason the launcher does before it runs a row:
  // a browser opened while an exclusive-focus layer surface is still mapped
  // comes up behind it.
  function run(command) {
    if (!command) return
    view.launcher.dismiss()
    Qt.callLater(function () { Util.execDetached(String(command)) })
  }

  // ------------------------------------------------------------ the totals

  readonly property int runningCount: {
    var n = 0
    for (var i = 0; i < view.launcher.rows.length; i++) {
      if (Number(view.launcher.rows[i].band) === 0) n += 1
    }
    return n
  }

  readonly property int failingCount: {
    var n = 0
    for (var i = 0; i < view.launcher.rows.length; i++) {
      var row = view.launcher.rows[i]
      if (Number(row.band) === 1 || String(row.health || "") === "unhealthy") n += 1
    }
    return n
  }

  // Negative until the sampler has answered even once, so the tiles can show
  // nothing rather than a confident zero that was never measured.
  readonly property real totalCpu: {
    var sum = -1
    for (var i = 0; i < view.launcher.rows.length; i++) {
      var cpu = view.launcher.rows[i].cpu
      if (cpu === undefined || cpu === null) continue
      sum = (sum < 0 ? 0 : sum) + Number(cpu)
    }
    return sum
  }

  readonly property real totalMem: {
    var sum = -1
    for (var i = 0; i < view.launcher.rows.length; i++) {
      var row = view.launcher.rows[i]
      if (row.cpu === undefined || row.cpu === null) continue
      sum = (sum < 0 ? 0 : sum) + Number(row.memBytes || 0)
    }
    return sum
  }

  readonly property real hostCores: {
    var row = view.launcher.rows.length > 0 ? view.launcher.rows[0] : null
    return row ? Math.max(1, Number(row.hostCores || 1)) : 1
  }

  readonly property real hostMem: {
    var row = view.launcher.rows.length > 0 ? view.launcher.rows[0] : null
    return row ? Math.max(1, Number(row.hostMem || 1)) : 1
  }

  Column {
    width: view.width
    spacing: view.gutter

    // Four readings, side by side, sized like readings. This is the answer to
    // the question a bare `docker:` is actually asking, and it used to be a
    // sentence in the corner.
    Row {
      x: view.gutter
      spacing: view.gutter

      Repeater {
        model: [
          { label: "up",
            value: view.runningCount + " / " + view.launcher.rows.length,
            fraction: view.launcher.rows.length > 0
              ? view.runningCount / view.launcher.rows.length : 0,
            loud: false },
          { label: "cpu",
            value: view.totalCpu < 0 ? "" : Math.round(view.totalCpu) + "%",
            fraction: view.totalCpu < 0 ? 0 : view.totalCpu / (view.hostCores * 100),
            loud: false },
          { label: "memory",
            value: view.totalMem < 0 ? "" : view.human(view.totalMem),
            fraction: view.totalMem < 0 ? 0 : view.totalMem / view.hostMem,
            loud: false },
          // The only tile that changes character. Nothing failing is the
          // normal state of a machine and should not be announced in the
          // urgent colour; one thing failing is the reason you opened this.
          { label: "failing",
            value: String(view.failingCount),
            fraction: 0,
            loud: view.failingCount > 0,
            quiet: view.failingCount === 0 }
        ]

        Item {
          id: stat

          required property var modelData

          width: Math.floor((view.width - view.gutter * 5) / 4)
          height: view.statHeight

          Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                           view.launcher.foreground.b, 0.05)
          }

          Text {
            id: reading
            anchors.left: parent.left
            anchors.leftMargin: Style.space(12)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.top: parent.top
            anchors.topMargin: Style.space(11)
            text: String(stat.modelData.value)
            // A zero here is the answer nobody needs to act on, so it is drawn
            // at the weight of a fact rather than the weight of a warning.
            color: stat.modelData.loud
              ? Color.urgent
              : (stat.modelData.quiet === true
                 ? Qt.darker(view.launcher.foreground, 2.2)
                 : view.launcher.foreground)
            font.family: view.launcher.fontFamily
            // A reading steps down rather than eliding. "62.5GiB" and "5 / 7"
            // are both the answer and only one of them fits at display size.
            font.pixelSize: String(stat.modelData.value).length > 6
              ? Style.font.heading : Style.font.display
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(12)
            anchors.top: reading.bottom
            anchors.topMargin: Style.space(1)
            text: String(stat.modelData.label)
            color: Qt.darker(view.launcher.foreground, 2.3)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 0.6
          }

          // A hairline of proportion along the bottom edge of the tile, so the
          // three tiles that are fractions read as fractions without spending
          // a whole meter on each.
          Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, Number(stat.modelData.fraction || 0)))
            height: Math.max(1, Style.space(2))
            radius: height / 2
            color: Color.accent
            visible: Number(stat.modelData.fraction || 0) > 0
          }
        }
      }
    }

    // ---------------------------------------------------------- the machines

    Grid {
      x: view.gutter
      columns: view.columns
      spacing: view.gutter

      Repeater {
        model: Math.min(view.launcher.rows.length, view.tileRows * view.columns)

        delegate: Item {
          id: tile

          required property int index
          // The rows array is replaced wholesale on every refresh and a
          // delegate outlives the array it was built from by a frame. An
          // unguarded read here is a TypeError, and a TypeError in a delegate
          // draws an empty tile rather than saying anything at all.
          readonly property var box: view.launcher.rows[tile.index] || ({})

          readonly property bool selected: tile.index === view.launcher.selectedIndex
          readonly property bool up: Number(tile.box.band) === 0
          readonly property bool failing: Number(tile.box.band) === 1
            || String(tile.box.health || "") === "unhealthy"
          readonly property var ports: tile.box.ports || []
          readonly property bool measured: tile.box.cpu !== undefined && tile.box.cpu !== null

          readonly property color edge: {
            if (tile.failing) return Color.urgent
            if (!tile.up) return Qt.darker(view.launcher.foreground, 3.0)
            if (String(tile.box.health || "") === "starting") {
              return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
            }
            return Color.accent
          }

          width: view.tileWidth
          height: view.tileHeight

          Rectangle {
            id: face
            anchors.fill: parent
            radius: Style.cornerRadius
            // A stopped tile sits lower than the surface a running one sits
            // on. Switched off, rather than on and idle.
            color: tile.selected
              ? view.launcher.selectedBackground
              : Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                        view.launcher.foreground.b, tile.up ? 0.055 : 0.02)
            border.width: tile.selected ? Math.max(1, Style.space(1)) : 0
            border.color: Color.accent
          }

          // The state, and the only statement of it anywhere on the card.
          Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: Style.space(1)
            anchors.bottomMargin: Style.space(1)
            width: Math.max(2, Style.space(3))
            radius: width / 2
            color: tile.edge
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: view.launcher.select(tile.index)
            onClicked: view.launcher.activate(tile.box)
          }

          // ------------------------------------------------------- the name

          Text {
            id: uptime
            anchors.top: parent.top
            anchors.topMargin: Style.space(11)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            text: {
              var age = view.ago(tile.box.since)
              if (age === "") return ""
              if (tile.up) return age
              if (Number(tile.box.band) === 1) return "crashed " + age
              return age + " ago"
            }
            color: Qt.darker(view.launcher.foreground, 2.4)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            id: name
            anchors.top: parent.top
            anchors.topMargin: Style.space(8)
            anchors.left: parent.left
            anchors.leftMargin: Style.space(14)
            anchors.right: uptime.left
            anchors.rightMargin: Style.space(8)
            text: String(tile.box.name || "")
            color: tile.up
              ? (tile.selected ? view.launcher.selectedText : view.launcher.foreground)
              : Qt.darker(view.launcher.foreground, 1.7)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          // ------------------------------------------ what it is, and health

          Chip {
            id: healthChip
            anchors.top: name.bottom
            anchors.topMargin: Style.space(4)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            // Health only speaks when it has something to say. A healthcheck
            // that is passing is already the colour of the edge, and repeating
            // "healthy" on every tile costs the unhealthy one its contrast.
            text: {
              if (Number(tile.box.restarts || 0) > 0) return "↻" + Number(tile.box.restarts || 0)
              var health = String(tile.box.health || "")
              if (health === "unhealthy" || health === "starting") return health
              return ""
            }
            accented: text !== "" && text !== "starting"
            tint: Color.urgent
            foreground: view.launcher.foreground
            fontFamily: view.launcher.fontFamily
          }

          Text {
            id: origin
            anchors.top: name.bottom
            anchors.topMargin: Style.space(5)
            anchors.left: parent.left
            anchors.leftMargin: Style.space(14)
            anchors.right: healthChip.text !== "" ? healthChip.left : parent.right
            anchors.rightMargin: Style.space(10)
            // The compose service first when there is one: in a stack of nine
            // the image repeats three times and the service never does.
            text: {
              var service = String(tile.box.service || "")
              var image = String(tile.box.image || "")
              if (service !== "" && image !== "") return service + "  ·  " + image
              return service !== "" ? service : image
            }
            color: Qt.darker(view.launcher.foreground, 2.3)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          // ----------------------------------------------------- the meters

          Column {
            id: meters
            visible: tile.up
            anchors.top: origin.bottom
            anchors.topMargin: Style.space(9)
            anchors.left: parent.left
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            spacing: Style.space(6)

            Repeater {
              model: [
                { label: "cpu",
                  reading: tile.measured
                    ? ((Number(tile.box.cpu) >= 10
                        ? Math.round(Number(tile.box.cpu))
                        : Math.round(Number(tile.box.cpu) * 10) / 10) + "%")
                    : "",
                  scale: String(tile.box.cpuFullText || ""),
                  fraction: tile.measured && Number(tile.box.cpuFull || 0) > 0
                    ? Number(tile.box.cpu) / Number(tile.box.cpuFull) : 0 },
                { label: "mem",
                  reading: tile.measured ? String(tile.box.mem || "") : "",
                  scale: String(tile.box.memCapText || ""),
                  fraction: tile.measured ? Number(tile.box.memPct || 0) / 100 : 0 }
              ]

              Item {
                id: meter

                required property var modelData

                width: meters.width
                height: Style.space(22)

                // Which meter this is. It stays on screen while the sampler is
                // still out, so the two empty tracks are a cpu bar and a memory
                // bar rather than two anonymous lines.
                Text {
                  id: meterLabel
                  anchors.top: parent.top
                  anchors.left: parent.left
                  width: Style.space(26)
                  text: meter.modelData.label
                  color: Qt.darker(view.launcher.foreground, 2.5)
                  font.family: view.launcher.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  id: meterReading
                  anchors.top: parent.top
                  anchors.left: meterLabel.right
                  text: meter.modelData.reading
                  color: meter.modelData.fraction >= 0.85
                    ? Color.urgent
                    : (tile.selected ? view.launcher.selectedText : view.launcher.foreground)
                  font.family: view.launcher.fontFamily
                  font.pixelSize: Style.font.caption
                }

                // The denominator, spelled out. A bar against a 512MiB cap and
                // a bar against 62GiB of host mean opposite things at the same
                // length, and the only way to tell is to say so.
                Text {
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.left: meterReading.right
                  anchors.leftMargin: Style.space(6)
                  horizontalAlignment: Text.AlignRight
                  text: meterReading.text === "" ? "" : "of " + meter.modelData.scale
                  color: Qt.darker(view.launcher.foreground, 2.6)
                  font.family: view.launcher.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }

                Rectangle {
                  id: track
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Style.space(2)
                  anchors.left: parent.left
                  anchors.right: parent.right
                  height: Math.max(2, Style.space(4))
                  radius: height / 2
                  color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                                 view.launcher.foreground.b, 0.12)
                }

                Rectangle {
                  anchors.left: track.left
                  anchors.verticalCenter: track.verticalCenter
                  // A reading that is real but tiny still gets a mark, because
                  // a bar of zero width and a bar that has not been measured
                  // yet would otherwise look the same.
                  width: meterReading.text === ""
                    ? 0
                    : Math.max(track.height,
                               track.width * Math.max(0, Math.min(1, meter.modelData.fraction)))
                  height: track.height
                  radius: track.radius
                  color: meter.modelData.fraction >= 0.85 ? Color.urgent : Color.accent
                }
              }
            }
          }

          // How a stopped container ended, in place of the meters it does not
          // have. One line, quiet, and no bars at all.
          Text {
            visible: !tile.up
            anchors.top: origin.bottom
            anchors.topMargin: Style.space(12)
            anchors.left: parent.left
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            text: {
              if (tile.box.oom === true) return "killed, out of memory"
              var code = Number(tile.box.exitCode || 0)
              if (Number(tile.box.band) === 1) return "restarting, last exit " + code
              return code === 0 ? "stopped cleanly" : "stopped, exit " + code
            }
            color: Number(tile.box.exitCode || 0) !== 0 || tile.box.oom === true
              ? Color.urgent : Qt.darker(view.launcher.foreground, 2.4)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          // ------------------------------------------------------ the ports

          Row {
            id: portRow
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(9)
            anchors.left: parent.left
            anchors.leftMargin: Style.space(14)
            spacing: Style.space(5)

            Repeater {
              // Four is what fits across a tile at this width. The rest stay
              // reachable through the action panel, which lists every one.
              model: tile.ports.length > 4 ? 4 : tile.ports.length

              Item {
                id: portCell

                required property int index
                readonly property var port: tile.ports[portCell.index] || ({})

                width: pill.implicitWidth
                height: pill.implicitHeight

                Chip {
                  id: pill
                  anchors.fill: parent
                  text: String(portCell.port.label || "")
                  accented: hot.containsMouse
                  foreground: view.launcher.foreground
                  fontFamily: view.launcher.fontFamily
                }

                MouseArea {
                  id: hot
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: view.launcher.select(tile.index)
                  onClicked: view.run(portCell.port.exec)
                }
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: tile.ports.length > 4
              text: "+" + (tile.ports.length - 4)
              color: Qt.darker(view.launcher.foreground, 2.4)
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
