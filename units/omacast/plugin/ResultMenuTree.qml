import QtQuick
import qs.Commons
import qs.Ui

// Omarchy's menu, drawn as a menu.
//
// The script flattens a tree so that any setting is one query away, and the
// list view then threw the tree away again: "Theme" under Style and "Style"
// itself came out as two identical rows with a grey sentence under each. The
// flattening is what makes the keyword worth having; losing the structure is
// what made it worth nothing to look at.
//
// So the view puts the structure back without making anyone walk it.
//
// Nothing typed is browsing, and the answer to browsing is the menu's own root:
// ten tiles, each with the icon Omarchy already gave it and how much sits
// behind it. That is the picture you have from opening the menu, which is the
// picture that makes the next keystroke obvious.
//
// Something typed is searching, and then every answer comes from somewhere. The
// path is drawn as a path, in front of the name and dimmer than it, so `Style ›
// Theme` reads as a location rather than as a subtitle nobody's eye goes to.
// A chip on the right says what Enter does, because the one thing the old list
// could not tell you was whether you were about to change a setting or open
// another menu.
//
// The row carries, beyond the usual title and glyph:
//   mode      "browse" for the root, "search" for a flattened match
//   trail     the path above this route, as parts, outermost first
//   kind      "menu" opens a submenu, "action" runs, "link" opens a target
//   node      the dotted route, e.g. style.theme
//   depth     how deep the route sits, 1 for the root
//   children  how many routes sit under this one
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

  readonly property var head: launcher.rows.length > 0 ? launcher.rows[0] : null
  // Only the script knows which question was asked, and it says so on every
  // row. Guessing from the query would mean this view reading the input box,
  // which is the launcher's business and not a view's.
  readonly property bool browsing: !!view.head && String(view.head.mode || "") === "browse"

  readonly property int pad: Style.space(8)
  readonly property int gutter: Style.space(14)

  // ---- browsing

  readonly property int tileHeight: Style.space(66)
  readonly property int tileGap: Style.space(8)
  // Two columns on a narrow card, four on a wide one. A single column would be
  // the list this view exists to stop being, and five puts four words on two
  // lines.
  readonly property int columns: Math.max(2, Math.min(4,
    Math.floor((view.width - view.gutter * 2) / Style.space(150))))
  readonly property int tileRowCount: Math.ceil(view.launcher.rows.length / view.columns)

  // Whole rows of tiles only. Half a tile at the bottom edge reads as a
  // rendering fault rather than as "there is more".
  readonly property int tileRowsShown: {
    if (!view.browsing) return 0
    if (view.maxHeight <= 0) return view.tileRowCount
    var room = view.maxHeight - view.pad * 2
    return Math.max(1, Math.min(view.tileRowCount,
      Math.floor((room + view.tileGap) / (view.tileHeight + view.tileGap))))
  }

  // A grid does not scroll itself, and the selection has to stay visible or Tab
  // walks the cursor off the bottom of a card that never moves. Shifting by
  // whole tile rows is the cheap version of that: the top edge always lands on
  // a boundary, so nothing is ever cut through the middle.
  readonly property int firstTileRow: {
    var selRow = Math.floor(view.launcher.selectedIndex / view.columns)
    var last = Math.max(0, view.tileRowCount - view.tileRowsShown)
    return Math.max(0, Math.min(last, selRow - view.tileRowsShown + 1))
  }

  // ---- searching

  readonly property int rowHeight: Style.space(40)

  readonly property int listRowsShown: {
    var total = Math.min(view.launcher.rows.length, view.launcher.maxRows)
    if (view.maxHeight <= 0) return total
    var room = view.maxHeight - view.pad * 2
    return Math.max(1, Math.min(total, Math.floor(room / view.rowHeight)))
  }

  implicitHeight: view.launcher.rows.length === 0 ? 0 : (view.browsing
    ? view.tileRowsShown * (view.tileHeight + view.tileGap) - view.tileGap + view.pad * 2
    : view.listRowsShown * view.rowHeight + view.pad * 2)

  // Left and right walk the tiles, because in a grid they are the natural way
  // across and the launcher's Up and Down only ever move by one. In the search
  // list they belong to the text cursor and are left alone.
  function nudge(delta) {
    if (!view.browsing) return
    view.launcher.select(Math.max(0, Math.min(view.launcher.rows.length - 1,
      view.launcher.selectedIndex + delta)))
  }

  // ---- the root, as tiles

  Item {
    anchors.fill: parent
    visible: view.browsing
    clip: true

    Grid {
      id: tiles
      x: view.gutter
      y: view.pad - view.firstTileRow * (view.tileHeight + view.tileGap)
      width: view.width - view.gutter * 2
      columns: view.columns
      spacing: view.tileGap

      Repeater {
        model: view.browsing ? view.launcher.rows : []

        Item {
          id: tile

          required property var modelData
          required property int index

          readonly property bool selected: tile.index === view.launcher.selectedIndex
          readonly property int subCount: Number(tile.modelData.children || 0)

          width: Math.floor((tiles.width - (view.columns - 1) * view.tileGap) / view.columns)
          height: view.tileHeight

          Rectangle {
            id: face
            anchors.fill: parent
            radius: Style.cornerRadius
            color: tile.selected
              ? view.launcher.selectedBackground
              : Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                        view.launcher.foreground.b, 0.05)
            border.width: tile.selected ? Math.max(1, Style.space(1)) : 0
            border.color: Color.accent
          }

          MouseArea {
            anchors.fill: face
            hoverEnabled: true
            onEntered: view.launcher.select(tile.index)
            onClicked: view.launcher.activate(tile.modelData)
          }

          // Omarchy's own icon for the route. It is the only part of a tile the
          // eye lands on before reading, and the menu has already taught it.
          Text {
            id: mark
            anchors.left: face.left
            anchors.leftMargin: Style.space(12)
            anchors.top: face.top
            anchors.topMargin: Style.space(10)
            text: String(tile.modelData.iconGlyph || "")
            color: tile.selected ? view.launcher.selectedText : Color.accent
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.iconLarge
          }

          Text {
            anchors.left: face.left
            anchors.leftMargin: Style.space(12)
            anchors.right: count.left
            anchors.rightMargin: Style.space(6)
            anchors.bottom: face.bottom
            anchors.bottomMargin: Style.space(10)
            text: String(tile.modelData.title || "")
            color: tile.selected ? view.launcher.selectedText : view.launcher.foreground
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.subtitle
            elide: Text.ElideRight
          }

          // How much is behind the tile. Zero is not a count worth printing: a
          // section that answers with a provider rather than with children has
          // no number to give, and "0" would read as empty.
          Text {
            id: count
            anchors.right: face.right
            anchors.rightMargin: Style.space(12)
            anchors.bottom: face.bottom
            anchors.bottomMargin: Style.space(11)
            visible: tile.subCount > 0
            text: tile.subCount
            color: Qt.darker(view.launcher.foreground, tile.selected ? 1.4 : 2.4)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  // ---- a search, as routes

  ListView {
    id: list
    anchors.fill: parent
    visible: !view.browsing
    clip: true
    topMargin: view.pad
    bottomMargin: view.pad
    focus: false
    interactive: true
    currentIndex: view.launcher.selectedIndex
    highlightMoveDuration: 0
    model: view.browsing ? [] : view.launcher.rows

    delegate: Item {
      id: route

      required property var modelData
      required property int index

      readonly property bool selected: route.index === view.launcher.selectedIndex
      readonly property string kind: String(route.modelData.kind || "action")
      readonly property var trail: route.modelData.trail || []

      width: list.width
      height: view.rowHeight

      Rectangle {
        id: bar
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        anchors.topMargin: Style.space(2)
        anchors.bottomMargin: Style.space(2)
        radius: Style.cornerRadius
        color: route.selected ? view.launcher.selectedBackground : "transparent"
      }

      MouseArea {
        anchors.fill: bar
        hoverEnabled: true
        onEntered: view.launcher.select(route.index)
        onClicked: view.launcher.activate(route.modelData)
      }

      Text {
        id: icon
        anchors.left: bar.left
        anchors.leftMargin: view.gutter
        anchors.verticalCenter: bar.verticalCenter
        width: Style.space(20)
        horizontalAlignment: Text.AlignHCenter
        text: String(route.modelData.iconGlyph || "")
        // A submenu is a container and a route is a thing you do, so only the
        // things you do wear the accent. Accenting every icon would make the
        // column of them decoration again.
        color: route.selected
          ? view.launcher.selectedText
          : (route.kind === "menu" ? Qt.darker(view.launcher.foreground, 1.9) : Color.accent)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.icon
      }

      // The path, in front of the name and quieter than it. In front rather
      // than under, because the two read as one line that way: `Style › Theme`
      // is where the setting is, and a subtitle under the title is a second
      // line the eye skips.
      Text {
        id: crumb
        anchors.left: icon.right
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: bar.verticalCenter
        visible: route.trail.length > 0
        text: route.trail.join("  ›  ") + "  ›  "
        color: Qt.darker(view.launcher.foreground, route.selected ? 1.5 : 2.5)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideLeft
        // A deep path never gets to push the name off the row: the name is what
        // was searched for, and the path is context.
        width: Math.min(implicitWidth, Math.max(0, bar.width * 0.34))
      }

      Text {
        anchors.left: crumb.visible ? crumb.right : icon.right
        anchors.leftMargin: crumb.visible ? 0 : Style.space(10)
        anchors.right: verb.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: bar.verticalCenter
        text: String(route.modelData.title || "")
        color: route.selected ? view.launcher.selectedText : view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.subtitle
        elide: Text.ElideRight
      }

      // What Enter does, in one word. This is the difference the flat list
      // could not draw: pressing Return on "Theme" changes your theme, and
      // pressing it on "Style" opens a menu you then have to read.
      Chip {
        id: verb
        anchors.right: bar.right
        anchors.rightMargin: view.gutter
        anchors.verticalCenter: bar.verticalCenter
        text: route.kind === "menu" ? "opens"
          : (route.kind === "link" ? "web" : "runs")
        accented: route.kind === "action"
        foreground: view.launcher.foreground
        fontFamily: view.launcher.fontFamily
      }
    }
  }
}
