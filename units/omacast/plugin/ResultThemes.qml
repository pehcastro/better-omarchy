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
// foreground, and carries its accent and six hues on the surface the theme
// paints windows in, so two dark themes are told apart by looking rather than
// by previewing both.
//
// The colours come from the theme's colors.toml rather than its preview.png.
// The previews are 300-700KB screenshots of a desktop: twenty-two of them is
// several megabytes of decoding per keystroke, most of the pixels are wallpaper
// and window furniture, and at card size the palette is a few dozen pixels of
// terminal text. colors.toml is six hundred bytes, exact, present for every
// theme, and it is the same file the preview retint sends to the shell, so a
// card cannot disagree with what selecting it does.
//
// ------------------------------------------------------------- how compact
//
// Twenty-two themes ship. Omarchy users install their own, and three hundred
// is a collection somebody has. The card was 198x96 in three columns, which is
// twenty-one on screen: right for twenty-two themes and a wall of scrolling
// for three hundred.
//
// So the card was cut to what only a card can say. Gone: the word "dark" or
// "light", which is the one fact you can already see, because the card is
// painted in that background and nothing else on it is; and the separate
// accent dot, which now shares the name's line as the marker in front of it.
// Kept: the background, the foreground the name is written in, the accent, the
// surface, and the six hues in their fixed order. That is the whole of what
// distinguishes two dark themes, and it fits in 149x62 across four columns,
// forty-eight on screen where twenty-one were.
//
// The name is set one step down from body, which is the size at which
// "Catppuccin Latte", the longest name that ships, still fits a cell whole. A
// name that elides puts the list's problem back on the card.
//
// The script sends one launcher-full and says how many it did not send, so
// three hundred themes is forty-eight cards and a line saying so, not three
// hundred cards nobody scrolls to the end of. Typing is the way through a
// large collection and browsing is the way through a small one, and the cap is
// what keeps the second from becoming the first.
//
// The row carries:
//   bg fg dim accent surface   hex, or "" when the theme has no colours file
//   swatches[]                 six hues: red yellow green cyan blue magenta
//   mode                       dark|light
//   current                    true for the theme in use
//   total shown                how much of the collection this answer is
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

  readonly property int gutter: Style.space(10)
  // Three columns at the default card width, two on a narrow one. Four fitted,
  // and a wall of four is exactly what this was meant to avoid: at three the
  // palette strip is wide enough to compare across cards, which is the only
  // reason to draw a card rather than a row.
  readonly property int minTile: Style.space(200)
  readonly property int tileHeight: Style.space(56)

  readonly property int columns: Math.max(1, Math.floor((width - view.gutter) / view.minTile))
  readonly property int rowCount: Math.ceil(launcher.rows.length / view.columns)

  // How much of the collection is not on screen. Every row carries the same
  // pair, so the first one answers for all of them, and a row from somewhere
  // else answers zero rather than throwing.
  readonly property int total: launcher.rows.length > 0
    ? (Number(launcher.rows[0].total) || 0) : 0
  readonly property bool hasMore: view.total > launcher.rows.length
  readonly property int hintHeight: view.hasMore ? Style.space(22) : 0

  // Whole cards only. Half a palette below the fold reads as a drawing fault,
  // and a palette is the one thing here that cannot be judged from a strip.
  readonly property int visibleRows: {
    var room = (view.maxHeight > 0 ? view.maxHeight : view.cellHeight * 6)
      - view.gutter - view.hintHeight
    return Math.max(1, Math.min(view.rowCount, Math.floor(room / view.cellHeight)))
  }

  readonly property int cellWidth: Math.floor((view.width - view.gutter * 2) / view.columns)
  readonly property int cellHeight: view.tileHeight + view.gutter

  implicitHeight: launcher.rows.length > 0
    ? view.gutter + view.visibleRows * view.cellHeight + view.hintHeight : 0

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

        // One slot in front of the name, doing both jobs at once. Normally the
        // accent, as a block rather than as a word: it is the colour the theme
        // puts on everything you are about to look at. On the theme you are
        // already using it becomes a check mark, drawn in that same accent, so
        // marking the current theme costs the name no width. The scores float
        // it to the front, but the front of a grid is not somewhere you can
        // point at.
        Item {
          id: marker
          x: Style.space(8)
          anchors.verticalCenter: name.verticalCenter
          width: Style.space(9)
          height: width

          Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: Style.cornerRadius > 0 ? Style.space(2) : 0
            color: cell.tint
            visible: cell.modelData.current !== true
          }

          Text {
            anchors.centerIn: parent
            visible: cell.modelData.current === true
            text: "✓"
            color: cell.tint
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Text {
          id: name
          anchors.left: marker.right
          anchors.leftMargin: Style.space(5)
          anchors.right: tile.right
          anchors.rightMargin: Style.space(8)
          anchors.top: tile.top
          anchors.topMargin: Style.space(8)
          text: String(cell.modelData.title || "")
          color: cell.ink
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: cell.selected
          elide: Text.ElideRight
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
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          anchors.bottomMargin: Style.space(8)
          height: Style.space(14)
          radius: Style.cornerRadius > 0 ? Style.space(3) : 0
          color: view.pick(cell.modelData.surface, Qt.lighter(cell.paper, 1.3))

          Row {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(5)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Repeater {
              model: cell.modelData.swatches || []

              Rectangle {
                required property var modelData
                width: Style.space(8)
                height: Style.space(8)
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

  // What the answer is a part of. An answer that was cut and does not say so
  // is a lie about how many themes are installed, and this is the line that
  // tells someone with three hundred of them that the way through is the
  // keyboard. In the launcher's own colours, not a theme's: it is the
  // launcher talking, not a card.
  Text {
    visible: view.hasMore
    x: view.gutter + Style.space(2)
    y: view.gutter + view.visibleRows * view.cellHeight
    height: view.hintHeight
    verticalAlignment: Text.AlignVCenter
    text: launcher.rows.length + " of " + view.total + " themes  ·  type a name, or light / dark"
    color: Qt.darker(view.launcher.foreground, 1.8)
    font.family: view.launcher.fontFamily
    font.pixelSize: Style.font.caption
  }
}
