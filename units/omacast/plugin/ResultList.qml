import QtQuick
import qs.Commons
import qs.Ui

// The default view: grouped rows, an icon, a title, and a chip on the right.
//
// Rows arrive ranked across every provider, so they are grouped here only where
// the group actually changes. That keeps the best answer first, wherever it
// came from, while still telling you what kind of thing you are looking at.
//
// The left gutter carries the row's number, which is what Ctrl+1 to Ctrl+9
// run, and the right edge carries a star when the row is pinned.
ListView {
  id: view

  required property var launcher

  readonly property int rowHeight: Style.space(42)
  readonly property int headerHeight: Style.space(24)

  // The first row of each run of a group carries that group's header. Ranking
  // decides the order, so a group can appear more than once and that is fine:
  // the header is a label, not a section.
  function headerFor(index) {
    var rows = view.launcher.rows
    if (index >= rows.length) return ""
    var group = String(rows[index].group || "")
    if (index === 0) return group
    return String(rows[index - 1].group || "") === group ? "" : group
  }

  implicitHeight: Math.min(count, launcher.maxRows) * rowHeight + Style.space(20)
  clip: true
  focus: false
  interactive: true
  currentIndex: launcher.selectedIndex
  highlightMoveDuration: 0
  model: launcher.rows

  delegate: Column {
    required property var modelData
    required property int index

    width: view.width
    spacing: 0

    readonly property bool selected: index === view.launcher.selectedIndex
    readonly property string header: view.headerFor(index)

    Item {
      width: parent.width
      height: parent.header !== "" ? view.headerHeight : 0
      visible: parent.header !== ""

      Text {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(30)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(4)
        text: parent.parent.header.toUpperCase()
        color: Qt.darker(view.launcher.foreground, 2.1)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
      }
    }

    Item {
      width: parent.width
      height: view.rowHeight

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        anchors.topMargin: Style.space(1)
        anchors.bottomMargin: Style.space(1)
        radius: Style.cornerRadius
        color: parent.parent.selected ? view.launcher.selectedBackground : "transparent"
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: view.launcher.select(parent.parent.index)
        onClicked: view.launcher.activate(parent.parent.modelData)
      }

      // Only the first nine are numbered, because only the first nine have a
      // chord that runs them.
      Text {
        visible: parent.parent.index < 9
        text: String(parent.parent.index + 1)
        color: Qt.darker(view.launcher.foreground, 2.4)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        width: Style.space(12)
        horizontalAlignment: Text.AlignRight
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
      }

      Image {
        id: icon
        visible: String(parent.parent.modelData.iconSource || "") !== ""
        source: parent.parent.modelData.iconSource || ""
        width: Style.space(20)
        height: Style.space(20)
        fillMode: Image.PreserveAspectFit
        sourceSize.width: width * Screen.devicePixelRatio
        sourceSize.height: height * Screen.devicePixelRatio
        anchors.left: parent.left
        anchors.leftMargin: Style.space(30)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        visible: !icon.visible
        text: String(parent.parent.modelData.iconGlyph || "")
        color: parent.parent.selected ? view.launcher.selectedText : Qt.darker(view.launcher.foreground, 1.5)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        width: Style.space(20)
        horizontalAlignment: Text.AlignHCenter
        anchors.left: parent.left
        anchors.leftMargin: Style.space(30)
        anchors.verticalCenter: parent.verticalCenter
      }

      // Title above, detail below, so a row can carry two facts without either
      // fighting the other for the same line.
      Column {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(62)
        anchors.right: tail.left
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          width: parent.width
          text: String(parent.parent.parent.modelData.title || "")
          color: parent.parent.parent.selected ? view.launcher.selectedText : view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
          opacity: parent.parent.parent.modelData.pending ? 0.5 : 1
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          visible: text !== ""
          text: String(parent.parent.parent.modelData.detail || "")
          color: Qt.darker(view.launcher.foreground, 2.0)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Row {
        id: tail
        anchors.right: parent.right
        anchors.rightMargin: Style.space(20)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: tail.parent.parent.modelData.pinned === true
          text: "\u2605"
          color: Color.accent
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: String(tail.parent.parent.modelData.subtitle || "")
          color: Qt.darker(view.launcher.foreground, 1.8)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          width: Math.min(implicitWidth, view.width * 0.32)
        }

        Chip {
          anchors.verticalCenter: parent.verticalCenter
          text: String(tail.parent.parent.modelData.accessory || "")
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }
      }
    }
  }
}
