import QtQuick
import qs.Commons

// A small pill of secondary information: the scope you are in, a file
// extension, a workspace name, a track's year.
//
// A chip exists to be scanned, not read. It carries one short fact and gets out
// of the way, which is why it is quieter than body text rather than louder:
// making every label shout is how a list stops having a hierarchy at all.
Rectangle {
  id: chip

  property alias text: label.text
  property color foreground: Color.menu.text
  property bool accented: false
  property string fontFamily: Style.font.menuFamily

  implicitWidth: label.implicitWidth + Style.space(16)
  implicitHeight: Style.space(20)
  radius: height / 2

  color: accented
    ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
    : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.07)

  visible: label.text !== ""

  Text {
    id: label
    anchors.centerIn: parent
    color: chip.accented ? Color.accent : Qt.darker(chip.foreground, 1.6)
    font.family: chip.fontFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 0.2
  }
}
