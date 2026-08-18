import QtQuick
import qs.Commons
import qs.Ui

// Ctrl+K: everything else this result can do.
//
// The primary action is on Enter and stays there. This is for the second and
// third: copy the path rather than open the file, ask ChatGPT rather than
// search the web, uninstall rather than launch.
BorderSurface {
  id: panel

  required property var launcher

  property int index: 0

  readonly property var actions: launcher.currentActions()
  readonly property int rowHeight: Style.space(36)

  width: Style.space(300)
  height: Math.min(actions.length, 7) * rowHeight + Style.space(16)
  radius: Style.cornerRadius
  color: launcher.background
  borderSpec: launcher.borderSpec
  padding: 0

  function move(delta) {
    if (panel.actions.length === 0) return
    panel.index = Math.max(0, Math.min(panel.actions.length - 1, panel.index + delta))
  }

  function activate() {
    var action = panel.actions[panel.index]
    if (!action) return
    panel.launcher.runAction(action)
  }

  onVisibleChanged: if (visible) panel.index = 0

  // Swallow clicks so a press inside the panel does not dismiss the launcher.
  MouseArea { anchors.fill: parent; onClicked: {} }

  ListView {
    anchors.fill: parent
    anchors.topMargin: Style.space(8)
    anchors.bottomMargin: Style.space(8)
    clip: true
    focus: false
    currentIndex: panel.index
    highlightMoveDuration: 0
    model: panel.actions

    delegate: Item {
      required property var modelData
      required property int index

      width: parent ? parent.width : 0
      height: panel.rowHeight

      readonly property bool selected: index === panel.index

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        radius: Style.cornerRadius
        color: parent.selected ? panel.launcher.selectedBackground : "transparent"
      }

      MouseArea {
        anchors.fill: parent
        onClicked: {
          panel.index = index
          panel.activate()
        }
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(18)
        anchors.right: shortcut.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        text: String(modelData.title || "")
        color: parent.selected ? panel.launcher.selectedText : panel.launcher.foreground
        font.family: panel.launcher.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Text {
        id: shortcut
        anchors.right: parent.right
        anchors.rightMargin: Style.space(18)
        anchors.verticalCenter: parent.verticalCenter
        text: String(modelData.shortcut || "")
        color: Qt.darker(panel.launcher.foreground, 2.0)
        font.family: panel.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
