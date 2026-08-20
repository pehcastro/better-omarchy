import QtQuick
import qs.Commons
import qs.Ui

// The way out of a level, drawn at the top of every screen that is not home.
//
// Escape already pops the launcher step stack and always did. This is the same
// move made visible, because a keystroke nobody can see is a keystroke half the
// people using it never find. It names where it goes rather than saying "back",
// so the top of a unit page reads as the marketplace it belongs to.
//
// It is a real row in the launcher list, the first one, so it is reachable with
// the arrow keys, clickable with the mouse, and the footer describes it like
// any other row. That also makes it the row selected on arrival, which is on
// purpose: the first thing your finger can hit on a new screen is the thing
// that undoes the navigation, never the thing that changes the machine.
Item {
  id: back

  required property var launcher
  property string label: ""
  property bool selected: false

  height: Style.space(26)

  // The fill hugs the words rather than filling the row it sits in. A
  // full-width bar behind two words reads as a table row and made the whole
  // screen look like a form.
  Rectangle {
    x: Style.space(3)
    y: Style.space(2)
    width: arrow.width + label.width + Style.space(23)
    height: parent.height - Style.space(4)
    radius: height / 2
    color: back.selected
      ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
      : "transparent"
  }

  Text {
    id: arrow
    x: Style.space(9)
    anchors.verticalCenter: parent.verticalCenter
    text: "←"
    color: back.selected ? back.launcher.selectedText
                         : Qt.rgba(back.launcher.foreground.r, back.launcher.foreground.g,
                                   back.launcher.foreground.b, 0.40)
    font.family: back.launcher.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Text {
    id: label
    anchors.left: arrow.right
    anchors.leftMargin: Style.space(8)
    anchors.baseline: arrow.baseline
    text: back.label
    color: back.selected ? back.launcher.selectedText
                         : Qt.rgba(back.launcher.foreground.r, back.launcher.foreground.g,
                                   back.launcher.foreground.b, 0.52)
    font.family: back.launcher.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
