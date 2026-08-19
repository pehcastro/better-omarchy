import QtQuick
import qs.Commons
import qs.Ui

// A column of times, laid out as times rather than as sentences.
//
// The list view drew "03:38 · Sao Paulo" as one string with the zone id under
// it, which gives the clock, the city and the machine-readable name the same
// weight. They do not have the same weight: you came here for the clock, the
// city tells you whose clock it is, and the zone id is there so you can be sure
// it is the right one. Three jobs, three levels.
//
//   03:38   Sao Paulo                            Local
//           America/Sao_Paulo · -03
//
// The time is set in the largest size the row can carry and in the foreground
// colour; the city sits beside it; the identifier below it is dimmed twice
// over. The shift is right-aligned so the column of "4h behind" can be read
// down the edge without touching anything else. A day chip appears only when
// the date differs from yours, which is the thing people get wrong.
ListView {
  // The card cannot hold a view that draws past its own height.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property int rowHeight: Style.space(46)
  readonly property int pad: Style.space(8)
  readonly property int clockWidth: Style.space(76)

  readonly property int wantedHeight: view.pad * 2 + launcher.rows.length * rowHeight

  readonly property int cap: {
    var byRows = view.pad * 2 + launcher.maxRows * rowHeight
    return view.maxHeight > 0 ? Math.min(view.maxHeight, byRows) : byRows
  }

  // Whole rows only, the same reason the plain list does it: a row cut through
  // the middle at the bottom edge reads as a fault, not as "there is more".
  implicitHeight: {
    if (view.wantedHeight <= view.cap) return view.wantedHeight
    return view.pad + Math.max(1, Math.floor((view.cap - view.pad) / rowHeight)) * rowHeight
  }

  topMargin: view.pad
  bottomMargin: view.pad
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
      anchors.topMargin: Style.space(1)
      anchors.bottomMargin: Style.space(1)
      radius: Style.cornerRadius
      color: parent.selected ? view.launcher.selectedBackground : "transparent"
    }

    // The clock. Its own column, so the times line up down the list and a
    // glance reads the column rather than four separate rows.
    Text {
      id: clock
      anchors.left: parent.left
      anchors.leftMargin: Style.space(24)
      anchors.verticalCenter: parent.verticalCenter
      width: view.clockWidth
      text: String(modelData.clock || "")
      color: parent.selected ? view.launcher.selectedText : view.launcher.foreground
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.large
    }

    Column {
      anchors.left: clock.right
      anchors.leftMargin: Style.space(12)
      anchors.right: shift.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      Text {
        width: parent.width
        text: String(modelData.title || "")
        color: parent.parent.selected ? view.launcher.selectedText : view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      // The identifier, and the abbreviation when it says something the
      // identifier does not. Dimmed twice: it is here to be checked, not read.
      Text {
        width: parent.width
        text: {
          var id = String(modelData.zoneid || "")
          var abbr = String(modelData.detail || "")
          return abbr === "" ? id : id + "  ·  " + abbr
        }
        color: Qt.darker(view.launcher.foreground, 2.3)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    // A day chip, only when the date is not yours.
    Chip {
      id: dayChip
      anchors.right: parent.right
      anchors.rightMargin: Style.space(24)
      anchors.verticalCenter: parent.verticalCenter
      visible: String(modelData.accessory || "") !== ""
      text: String(modelData.accessory || "")
      accented: true
      foreground: view.launcher.foreground
      fontFamily: view.launcher.fontFamily
    }

    // The shift, right-aligned so it forms its own readable column. Your own
    // zone says "Local" and gets the accent, because it is the one row you are
    // measuring everything else against.
    Text {
      id: shift
      anchors.right: dayChip.visible ? dayChip.left : parent.right
      anchors.rightMargin: dayChip.visible ? Style.space(10) : Style.space(24)
      anchors.verticalCenter: parent.verticalCenter
      text: String(modelData.subtitle || "")
      color: text === "Local" ? Color.accent : Qt.darker(view.launcher.foreground, 1.8)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
