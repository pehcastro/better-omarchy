import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.Commons
import qs.Ui
import "Query.js" as Query
import "Rank.js" as Rank
import "Score.js" as Score
import "Calc.js" as Calc
import "Commands.js" as Commands

// OmarchyCast: one box that answers with apps, arithmetic, Omarchy commands, or
// the web.
//
// The shell injects `shell`, `manifest` and `omarchyPath` by name, calls
// open(payloadJson) and close(), and reads `opened`. `keepLoaded: true` in the
// manifest keeps this instance alive between summons, so close() has to reset
// state and stop background work; nothing here is constructed fresh.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string queryText: ""
  property int selectedIndex: 0
  property bool cursorMoved: false
  property string selectedKey: ""

  // Bumped on every keystroke. Every async result carries the epoch it was
  // asked for and is dropped when it no longer matches, so a slow process
  // cannot repopulate the list two keystrokes later.
  property int epoch: 0

  // providerId -> { epoch, text, rows }
  property var buckets: ({})
  property var rows: []

  // Enter pressed on a placeholder row. The engine fires it once the real row
  // arrives, so typing 1+1 and hitting Enter never launches an app instead.
  property string pendingActivate: ""

  readonly property var appLibrary: root.shell ? root.shell.appLibrary : null

  // The [menu] surface tokens, so a theme that styles the Omarchy menu styles
  // this too, with no extra work from the user.
  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color scrim: Color.menu.scrim
  readonly property color selectedBackground: Color.menu.selectedBackground
  readonly property color selectedText: Color.menu.selectedText
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
  readonly property string fontFamily: Style.font.menuFamily

  readonly property int cardWidth: Math.min(Style.space(620), panel.width - Style.gapsOut * 2)
  readonly property int rowHeight: Style.space(44)
  readonly property int maxRows: 9

  // ------------------------------------------------------------ lifecycle

  function open(payloadJson) {
    pinScreen()
    root.opened = true
    root.queryText = ""
    root.pendingActivate = ""
    resetSelection()
    setQuery("")
    if (root.appLibrary) root.appLibrary.refreshIcons()
    Qt.callLater(function () {
      input.forceActiveFocus()
      input.selectAll()
    })
  }

  function close() {
    root.opened = false
    calc.cancel()
    root.buckets = ({})
    root.rows = []
    root.pendingActivate = ""
  }

  function toggle() {
    if (root.opened) dismiss()
    else open("")
  }

  // Tell the shell, do not just hide. It tracks open panels in its own set, and
  // a close that skips this leaves the entry stale, so the next toggle inverts.
  function dismiss() {
    close()
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide((root.manifest && root.manifest.id) || "bo.omarchycast")
    }
  }

  // A bare PanelWindow binds to Quickshell.screens[0], not the focused output.
  // Pin before `opened` goes true: reassigning `screen` on a mapped layer
  // surface recreates it and drops the keyboard grab.
  function pinScreen() {
    var monitor = Hyprland.focusedMonitor
    if (!monitor) return

    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (String(screens[i].name) === String(monitor.name)) {
        panel.screen = screens[i]
        return
      }
    }
  }

  // ------------------------------------------------------------ querying

  function setQuery(text) {
    root.queryText = text
    var query = Query.parse(text, ++root.epoch)

    queryApps(query)
    queryCommands(query)
    queryWeb(query)
    calc.run(query)

    rebuild()
  }

  function put(providerId, query, producedRows) {
    if (query.epoch !== root.epoch) return
    var next = root.buckets
    next[providerId] = { epoch: query.epoch, text: query.text, rows: producedRows }
    root.buckets = next
  }

  function rebuild() {
    var query = Query.parse(root.queryText, root.epoch)
    root.rows = Rank.merge(root.buckets, query.mode, 60)

    if (!root.cursorMoved) {
      root.selectedIndex = 0
    } else {
      var at = Rank.indexOfKey(root.rows, root.selectedKey)
      root.selectedIndex = at >= 0 ? at : 0
    }
    root.selectedKey = root.rows.length > 0 ? root.rows[root.selectedIndex].key : ""

    // A queued Enter fires as soon as its placeholder resolves.
    if (root.pendingActivate !== "") {
      var index = Rank.indexOfKey(root.rows, root.pendingActivate)
      if (index >= 0 && !root.rows[index].pending) {
        var target = root.pendingActivate
        root.pendingActivate = ""
        activate(root.rows[index])
        return
      }
    }
  }

  function resetSelection() {
    root.selectedIndex = 0
    root.cursorMoved = false
    root.selectedKey = ""
  }

  // ------------------------------------------------------------ providers

  function queryApps(query) {
    if (!Query.routesTo(query, "apps") || query.empty || !root.appLibrary) {
      return put("apps", query, [])
    }

    var found = root.appLibrary.sortedEntries(query.text)
    var out = []
    for (var i = 0; i < found.length && i < 20; i++) {
      var entry = found[i].entry
      out.push({
        key: "app:" + entry.id,
        providerId: "apps",
        group: "Applications",
        title: root.appLibrary.entryName(entry),
        subtitle: root.appLibrary.entrySubtext(entry),
        accessory: "",
        iconSource: root.appLibrary.iconSource(entry.icon),
        iconGlyph: "",
        score: Rank.score(Rank.tierFor(found[i].score), Rank.local(found[i].score), 0),
        pending: false,
        run: (function (id, name) {
          return function () { root.appLibrary.launch(id, name) }
        })(entry.id, root.appLibrary.entryName(entry))
      })
    }
    put("apps", query, out)
  }

  function queryCommands(query) {
    if (!Query.routesTo(query, "commands") || query.empty) {
      return put("commands", query, [])
    }

    var out = []
    for (var i = 0; i < Commands.COMMANDS.length; i++) {
      var command = Commands.COMMANDS[i]
      var fuzzy = Score.fuzzy(Commands.asEntry(command), query.text)
      if (fuzzy < 0) continue

      out.push({
        key: "cmd:" + command.id,
        providerId: "commands",
        group: "Commands",
        title: command.title,
        subtitle: command.subtitle,
        accessory: "",
        iconSource: "",
        iconGlyph: command.glyph,
        // A command beats an app only at equal match quality: the bias moves it
        // inside a tier and can never lift it into a higher one. Typing "the"
        // puts Change Theme above Thunderbird; typing "thun" still puts
        // Thunderbird first, because a name prefix outranks a substring.
        score: Rank.score(Rank.tierFor(fuzzy), Rank.local(fuzzy), 3000),
        pending: false,
        run: (function (exec) {
          return function () { Util.execDetached(exec) }
        })(command.exec)
      })
    }
    put("commands", query, out)
  }

  function queryWeb(query) {
    if (!Query.routesTo(query, "web") || query.empty) {
      return put("web", query, [])
    }

    var text = query.text
    put("web", query, [{
      key: "web:" + text,
      providerId: "web",
      group: "Web",
      title: "Search the web for “" + text + "”",
      subtitle: "DuckDuckGo",
      accessory: "",
      iconSource: "",
      iconGlyph: "",
      score: Rank.score(Rank.TIER.web, 0, 0),
      pending: false,
      run: function () {
        Util.execDetached("omarchy-launch-browser " + Util.shellQuote(
          "https://duckduckgo.com/?q=" + encodeURIComponent(text)))
      }
    }])
  }

  // ------------------------------------------------------------ activation

  function activate(row) {
    if (!row) return

    if (row.pending) {
      // Hold Enter until the real answer replaces this placeholder.
      root.pendingActivate = row.key
      return
    }

    // Dismiss before running. Launching while an exclusive-focus layer surface
    // is still mapped puts the new window behind it, and Omarchy's launch OSD
    // would render underneath this overlay.
    var action = row.run
    dismiss()
    if (typeof action === "function") Qt.callLater(action)
  }

  function move(delta) {
    if (root.rows.length === 0) return
    root.cursorMoved = true
    root.selectedIndex = Math.max(0, Math.min(root.rows.length - 1, root.selectedIndex + delta))
    root.selectedKey = root.rows[root.selectedIndex].key
  }

  // ------------------------------------------------------------ calculator

  QtObject {
    id: calc

    // qalc costs about 40ms cold, which is long enough to matter per keystroke
    // but short enough that a 90ms debounce hides it entirely.
    property int inflightEpoch: -1
    property int pendingEpoch: -1
    property string pendingText: ""

    function run(query) {
      if (!Query.routesTo(query, "calc") || query.empty) {
        cancel()
        return root.put("calc", query, [])
      }

      if (query.mode !== "calc" && !Calc.looksLikeMath(query.text)) {
        cancel()
        return root.put("calc", query, [])
      }

      // Synchronous placeholder, scored to the top, so Enter cannot fall
      // through to an app while qalc is still running.
      var row = Calc.placeholder(query.text)
      row.score = Rank.score(Rank.TIER.calc, 0, 0)
      root.put("calc", query, [row])

      calc.pendingEpoch = query.epoch
      calc.pendingText = query.text
      debounce.restart()
    }

    function cancel() {
      calc.pendingEpoch = -1
      debounce.stop()
      if (process.running) process.running = false
    }

    function start() {
      if (calc.pendingEpoch < 0) return
      calc.inflightEpoch = calc.pendingEpoch
      calc.pendingEpoch = -1
      // -m bounds the calculation: qalc will otherwise chew on a pathological
      // expression for as long as it takes.
      process.command = ["qalc", "-t", "-m", "200", "--", calc.pendingText]
      process.running = true
    }

    function finish(text) {
      if (calc.inflightEpoch !== root.epoch) return

      var query = Query.parse(root.queryText, root.epoch)
      var row = Calc.parse(calc.pendingText, text)
      if (!row) return root.put("calc", query, [])

      row.score = Rank.score(Rank.TIER.calc, 0, 0)
      row.run = (function (answer) {
        return function () {
          Util.execDetached("printf %s " + Util.shellQuote(answer) + " | wl-copy")
        }
      })(row.title)
      root.put("calc", query, [row])
      root.rebuild()
    }

    property Timer debounceTimer: Timer {
      id: debounce
      interval: 90
      onTriggered: {
        // Setting running false sends SIGTERM; onExited then restarts with the
        // newer expression. Assigning command while running does not restart.
        if (process.running) process.running = false
        else calc.start()
      }
    }

    property Process proc: Process {
      id: process
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: calc.finish(text)
      }
      // onExited and onStreamFinished have no guaranteed order, so the payload
      // is read above and this only ever restarts.
      onExited: if (calc.pendingEpoch >= 0) Qt.callLater(calc.start)
    }
  }

  // ------------------------------------------------------------ window

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchycast"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      radius: Style.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: 0

      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(parent.height * 0.18)
      height: header.height + (root.rows.length > 0 ? list.height + Style.space(8) : 0)

      Behavior on height {
        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
      }

      // Swallow clicks so they do not reach the dismissing MouseArea behind.
      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Style.space(58)

        Text {
          id: prompt
          anchors.left: parent.left
          anchors.leftMargin: Style.space(18)
          anchors.verticalCenter: parent.verticalCenter
          text: ""
          color: Qt.darker(root.foreground, 1.6)
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        TextInput {
          id: input
          anchors.left: prompt.right
          anchors.leftMargin: Style.space(12)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(18)
          anchors.verticalCenter: parent.verticalCenter

          color: root.foreground
          selectionColor: Style.selectionFillFor(root.foreground, Color.accent)
          selectedTextColor: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          clip: true
          focus: true

          onTextChanged: {
            root.resetSelection()
            root.setQuery(text)
          }

          // BeforeItem so navigation keys never reach the editor, and everything
          // else does. Left, Right, Home, End, Backspace and the usual editing
          // chords are deliberately absent: they belong to the text cursor.
          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
              if (input.text.length > 0) input.text = ""
              else root.dismiss()
              event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab
                       || (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier))) {
              root.move(1)
              event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
                       || (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier))) {
              root.move(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_PageDown) {
              root.move(root.maxRows)
              event.accepted = true
            } else if (event.key === Qt.Key_PageUp) {
              root.move(-root.maxRows)
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.activate(root.rows[root.selectedIndex])
              event.accepted = true
            }
          }

          Text {
            anchors.fill: parent
            visible: input.text.length === 0
            verticalAlignment: Text.AlignVCenter
            text: "Search apps, do maths, run a command"
            color: Qt.darker(root.foreground, 1.8)
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }
        }
      }

      Rectangle {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.rows.length > 0 ? Math.max(1, Style.space(1)) : 0
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
      }

      ListView {
        id: list
        anchors.top: header.bottom
        anchors.topMargin: Style.space(8)
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(root.rows.length, root.maxRows) * root.rowHeight
        clip: true
        focus: false
        interactive: true
        currentIndex: root.selectedIndex
        highlightMoveDuration: 0
        model: root.rows

        delegate: Item {
          required property var modelData
          required property int index

          width: list.width
          height: root.rowHeight

          readonly property bool selected: index === root.selectedIndex

          Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            radius: Style.cornerRadius
            color: parent.selected ? root.selectedBackground : "transparent"
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            onClicked: root.activate(modelData)
          }

          Image {
            id: icon
            visible: String(modelData.iconSource || "") !== ""
            source: modelData.iconSource || ""
            width: Style.space(22)
            height: Style.space(22)
            sourceSize.width: width * Screen.devicePixelRatio
            sourceSize.height: height * Screen.devicePixelRatio
            anchors.left: parent.left
            anchors.leftMargin: Style.space(18)
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            visible: !icon.visible
            text: String(modelData.iconGlyph || "")
            color: parent.selected ? root.selectedText : Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            width: Style.space(22)
            horizontalAlignment: Text.AlignHCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.space(18)
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            id: title
            anchors.left: parent.left
            anchors.leftMargin: Style.space(52)
            anchors.right: subtitle.left
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            text: String(modelData.title || "")
            color: parent.selected ? root.selectedText : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            opacity: modelData.pending ? 0.5 : 1
            elide: Text.ElideRight
          }

          Text {
            id: subtitle
            anchors.right: parent.right
            anchors.rightMargin: Style.space(20)
            anchors.verticalCenter: parent.verticalCenter
            text: String(modelData.subtitle || "")
            color: Qt.darker(root.foreground, 1.7)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: Math.min(implicitWidth, list.width * 0.35)
          }
        }
      }
    }
  }
}
