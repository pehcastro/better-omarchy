import QtQuick
import qs.Commons
import qs.Ui

// A player, not a menu.
//
// `music:` used to answer with a row saying "Play or Pause" and three more like
// it, which is a list of commands rather than the thing you asked about. This
// is the cover, the track, where you are in it, and buttons you press.
//
// The elapsed time ticks locally while the track plays. The script only reports
// a position at the moment it ran, and re-running it every second to move a
// number would be absurd, so the clock runs here and the next real reading
// corrects it.
Item {
  // The card cannot hold a view that draws past its own height, and every view
  // here computes that height from its content. Clipping at the root is the one
  // thing that makes a wrong sum a short answer rather than rows spilling over
  // the footer and onto the wallpaper.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property var track: launcher.rows.length > 0 ? launcher.rows[0] : null
  readonly property bool playing: track && String(track.status || "") === "Playing"

  readonly property real reportedProgress: track && track.progress !== undefined ? Number(track.progress) : 0
  readonly property real lengthSeconds: track && track.lengthSeconds !== undefined ? Number(track.lengthSeconds) : 0

  // Seconds since the reading, added to it. Reset whenever a new reading lands.
  property real drift: 0

  readonly property real position: {
    if (view.lengthSeconds <= 0) return 0
    var elapsed = view.reportedProgress * view.lengthSeconds + view.drift
    return Math.max(0, Math.min(view.lengthSeconds, elapsed))
  }

  readonly property bool shuffleOn: track && track.shuffle === true
  readonly property string loop: track ? String(track.loop || "None") : "None"
  readonly property bool canNext: !track || track.canNext !== false
  readonly property bool canPrev: !track || track.canPrev !== false

  readonly property real fraction: view.lengthSeconds > 0 ? view.position / view.lengthSeconds : 0

  onReportedProgressChanged: view.drift = 0

  function clock(seconds) {
    var total = Math.max(0, Math.round(seconds))
    var minutes = Math.floor(total / 60)
    var rest = total % 60
    return minutes + ":" + (rest < 10 ? "0" : "") + rest
  }

  // Run a control, then ask again. MPRIS applies the change on its own
  // schedule, so without this the button keeps drawing the old state until
  // something else happens to re-query, which reads as a button that does not
  // work.
  function run(command) {
    if (!command) return
    Util.execDetached(String(command))
    settle.restart()
  }

  Timer {
    id: settle
    interval: 260
    repeat: true
    property int round: 0
    onTriggered: {
      round += 1
      if (view.launcher && typeof view.launcher.refresh === "function") view.launcher.refresh()
      // Twice: Spotify acknowledges a property set quickly, but a track change
      // from next or previous takes longer to report new metadata.
      if (round >= 3) { round = 0; stop() }
    }
  }

  // Keep up with the app while the player is on screen, so pressing pause in
  // Spotify itself is reflected here rather than leaving a stale button.
  Timer {
    interval: 2500
    running: view.launcher && view.launcher.opened
    repeat: true
    onTriggered: if (view.launcher && typeof view.launcher.refresh === "function") view.launcher.refresh()
  }

  implicitHeight: Style.space(228)

  Timer {
    interval: 1000
    running: view.playing && view.lengthSeconds > 0
    repeat: true
    onTriggered: view.drift += 1
  }

  // The cover, as large as the card allows. It is the thing you recognise a
  // track by, so it is not a 44px thumbnail here.
  Rectangle {
    id: cover
    width: Style.space(132)
    height: width
    radius: Style.cornerRadius
    color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g, view.launcher.foreground.b, 0.06)
    anchors.left: parent.left
    anchors.leftMargin: Style.space(22)
    anchors.top: parent.top
    anchors.topMargin: Style.space(14)
    clip: true

    Image {
      anchors.fill: parent
      source: String((view.track && view.track.art) || "")
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: width * Screen.devicePixelRatio
      sourceSize.height: height * Screen.devicePixelRatio
      asynchronous: true

      // Not cached, for the reason spelled out in ResultFiles.qml: Qt keeps
      // every decoded image by URL for the life of the process, and this is
      // one new cover per track. A day of listening retains a day of covers.
      cache: false
    }

    Text {
      anchors.centerIn: parent
      visible: String((view.track && view.track.art) || "") === ""
      text: ""
      color: Qt.darker(view.launcher.foreground, 1.7)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.displayLarge
    }
  }

  // Bounded top and bottom, and clipped, so a long album name is cut rather
  // than running under the scrubber.
  Item {
    id: details
    anchors.left: cover.right
    anchors.leftMargin: Style.space(22)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(22)
    anchors.top: cover.top
    anchors.bottom: scrubber.top
    anchors.bottomMargin: Style.space(10)
    clip: true

    Column {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Style.space(4)

    Row {
      spacing: Style.space(8)

      Chip {
        text: String((view.track && view.track.status) || "")
        accented: view.playing
        foreground: view.launcher.foreground
        fontFamily: view.launcher.fontFamily
      }

      Chip {
        text: String((view.track && view.track.player) || "")
        foreground: view.launcher.foreground
        fontFamily: view.launcher.fontFamily
      }
    }

    Item { width: 1; height: Style.space(4) }

    Text {
      width: parent.width
      text: String((view.track && view.track.title) || "Nothing playing")
      color: view.launcher.foreground
      font.family: view.launcher.fontFamily
      font.pixelSize: text.length > 24 ? Style.font.title : Style.font.display
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: String((view.track && view.track.subtitle) || "")
      color: Qt.darker(view.launcher.foreground, 1.4)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: String((view.track && view.track.detail) || "")
      color: Qt.darker(view.launcher.foreground, 1.9)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
    }
  }

  // Scrubber. Clicking it seeks, which is the one thing a progress bar in a
  // player is expected to do and the reason it is not just a meter.
  Item {
    id: scrubber
    anchors.left: details.left
    anchors.right: details.right
    anchors.bottom: controls.top
    anchors.bottomMargin: Style.space(12)
    height: Style.space(24)
    visible: view.lengthSeconds > 0

    Rectangle {
      id: rail
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: Style.space(4)
      radius: height / 2
      color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g, view.launcher.foreground.b, 0.15)
    }

    Rectangle {
      anchors.left: rail.left
      anchors.verticalCenter: rail.verticalCenter
      height: rail.height
      radius: rail.radius
      width: rail.width * view.fraction
      color: Color.accent
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: function (mouse) {
        if (!view.track || !view.track.seek) return
        var target = Math.round((mouse.x / width) * view.lengthSeconds)
        // MPRIS SetPosition takes microseconds and an absolute track id, so the
        // script is handed the seconds and builds the call itself.
        view.run(String(view.track.seek).replace("{seconds}", target))
      }
    }

    Text {
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      text: view.clock(view.position)
      color: Qt.darker(view.launcher.foreground, 2.0)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      text: view.clock(view.lengthSeconds)
      color: Qt.darker(view.launcher.foreground, 2.0)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  // Transport. Shuffle and repeat sit either side of the three that move the
  // track, lit when they are on, so the row reads as state and not as four
  // identical buttons.
  Row {
    id: controls
    anchors.horizontalCenter: details.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(18)
    spacing: Style.space(4)

    Repeater {
      model: [
        { key: "shuffle",   glyph: "󰒟", primary: false,
          on: view.shuffleOn, enabled: true },
        { key: "prev",      glyph: "󰒮", primary: false,
          on: false, enabled: view.canPrev },
        { key: "playPause", glyph: view.playing ? "󰏤" : "󰐊", primary: true,
          on: false, enabled: true },
        { key: "next",      glyph: "󰒭", primary: false,
          on: false, enabled: view.canNext },
        { key: "loop",      glyph: view.loop === "Track" ? "󰑘" : "󰑖", primary: false,
          on: view.loop !== "None", enabled: true }
      ]

      Item {
        required property var modelData

        // One box for every button, so the three glyph sizes do not shuffle the
        // spacing between them. Only the circle inside changes size.
        width: Style.space(48)
        height: Style.space(48)

        Rectangle {
          anchors.centerIn: parent
          width: modelData.primary ? Style.space(42) : Style.space(32)
          height: width
          radius: width / 2
          color: {
            if (modelData.primary) {
              return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b,
                             hover.containsMouse ? 0.3 : 0.2)
            }
            if (hover.containsMouse && modelData.enabled) {
              return Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                             view.launcher.foreground.b, 0.1)
            }
            return "transparent"
          }
        }

        Text {
          anchors.centerIn: parent
          text: modelData.glyph
          color: {
            if (modelData.primary) return Color.accent
            if (modelData.on) return Color.accent
            return view.launcher.foreground
          }
          // A control the player says it cannot do is dimmed rather than
          // hidden, so the row does not reflow as tracks change.
          opacity: modelData.enabled ? (modelData.on ? 1 : 0.75) : 0.25
          font.family: view.launcher.fontFamily
          font.pixelSize: modelData.primary ? Style.font.display : Style.font.title
        }

        // The dot every player puts under an active toggle.
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(6)
          width: Style.space(4)
          height: width
          radius: width / 2
          visible: modelData.on
          color: Color.accent
        }

        MouseArea {
          id: hover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            if (!modelData.enabled) return
            if (!view.track || !view.track.controls) return
            view.run(view.track.controls[modelData.key])
          }
        }
      }
    }
  }
}
