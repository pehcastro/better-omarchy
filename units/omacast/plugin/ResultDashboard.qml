import QtQuick
import qs.Commons
import qs.Ui

// Readings as a wall of numbers rather than as a list of them.
//
// `sys:` answers with everything at once, and every row is equally loud, so
// finding the battery means reading nine lines to get to one word. Tiles let
// the number be the first thing you see, and a bar under the readings that are
// proportions says "nearly full" before you have read any digits at all.
//
// A row with `progress` is a proportion and gets the big treatment. A row
// without one is a fact, and a fact does not need a meter or a display face to
// be true, so it stays quiet and lets the meters carry the tile.
Item {
  id: view

  required property var launcher

  readonly property int gutter: Style.space(12)
  // Wide enough for "10G of 67G" at display size, which is the longest reading
  // the tiles have to hold without stepping down.
  readonly property int minTile: Style.space(180)
  readonly property int columns: Math.max(1, Math.floor((width - gutter) / minTile))
  readonly property int tileWidth: Math.max(minTile, Math.floor((width - gutter * (columns + 1)) / columns))
  readonly property int tileHeight: Style.space(94)
  readonly property int tileRows: Math.ceil(launcher.rows.length / columns)

  implicitHeight: tileRows > 0 ? tileRows * tileHeight + (tileRows + 1) * gutter : 0

  Grid {
    x: view.gutter
    y: view.gutter
    columns: view.columns
    spacing: view.gutter

    Repeater {
      model: view.launcher.rows

      delegate: Item {
        id: tile

        required property var modelData
        required property int index

        readonly property bool selected: index === view.launcher.selectedIndex
        // A missing key and an explicit null both mean "not a proportion", so a
        // script that always emits the field cannot turn a fact into a meter
        // stuck at zero.
        readonly property bool metered: modelData.progress !== undefined && modelData.progress !== null
        readonly property real fraction: Math.max(0, Math.min(1, Number(modelData.progress || 0)))
        // A long reading steps down rather than eliding: "6.17.8-arch1-3" and
        // "100%" are both the answer, and only one of them fits at display size.
        readonly property int valueSize: {
          var reading = String(tile.modelData.title || "")
          if (tile.metered) return reading.length > 10 ? Style.font.heading : Style.font.display
          return reading.length > 16 ? Style.font.body : Style.font.heading
        }

        width: view.tileWidth
        height: view.tileHeight

        Rectangle {
          anchors.fill: parent
          radius: Style.cornerRadius
          color: tile.selected
            ? view.launcher.selectedBackground
            : Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g, view.launcher.foreground.b, 0.05)
          border.width: tile.selected ? Math.max(1, Style.space(1)) : 0
          border.color: Color.accent
        }

        MouseArea {
          anchors.fill: parent
          onClicked: view.launcher.activate(tile.modelData)
        }

        Text {
          id: label
          anchors.top: parent.top
          anchors.topMargin: Style.space(10)
          anchors.left: parent.left
          anchors.leftMargin: Style.space(12)
          anchors.right: tag.left
          anchors.rightMargin: Style.space(6)
          text: String(tile.modelData.subtitle || "").toUpperCase()
          color: Qt.darker(view.launcher.foreground, 2.1)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 0.8
          elide: Text.ElideRight
        }

        Chip {
          id: tag
          anchors.top: parent.top
          anchors.topMargin: Style.space(6)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          text: String(tile.modelData.accessory || "")
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }

        Text {
          id: value
          anchors.bottom: meter.top
          anchors.bottomMargin: Style.space(4)
          anchors.left: parent.left
          anchors.leftMargin: Style.space(12)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(12)
          text: String(tile.modelData.title || "")
          color: tile.selected ? view.launcher.selectedText : view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: tile.valueSize
          font.bold: tile.metered
          elide: Text.ElideRight
        }

        // Zero height when the row carries no proportion, so a fact's value and
        // context sit exactly where a meter's do and the grid stays on one line.
        Item {
          id: meter
          anchors.bottom: context.top
          anchors.bottomMargin: Style.space(4)
          anchors.left: parent.left
          anchors.leftMargin: Style.space(12)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(12)
          height: tile.metered ? Style.space(6) : 0
          visible: tile.metered

          Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Style.space(3)
            radius: height / 2
            color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g, view.launcher.foreground.b, 0.15)
          }

          Rectangle {
            anchors.left: track.left
            anchors.verticalCenter: track.verticalCenter
            width: track.width * tile.fraction
            height: track.height
            radius: track.radius
            color: Color.accent
          }
        }

        Text {
          id: context
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(10)
          anchors.left: parent.left
          anchors.leftMargin: Style.space(12)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(12)
          text: String(tile.modelData.detail || "")
          color: Qt.darker(view.launcher.foreground, 1.9)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }
}
