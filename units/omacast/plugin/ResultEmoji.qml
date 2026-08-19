import QtQuick
import qs.Commons
import qs.Ui

// A wall of emoji, with the name of the one under the cursor written once.
//
// An emoji is a picture, and you pick a picture by looking at it. Drawn as a
// list, `emoji:` showed six characters and six names down a column, which is
// six answers to a question that has eighteen hundred: the name was repeated on
// every row, and the one thing you were actually reading was 24 pixels wide.
//
// So the glyphs get the space and the name gets one line under them. Sixty fit
// where six did, which is the difference between scanning and searching.
//
// The cell is the same size as Omarchy's own emoji picker uses, on purpose: the
// two are the same act, and a character that is recognisable in one has to be
// recognisable in the other.
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

  readonly property var current: (launcher.selectedIndex >= 0
    && launcher.selectedIndex < launcher.rows.length)
    ? launcher.rows[launcher.selectedIndex] : null

  readonly property int cell: Math.max(Style.space(44), Style.font.display + Style.spacing.md)
  readonly property int margin: Style.space(12)
  readonly property int pad: Style.space(8)
  readonly property int nameHeight: Style.space(40)

  readonly property int columns: Math.max(1, Math.floor((width - view.margin * 2) / view.cell))
  readonly property int rowCount: Math.ceil(launcher.rows.length / view.columns)

  // Whole rows only. A grid that ends on half a face reads as a rendering
  // fault rather than as a list that continues, and the half row is the one
  // thing scrolling cannot explain.
  readonly property int visibleRows: {
    // Six rows when the launcher has not said yet: enough to be a wall, small
    // enough that the first paint is never taller than the answer.
    var room = (view.maxHeight > 0 ? view.maxHeight : view.cell * 6 + view.nameHeight)
      - view.nameHeight - view.pad * 2
    return Math.max(1, Math.min(view.rowCount, Math.floor(room / view.cell)))
  }

  implicitHeight: launcher.rows.length > 0
    ? view.pad * 2 + view.visibleRows * view.cell + view.nameHeight : 0

  // The launcher routes left and right here and keeps every other key. Up and
  // down are its own, and travel a whole row: see `verticalStep`.
  function nudge(delta) { view.launcher.move(delta) }

  GridView {
    id: grid
    x: view.margin
    y: view.pad
    width: view.width - view.margin * 2
    height: view.visibleRows * view.cell
    cellWidth: view.cell
    cellHeight: view.cell
    clip: true
    focus: false
    // Bound rather than set, so walking past the last visible row scrolls the
    // wall instead of moving the selection somewhere nobody can see.
    currentIndex: view.launcher.selectedIndex
    highlightMoveDuration: 0
    boundsBehavior: Flickable.StopAtBounds
    model: view.launcher.rows

    delegate: Item {
      required property var modelData
      required property int index

      width: grid.cellWidth
      height: grid.cellHeight

      readonly property bool selected: index === view.launcher.selectedIndex

      Rectangle {
        anchors.fill: parent
        anchors.margins: Style.space(2)
        radius: Style.cornerRadius
        color: parent.selected ? view.launcher.selectedBackground : "transparent"
        border.width: parent.selected ? Math.max(1, Style.space(1)) : 0
        border.color: Color.accent
      }

      // The row's glyph, not its title: the launcher puts a script's `glyph`
      // into `iconGlyph`, and here that glyph is the whole answer.
      Text {
        anchors.centerIn: parent
        text: String(modelData.iconGlyph || "")
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.display
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: view.launcher.select(index)
        onClicked: view.launcher.activate(modelData)
      }
    }
  }

  // The one name on screen. Which emoji is selected is said by the cell; what
  // it is called is said here, once, because thirteen names across a row would
  // be unreadable and sixty of them would be the list again.
  Item {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: view.nameHeight
    visible: view.current !== null

    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: Math.max(1, Style.space(1))
      color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                     view.launcher.foreground.b, 0.08)
    }

    Text {
      id: face
      anchors.left: parent.left
      anchors.leftMargin: Style.space(20)
      anchors.verticalCenter: parent.verticalCenter
      text: String((view.current && view.current.iconGlyph) || "")
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.heading
    }

    Text {
      anchors.left: face.right
      anchors.leftMargin: Style.space(10)
      anchors.right: tail.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: String((view.current && view.current.title) || "")
      color: view.launcher.foreground
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    Row {
      id: tail
      anchors.right: parent.right
      anchors.rightMargin: Style.space(20)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      // Nothing else says the wall goes on: the rows below the fold are simply
      // not drawn, and a grid that ends flush looks finished. A position rather
      // than a remainder, because the remainder stops being true as soon as the
      // grid scrolls.
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: view.rowCount > view.visibleRows
        text: (view.launcher.selectedIndex + 1) + " / " + view.launcher.rows.length
        color: Qt.darker(view.launcher.foreground, 2.2)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }

      Chip {
        anchors.verticalCenter: parent.verticalCenter
        // "Recently used" on the ones the script put first, and nothing on the
        // rest: a chip saying "Emoji" under a wall of emoji is furniture.
        text: {
          var s = String((view.current && view.current.subtitle) || "")
          return s === "Emoji" ? "" : s
        }
        foreground: view.launcher.foreground
        fontFamily: view.launcher.fontFamily
      }
    }
  }
}
