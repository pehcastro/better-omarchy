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
// Keyboard first, because this is a launcher. Up and down walk the rows as
// they do in every other view, left and right walk the five controls, and
// Enter presses the one with the ring on it. The launcher routes left and
// right here through `nudge`; Enter arrives on its own, through the row's
// first action, which `applyArm` points at the armed control.
//
// Rows carry:
//   kind      "player" for the one at the top, "station" for the rest
//   status    Connecting | Buffering | Playing | Paused
//   station volume muted elapsedSeconds followUp
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

  // The player row, wherever it ended up.
  //
  // This looked for it at index 0 and the panel vanished the moment anything
  // was typed. The launcher does not promise an order: after `Rank.merge` the
  // rows are re-scored by frecency and by pins, both of which lift a row inside
  // its tier, and a pin is worth 20000 against the 9000 that separated the
  // player from the stations. A station you had pinned or played often
  // therefore sorted above it, the first row stopped being the player, and a
  // check on rows[0] read that as "nothing is playing". A station playing means
  // the player is on screen, so the player is found by what it is and not by
  // where it sits.
  readonly property int playerIndex: {
    var rows = view.launcher.rows
    for (var i = 0; i < rows.length; i++) {
      if (String(rows[i].kind || "") === "player") return i
    }
    return -1
  }

  readonly property var player: view.playerIndex >= 0
    ? view.launcher.rows[view.playerIndex] : null
  readonly property bool hasPlayer: view.playerIndex >= 0
  readonly property bool playerSelected: view.hasPlayer
    && view.launcher.selectedIndex === view.playerIndex

  // Everything that is not the player, each carrying the launcher index it came
  // from. A fixed offset would be wrong for the same reason rows[0] was: the
  // player is not guaranteed to be the row above them.
  readonly property var stations: {
    var out = []
    var rows = view.launcher.rows
    for (var i = 0; i < rows.length; i++) {
      if (i === view.playerIndex) continue
      out.push({ row: rows[i], at: i })
    }
    return out
  }

  readonly property string status: view.hasPlayer ? String(view.player.status || "") : ""
  readonly property bool paused: view.status === "Paused"
  readonly property bool connecting: view.status === "Connecting"
  readonly property bool muted: view.hasPlayer && view.player.muted === true
  readonly property int volume: view.hasPlayer ? Number(view.player.volume || 0) : 0

  readonly property int panelHeight: view.hasPlayer ? Style.space(118) : 0
  readonly property int rowHeight: Style.space(58)

  // ---------------------------------------------------------- the transport
  //
  // Five controls, in one list, because three things read from it: the buttons
  // drawn on the panel, the ring that says which one Enter will press, and the
  // action written into the row so that Enter presses it. Two of those used to
  // be a mouse handler and nothing else, which is why none of this worked
  // without a pointer.
  readonly property var transport: [
    { key: "playPause",  title: view.paused ? "Resume" : "Pause",
      glyph: view.paused ? "󰐊" : "󰏤", primary: true,  danger: false, on: false },
    // Stop is as large as play and drawn in the warning colour. It is the
    // control whose absence caused this rewrite, so it is not a small grey
    // glyph at the end of a row.
    { key: "stop",       title: "Stop",
      glyph: "󰓛", primary: true,  danger: true,  on: false },
    { key: "volumeDown", title: "Volume Down",
      glyph: "󰝞", primary: false, danger: false, on: false },
    { key: "volumeUp",   title: "Volume Up",
      glyph: "󰝝", primary: false, danger: false, on: false },
    { key: "mute",       title: view.muted ? "Unmute" : "Mute",
      glyph: "󰝟", primary: false, danger: false, on: view.muted }
  ]

  // Which control Enter will press. Play and pause, always, until the arrows
  // move it.
  property int armed: 0

  // Left and right, from the launcher's key handler.
  //
  // The scheme: up and down walk the rows as they do everywhere, left and right
  // walk the five controls, and Enter presses the one with the ring on it. It
  // only answers while the selection is on the player, so left and right never
  // move anything while you are picking a station, and the ring is only drawn
  // then either: a ring you cannot press would be a lie about where Enter goes.
  // The player is the first row, so reaching the controls from the list is one
  // press of Up.
  //
  // No wrapping at the ends. Wrapping saves one keypress and costs you knowing
  // where you are, and the two ends of this row are Pause and Mute, which are
  // not neighbours in any sense a listener would expect.
  function nudge(delta) {
    if (!view.playerSelected) return
    view.armed = Math.max(0, Math.min(view.transport.length - 1, view.armed + delta))
    view.applyArm()
  }

  // Point the row's first action at the armed control.
  //
  // `activate` runs `row.actions[0]` when that action carries a `query`, and it
  // reads it at the moment Enter is pressed rather than when the row was built.
  // So arming a control is writing it into that slot. The alternative was a
  // second key route in the launcher for Enter, which would have to know what a
  // radio is; this keeps the knowledge here.
  //
  // The rows array is rebuilt on every refresh, which throws this away, so it
  // is re-applied whenever the rows change rather than only when the ring
  // moves.
  function applyArm() {
    var row = view.player
    if (!row || !row.controls) return
    if (!row.actions || row.actions.length === 0) return

    var control = view.transport[view.armed]
    if (!control) return

    var exec = String(row.controls[control.key] || "")
    if (exec === "") return

    row.actions[0].title = control.title
    row.actions[0].exec = exec
    // The follow-up is what keeps the launcher here after the press. The script
    // put it on the row so this can rewrite the action without losing it.
    row.actions[0].query = String(row.followUp || "radio:")
  }

  onArmedChanged: view.applyArm()
  Component.onCompleted: view.applyArm()

  // Back to play and pause when the player goes away, so the next station does
  // not open with Stop under the ring.
  onHasPlayerChanged: if (!view.hasPlayer) view.armed = 0

  Connections {
    target: view.launcher
    function onRowsChanged() { view.applyArm() }
  }

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

    readonly property bool selected: view.playerSelected

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
      onEntered: view.launcher.select(view.playerIndex)
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
        model: view.transport

        Item {
          id: button

          required property var modelData
          required property int index
          readonly property bool primary: button.modelData.primary === true
          // Where Enter goes, drawn only while Enter can go there.
          readonly property bool armed: view.playerSelected && button.index === view.armed

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
              if (button.primary || button.armed) {
                return Qt.rgba(tint.r, tint.g, tint.b, hover.containsMouse ? 0.32 : 0.18)
              }
              if (hover.containsMouse) {
                return Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                               view.launcher.foreground.b, 0.12)
              }
              return "transparent"
            }

            // The ring, on the one Enter will press. A ring rather than a
            // brighter fill: two of these buttons are already filled because
            // they are the loud ones, and a keyboard cursor has to be legible
            // on top of whatever the button looks like anyway.
            border.width: button.armed ? Math.max(1, Style.space(2)) : 0
            border.color: button.modelData.danger ? Color.urgent : Color.accent
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
              // The pointer moves the ring too. Otherwise clicking Stop and
              // then pressing Enter would run whatever the arrows were last
              // left on, which is the sort of thing that gets a player a
              // reputation for doing the wrong thing.
              view.launcher.select(view.playerIndex)
              view.armed = button.index
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
    // Found rather than computed, because the player is not guaranteed to be
    // the row above this list even though it is drawn above it.
    currentIndex: {
      for (var i = 0; i < view.stations.length; i++) {
        if (view.stations[i].at === view.launcher.selectedIndex) return i
      }
      return -1
    }
    highlightMoveDuration: 0
    model: view.stations

    delegate: Item {
      id: station

      // Each entry is the row plus the launcher index it came from, so
      // selecting and activating speak the launcher's numbering rather than
      // this list's.
      required property var modelData
      readonly property var box: station.box.row
      readonly property int at: station.box.at

      width: list.width
      height: view.rowHeight

      readonly property bool selected: station.at === view.launcher.selectedIndex
      // The one already on. It is the row you are least likely to want to press
      // and the one you most want to find, so it is marked rather than being
      // identical to the nine it is not.
      readonly property bool onAir: view.hasPlayer
        && String(station.box.title || "") === String(view.player.station || "")

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
        onEntered: view.launcher.select(station.at)
        onClicked: view.launcher.activate(station.box)
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
          source: String(station.box.art || "")
          fillMode: Image.PreserveAspectFit
          sourceSize.width: width * Screen.devicePixelRatio
          sourceSize.height: height * Screen.devicePixelRatio
          asynchronous: true
        }

        Text {
          anchors.centerIn: parent
          visible: String(station.box.art || "") === ""
          text: String(station.box.iconGlyph || "")
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
          text: String(station.box.title || "")
          color: station.selected ? view.launcher.selectedText : view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          visible: text !== ""
          text: {
            var where = String(station.box.subtitle || "")
            var what = String(station.box.detail || "")
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
          text: String(station.box.accessory || "")
          color: Qt.darker(view.launcher.foreground, 2.1)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
