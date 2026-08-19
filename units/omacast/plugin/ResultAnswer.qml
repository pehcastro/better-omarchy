import QtQuick
import qs.Commons
import qs.Ui

// A streamed answer, filling the card while it arrives.
//
// Nothing else in the launcher takes time on purpose. This does, so it has to
// show that it is working from the first frame: a caret that blinks while the
// model is still writing, and text that grows rather than appearing at the end.
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

  implicitHeight: Math.min(
    Math.max(Style.space(120), body.implicitHeight + Style.space(48)),
    Style.space(420))

  Flickable {
    id: scroll
    anchors.fill: parent
    anchors.leftMargin: Style.space(20)
    anchors.rightMargin: Style.space(20)
    anchors.topMargin: Style.space(6)
    anchors.bottomMargin: Style.space(6)
    contentWidth: width
    contentHeight: body.implicitHeight + Style.space(24)
    clip: true
    interactive: true

    // Follow the tail while it writes, and stop following the moment the reader
    // scrolls up, because yanking someone back to the bottom mid-sentence is
    // worse than making them scroll down again.
    property bool following: true
    onContentYChanged: {
      if (!view.launcher.answerStreaming) return
      following = contentY >= contentHeight - height - Style.space(40)
    }
    onContentHeightChanged: if (following) contentY = Math.max(0, contentHeight - height)

    Column {
      id: body
      width: scroll.width
      spacing: Style.space(8)

      Row {
        spacing: Style.space(8)

        Chip {
          text: view.launcher.answerModel
          accented: true
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: view.launcher.answerQuestion
          color: Qt.darker(view.launcher.foreground, 1.7)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          width: Math.min(implicitWidth, scroll.width - Style.space(120))
        }
      }

      Text {
        id: answer
        width: parent.width
        text: view.launcher.answerText
        color: view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
      }

      Text {
        visible: view.launcher.answerStreaming
        text: view.launcher.answerText === "" ? "thinking" : "▋"
        color: Color.accent
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body

        SequentialAnimation on opacity {
          running: view.launcher.answerStreaming
          loops: Animation.Infinite
          NumberAnimation { to: 0.25; duration: 500 }
          NumberAnimation { to: 1.0; duration: 500 }
        }
      }

      Text {
        visible: view.launcher.answerError !== ""
        width: parent.width
        text: view.launcher.answerError
        color: Color.urgent
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }
    }
  }
}
