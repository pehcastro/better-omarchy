import QtQuick
import qs.Commons
import qs.Ui

// A section label, drawn exactly the way ResultList draws the word above
// QUICKLINKS and WEB: uppercase, caption size, bold, letter-spaced, at the
// foreground darkened 2.1, sitting on the bottom of a 24px band.
//
// It is a file rather than nine lines copied into three views because the whole
// point of matching the launcher's own label is that it keeps matching, and two
// copies of a style are two copies that drift.
Item {
  id: root

  required property var launcher
  property string label: ""
  property int inset: 0

  height: root.label !== "" ? Style.space(24) : 0
  visible: root.label !== ""

  Text {
    anchors.left: parent.left
    anchors.leftMargin: root.inset
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(4)
    text: root.label.toUpperCase()
    color: Qt.darker(root.launcher.foreground, 2.1)
    font.family: root.launcher.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 0.8
  }
}
