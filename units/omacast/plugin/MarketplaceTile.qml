import QtQuick
import qs.Commons
import qs.Ui

// One tile in the `bo:` grid, drawn the same on the home screen and in the
// browse. It lives in its own file because the two screens have to be one
// design: a unit that reads one way under INSTALLED and another way under
// `bo:plugins` is two designs that happen to share a colour scheme.
//
// State is the tile, not a control on it. A unit that is on is filled and
// written at full contrast; one that is off is flat and grey; one this machine
// cannot run is fainter still and its summary is replaced by the reason. There
// is no switch, because a switch is a thing to read and a filled tile among
// flat ones is a thing to see. Enter is the switch, and the launcher's footer
// says which way it will go.
//
// Three levels and no boxes: the name at 13px full contrast, the summary at
// 10px around 60%, and one quiet line at 10px around 30% carrying the keys and
// the warnings. One alignment column, nothing right-aligned, and no border,
// rail or edge anywhere.
//
// The height is the content's height. A unit with five keybindings is taller
// than one with none, and an unavailable unit is shortest of all because it has
// the least to offer.
//
// The parent sets `width`, `row`, `position` and `selected`, and reads
// `implicitHeight` back.
Item {
  id: tile

  required property var launcher

  // The row this tile draws, or null for a slot past the end of the answer.
  // A null slot holds its column open at zero height, so the last row of a
  // grid does not stretch one tile across the full width.
  property var row: null

  // Where this row sits in the launcher's list, for select and activate.
  property int position: -1
  property bool selected: false

  readonly property int pad: Style.space(14)

  readonly property bool isMarket: tile.row !== null
    && String(tile.row.tile || "unit") === "market"
  readonly property string unitState: tile.row !== null
    ? String(tile.row.state || "off") : "off"
  readonly property bool isOn: !tile.isMarket && tile.unitState === "on"
  readonly property bool blocked: !tile.isMarket && tile.unitState === "unavailable"

  // A marketplace says its counts second and where it lives last; a unit says
  // what it does second and what it will claim last. Same three slots, so the
  // two never look like two designs.
  readonly property string body2: tile.row === null ? ""
    : (tile.isMarket ? String(tile.row.meta || "")
       : (tile.blocked ? String(tile.row.reason || "")
          : String(tile.row.subtitle || "")))
  readonly property string body3: tile.row === null ? ""
    : (tile.isMarket ? String(tile.row.subtitle || "")
       : String(tile.row.meta || ""))

  implicitHeight: tile.row !== null ? content.height + tile.pad * 2 + Style.space(2) : 0

  function faint(alpha) {
    return Qt.rgba(tile.launcher.foreground.r, tile.launcher.foreground.g,
                   tile.launcher.foreground.b, alpha)
  }

  Rectangle {
    id: plate
    anchors.fill: parent
    radius: Style.cornerRadius
    visible: tile.row !== null

    // The whole of the state, and the whole of the selection. A filled tile is
    // on; a tile with an accent wash under it is the one the cursor is on. No
    // outline: an outline on a card is what makes a wall of them read as a form
    // rather than as a shelf.
    color: tile.selected
      ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b,
                tile.isOn ? 0.24 : 0.13)
      : (tile.isOn ? tile.faint(0.07) : "transparent")

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onEntered: if (tile.row && tile.position >= 0) tile.launcher.select(tile.position)
      onClicked: if (tile.row) tile.launcher.activate(tile.row)
    }

    Column {
      id: content
      x: tile.pad
      y: tile.pad
      width: Math.max(1, tile.width - tile.pad * 2)
      spacing: Style.space(4)

      Text {
        width: parent.width
        text: tile.row ? String(tile.row.title || "") : ""
        color: tile.selected ? tile.launcher.selectedText
             : tile.isOn || tile.isMarket ? tile.launcher.foreground
             : tile.blocked ? tile.faint(0.38)
             : tile.faint(0.62)
        font.family: tile.launcher.fontFamily
        font.pixelSize: Style.font.subtitle
        // Weight is the half of the on/off signal that survives a theme where
        // the accent and the foreground are the same colour, which is the
        // shipped default.
        font.bold: tile.isOn || tile.isMarket
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: tile.body2 !== ""
        text: tile.body2
        // The reason keeps its hue rather than being dimmed with the rest of
        // the tile: it is the one thing on an unavailable tile worth reading,
        // and it turns "not this one" into "not until you install that".
        color: tile.blocked ? Color.urgent
             : tile.isOn || tile.isMarket ? tile.faint(0.60)
             : tile.faint(0.36)
        font.family: tile.launcher.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        lineHeight: 1.25
      }

      Text {
        width: parent.width
        visible: tile.body3 !== ""
        text: tile.body3
        color: tile.faint(tile.selected ? 0.42
             : (tile.isOn || tile.isMarket ? 0.32 : 0.24))
        font.family: tile.launcher.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }
}
