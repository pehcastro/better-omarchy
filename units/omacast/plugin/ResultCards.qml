import QtQuick
import qs.Commons
import qs.Ui

// Art on the left, three lines of metadata beside it. For results where the
// picture is how you recognise the thing: tracks, albums, images. A 44px row
// cannot hold cover art at a size worth showing.
ListView {
  id: view

  required property var launcher

  readonly property int rowHeight: Style.space(64)

  implicitHeight: Math.min(count, Math.max(3, view.launcher.maxRows - 3)) * rowHeight
  clip: true
  focus: false
  interactive: true
  currentIndex: launcher.selectedIndex
  highlightMoveDuration: 0
  model: launcher.rows

  delegate: Item {
    required property var modelData
    required property int index

    width: view.width
    height: view.rowHeight

    readonly property bool selected: index === view.launcher.selectedIndex

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      anchors.topMargin: Style.space(2)
      anchors.bottomMargin: Style.space(2)
      radius: Style.cornerRadius
      color: parent.selected ? view.launcher.selectedBackground : "transparent"
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onEntered: view.launcher.select(index)
      onClicked: view.launcher.activate(modelData)
    }

    Rectangle {
      id: artFrame
      width: Style.space(44)
      height: Style.space(44)
      radius: Math.max(2, Style.cornerRadius / 2)
      color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g, view.launcher.foreground.b, 0.08)
      anchors.left: parent.left
      anchors.leftMargin: Style.space(18)
      anchors.verticalCenter: parent.verticalCenter
      clip: true

      Image {
        anchors.fill: parent
        source: String(modelData.art || modelData.iconSource || "")
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: width * Screen.devicePixelRatio
        sourceSize.height: height * Screen.devicePixelRatio
        asynchronous: true
      }

      // Shown while the art loads, and left in place when there is none.
      Text {
        anchors.centerIn: parent
        visible: String(modelData.art || modelData.iconSource || "") === ""
        text: String(modelData.iconGlyph || "")
        color: Qt.darker(view.launcher.foreground, 1.6)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.title
      }
    }

    Column {
      anchors.left: artFrame.right
      anchors.leftMargin: Style.space(14)
      anchors.right: accessory.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        width: parent.width
        text: String(modelData.title || "")
        color: parent.parent.selected ? view.launcher.selectedText : view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: String(modelData.subtitle || "")
        color: Qt.darker(view.launcher.foreground, 1.6)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: String(modelData.detail || "")
        color: Qt.darker(view.launcher.foreground, 2.0)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Text {
      id: accessory
      anchors.right: parent.right
      anchors.rightMargin: Style.space(20)
      anchors.verticalCenter: parent.verticalCenter
      text: String(modelData.accessory || "")
      color: Qt.darker(view.launcher.foreground, 1.8)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      width: Math.min(implicitWidth, view.width * 0.22)
    }
  }
}
