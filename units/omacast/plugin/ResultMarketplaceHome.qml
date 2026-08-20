import QtQuick
import qs.Commons
import qs.Ui

// Level one of `bo:`: what you can browse, and what you already have.
//
// Two sections and nothing else. MARKETPLACES is one line per source, full
// card width, and pressing Enter on one opens that marketplace. INSTALLED is
// the units that are on, drawn with the same tile the browse screen uses, and
// pressing Enter on one opens that unit's page.
//
// What used to be here and is gone: a 28px count of units, a sentence saying
// how many were on, the word "browse", and a wrapped run of filter tokens.
// Filters narrow what you are looking at; they were never how you move around,
// and presenting them as the opening screen made the first thing anyone saw a
// wall of words rather than their marketplaces.
//
// The section labels are the launcher's own group header, the one ResultList
// draws above QUICKLINKS and WEB, so this screen belongs to the launcher rather
// than being a second design inside it.
//
// Selection runs through both sections in one sequence, because the rows are
// one array: every marketplace first, then every unit. The view finds the
// boundary by counting the leading rows whose `tile` is "market", so nothing
// has to agree about an index.
//
// Typing narrows the second section and never the first. The marketplaces are
// where you are, not what you are searching, and having them vanish under a
// keystroke would leave the screen with no shape. When narrowed, the section is
// labelled with the search rather than INSTALLED, because the answer then
// includes units that are not installed and a label that lied about that would
// be worse than no label.
Item {
  // The card cannot hold a view that draws past its own height. Clipping at the
  // root is what makes a wrong sum a short answer rather than tiles spilling
  // over the footer and onto the wallpaper.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property var rows: launcher.rows
  // Rows are grouped by what they are, never by where they are: the launcher
  // reorders them, because Frecency.js adds up to 9000 to anything the user has
  // activated, and a boosted unit tile would otherwise be counted as a
  // marketplace and drawn in the wrong section.
  readonly property var marketIndex: {
    var out = []
    for (var i = 0; i < view.rows.length; i++) {
      if (String(view.rows[i].tile || "") === "market") out.push(i)
    }
    return out
  }

  readonly property var unitIndex: {
    var out = []
    for (var i = 0; i < view.rows.length; i++) {
      if (String(view.rows[i].tile || "") === "unit") out.push(i)
    }
    return out
  }

  // The row carrying the page totals, found by having them rather than by being
  // first: a boosted tile can take that position.
  readonly property var pageRow: {
    for (var i = 0; i < view.rows.length; i++) {
      if (view.rows[i] && view.rows[i].counts) return view.rows[i]
    }
    return view.rows.length > 0 ? view.rows[0] : null
  }
  readonly property var counts: (view.pageRow && view.pageRow.counts) ? view.pageRow.counts : ({})

  readonly property int pad: Style.space(14)
  readonly property int gap: Style.space(9)
  readonly property int minTile: Style.space(228)
  readonly property int labelHeight: Style.space(24)

  readonly property int inner: Math.max(1, view.width - view.pad * 2)
  readonly property int columns: Math.max(1,
    Math.floor((view.inner + view.gap) / (view.minTile + view.gap)))
  readonly property int tileWidth: Math.floor(
    (view.inner - view.gap * (view.columns - 1)) / view.columns)

  readonly property int marketCount: view.marketIndex.length
  readonly property int unitCount: view.unitIndex.length

  // Where the cursor is among the tiles, or -1 while it is on a marketplace.
  readonly property int selectedTile: view.unitIndex.indexOf(view.launcher.selectedIndex)
  readonly property string unitLabel: String(view.counts.section || "installed")

  readonly property int marketRowHeight: Style.space(44)
  readonly property int lineName: Math.round(Style.font.subtitle * 1.45)
  readonly property int lineBody: Math.round(Style.font.caption * 1.5)

  // An over-estimate of one tile, used only to decide how many rows of them to
  // draw. Real content is never taller than this, so a tile can never be cut in
  // half at the bottom edge; drawing one row fewer than would have fit is the
  // price, and it is the right one.
  readonly property int tileMax: Style.space(15) * 2 + view.lineName
    + view.lineBody * 3 + Style.space(10)

  readonly property int gridRows: Math.ceil(view.unitCount / view.columns)

  readonly property int marketSection: view.marketCount > 0
    ? view.labelHeight + view.marketCount * view.marketRowHeight + Style.space(6) : 0

  readonly property int matched: Number(view.counts.matched || view.unitCount)
  readonly property bool hasMore: view.matched > view.unitCount
  readonly property int hintHeight: view.hasMore ? Style.space(20) : 0

  readonly property int visibleGridRows: {
    if (view.unitCount === 0) return 0
    var room = (view.maxHeight > 0 ? view.maxHeight : view.tileMax * 3)
      - view.pad * 2 - view.marketSection - view.labelHeight - view.hintHeight
    var fit = Math.floor((room + view.gap) / (view.tileMax + view.gap))
    return Math.max(1, Math.min(view.gridRows, fit))
  }

  // The tile window slides only far enough to keep the selection inside it. A
  // selection still up in the marketplaces holds the tiles at the top.
  readonly property int firstGridRow: {
    var sel = view.selectedTile
    if (sel < 0) return 0
    var selRow = Math.floor(Math.min(sel, view.unitCount - 1) / view.columns)
    if (selRow < view.visibleGridRows) return 0
    return Math.min(Math.max(0, view.gridRows - view.visibleGridRows),
                    selRow - view.visibleGridRows + 1)
  }

  implicitHeight: view.rows.length > 0
    ? view.pad * 2 + view.marketSection
      + (view.unitCount > 0 ? view.labelHeight + grid.height + view.hintHeight : 0)
    : 0

  function faint(alpha) {
    return Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                   view.launcher.foreground.b, alpha)
  }

  // ---------------------------------------------------------- marketplaces
  MarketplaceLabel {
    id: marketsLabel
    launcher: view.launcher
    label: view.marketCount > 0 ? "marketplaces" : ""
    x: view.pad
    y: view.pad
    width: view.inner
    inset: Style.space(2)
  }

  Column {
    id: marketList
    x: view.pad
    y: view.pad + (view.marketCount > 0 ? view.labelHeight : 0)
    width: view.inner
    spacing: 0

    Repeater {
      model: view.marketCount

      delegate: Item {
        id: marketRow

        required property int index

        readonly property int slot: marketRow.index < view.marketIndex.length
          ? view.marketIndex[marketRow.index] : -1
        readonly property var row: marketRow.slot >= 0 ? view.rows[marketRow.slot] : null
        readonly property bool selected: marketRow.slot === view.launcher.selectedIndex

        width: view.inner
        height: view.marketRowHeight

        // No box, no border, no rail. The only fill on this row is the cursor.
        Rectangle {
          anchors.fill: parent
          anchors.topMargin: Style.space(2)
          anchors.bottomMargin: Style.space(2)
          radius: Style.cornerRadius
          color: marketRow.selected
            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.13)
            : "transparent"
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: if (marketRow.slot >= 0) view.launcher.select(marketRow.slot)
          onClicked: if (marketRow.row) view.launcher.activate(marketRow.row)
        }

        Text {
          id: marketName
          x: Style.space(10)
          anchors.top: parent.top
          anchors.topMargin: Style.space(7)
          width: Math.max(Style.space(60),
            parent.width - marketStats.width - Style.space(30))
          text: marketRow.row ? String(marketRow.row.title || "") : ""
          color: marketRow.selected ? view.launcher.selectedText
                                    : view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        // The count sits on the name's line, on the right, because it is the
        // one fact about a marketplace that is a number and numbers want a
        // column. Everything else on this screen is left aligned.
        Text {
          id: marketStats
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.baseline: marketName.baseline
          text: marketRow.row ? String(marketRow.row.meta || "") : ""
          color: view.faint(0.40)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        // Local or remote, then where it points. Two Texts rather than one
        // string, because the word is a step brighter than the path: a
        // marketplace you are editing and one you pulled are different things
        // to be running against, and this row used to show a path either way
        // with nothing saying which. No pill and no badge: the word does it,
        // the way the CLI does it.
        Text {
          id: marketKind
          x: Style.space(10)
          anchors.top: marketName.bottom
          anchors.topMargin: Style.space(2)
          visible: text !== ""
          text: marketRow.row ? String(marketRow.row.kindWord || "") : ""
          color: view.faint(0.44)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          anchors.left: marketKind.visible ? marketKind.right : parent.left
          anchors.leftMargin: marketKind.visible ? Style.space(8) : Style.space(10)
          anchors.baseline: marketKind.baseline
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          text: marketRow.row ? String(marketRow.row.subtitle || "") : ""
          color: view.faint(0.22)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideLeft
        }
      }
    }
  }

  // --------------------------------------------------------------- installed
  MarketplaceLabel {
    launcher: view.launcher
    label: view.unitCount > 0 ? view.unitLabel : ""
    x: view.pad
    y: view.pad + view.marketSection
    width: view.inner
    inset: Style.space(2)
  }

  Column {
    id: grid
    x: view.pad
    y: view.pad + view.marketSection + view.labelHeight
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
          model: view.columns

          delegate: MarketplaceTile {
            id: cell

            required property int index

            readonly property int place:
              (view.firstGridRow + gridRow.index) * view.columns + cell.index
            readonly property int slot: (cell.place >= 0 && cell.place < view.unitCount)
              ? view.unitIndex[cell.place] : -1

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

  Text {
    visible: view.hasMore
    x: view.pad + Style.space(2)
    y: view.pad + view.marketSection + view.labelHeight + grid.height + Style.space(2)
    height: view.hintHeight
    verticalAlignment: Text.AlignVCenter
    text: view.unitCount + " of " + view.matched + "  ·  keep typing to narrow it"
    color: view.faint(0.30)
    font.family: view.launcher.fontFamily
    font.pixelSize: Style.font.caption
  }
}
