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
  moduleName: "bo.workspace-names"
  ipcTarget: "bo.workspace-names"

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

  // WidgetButton sizes itself to its label and cannot elide, so a long name
  // is cut here instead. The full name stays in the button's tooltip.
  readonly property int maxLabelChars: root.setting("maxLabelChars", 18)

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

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
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
      "omarchy bar set bo.workspace-names names " + Util.shellQuote(JSON.stringify(next)) + " --json" +
      " ; hyprctl dispatch " + Util.shellQuote("hl.dsp.workspace.rename({ workspace = " + id + ", name = \"" + hyprName.replace(/"/g, "") + "\" })")
    )
  }

  // Delegate buttons by workspace id, so the panel can anchor under the one
  // being renamed rather than under the widget as a whole.
  property var buttons: ({})

  function registerButton(id, item) {
    var next = root.buttons
    next[String(id)] = item
    root.buttons = next
  }

  implicitWidth: grid.implicitWidth + (root.vertical ? 0 : Style.spaceReal(1.5))
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.vertical ? 0 : Style.spaceReal(1.5)
    columns: root.vertical ? 1 : root.workspaceIds().length
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
        opacity: focused ? 1 : (occupied ? 0.6 : 0.35)
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
