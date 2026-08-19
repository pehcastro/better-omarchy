import QtQuick
import qs.Commons
import qs.Ui

// A radio, and the dial you turn it with.
//
// `radio:` used to answer with a list of stations whose Enter ran mpv detached
// and closed the launcher. That is not a radio, it is a way of starting one:
// there was nothing that said what was on, nothing that could stop it, and a
// second press started a second station over the first. Someone ended up with
// four of them playing at once and had to have them killed by hand.
//
// So the answer to `radio:` is one thing, not two screens. A station playing
// puts a player at the top; the stations stay underneath it either way. You can
// see what is on and change to something else without retyping the question,
// and Stop is on the card rather than three keystrokes away in a panel.
//
// It is not the Spotify player with different words. A live stream has no
// length, no position you can move to, no next and no previous, so there is no
// scrubber and no transport: drawing a progress bar that can never fill, or a
// skip button that can never do anything, is worse than not drawing it. What a
// radio does have is pause, stop, and volume, and those are what is here. The
// clock is time spent listening, which is the only elapsed number that means
// anything on a stream with no beginning.
//
// Rows carry:
//   kind      "player" for the one at the top, "station" for the rest
//   status    Connecting | Buffering | Playing | Paused
//   station volume muted elapsedSeconds
//   controls  { playPause, stop, mute, volumeUp, volumeDown }
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

  // The player is only ever the first row, and only when the script put one
  // there. Nothing playing means this whole block is absent and the stations
  // start at the top, which is the same view drawing one thing less rather
  // than a second view to switch to.
  readonly property var player: {
    var rows = view.launcher.rows
    if (rows.length === 0) return null
    return String(rows[0].kind || "") === "player" ? rows[0] : null
  }

  readonly property bool hasPlayer: view.player !== null
  // How far the launcher's selection is ahead of this list's own index.
  readonly property int offset: view.hasPlayer ? 1 : 0
  readonly property var stations: view.launcher.rows.slice(view.offset)

  readonly property string status: view.hasPlayer ? String(view.player.status || "") : ""
  readonly property bool paused: view.status === "Paused"
  readonly property bool connecting: view.status === "Connecting"
  readonly property bool muted: view.hasPlayer && view.player.muted === true
  readonly property int volume: view.hasPlayer ? Number(view.player.volume || 0) : 0

  readonly property int panelHeight: view.hasPlayer ? Style.space(118) : 0
  readonly property int rowHeight: Style.space(58)

  // Seconds since the reading, added to it. The script reports a position at
  // the moment it ran; re-running it every second to move a number would be
  // absurd, so the clock runs here and the next real reading corrects it.
  property real drift: 0
  readonly property real reported: view.hasPlayer ? Number(view.player.elapsedSeconds || 0) : 0
  onReportedChanged: view.drift = 0

  readonly property int elapsed: Math.max(0, Math.round(view.reported + view.drift))

  // Whole rows only. A row cut through the middle at the bottom edge reads as a
  // rendering fault rather than as "the list goes on".
  readonly property int shown: {
    var wanted = Math.min(view.stations.length, Math.max(1, view.launcher.maxRows - 2))
    if (view.maxHeight <= 0) return wanted
    var room = view.maxHeight - view.panelHeight
    return Math.max(0, Math.min(wanted, Math.floor(room / view.rowHeight)))
  }

  implicitHeight: view.panelHeight + view.shown * view.rowHeight

  function clock(seconds) {
    var total = Math.max(0, Math.round(seconds))
    var minutes = Math.floor(total / 60)
    var rest = total % 60
    if (minutes < 60) return minutes + ":" + (rest < 10 ? "0" : "") + rest
    var hours = Math.floor(minutes / 60)
    var mins = minutes % 60
    return hours + ":" + (mins < 10 ? "0" : "") + mins + ":" + (rest < 10 ? "0" : "") + rest
  }

  // Run a control, then ask again. mpv applies pause and volume immediately but
  // this view only learns about it by re-running the script, so without the
  // follow-up the button keeps drawing the old state and reads as a button that
  // does not work. Stop is the one that matters most: the player has to
  // disappear on the press, not on the next tick.
  function run(command) {
    if (!command) return
    Util.execDetached(String(command))
    settle.restart()
  }

  Timer {
    id: settle
    interval: 240
    repeat: true
    property int round: 0
    onTriggered: {
      round += 1
      view.launcher.refresh()
      if (round >= 3) { round = 0; stop() }
    }
  }

  // Keep up with the stream while the player is on screen. Three seconds rather
  // than one, because what changes here is the track name a station announces
  // every few minutes, not a position that moves. It only runs when there is a
  // player: browsing stations with nothing playing should cost nothing.
  Timer {
    interval: 3000
    running: view.hasPlayer && view.launcher.opened
    repeat: true
    onTriggered: view.launcher.refresh()
  }

  Timer {
    interval: 1000
    running: view.hasPlayer && !view.paused && !view.connecting
    repeat: true
    onTriggered: view.drift += 1
  }

  // ------------------------------------------------------------ the player

  Item {
    id: panel
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: view.panelHeight
    visible: view.hasPlayer

    readonly property bool selected: view.hasPlayer && view.launcher.selectedIndex === 0

    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.space(8)
      radius: Style.cornerRadius
      color: panel.selected
        ? view.launcher.selectedBackground
        : Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                  view.launcher.foreground.b, 0.06)
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onEntered: view.launcher.select(0)
      onClicked: view.launcher.activate(view.player)
    }

    // The station's own picture. Most of radio-browser carries one and it is
    // how you recognise a station you have played before, so it is here at a
    // size worth looking at rather than as a 20px favicon.
    Rectangle {
      id: logo
      width: Style.space(70)
      height: width
      radius: Math.max(2, Style.cornerRadius / 2)
      color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                     view.launcher.foreground.b, 0.07)
      anchors.left: parent.left
      anchors.leftMargin: Style.space(22)
      anchors.verticalCenter: parent.verticalCenter
      clip: true

      Image {
        anchors.fill: parent
        anchors.margins: Style.space(6)
        source: String((view.player && view.player.art) || "")
        fillMode: Image.PreserveAspectFit
        sourceSize.width: width * Screen.devicePixelRatio
        sourceSize.height: height * Screen.devicePixelRatio
        asynchronous: true
      }

      Text {
        anchors.centerIn: parent
        visible: String((view.player && view.player.art) || "") === ""
        text: String((view.player && view.player.iconGlyph) || "")
        color: Qt.darker(view.launcher.foreground, 1.7)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.display
      }
    }

    // Bounded left and right by the two things that must not move, and clipped,
    // so a long track name is cut rather than running under the buttons.
    Item {
      id: details
      anchors.left: logo.right
      anchors.leftMargin: Style.space(16)
      anchors.right: transport.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      height: stack.implicitHeight
      clip: true

      Column {
        id: stack
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(3)

        Row {
          spacing: Style.space(6)

          Chip {
            // Connecting and Buffering are real states worth saying, not
            // errors. A stream takes a second or two to open and a listener who
            // is told nothing assumes the button did not work.
            text: view.status
            accented: view.status === "Playing"
            foreground: view.launcher.foreground
            fontFamily: view.launcher.fontFamily
          }

          Chip {
            text: view.muted ? "muted" : ("vol " + view.volume)
            accented: view.muted
            tint: Color.urgent
            foreground: view.launcher.foreground
            fontFamily: view.launcher.fontFamily
          }

          Chip {
            // Time spent listening. A stream has no length and no position, so
            // this is the only elapsed number that is true.
            text: view.elapsed > 0 ? view.clock(view.elapsed) : ""
            foreground: view.launcher.foreground
            fontFamily: view.launcher.fontFamily
          }
        }

        Text {
          width: parent.width
          text: String((view.player && view.player.title) || "")
          color: panel.selected ? view.launcher.selectedText : view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: text.length > 26 ? Style.font.title : Style.font.display
          font.bold: true
          elide: Text.ElideRight
        }

        // What is playing under the name of what is playing it. While the
        // stream is still opening there is genuinely no answer to this yet, so
        // the line is held by a placeholder: an empty gap here looks like a
        // station that reports nothing, which is a different and permanent
        // thing.
        Item {
          width: parent.width
          height: Style.space(16)

          Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !view.connecting
            text: String((view.player && view.player.subtitle) || "")
            color: Qt.darker(view.launcher.foreground, 1.5)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }

          Skeleton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(140)
            height: Style.space(10)
            radius: Style.space(3)
            tint: view.launcher.foreground
            visible: view.connecting
          }
        }
      }
    }

    // Pause, stop, and the volume. Everything a stream can actually do, in the
    // order you reach for it.
    Row {
      id: transport
      anchors.right: parent.right
      anchors.rightMargin: Style.space(18)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Repeater {
        model: [
          { key: "playPause", glyph: view.paused ? "󰐊" : "󰏤", size: "primary", danger: false, on: false },
          // Stop is deliberately as large as play and drawn in the warning
          // colour on hover. It is the control whose absence caused this
          // rewrite, so it is not a small grey glyph at the end of a row.
          { key: "stop",       glyph: "󰓛", size: "primary", danger: true,  on: false },
          { key: "volumeDown", glyph: "󰝞", size: "small",   danger: false, on: false },
          { key: "volumeUp",   glyph: "󰝝", size: "small",   danger: false, on: false },
          { key: "mute",       glyph: "󰝟", size: "small",   danger: false, on: view.muted }
        ]

        Item {
          id: button

          required property var modelData
          readonly property bool primary: button.modelData.size === "primary"

          // One box for every button, so the glyph sizes do not shuffle the
          // spacing between them. Only the circle inside changes size.
          width: Style.space(38)
          height: Style.space(38)

          Rectangle {
            anchors.centerIn: parent
            width: button.primary ? Style.space(34) : Style.space(28)
            height: width
            radius: width / 2
            color: {
              var tint = button.modelData.danger ? Color.urgent : Color.accent
              if (button.primary) {
                return Qt.rgba(tint.r, tint.g, tint.b, hover.containsMouse ? 0.32 : 0.18)
              }
              if (hover.containsMouse) {
                return Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                               view.launcher.foreground.b, 0.12)
              }
              return "transparent"
            }
          }

          Text {
            anchors.centerIn: parent
            text: button.modelData.glyph
            color: {
              if (button.modelData.danger) return Color.urgent
              if (button.primary || button.modelData.on) return Color.accent
              return view.launcher.foreground
            }
            opacity: button.modelData.on ? 1 : 0.85
            font.family: view.launcher.fontFamily
            font.pixelSize: button.primary ? Style.font.title : Style.font.heading
          }

          // The dot every player puts under an active toggle.
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(4)
            width: Style.space(4)
            height: width
            radius: width / 2
            visible: button.modelData.on
            color: Color.accent
          }

          MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (!view.player || !view.player.controls) return
              view.run(view.player.controls[button.modelData.key])
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------- the stations

  ListView {
    id: list
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: panel.visible ? panel.bottom : parent.top
    height: view.shown * view.rowHeight
    visible: view.shown > 0
    clip: true
    focus: false
    // The player is index 0 when there is one, so this list is offset by it.
    currentIndex: view.launcher.selectedIndex - view.offset
    highlightMoveDuration: 0
    model: view.stations

    delegate: Item {
      id: station

      required property var modelData
      required property int index

      width: list.width
      height: view.rowHeight

      readonly property bool selected: (station.index + view.offset) === view.launcher.selectedIndex
      // The one already on. It is the row you are least likely to want to press
      // and the one you most want to find, so it is marked rather than being
      // identical to the nine it is not.
      readonly property bool onAir: view.hasPlayer
        && String(station.modelData.title || "") === String(view.player.station || "")

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        anchors.topMargin: Style.space(2)
        anchors.bottomMargin: Style.space(2)
        radius: Style.cornerRadius
        color: station.selected ? view.launcher.selectedBackground : "transparent"
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: view.launcher.select(station.index + view.offset)
        onClicked: view.launcher.activate(station.modelData)
      }

      Rectangle {
        id: badge
        width: Style.space(38)
        height: width
        radius: Math.max(2, Style.cornerRadius / 2)
        color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                       view.launcher.foreground.b, 0.07)
        anchors.left: parent.left
        anchors.leftMargin: Style.space(22)
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        Image {
          anchors.fill: parent
          anchors.margins: Style.space(4)
          source: String(station.modelData.art || "")
          fillMode: Image.PreserveAspectFit
          sourceSize.width: width * Screen.devicePixelRatio
          sourceSize.height: height * Screen.devicePixelRatio
          asynchronous: true
        }

        Text {
          anchors.centerIn: parent
          visible: String(station.modelData.art || "") === ""
          text: String(station.modelData.iconGlyph || "")
          color: Qt.darker(view.launcher.foreground, 1.8)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
        }
      }

      Column {
        anchors.left: badge.right
        anchors.leftMargin: Style.space(12)
        anchors.right: tail.left
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
          width: parent.width
          text: String(station.modelData.title || "")
          color: station.selected ? view.launcher.selectedText : view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          visible: text !== ""
          text: {
            var where = String(station.modelData.subtitle || "")
            var what = String(station.modelData.detail || "")
            if (where !== "" && what !== "") return where + "  ·  " + what
            return where !== "" ? where : what
          }
          color: Qt.darker(view.launcher.foreground, 1.8)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Item {
        id: tail
        anchors.right: parent.right
        anchors.rightMargin: Style.space(22)
        anchors.verticalCenter: parent.verticalCenter
        width: onAirChip.visible ? onAirChip.implicitWidth : votes.implicitWidth
        height: Style.space(20)

        Chip {
          id: onAirChip
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          visible: station.onAir
          text: "on air"
          accented: true
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }

        Text {
          id: votes
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          visible: !station.onAir
          text: String(station.modelData.accessory || "")
          color: Qt.darker(view.launcher.foreground, 2.1)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
