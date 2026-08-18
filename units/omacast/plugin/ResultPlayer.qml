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
  id: view

  required property var launcher

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

  readonly property real fraction: view.lengthSeconds > 0 ? view.position / view.lengthSeconds : 0

  onReportedProgressChanged: view.drift = 0

  function clock(seconds) {
    var total = Math.max(0, Math.round(seconds))
    var minutes = Math.floor(total / 60)
    var rest = total % 60
    return minutes + ":" + (rest < 10 ? "0" : "") + rest
  }

  function run(command) {
    if (!command) return
    Util.execDetached(String(command))
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

  Row {
    id: controls
    anchors.left: details.left
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(16)
    spacing: Style.space(10)

    Repeater {
      model: [
        { glyph: "󰒮", key: "prev", size: Style.font.title, primary: false },
        { glyph: view.playing ? "󰏤" : "󰐊", key: "playPause", size: Style.font.displayLarge, primary: true },
        { glyph: "󰒭", key: "next", size: Style.font.title, primary: false }
      ]

      Item {
        required property var modelData

        width: modelData.primary ? Style.space(44) : Style.space(34)
        height: width

        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: modelData.primary
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, hover.containsMouse ? 0.28 : 0.18)
            : (hover.containsMouse
               ? Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g, view.launcher.foreground.b, 0.1)
               : "transparent")
        }

        Text {
          anchors.centerIn: parent
          text: modelData.glyph
          color: modelData.primary ? Color.accent : view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: modelData.size
        }

        MouseArea {
          id: hover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (!view.track || !view.track.controls) return
            view.run(view.track.controls[modelData.key])
          }
        }
      }
    }
  }
}
