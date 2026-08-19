import QtQuick
import qs.Commons
import qs.Ui

// The default view: grouped rows, an icon, a title, and a chip on the right.
//
// Rows arrive ranked across every provider, so they are grouped here only where
// the group actually changes. That keeps the best answer first, wherever it
// came from, while still telling you what kind of thing you are looking at.
//
// The left gutter carries the row's number, which is what Ctrl+1 to Ctrl+9
// run, and the right edge carries a star when the row is pinned.
ListView {
  // The card cannot hold a view that draws past its own height, and every view
  // here computes that height from its content. Clipping at the root is the one
  // thing that makes a wrong sum a short answer rather than rows spilling over
  // the footer and onto the wallpaper.
  clip: true
  id: view

  required property var launcher

  readonly property int rowHeight: Style.space(42)
  readonly property int headerHeight: Style.space(24)

  // The first row of each run of a group carries that group's header. Ranking
  // decides the order, so a group can appear more than once and that is fine:
  // the header is a label, not a section.
  function headerFor(index) {
    var rows = view.launcher.rows
    if (index >= rows.length) return ""
    var group = String(rows[index].group || "")

    // When the rows are naming their own source, a header saying the same word
    // above them is that word twice. A group that says something the source
    // does not, like Tracks under Spotify, still earns its line.
    if (group === String(rows[index].source || "")) return ""

    if (index === 0) return group
    return String(rows[index - 1].group || "") === group ? "" : group
  }

  // Group headers are drawn inside the delegate, above the row, so a grouped
  // answer is taller than its row count says. Counting only rows left `git:`,
  // which has four groups, about a hundred pixels shorter than its own content,
  // and the rows that did not fit were clipped away with nothing to say so.
  readonly property int headerCount: {
    var seen = 0
    for (var i = 0; i < count && i < launcher.maxRows; i++)
      if (view.headerFor(i) !== "") seen += 1
    return seen
  }

  // How much room the card has left. The launcher sets it, because only the
  // launcher knows where the bottom of the screen is.
  property int maxHeight: 0

  readonly property int pad: Style.space(10)

  // Everything the model would draw, plus a margin at each end.
  readonly property int contentHeight_: launcher.rows.length * rowHeight
    + headerCount * headerHeight
  readonly property int wantedHeight: view.pad + contentHeight_ + view.pad

  // When the answer is longer than the room, the view ends on a row boundary
  // with the top margin still in place. A bottom margin only exists after the
  // last item, so it cannot protect this edge: without the exact arithmetic the
  // next row peeks over the bottom and the card reads as broken rather than as
  // scrollable.
  // Two limits: how many rows the user wants at once, and how much screen is
  // left. Whichever is smaller wins.
  readonly property int cap: {
    var byRows = view.pad * 2 + launcher.maxRows * rowHeight + headerCount * headerHeight
    return view.maxHeight > 0 ? Math.min(view.maxHeight, byRows) : byRows
  }

  implicitHeight: {
    if (view.wantedHeight <= view.cap) return view.wantedHeight
    var body = view.cap - view.pad - headerCount * headerHeight
    return view.pad + Math.max(1, Math.floor(body / rowHeight)) * rowHeight
      + headerCount * headerHeight
  }

  // Real margins, not extra room inside the view. The breathing space used to
  // be added to implicitHeight alone, which left a gap the next row peeked
  // through: the answer looked cut in half rather than merely longer than the
  // box. Margins move the content instead of making space beside it.
  topMargin: Style.space(10)
  bottomMargin: Style.space(10)

  focus: false
  interactive: true
  currentIndex: launcher.selectedIndex
  highlightMoveDuration: 0
  model: launcher.rows

  delegate: Column {
    required property var modelData
    required property int index

    width: view.width
    spacing: 0

    readonly property bool selected: index === view.launcher.selectedIndex
    readonly property string header: view.headerFor(index)

    Item {
      width: parent.width
      height: parent.header !== "" ? view.headerHeight : 0
      visible: parent.header !== ""

      Text {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(30)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(4)
        text: parent.parent.header.toUpperCase()
        color: Qt.darker(view.launcher.foreground, 2.1)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
      }
    }

    Item {
      width: parent.width
      height: view.rowHeight

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        anchors.topMargin: Style.space(1)
        anchors.bottomMargin: Style.space(1)
        radius: Style.cornerRadius
        color: parent.parent.selected ? view.launcher.selectedBackground : "transparent"
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: view.launcher.select(parent.parent.index)
        onClicked: view.launcher.activate(parent.parent.modelData)
      }

      // Only the first nine are numbered, because only the first nine have a
      // chord that runs them.
      Text {
        visible: parent.parent.index < 9
        text: String(parent.parent.index + 1)
        color: Qt.darker(view.launcher.foreground, 2.4)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        width: Style.space(12)
        horizontalAlignment: Text.AlignRight
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
      }

      Image {
        id: icon
        visible: String(parent.parent.modelData.iconSource || "") !== ""
        source: parent.parent.modelData.iconSource || ""
        width: Style.space(20)
        height: Style.space(20)
        fillMode: Image.PreserveAspectFit
        sourceSize.width: width * Screen.devicePixelRatio
        sourceSize.height: height * Screen.devicePixelRatio
        anchors.left: parent.left
        anchors.leftMargin: Style.space(30)
        anchors.verticalCenter: parent.verticalCenter
      }

      // The glyph takes the extension's own colour when it declared one, which
      // is the cheapest place to put it: it is already the leftmost thing on
      // the row, so a green dot and a red dot separate two sources before
      // either name has been read.
      Text {
        visible: !icon.visible
        text: String(parent.parent.modelData.iconGlyph || "")
        color: parent.parent.modelData.accent
          ? parent.parent.modelData.accent
          : (parent.parent.selected ? view.launcher.selectedText : Qt.darker(view.launcher.foreground, 1.5))
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        width: Style.space(20)
        horizontalAlignment: Text.AlignHCenter
        anchors.left: parent.left
        anchors.leftMargin: Style.space(30)
        anchors.verticalCenter: parent.verticalCenter
      }

      // Title above, detail below, so a row can carry two facts without either
      // fighting the other for the same line.
      Column {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(62)
        anchors.right: star.visible ? star.left : descriptor.left
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          width: parent.width
          text: String(parent.parent.parent.modelData.title || "")
          color: parent.parent.parent.selected ? view.launcher.selectedText : view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
          opacity: parent.parent.parent.modelData.pending ? 0.5 : 1
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          visible: text !== ""
          text: String(parent.parent.parent.modelData.detail || "")
          color: Qt.darker(view.launcher.foreground, 2.0)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      // The kind of thing this is, last and hard against the right edge, in a
      // slot as wide as the widest one in this answer. A row without a chip
      // leaves the slot empty rather than letting the text beside it slide
      // across, so the chips share a left edge as well as a right one.
      Item {
        id: tail
        anchors.right: parent.right
        anchors.rightMargin: Style.space(20)
        anchors.verticalCenter: parent.verticalCenter
        width: view.launcher.chipColumn
        height: Style.space(20)

        Chip {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: view.launcher.chipFor(tail.parent.parent.modelData)
          accented: String(tail.parent.parent.modelData.source || "") !== ""
          tint: tail.parent.parent.modelData.accent
            ? tail.parent.parent.modelData.accent : Color.accent
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }
      }

      // What the thing is: an app's own descriptor, a command's category. Plain
      // text, right-aligned against the chip slot, so its right edge is a column
      // too even though its length is not.
      Text {
        id: descriptor
        anchors.right: tail.left
        anchors.rightMargin: view.launcher.chipColumn > 0 ? Style.space(10) : 0
        anchors.verticalCenter: parent.verticalCenter
        text: String(parent.parent.modelData.subtitle || "")
        color: Qt.darker(view.launcher.foreground, 1.8)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        width: Math.min(implicitWidth, view.width * 0.3)
      }

      Text {
        id: star
        anchors.right: descriptor.left
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        visible: parent.parent.modelData.pinned === true
        text: "\u2605"
        color: Color.accent
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
