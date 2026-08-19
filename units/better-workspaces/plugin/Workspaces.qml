import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Workspace row that renders names instead of numbers, plus a rename panel
// anchored under the workspace being renamed (SUPER + F2, or right-click).
//
// Names live in this widget's shell.json entry under `names`, keyed by
// workspace id, so they survive a restart without a Hyprland reload and
// without a generated Lua file. Hyprland is renamed to match, so
// `hyprctl workspaces` stays truthful for anything that reads it.
Panel {
  id: root
  moduleName: "bo.better-workspaces"
  ipcTarget: "bo.better-workspaces"

  // Panel is a bare Item, so the two geometry properties BarWidget would
  // have supplied are lifted off the host here.
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal

  // id (as a string) -> { label: string, keepNumber: bool }
  readonly property var names: root.setting("names", ({}))

  // Workspace the open panel is editing. 0 when the panel is closed.
  property int editingId: 0
  property var editingAnchor: null

  function entryFor(id) {
    var entry = root.names[String(id)]
    if (!entry) return ({ label: "", keepNumber: false })

    // A bare string is accepted so the setting can be hand-edited.
    if (typeof entry === "string") return ({ label: entry, keepNumber: false })

    return ({ label: String(entry.label || ""), keepNumber: entry.keepNumber === true })
  }

  // WidgetButton sizes itself to its label and cannot elide, so a long name is
  // cut here instead. The full name stays in the button's tooltip.
  //
  // How much to cut depends on how much bar there is, and the first attempt at
  // this guessed: a character was assumed to be 0.62 of the font size and the
  // per-button padding was a number picked to make one screen look right. It
  // was wrong in both directions on the next screen, cutting "general" to
  // "gen…" on a desktop with room for all of it.
  //
  // So it is measured. TextMetrics reports the real advance width of the real
  // font, the padding is read off the button rather than assumed, and the
  // budget is what is left before whatever sits in the middle of the bar.
  readonly property int maxLabelCeiling: root.setting("maxLabelChars", 18)

  // The names may use this much of the bar. The clock is centred, so half is the
  // hard wall, and with the empty workspaces hidden the row is short enough to
  // go right up to it.
  readonly property real labelShare: root.setting("labelShare", 0.50)

  readonly property string barFontFamily: bar ? bar.fontFamily : Style.font.family

  TextMetrics {
    id: charProbe
    font.family: root.barFontFamily
    font.pixelSize: Style.font.body
    // Twenty characters of mixed width, so the average is an average rather
    // than the width of whichever letter was picked.
    text: "abcdefghijklmnopqrst"
  }

  readonly property real charWidth: charProbe.advanceWidth > 0
    ? charProbe.advanceWidth / 20 : Style.font.body * 0.62

  // horizontalMargin 6 either side, plus the column spacing between buttons.
  readonly property real buttonOverhead: Style.space(12) + Style.space(1)

  readonly property int namedCount: {
    var ids = root.workspaceIds()
    var n = 0
    for (var i = 0; i < ids.length; i++) {
      if (root.entryFor(ids[i]).label !== "") n += 1
    }
    return Math.max(1, n)
  }

  readonly property int maxLabelChars: {
    if (root.vertical) return root.maxLabelCeiling

    // Screen.width is already in logical pixels, the same units everything here
    // is laid out in. Dividing it by devicePixelRatio halved the budget.
    var ids = root.workspaceIds()
    var numbered = Math.max(0, ids.length - root.namedCount)

    // A numbered workspace is one or two digits plus the same padding.
    var numberedCost = numbered * (root.charWidth * 2 + root.buttonOverhead)
    var budget = Screen.width * root.labelShare - numberedCost

    var perLabel = budget / root.namedCount - root.buttonOverhead
    var chars = Math.floor(perLabel / Math.max(1, root.charWidth))

    return Math.max(4, Math.min(root.maxLabelCeiling, chars))
  }

  function truncate(text) {
    if (root.maxLabelChars < 1 || text.length <= root.maxLabelChars) return text
    return text.slice(0, root.maxLabelChars - 1).replace(/\s+$/, "") + "\u2026"
  }

  function displayName(id) {
    var entry = root.entryFor(id)
    var number = id === 10 ? "0" : String(id)

    if (entry.label === "") return number

    var label = root.truncate(entry.label)
    return entry.keepNumber ? label + " (" + number + ")" : label
  }

  function fullName(id) {
    var entry = root.entryFor(id)
    var number = id === 10 ? "0" : String(id)

    if (entry.label === "") return "Workspace " + number

    return entry.keepNumber ? entry.label + " (" + number + ")" : entry.label
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  // Show every workspace, or only the ones that are actually something.
  //
  // A row of five empty numbers is five slots of bar spent on nothing, and it
  // is why the names had to be cut: they were competing with placeholders. With
  // this on, a workspace earns its place by having a window, having a name, or
  // being the one you are looking at.
  readonly property bool hideEmpty: root.setting("hideEmpty", true)

  // A trailing button that takes you to the first free workspace. With the
  // empty ones hidden there is otherwise no way to reach one by mouse, and
  // "somewhere new" is a thing you want often enough to be one click.
  readonly property bool showNewButton: root.setting("showNewButton", true)

  // How long a workspace stays in the row after its last window closes. Without
  // this the button vanishes on the same frame as the window, which reads as
  // the bar glitching rather than as the workspace being finished with, and
  // there is nothing for the fade to fade.
  readonly property int emptyLingerMs: root.setting("emptyLingerMs", 5000)

  // id -> the moment it emptied. Absent while it still has windows.
  property var emptiedAt: ({})

  Timer {
    id: lingerTick
    running: root.hideEmpty
    interval: 400
    repeat: true
    onTriggered: {
      var now = Date.now()
      var next = root.emptiedAt
      var changed = false

      for (var id = 1; id <= 10; id++) {
        var key = String(id)
        var ws = root.workspaceById(id)
        var occupied = ws !== null && ws.toplevels.values.length > 0

        if (occupied) {
          if (next[key] !== undefined) { delete next[key]; changed = true }
        } else if (next[key] === undefined) {
          next[key] = now
          changed = true
        } else if (now - next[key] < root.emptyLingerMs + lingerTick.interval) {
          // Still inside the window, or the tick just past it. liveIds reads
          // Date.now(), which is not reactive, so the map has to be nudged on
          // every tick or the row never notices the deadline passing.
          changed = true
        }
      }

      if (changed) { root.emptiedAt = ({}); root.emptiedAt = next }
    }
  }

  function lingering(id) {
    var at = root.emptiedAt[String(id)]
    if (at === undefined) return false
    return Date.now() - at < root.emptyLingerMs
  }

  // The workspaces that have earned a place right now.
  readonly property var liveIds: {
    var ids = []
    var values = Hyprland.workspaces.values
    var active = root.activeWorkspaceId()
    var stamps = root.emptiedAt

    for (var id = 1; id <= 10; id++) {
      var ws = root.workspaceById(id)
      var occupied = ws !== null && ws.toplevels.values.length > 0
      // A name does not earn a place. The name describes what you are doing
      // there, so an empty workspace with a name is a label on nothing, and
      // leaving it in the row is what filled the bar with things to skip past.
      if (!root.hideEmpty || occupied || id === active
          || root.lingering(id)) ids.push(id)
    }

    // Never an empty row: with nothing open and nothing named there would be
    // no workspace to click, and the widget would look broken rather than tidy.
    if (ids.length === 0) ids.push(active > 0 ? active : 1)
    return ids
  }

  // Workspaces on their way out, kept in the row long enough to animate. A
  // button that disappears between two frames reads as a glitch; one that fades
  // and closes its own gap reads as the workspace being finished with.
  property var leavingIds: []

  readonly property int leaveMs: root.setting("leaveMs", 260)

  // What was live last time, so a departure can be spotted. Diffing against
  // what is drawn would read a property that already includes the change, and
  // the diff would always be empty.
  property var previousLive: []

  onLiveIdsChanged: {
    var gone = []
    for (var i = 0; i < root.previousLive.length; i++) {
      var id = root.previousLive[i]
      if (root.liveIds.indexOf(id) < 0 && root.leavingIds.indexOf(id) < 0) gone.push(id)
    }
    root.previousLive = root.liveIds.slice()
    if (gone.length === 0) return

    root.leavingIds = root.leavingIds.concat(gone)
    leaveTimer.restart()
  }

  Timer {
    id: leaveTimer
    interval: root.leaveMs
    onTriggered: root.leavingIds = []
  }

  // What the row actually draws: what is live, plus what is still leaving.
  readonly property var shownIds: {
    var ids = root.liveIds.slice()
    for (var i = 0; i < root.leavingIds.length; i++) {
      if (ids.indexOf(root.leavingIds[i]) < 0) ids.push(root.leavingIds[i])
    }
    ids.sort(function (left, right) { return left - right })
    return ids
  }

  function workspaceIds() { return root.shownIds }

  // The lowest workspace with nothing on it and no name. 0 when there is none,
  // which hides the button rather than offering somewhere that does not exist.
  function firstFreeWorkspace() {
    for (var id = 1; id <= 10; id++) {
      var ws = root.workspaceById(id)
      var occupied = ws !== null && ws.toplevels.values.length > 0
      if (!occupied && root.entryFor(id).label === "") return id
    }
    return 0
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  function activeWorkspaceId() {
    return Hyprland.focusedWorkspace !== null ? Hyprland.focusedWorkspace.id : 1
  }

  // ---------- Rename panel ----------

  function open() {
    var id = root.activeWorkspaceId()
    root.openRename(id, root.buttons[String(id)] || null)
  }

  function openRename(id, anchor) {
    if (id < 1 || id > 10) return

    var entry = root.entryFor(id)
    root.editingId = id
    root.editingAnchor = anchor
    nameField.text = entry.label
    keepNumber.checked = entry.keepNumber
    root.controller.show()
    Qt.callLater(function() { nameField.forceActiveFocus(); nameField.selectAll() })
  }

  function toggle() {
    if (root.opened) return root.close()

    var id = root.activeWorkspaceId()
    root.openRename(id, root.buttons[String(id)] || null)
  }

  function close() {
    root.editingId = 0
    root.editingAnchor = null
    root.controller.hide()
  }

  function saveRename() {
    var id = root.editingId
    if (id < 1) return root.close()

    var label = nameField.text.trim()
    var keep = keepNumber.checked
    var next = {}
    for (var key in root.names) next[key] = root.names[key]

    // Empty input clears the name, which puts the workspace back to its number.
    if (label === "") delete next[String(id)]
    else next[String(id)] = { label: label, keepNumber: keep }

    root.close()
    if (!root.bar) return

    // `omarchy bar set` rewrites shell.json and reloads every bar surface, so
    // this is what makes the name stick. The Hyprland rename only keeps
    // hyprctl in step and is not what the row reads.
    var hyprName = label === "" ? String(id) : (keep ? label + " (" + id + ")" : label)
    root.bar.run(
      "omarchy bar set bo.better-workspaces names " + Util.shellQuote(JSON.stringify(next)) + " --json" +
      " ; hyprctl dispatch " + Util.shellQuote("hl.dsp.workspace.rename({ workspace = " + id + ", name = \"" + hyprName.replace(/"/g, "") + "\" })")
    )
  }

  // A name is a plan for a workspace. When the workspace is empty and you have
  // walked away from it, the plan is over: quitting everything on "spotify" and
  // going back to "coding" should leave a free workspace behind, not a label
  // pointing at nothing.
  //
  // On a short grace period rather than immediately, because closing the last
  // window to open another one is a normal thing to do and the name should
  // survive it. Five seconds is long enough for that and short enough that the
  // workspace is gone before you wonder why it is still there.
  // Off by default, and it should stay that way. Hiding an empty workspace from
  // the bar costs the user nothing: the name is still there when they go back.
  // Deleting the name is not reversible, and somebody who names a workspace
  // "invoices" and opens it once a month would lose it the first time they
  // restarted the shell. Anyone who wants their names to be disposable can say
  // so; nobody should have to discover it.
  readonly property bool releaseEmptyNames: root.setting("releaseEmptyNames", false)
  readonly property int releaseAfterMs: root.setting("releaseAfterMs", 5000)

  // id -> 0 while it still has windows, or the moment it emptied. A workspace
  // absent from here has never had a window since the widget loaded, and its
  // name is never touched.
  property var lastAlive: ({})

  Timer {
    id: releaseTimer
    running: root.releaseEmptyNames
    interval: 5000
    repeat: true
    onTriggered: root.releaseStaleNames()
  }

  function releaseStaleNames() {
    var now = Date.now()
    var active = root.activeWorkspaceId()
    var seen = root.lastAlive
    var stale = []

    for (var id = 1; id <= 10; id++) {
      var key = String(id)
      if (root.entryFor(id).label === "") { delete seen[key]; continue }

      var ws = root.workspaceById(id)
      var occupied = ws !== null && ws.toplevels.values.length > 0

      // Used means used: having windows, or being the one you are on. A
      // workspace you have finished with has nothing running and you are not
      // looking at it, and then its name has no work left to do.
      if (occupied || id === active) { seen[key] = 0; continue }

      // Never touched since the shell started. Turning this feature on should
      // clean up after the session you are in, not reach back and delete names
      // set before it.
      if (seen[key] === undefined) continue

      // First tick since it went quiet. Start the clock rather than reading a
      // zero as "five seconds ago".
      if (seen[key] === 0) { seen[key] = now; continue }

      if (now - seen[key] >= root.releaseAfterMs) stale.push(id)
    }

    root.lastAlive = seen
    if (stale.length === 0 || !root.bar) return

    // One write for all of them. Each `omarchy bar set` reloads every bar
    // surface, so releasing three names in three calls would rebuild the bar
    // three times.
    var next = {}
    for (var k in root.names) next[k] = root.names[k]

    var renames = ""
    for (var i = 0; i < stale.length; i++) {
      delete next[String(stale[i])]
      renames += " ; hyprctl dispatch " + Util.shellQuote(
        "hl.dsp.workspace.rename({ workspace = " + stale[i] + ", name = \"" + stale[i] + "\" })")
      delete root.lastAlive[String(stale[i])]
    }

    root.bar.run("omarchy bar set bo.better-workspaces names "
      + Util.shellQuote(JSON.stringify(next)) + " --json" + renames)
  }

  // Delegate buttons by workspace id, so the panel can anchor under the one
  // being renamed rather than under the widget as a whole.
  property var buttons: ({})

  function registerButton(id, item) {
    var next = root.buttons
    next[String(id)] = item
    root.buttons = next
  }

  readonly property bool newVisible: root.showNewButton && root.firstFreeWorkspace() > 0

  implicitWidth: grid.implicitWidth + (root.vertical ? 0 : Style.spaceReal(1.5))
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.vertical ? 0 : Style.spaceReal(1.5)
    columns: root.vertical ? 1 : root.workspaceIds().length + (root.newVisible ? 1 : 0)
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: wsButton
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        // Names are wider than digits and vary in length, so the button sizes
        // to its label instead of the fixed slot a numeric row can rely on.
        text: root.displayName(modelData)
        tooltipText: root.fullName(modelData)
        readonly property bool leaving: root.leavingIds.indexOf(modelData) >= 0

        opacity: leaving ? 0 : (focused ? 1 : (occupied ? 0.6 : 0.35))
        scale: leaving ? 0.85 : 1

        Behavior on opacity { NumberAnimation { duration: root.leaveMs; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: root.leaveMs; easing.type: Easing.OutCubic } }
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : -1
        fixedHeight: root.barSize
        onPressed: function(button) {
          if (button === Qt.RightButton) root.openRename(modelData, wsButton)
          else root.focusWorkspace(modelData)
        }

        Component.onCompleted: root.registerButton(modelData, wsButton)
      }
    }

    WidgetButton {
      visible: root.newVisible
      bar: root.bar
      text: "+"
      tooltipText: "New workspace " + root.firstFreeWorkspace()
      opacity: 0.35
      horizontalMargin: 6
      verticalPadding: 6
      fixedWidth: root.vertical ? root.barSize : -1
      fixedHeight: root.barSize
      // The same command SUPER+F3 runs, so there is one definition of "the
      // first free workspace" rather than one here and one in a script.
      onPressed: function(button) {
        if (root.bar) root.bar.run("bo-workspace-new")
      }
    }
  }

  KeyboardPanel {
    id: renamePanel
    anchorItem: root.editingAnchor || root
    owner: root
    bar: root.bar
    open: root.opened && root.editingId > 0
    focusTarget: nameField
    contentWidth: renamePanel.fittedContentWidth(Style.space(320))
    contentHeight: renamePanel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(12)

      PanelSectionHeader {
        width: parent.width
        text: "Rename workspace " + root.editingId
      }

      TextField {
        id: nameField
        width: parent.width
        placeholderText: "Workspace name"
        onAccepted: root.saveRename()
        Keys.onEscapePressed: root.close()
      }

      Toggle {
        id: keepNumber
        width: parent.width
        label: "Keep number"
        description: "Show the workspace number after the name"
        onClicked: keepNumber.checked = !keepNumber.checked
      }

      Text {
        width: parent.width
        text: nameField.text.trim() === ""
          ? "Empty resets it to " + (root.editingId === 10 ? "0" : root.editingId)
          : "Shows as: " + (keepNumber.checked
              ? nameField.text.trim() + " (" + (root.editingId === 10 ? "0" : root.editingId) + ")"
              : nameField.text.trim())
        color: Qt.darker(root.barForeground, 1.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }
}
