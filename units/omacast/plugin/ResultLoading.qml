import QtQuick
import qs.Commons
import qs.Ui

// What is on screen while an extension is still answering.
//
// A blank card with "Nothing matches" under it is a wrong answer, not a missing
// one: the launcher is saying there is nothing there when it has not looked
// yet. And a card that collapses to a line and then jumps back open when the
// rows arrive is worse than one that stays still.
//
// So the shape of the answer is drawn before the answer exists. Rows of the
// right height in the right places, breathing gently, and when the real rows
// replace them nothing moves.
Item {
  clip: true
  id: view

  required property var launcher

  property int maxHeight: 0

  readonly property int rowHeight: Style.space(46)
  readonly property int pad: Style.space(8)

  // Three is enough to read as a list without pretending to know how long the
  // answer will be.
  readonly property int rows: 3

  implicitHeight: {
    var wanted = view.pad * 2 + view.rows * view.rowHeight
    return view.maxHeight > 0 ? Math.min(wanted, view.maxHeight) : wanted
  }

  Column {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: view.pad
    spacing: 0

    Repeater {
      model: view.rows

      Item {
        required property int index
        width: parent.width
        height: view.rowHeight

        Row {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(24)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(12)

          // A short block where the leading value goes, then a longer one for
          // the name. Two widths rather than one, so it reads as a row of
          // content and not as a progress bar.
          Rectangle {
            width: Style.space(56)
            height: Style.space(12)
            radius: Style.space(3)
            color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                           view.launcher.foreground.b, 0.10)
          }

          Rectangle {
            width: Style.space(120) + (index % 2 === 0 ? Style.space(40) : 0)
            height: Style.space(12)
            radius: Style.space(3)
            color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                           view.launcher.foreground.b, 0.07)
          }
        }
      }
    }
  }

  // Deliberately still.
  //
  // It pulsed, which looked alive and cost more than it was worth: a screen
  // that never stops changing cannot be watched for stillness, and the recorder
  // that waits for an answer to settle sat through the full timeout on every
  // query that showed this. A skeleton says "not yet" by being a skeleton. It
  // does not need to breathe.
}
