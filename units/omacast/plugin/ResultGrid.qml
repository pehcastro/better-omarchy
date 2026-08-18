import QtQuick
import qs.Commons
import qs.Ui

// A grid of thumbnails with the selected one's details underneath.
//
// For results you pick by looking rather than by reading. A list of forty
// filenames tells you nothing about which picture is which; four rows of
// thumbnails answers it at a glance, and the strip below carries the facts a
// thumbnail cannot show.
Column {
  id: view

  required property var launcher

  readonly property var current: launcher.rows.length > launcher.selectedIndex
    ? launcher.rows[launcher.selectedIndex] : null

  // Big enough to tell one screenshot from another. A thumbnail you have to
  // squint at is just a filename with extra steps.
  readonly property int cellSize: Style.space(168)
  readonly property int columns: Math.max(1, Math.floor((width - Style.space(24)) / cellSize))

  spacing: 0

  GridView {
    id: grid
    width: view.width
    height: Math.min(
      Math.ceil(view.launcher.rows.length / view.columns),
      2) * view.cellSize + Style.space(8)
    leftMargin: Style.space(12)
    rightMargin: Style.space(12)
    topMargin: Style.space(4)
    cellWidth: view.cellSize
    cellHeight: view.cellSize
    clip: true
    focus: false
    currentIndex: view.launcher.selectedIndex
    highlightMoveDuration: 0
    model: view.launcher.rows

    delegate: Item {
      required property var modelData
      required property int index

      width: grid.cellWidth
      height: grid.cellHeight

      readonly property bool selected: index === view.launcher.selectedIndex

      Rectangle {
        anchors.fill: parent
        anchors.margins: Style.space(4)
        radius: Style.cornerRadius
        color: parent.selected ? view.launcher.selectedBackground : "transparent"
        border.width: parent.selected ? Math.max(1, Style.space(1)) : 0
        border.color: Color.accent
      }

      Image {
        anchors.fill: parent
        anchors.margins: Style.space(8)
        source: String(modelData.art || modelData.iconSource || "")
        fillMode: Image.PreserveAspectFit
        // Thumbnails are the whole point here, so they load off the main thread
        // and at the size they are drawn rather than full resolution.
        asynchronous: true
        cache: true
        sourceSize.width: view.cellSize * Screen.devicePixelRatio
        sourceSize.height: view.cellSize * Screen.devicePixelRatio
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: view.launcher.select(index)
        onClicked: view.launcher.activate(modelData)
      }
    }
  }

  // What the thumbnail cannot tell you: the name, where it lives, how big it is.
  Item {
    width: view.width
    height: view.current ? Style.space(46) : 0
    visible: view.current !== null

    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: Math.max(1, Style.space(1))
      color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g, view.launcher.foreground.b, 0.08)
    }

    Column {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(20)
      anchors.right: meta.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        width: parent.width
        text: String((view.current && view.current.title) || "")
        color: view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: String((view.current && view.current.subtitle) || "")
        color: Qt.darker(view.launcher.foreground, 1.9)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Row {
      id: meta
      anchors.right: parent.right
      anchors.rightMargin: Style.space(20)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      Chip {
        anchors.verticalCenter: parent.verticalCenter
        text: String((view.current && view.current.detail) || "")
        foreground: view.launcher.foreground
        fontFamily: view.launcher.fontFamily
      }

      Chip {
        anchors.verticalCenter: parent.verticalCenter
        text: String((view.current && view.current.accessory) || "")
        foreground: view.launcher.foreground
        fontFamily: view.launcher.fontFamily
      }
    }
  }
}
