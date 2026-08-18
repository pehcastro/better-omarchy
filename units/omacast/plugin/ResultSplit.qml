import QtQuick
import qs.Commons
import qs.Ui

// List on the left, the selected result on the right. For results whose content
// matters more than their name: a clipboard entry is its text, not its first
// line, and picking the right one means reading it.
Item {
  id: view

  required property var launcher

  readonly property var current: launcher.rows.length > launcher.selectedIndex
    ? launcher.rows[launcher.selectedIndex] : null
  readonly property int rowHeight: Style.space(38)

  implicitHeight: Math.max(
    Math.min(launcher.rows.length, launcher.maxRows) * rowHeight,
    Style.space(180))

  ListView {
    id: list
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Math.round(parent.width * 0.42)
    clip: true
    focus: false
    currentIndex: view.launcher.selectedIndex
    highlightMoveDuration: 0
    model: view.launcher.rows

    delegate: Item {
      required property var modelData
      required property int index

      width: list.width
      height: view.rowHeight

      readonly property bool selected: index === view.launcher.selectedIndex

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(4)
        radius: Style.cornerRadius
        color: parent.selected ? view.launcher.selectedBackground : "transparent"
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: view.launcher.select(index)
        onClicked: view.launcher.activate(modelData)
      }

      Text {
        anchors.fill: parent
        anchors.leftMargin: Style.space(20)
        anchors.rightMargin: Style.space(12)
        verticalAlignment: Text.AlignVCenter
        text: String(modelData.title || "")
        color: parent.selected ? view.launcher.selectedText : view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }

  Rectangle {
    id: divider
    anchors.left: list.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.topMargin: Style.space(6)
    anchors.bottomMargin: Style.space(6)
    width: Math.max(1, Style.space(1))
    color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g, view.launcher.foreground.b, 0.1)
  }

  Item {
    anchors.left: divider.right
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.margins: Style.space(16)

    // An image preview when the entry is one, text otherwise.
    Image {
      anchors.fill: parent
      visible: String((view.current && view.current.art) || "") !== ""
      source: (view.current && view.current.art) || ""
      fillMode: Image.PreserveAspectFit
      horizontalAlignment: Image.AlignLeft
      verticalAlignment: Image.AlignTop
      asynchronous: true
    }

    Text {
      anchors.fill: parent
      visible: String((view.current && view.current.art) || "") === ""
      text: String((view.current && (view.current.preview || view.current.detail || view.current.title)) || "")
      color: view.launcher.foreground
      // A row that says it is preformatted gets a fixed pitch, or a calendar's
      // columns land wherever the proportional font puts them.
      font.family: (view.current && view.current.mono) ? Style.font.family : view.launcher.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
      elide: Text.ElideRight
      // The preview is for reading, so it fills the pane top-down rather than
      // centring a paragraph in it.
      verticalAlignment: Text.AlignTop
    }
  }
}
