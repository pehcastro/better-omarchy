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
// Keyboard, because this is a launcher:
//
//   up, down    the rows, as everywhere else
//   ↵           play or pause
//   ⇧↵          stop
//   ←  →        volume down and up, applied on the press
//   ctrl+K      the rest: mute, copy the stream, open the homepage
//
// This was a ring you moved along the five buttons with left and right, which
// Enter then pressed. It went in because it looked like a keyboard cursor
// should look, and it came out because it could not be made honest. Enter runs
// `row.actions[0]`, so arming a control meant writing that control into the
// row's own action list from here, and two things follow from that. The footer
// reads the same list through `currentActions()`, a function whose binding does
// not re-evaluate when a nested object is mutated, so the footer went on saying
// "Pause" while the ring sat on Stop. And a change handler and a property
// binding have no defined order between them, so on any refresh the write could
// land on the row array that was being replaced rather than the one Enter would
// read, leaving the ring somewhere and Enter somewhere else.
//
// A launcher cannot afford either of those. So the keys map onto the actions
// the script already publishes, in the order the launcher already runs them,
// and nothing here writes a control into a row. ⇧↵ is the launcher's own second
// action; the script puts Stop second for exactly that reason. The reward is
// that the footer is right for free: it reads "↵ Pause" and "⇧↵ Stop" off the
// same list the keys run, so the labels cannot drift from the behaviour.
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

  readonly property var realPlayer: view.playerIndex >= 0
    ? view.launcher.rows[view.playerIndex] : null

  // A player drawn from the station that was just started, standing in until
  // the script has been asked about it. See startStation for why it exists.
  property var optimistic: null

  readonly property var player: {
    if (view.optimistic === null) return view.realPlayer
    if (view.realPlayer === null) return view.optimistic
    // A player still reporting the station you just left is not an answer to
    // the key you pressed, so the stand-in holds until the script names the new
    // one. Changing station is the case this covers: there is a real player row
    // throughout, and it is briefly about the wrong station.
    if (String(view.realPlayer.station || "") !== String(view.optimistic.station || "")) {
      return view.optimistic
    }
    return view.realPlayer
  }

  readonly property bool hasPlayer: view.player !== null
  // The panel only counts as selected when there is a real row under the
  // selection. The stand-in is not in `launcher.rows` and cannot be pointed at.
  readonly property bool playerSelected: view.playerIndex >= 0
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
  // Negative while there is nothing to report, so a stream that has not opened
  // yet says nothing about its volume rather than claiming to be at zero.
  readonly property int volume: view.hasPlayer && view.player.volume !== undefined
    ? Number(view.player.volume) : -1

  readonly property int panelHeight: view.hasPlayer ? Style.space(118) : 0
  readonly property int rowHeight: Style.space(58)

  // ---------------------------------------------------------- the transport
  //
  // The five things a stream can do, in the order you reach for them. Drawn,
  // and clickable, and nothing else: which of them the keyboard reaches is
  // decided by the launcher's own action list, not by a cursor kept here.
  readonly property var transport: [
    { key: "playPause", glyph: view.paused ? "󰐊" : "󰏤", primary: true,  danger: false, on: false },
    // Stop is as large as play and drawn in the warning colour. It is the
    // control whose absence caused this rewrite, so it is not a small grey
    // glyph at the end of a row.
    { key: "stop",       glyph: "󰓛", primary: true,  danger: true,  on: false },
    { key: "volumeDown", glyph: "󰝞", primary: false, danger: false, on: false },
    { key: "volumeUp",   glyph: "󰝝", primary: false, danger: false, on: false },
    { key: "mute",       glyph: "󰝟", primary: false, danger: false, on: view.muted }
  ]

  function control(key) {
    var row = view.player
    if (!row || !row.controls) return ""
    return String(row.controls[key] || "")
  }

  // Left and right, from the launcher's key handler.
  //
  // The volume, applied on the press rather than moving a cursor towards it.
  // Nothing else in this view uses left or right, so they never fight the list,
  // and they answer from any row: the volume chip is on screen whichever row is
  // selected, so the feedback is visible wherever you are when you press.
  property double lastNudge: 0

  function nudge(delta) {
    if (!view.hasPlayer) return

    // Held down, an arrow key repeats about twenty-five times a second, and
    // each one of these is a shell that has to read the volume back before it
    // can change it. Eight a second is a bound rather than a race, and at five
    // points a step it still crosses the whole range in about two seconds.
    var at = Date.now()
    if (at - view.lastNudge < 120) return
    view.lastNudge = at

    view.run(view.control(delta > 0 ? "volumeUp" : "volumeDown"))
  }

  // ----------------------------------------------------- starting a station
  //
  // Whether the selection should land on the player as soon as there is one.
  property bool claimSelection: false

  function startStation(row) {
    if (!row) return

    // Draw a player now, from what the row already says, and let the script
    // correct it. Enter on a station used to leave the card looking untouched
    // for over a second: the launcher's follow-up after an action does not fire
    // for 900ms, and this extension debounces for another 250 on top of that.
    // The press had worked. Nothing said so, which is indistinguishable from a
    // press that did nothing.
    //
    // Connecting is not a guess. It is the state the script itself reports for
    // the same moment, from the state file, before mpv has opened the stream.
    view.optimistic = {
      kind: "player",
      title: String(row.title || ""),
      subtitle: String(row.subtitle || ""),
      station: String(row.title || ""),
      art: String(row.art || ""),
      iconGlyph: String(row.iconGlyph || ""),
      status: "Connecting",
      muted: false,
      elapsedSeconds: 0,
      controls: null
    }

    // The cursor follows what you just did. Without this it stays on the
    // station row while a new row appears above it, and then the launcher's own
    // follow-up resets it to the top a second later: two moves, neither of them
    // asked for. One move, onto the thing you can now control, and `select`
    // pins it by key so later refreshes leave it alone.
    view.claimSelection = true

    Util.execDetached(String(row.exec || ""))
    settle.restart()
    stub.restart()
  }

  function starter(row) {
    return function () { view.startStation(row) }
  }

  // Re-hang everything that lives on the rows, and reconcile the stand-in.
  //
  // Read `view.launcher.rows` here rather than the `player` binding: a change
  // handler and a binding have no defined order between them, so the binding
  // may still be pointing at the array this signal is announcing the end of.
  // That is not theoretical, it is what made the old ring press the wrong
  // control.
  function sync() {
    var rows = view.launcher.rows
    var at = -1

    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      if (String(row.kind || "") === "player") { at = i; continue }

      // `runAction` prefers an action's `run` over its `exec` and calls it
      // through Qt.callLater, which is the only place in the launcher that
      // fires at the moment of the keypress. Hanging a function there is what
      // lets the panel appear immediately. If it ever fails to attach the
      // action's `exec` still starts the station, so the worst case is the
      // delay this was written to remove and not a key that does nothing.
      if (row.exec && row.actions && row.actions.length > 0) {
        row.actions[0].run = view.starter(row)
      }
    }

    if (at < 0) return

    if (view.optimistic !== null
        && String(rows[at].station || "") === String(view.optimistic.station || "")) {
      view.optimistic = null
    }

    if (view.claimSelection) {
      view.claimSelection = false
      var target = at
      Qt.callLater(function () { view.launcher.select(target) })
    }
  }

  Connections {
    target: view.launcher
    function onRowsChanged() { view.sync() }
  }

  Component.onCompleted: view.sync()

  Timer {
    id: stub
    // A stream that never opens must not leave Connecting on screen for the
    // rest of the session. mpv dying takes the state file with it, so the
    // script simply stops reporting a player and there is nothing left to
    // correct the stand-in with.
    interval: 8000
    onTriggered: view.optimistic = null
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

        // Not cached, for the reason spelled out in ResultFiles.qml: Qt keeps
        // every decoded image by URL for the life of the process, and this is
        // one new logo per station.
        cache: false
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
            text: view.muted ? "muted" : (view.volume >= 0 ? "vol " + view.volume : "")
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
      // Lifted by half the legend beneath it, so the buttons and their key line
      // sit centred as one block rather than the buttons alone.
      anchors.verticalCenterOffset: -Style.space(7)
      spacing: Style.space(2)

      Repeater {
        model: view.transport

        Item {
          id: button

          required property var modelData
          readonly property bool primary: button.modelData.primary === true
          // Nothing to press while the stream is still opening, so the row is
          // dimmed rather than offering buttons that do nothing.
          readonly property bool live: view.control(button.modelData.key) !== ""

          // One box for every button, so the glyph sizes do not shuffle the
          // spacing between them. Only the circle inside changes size.
          width: Style.space(38)
          height: Style.space(38)
          opacity: button.live ? 1 : 0.35

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
            onClicked: view.run(view.control(button.modelData.key))
          }
        }
      }
    }

    // The one key nothing else says.
    //
    // Because the scheme is the launcher's own action list, the footer already
    // reads "↵ Pause" and "⇧↵ Stop" whenever this row is selected, and
    // repeating them here would be two labels saying the same thing a hand's
    // width apart. Left and right are the exception: the footer only spells
    // those out for the slider view, so they are spelled out here, under the
    // two buttons they move.
    Text {
      // Bounded by the buttons on both sides, so a wider font elides the line
      // rather than running it back across the track name.
      anchors.left: transport.left
      anchors.right: transport.right
      anchors.rightMargin: Style.space(4)
      anchors.top: transport.bottom
      anchors.topMargin: Style.space(2)
      horizontalAlignment: Text.AlignRight
      visible: view.playerIndex >= 0
      text: "←→ volume"
      color: Qt.darker(view.launcher.foreground, 2.6)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
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
      // From modelData, not from itself. `station.box.row` reads its own value
      // to define its own value: it evaluates to undefined and every station
      // drew as an empty block, which read as a list that never finished
      // loading.
      readonly property var box: station.modelData.row
      readonly property int at: station.modelData.at

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

          // Not cached, for the reason spelled out in ResultFiles.qml. A
          // search over Radio Browser draws a logo for every station in the
          // list, and the next search draws a different set.
          cache: false
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
