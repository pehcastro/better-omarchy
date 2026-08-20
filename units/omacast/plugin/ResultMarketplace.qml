import QtQuick
import qs.Commons
import qs.Ui

// Level two of `bo:`: the units inside one marketplace, as tiles, two across.
//
// Reached by pressing Enter on a marketplace on the home screen, which writes
// `bo:@<name>` into the box and pushes a step the launcher's Escape walks back
// out of. Typing after that narrows this level and nothing else. `heading` on
// the first row is the name of the level, drawn in the launcher's own section
// label so this screen and the home screen read as one thing.
//
// The first version of this was ResultList with a switch bolted on: five
// identical full-width slabs at a uniform height, an accent rail down the left
// edge of each, and four alignment columns per slab so the eye zig-zagged
// across every one. Every fact on it was either body text or a pill, which
// means nothing was first.
//
// The tile itself is in MarketplaceTile.qml, because the home screen draws the
// same tiles under INSTALLED and the two screens have to be one design. This
// file is only the arithmetic: how many columns fit, how many rows fit, and
// which window of them is on screen.
//
// Height carries information. A tile is as tall as what it has to say, and both
// tiles in a row sit at the top of it, so a short tile beside a tall one reads
// as short rather than being stretched to match.
//
// The delegate count is a number, not a model, so a keystroke that narrows the
// answer rebinds the Texts already on screen instead of destroying them.
// ResultGrid needs a ListModel of keys because its delegates hold decoded
// images that reload on rebuild; nothing here holds anything but text, and text
// rebinds in a frame.
//
// Rows carry:
//   tile          unit | market
//   title subtitle
//   state         on | off | unavailable        (unit tiles)
//   reason        why it cannot be turned on     (unavailable only)
//   meta          the one quiet line, already worded by the script
//   counts        { total, matched, shown, sources }   on the first row
Item {
  // The card cannot hold a view that draws past its own height, and every view
  // here computes that height from its content. Clipping at the root is what
  // makes a wrong sum a short answer rather than tiles spilling over the footer
  // and onto the wallpaper.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property var rows: launcher.rows
  // Rows are found by what they are, never by where they are: the launcher
  // reorders them, because Frecency.js adds up to 9000 to anything the user has
  // activated. `tileIndex` is the launcher index of each tile in display order,
  // so nothing here assumes the way out is first.
  readonly property int backIndex: {
    for (var i = 0; i < view.rows.length; i++) {
      if (String(view.rows[i].part || "") === "back") return i
    }
    return -1
  }

  readonly property var tileIndex: {
    var out = []
    for (var i = 0; i < view.rows.length; i++) {
      if (String(view.rows[i].part || "") !== "back") out.push(i)
    }
    return out
  }

  readonly property var pageRow: view.backIndex >= 0 ? view.rows[view.backIndex]
    : (view.rows.length > 0 ? view.rows[0] : null)


  readonly property var counts: (view.pageRow && view.pageRow.counts) ? view.pageRow.counts : ({})
  readonly property string heading: view.pageRow ? String(view.pageRow.heading || "") : ""
  readonly property string backLabel: view.pageRow ? String(view.pageRow.backLabel || "") : ""
  readonly property int tileCount: view.tileIndex.length

  // Where the cursor is among the tiles, or -1 while it is on the way out.
  readonly property int selectedTile: view.tileIndex.indexOf(view.launcher.selectedIndex)

  // What one press of Down travels, read by the launcher rather than used here.
  // It is a whole grid row everywhere except on the way-out row, where it has to
  // be one so that Down lands on the first tile instead of the second.
  readonly property int columns: view.launcher.selectedIndex === view.backIndex
    ? 1 : view.gridColumns

  readonly property int pad: Style.space(14)
  readonly property int gap: Style.space(9)
  // Two columns at the default card width. A tile narrower than this cannot
  // hold a summary in two lines, and a summary cut to one line is a tile that
  // says the name twice.
  readonly property int minTile: Style.space(228)

  readonly property int inner: Math.max(1, view.width - view.pad * 2)
  readonly property int gridColumns: Math.max(1,
    Math.floor((view.inner + view.gap) / (view.minTile + view.gap)))
  readonly property int tileWidth: Math.floor(
    (view.inner - view.gap * (view.gridColumns - 1)) / view.gridColumns)

  readonly property int gridRows: Math.ceil(view.tileCount / view.gridColumns)

  readonly property int lineName: Math.round(Style.font.subtitle * 1.45)
  readonly property int lineBody: Math.round(Style.font.caption * 1.5)

  // The tallest a tile can be: name, two lines of summary, one meta line, and
  // its own padding. Used only to decide how many rows to draw, and only ever
  // an over-estimate, so the real content can never overflow the room and get
  // cut in half at the bottom edge. Drawing one row fewer than would have fit
  // is the cost, and a tile sliced through the middle is what it buys off.
  readonly property int tileMax: Style.space(15) * 2 + view.lineName
    + view.lineBody * 3 + Style.space(10)

  readonly property int matched: Number(view.counts.matched || view.tileCount)
  readonly property bool hasMore: view.matched > view.tileCount
  readonly property int hintHeight: view.hasMore ? Style.space(20) : 0

  readonly property int labelHeight: view.heading !== "" ? Style.space(24) : 0
  readonly property int backHeight: view.backIndex >= 0 ? Style.space(26) + Style.space(4) : 0

  readonly property int visibleGridRows: {
    var room = (view.maxHeight > 0 ? view.maxHeight : view.tileMax * 3)
      - view.pad * 2 - view.hintHeight - view.labelHeight - view.backHeight
    var fit = Math.floor((room + view.gap) / (view.tileMax + view.gap))
    return Math.max(1, Math.min(view.gridRows, fit))
  }

  // The window slides only far enough to keep the selection inside it.
  // Arrowing past the bottom of a fixed window selects a tile nobody can see,
  // and the launcher's footer would then be describing something invisible.
  readonly property int firstGridRow: {
    var sel = view.selectedTile
    if (sel < 0) return 0
    var selRow = Math.floor(Math.min(sel, view.tileCount - 1) / view.gridColumns)
    if (selRow < view.visibleGridRows) return 0
    return Math.min(Math.max(0, view.gridRows - view.visibleGridRows),
                    selRow - view.visibleGridRows + 1)
  }

  // The real height of what got drawn, not the reserved upper bound, so a
  // screen of short tiles is a short card rather than a card with a hole in it.
  implicitHeight: view.rows.length > 0
    ? view.pad * 2 + view.backHeight + view.labelHeight + body.height + view.hintHeight : 0

  function faint(alpha) {
    return Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                   view.launcher.foreground.b, alpha)
  }

  MarketplaceBack {
    launcher: view.launcher
    label: view.backLabel
    selected: view.backIndex >= 0 && view.launcher.selectedIndex === view.backIndex
    visible: view.backIndex >= 0
    x: view.pad
    y: view.pad
    width: view.inner
  }

  MarketplaceLabel {
    launcher: view.launcher
    label: view.heading
    x: view.pad
    y: view.pad + view.backHeight
    width: view.inner
  }

  Column {
    id: body
    x: view.pad
    y: view.pad + view.backHeight + view.labelHeight
    width: view.inner
    spacing: view.gap

    Repeater {
      model: view.visibleGridRows

      delegate: Row {
        id: gridRow

        required property int index

        width: view.inner
        spacing: view.gap

        Repeater {
          model: view.gridColumns

          delegate: MarketplaceTile {
            id: cell

            required property int index

            // Display position first, then the launcher index it maps to.
            readonly property int place:
              (view.firstGridRow + gridRow.index) * view.gridColumns + cell.index
            readonly property int slot: (cell.place >= 0 && cell.place < view.tileCount)
              ? view.tileIndex[cell.place] : -1

            launcher: view.launcher
            row: cell.slot >= 0 ? view.rows[cell.slot] : null
            position: cell.slot
            selected: cell.row !== null && cell.slot === view.launcher.selectedIndex
            width: view.tileWidth
            height: cell.implicitHeight
          }
        }
      }
    }
  }

  // What the answer is a part of. An answer that was cut and does not say so is
  // a lie about how many units exist, and this is the line that tells someone
  // with three hundred of them that the way through is the keyboard.
  Text {
    visible: view.hasMore
    x: view.pad + Style.space(2)
    y: view.pad + view.backHeight + view.labelHeight + body.height + Style.space(2)
    height: view.hintHeight
    verticalAlignment: Text.AlignVCenter
    text: view.tileCount + " of " + view.matched
      + (view.counts.sources === true ? " marketplaces" : " units")
      + "  ·  keep typing to narrow it"
    color: view.faint(0.30)
    font.family: view.launcher.fontFamily
    font.pixelSize: Style.font.caption
  }
}
