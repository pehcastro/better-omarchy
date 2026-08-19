import QtQuick
import qs.Commons
import qs.Ui

// Themes drawn in their own colours, because a theme is a palette and its name
// is not one.
//
// As a list, `theme:` was twenty-two words in the colours of the theme you
// already have. Choosing between "Ristretto" and "Miasma" that way is choosing
// at random, and the live preview only rescued it one theme at a time: you had
// to walk the whole list to see the list.
//
// Each card is painted in the theme's own background, named in its own
// foreground, and carries its accent, its surface and six hues in a fixed
// order, so two dark themes are told apart by looking rather than by
// previewing both.
//
// The colours come from the theme's colors.toml rather than its preview.png.
// The previews are 300-700KB screenshots of a desktop: twenty-two of them is
// several megabytes of decoding per keystroke, most of the pixels are wallpaper
// and window furniture, and at card size the palette is a few dozen pixels of
// terminal text. colors.toml is six hundred bytes, exact, present for every
// theme, and it is the same file the preview retint sends to the shell, so a
// card cannot disagree with what selecting it does.
//
// The row carries:
//   bg fg dim accent surface   hex, or "" when the theme has no colours file
//   swatches[]                 six hues: red yellow green cyan blue magenta
//   mode                       dark|light
//   current                    true for the theme in use
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

  readonly property int gutter: Style.space(12)
  // Wide enough for "Catppuccin Latte" at body size beside a check mark, which
  // is the longest name shipped. Narrower and the names elide, which puts the
  // list's problem back on a card that was supposed to end it.
  readonly property int minTile: Style.space(190)
  readonly property int tileHeight: Style.space(84)

  readonly property int columns: Math.max(1, Math.floor((width - view.gutter) / view.minTile))
  readonly property int rowCount: Math.ceil(launcher.rows.length / view.columns)

  // Whole cards only. Half a palette below the fold reads as a drawing fault,
  // and a palette is the one thing here that cannot be judged from a strip.
  readonly property int visibleRows: {
    var room = (view.maxHeight > 0 ? view.maxHeight : view.cellHeight * 4) - view.gutter
    return Math.max(1, Math.min(view.rowCount, Math.floor(room / view.cellHeight)))
  }

  readonly property int cellWidth: Math.floor((view.width - view.gutter * 2) / view.columns)
  readonly property int cellHeight: view.tileHeight + view.gutter

  implicitHeight: launcher.rows.length > 0
    ? view.gutter + view.visibleRows * view.cellHeight : 0

  // The launcher routes left and right here and keeps every other key,
  // including Escape, which is what puts the theme you started on back.
  function nudge(delta) { view.launcher.move(delta) }

  // A theme with no colours file gets the launcher's own colours rather than
  // black on black: an unpainted card should look plain, not broken.
  function pick(hex, fallback) {
    return String(hex || "") !== "" ? hex : fallback
  }

  GridView {
    id: grid
    x: view.gutter
    y: view.gutter
    width: view.width - view.gutter * 2
    height: view.visibleRows * view.cellHeight
    cellWidth: view.cellWidth
    cellHeight: view.cellHeight
    clip: true
    focus: false
    // Bound rather than set, so walking past the last visible row scrolls to
    // the theme being previewed instead of previewing one nobody can see.
    currentIndex: view.launcher.selectedIndex
    highlightMoveDuration: 0
    boundsBehavior: Flickable.StopAtBounds
    model: view.launcher.rows

    delegate: Item {
      id: cell

      required property var modelData
      required property int index

      width: grid.cellWidth
      height: grid.cellHeight

      readonly property bool selected: index === view.launcher.selectedIndex
      readonly property color paper: view.pick(modelData.bg, view.launcher.background)
      readonly property color ink: view.pick(modelData.fg, view.launcher.foreground)
      readonly property color quiet: view.pick(modelData.dim, Qt.darker(cell.ink, 1.8))
      readonly property color tint: view.pick(modelData.accent, Color.accent)

      Rectangle {
        id: tile
        anchors.fill: parent
        anchors.rightMargin: view.gutter
        anchors.bottomMargin: view.gutter
        radius: Style.cornerRadius
        color: cell.paper

        // Every card has an edge, drawn in its own foreground. Vantablack is
        // #000000 and the launcher over a dark theme is nearly that, so without
        // this the card with the most to say about itself is invisible.
        border.width: cell.selected ? Math.max(1, Style.space(2)) : Math.max(1, Style.space(1))
        border.color: cell.selected
          ? Color.accent
          : Qt.rgba(cell.ink.r, cell.ink.g, cell.ink.b, 0.22)

        // The accent, as a block rather than as a word. It is the colour the
        // theme puts on everything you are about to look at.
        Rectangle {
          id: dot
          x: Style.space(12)
          y: Style.space(12)
          width: Style.space(12)
          height: Style.space(12)
          radius: Style.cornerRadius > 0 ? Style.space(3) : 0
          color: cell.tint
        }

        Text {
          id: name
          anchors.left: dot.right
          anchors.leftMargin: Style.space(8)
          anchors.right: mark.visible ? mark.left : tile.right
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: dot.verticalCenter
          text: String(cell.modelData.title || "")
          color: cell.ink
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
          font.bold: cell.selected
          elide: Text.ElideRight
        }

        // Which one you are on now. The scores already float it to the front,
        // but the front of a grid is not somewhere you can point at.
        Text {
          id: mark
          anchors.right: tile.right
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: dot.verticalCenter
          visible: cell.modelData.current === true
          text: "✓"
          color: cell.tint
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          anchors.left: name.left
          anchors.top: name.bottom
          anchors.topMargin: Style.space(2)
          text: String(cell.modelData.mode || "")
          color: cell.quiet
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        // The hues, on the surface the theme actually paints windows in. The
        // strip is a window in miniature: the same six colours on a dark grey
        // and on a warm brown are two different themes to live in, and that
        // difference is invisible in a row of loose squares.
        Rectangle {
          id: strip
          anchors.left: tile.left
          anchors.right: tile.right
          anchors.bottom: tile.bottom
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          anchors.bottomMargin: Style.space(12)
          height: Style.space(20)
          radius: Style.cornerRadius > 0 ? Style.space(4) : 0
          color: view.pick(cell.modelData.surface, Qt.lighter(cell.paper, 1.3))

          Row {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(5)

            Repeater {
              model: cell.modelData.swatches || []

              Rectangle {
                required property var modelData
                width: Style.space(10)
                height: Style.space(10)
                radius: width / 2
                color: String(modelData)
              }
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          // Selecting is what previews, so hovering is what previews. The
          // launcher already waits 90ms before it retints, which is what keeps
          // a mouse crossing the grid from repainting the shell six times.
          onEntered: view.launcher.select(cell.index)
          onClicked: view.launcher.activate(cell.modelData)
        }
      }
    }
  }
}
