import QtQuick
import qs.Commons
import qs.Ui

// Your notes, drawn as notes.
//
// The split view this replaces was a column of filenames beside a pane showing
// whichever one the cursor was on. That is a file browser: it can only ever
// show you one note at a time, and finding the right one means walking the list
// and reading the pane again at every step. Scanning your own notes is not that
// job. You already know roughly what you wrote; you need to see enough of
// several at once to recognise which one it was.
//
// So each note is a card carrying the four things that identify it: what it is
// called, when you last touched it, how long it is, and the first couple of
// lines of what it actually says. Six of those on screen answer "which one"
// without a single keypress, which is what the preview pane was for.
//
// The row carries, beyond the usual title and subtitle:
//   kind      "note" for one that exists, "new" or "open" for the top row
//   excerpt   the body, heading stripped
//   words     how long the body is, in words
//   detail    the date in full, under the relative one
ListView {
  // The card cannot hold a view that draws past its own height, and every view
  // here computes that height from its content. Clipping at the root is the one
  // thing that makes a wrong sum a short answer rather than rows spilling over
  // the footer and onto the wallpaper.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property int pad: Style.space(8)
  readonly property int gutter: Style.space(14)

  // The write row is one line of intent and the notes under it are three lines
  // of content, so they are not the same height. Everything below that measures
  // the list has to ask rather than multiply.
  readonly property int actionHeight: Style.space(56)
  readonly property int noteHeight: Style.space(86)

  function heightOf(row) {
    return (row && String(row.kind || "note") !== "note")
      ? view.actionHeight : view.noteHeight
  }

  // Whole cards only, from the top. A card cut through the middle at the bottom
  // edge reads as a rendering fault rather than as "the list goes on", and with
  // mixed heights there is no row height to round to: the only way to land on a
  // boundary is to add them up until the next one does not fit.
  readonly property int fitted: {
    var rows = view.launcher.rows
    var room = view.maxHeight > 0 ? view.maxHeight - view.pad * 2 : -1
    var used = 0

    for (var i = 0; i < rows.length && i < view.launcher.maxRows; i++) {
      var next = used + view.heightOf(rows[i])
      if (room >= 0 && next > room) break
      used = next
    }

    // Room for less than one card still draws one, cut off. An empty card is a
    // blank box with a cursor in it, which reads as broken.
    if (used === 0 && rows.length > 0) used = Math.min(view.heightOf(rows[0]), Math.max(0, room))
    return used
  }

  implicitHeight: view.fitted > 0 ? view.fitted + view.pad * 2 : 0

  topMargin: view.pad
  bottomMargin: view.pad

  focus: false
  interactive: true
  currentIndex: launcher.selectedIndex
  highlightMoveDuration: 0
  model: launcher.rows

  delegate: Item {
    id: card

    required property var modelData
    required property int index

    readonly property bool selected: index === view.launcher.selectedIndex
    readonly property string kind: String(modelData.kind || "note")
    readonly property bool isAction: card.kind !== "note"
    readonly property string excerpt: String(modelData.excerpt || "")
    readonly property int words: Number(modelData.words || 0)

    // The write row centres its one line; a note starts its three at the top.
    // Both are anchored to the same edge with a different margin rather than to
    // different edges: an item with both `top` and `verticalCenter` set has two
    // anchors fighting over one axis, and QML resolves that by dropping one and
    // warning about it, which is a blank-looking row and a line in the journal.
    readonly property real headTop: card.isAction
      ? Math.max(0, (face.height - heading.implicitHeight) / 2) : Style.space(11)
    readonly property real stampTop: card.isAction
      ? Math.max(0, (face.height - stamp.implicitHeight) / 2) : Style.space(12)

    width: view.width
    height: view.heightOf(modelData)

    Rectangle {
      id: face
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      anchors.topMargin: Style.space(3)
      anchors.bottomMargin: Style.space(3)
      radius: Style.cornerRadius

      // A note is a piece of paper, so it has a face of its own rather than
      // sitting on the card's background: without it a column of notes is a
      // column of paragraphs and there is no edge between one and the next.
      color: card.selected
        ? view.launcher.selectedBackground
        : Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                  view.launcher.foreground.b, 0.045)

      // The write row is the only one on this card that changes anything on
      // disk, so it is the only one wearing the accent.
      border.width: card.isAction ? Math.max(1, Style.space(1)) : 0
      border.color: Color.accent
    }

    MouseArea {
      anchors.fill: face
      hoverEnabled: true
      onEntered: view.launcher.select(card.index)
      onClicked: view.launcher.activate(card.modelData)
    }

    // A glyph only where it means something. Every note having a page icon
    // beside it is a column of identical icons, which is decoration; the write
    // row having one is the difference between the two things on this list.
    Text {
      id: mark
      visible: card.isAction
      anchors.left: face.left
      anchors.leftMargin: view.gutter
      anchors.verticalCenter: face.verticalCenter
      text: card.kind === "new" ? "" : ""
      color: Color.accent
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.body
      width: Style.space(18)
      horizontalAlignment: Text.AlignHCenter
    }

    // When it was last touched, and how long it is, hard against the right edge
    // so they form a column down the list: the dates line up, and "which is the
    // recent one" is answered by the shape of the column rather than by reading
    // four of them.
    Text {
      id: stamp
      anchors.right: face.right
      anchors.rightMargin: view.gutter
      anchors.top: face.top
      anchors.topMargin: card.stampTop
      text: String(card.modelData.subtitle || "")
      color: card.selected
        ? view.launcher.selectedText : Qt.darker(view.launcher.foreground, 1.8)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
      width: Math.min(implicitWidth, view.width * 0.3)
    }

    Text {
      id: size
      visible: !card.isAction
      anchors.right: face.right
      anchors.rightMargin: view.gutter
      anchors.top: stamp.bottom
      anchors.topMargin: Style.space(2)
      // Zero words is not a missing count, it is a note with nothing under its
      // title yet, and saying so is the point.
      text: card.words === 1 ? "1 word" : card.words + " words"
      color: Qt.darker(view.launcher.foreground, 2.4)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
    }

    Text {
      id: heading
      anchors.left: mark.visible ? mark.right : face.left
      anchors.leftMargin: mark.visible ? Style.space(10) : view.gutter
      anchors.right: stamp.left
      anchors.rightMargin: Style.space(12)
      anchors.top: face.top
      anchors.topMargin: card.headTop
      text: String(card.modelData.title || "")
      color: card.selected ? view.launcher.selectedText : view.launcher.foreground
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.subtitle
      elide: Text.ElideRight
    }

    // Two lines of what it says. Not a preview of the whole note: two lines is
    // what it takes to recognise something you wrote yourself, and any more
    // turns the list back into a document you have to read.
    Text {
      visible: !card.isAction
      anchors.left: face.left
      anchors.leftMargin: view.gutter
      anchors.right: face.right
      anchors.rightMargin: view.gutter
      anchors.top: heading.bottom
      anchors.topMargin: Style.space(6)
      height: Style.space(32)
      text: card.excerpt !== "" ? card.excerpt : "Nothing under the title yet"
      color: card.excerpt !== ""
        ? Qt.darker(view.launcher.foreground, card.selected ? 1.3 : 1.7)
        : Qt.darker(view.launcher.foreground, 2.6)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
      font.italic: card.excerpt === ""
      wrapMode: Text.Wrap
      maximumLineCount: 2
      elide: Text.ElideRight
      verticalAlignment: Text.AlignTop
    }
  }
}
