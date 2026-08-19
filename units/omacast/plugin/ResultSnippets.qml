import QtQuick
import qs.Commons
import qs.Ui

// Your snippets, drawn as the text they are.
//
// A snippet is a piece of text you paste. The list showed its name, which is
// the one thing you already know, because you chose it: "sig" tells you nothing
// about whether this is the signature with the phone number in it. What decides
// whether this is the right one is the text, and the text was a grey line with
// its newlines squashed out.
//
// So the text is the row. It is set in the fixed-pitch family rather than the
// launcher's, and its line breaks are kept, because a snippet is bytes you are
// about to paste somewhere and it should look on screen the way it will look
// there. The name shrinks to a label above it, which is what a name is for.
//
// Cards are as tall as their snippet, up to four lines. A one-line URL in a
// card built for four lines is mostly empty space, and empty space between two
// snippets is what makes them read as one paragraph.
//
// The row carries, beyond the usual title:
//   text   the snippet, whole, newlines and all
//   lines  how many lines that is
//   chars  how long it is
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

  // The label strip, the text, and the breathing room under it. Split out
  // because everything that measures this list has to add the same three
  // numbers, and a card whose height disagrees with its contents by two pixels
  // is a card with a sliver of the next one showing through.
  readonly property int labelHeight: Style.space(20)
  readonly property int lineHeight: Style.space(16)
  readonly property int cardPad: Style.space(9)

  // How wide the text is, in characters. The card has to be as tall as the
  // snippet will actually draw, and a forty-character URL and a
  // four-hundred-character one are both one line as far as the script is
  // concerned. Measuring is exact here rather than a guess, because the text is
  // set in the fixed-pitch family and every character in it is this wide.
  FontMetrics {
    id: metrics
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }

  readonly property int columnsPerLine: Math.max(20, Math.floor(
    (view.width - Style.space(20) - view.gutter * 2)
      / Math.max(1, metrics.averageCharacterWidth)))

  // Four lines is where recognising stops and reading starts. Past that the
  // list is a document, and you are back to opening things to find out what
  // they are.
  function linesOf(row) {
    var body = String((row && (row.text || row.preview)) || "")
    if (body === "") return 1

    var parts = body.split("\n")
    var total = 0
    for (var i = 0; i < parts.length; i++) {
      total += Math.max(1, Math.ceil(parts[i].length / view.columnsPerLine))
      if (total >= 4) return 4
    }
    return Math.max(1, total)
  }

  function heightOf(row) {
    return view.cardPad * 2 + view.labelHeight + view.linesOf(row) * view.lineHeight
      + Style.space(6)
  }

  // Whole cards only, from the top. With mixed heights there is no row height
  // to round to, so the only way to land on a boundary is to add them up until
  // the next one does not fit.
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
    // blank box, which reads as broken.
    if (used === 0 && rows.length > 0) {
      used = Math.min(view.heightOf(rows[0]), Math.max(0, room))
    }
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

    readonly property bool selected: card.index === view.launcher.selectedIndex
    readonly property int shownLines: view.linesOf(card.modelData)
    // `text` is what the script sends; `preview` is the same string under the
    // name the launcher already had, and the title is the last resort so a
    // snippet store written by hand in some other shape still draws something.
    readonly property string body: String(card.modelData.text
      || card.modelData.preview || card.modelData.title || "")

    width: view.width
    height: view.heightOf(card.modelData)

    Rectangle {
      id: face
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      anchors.topMargin: Style.space(3)
      anchors.bottomMargin: Style.space(3)
      radius: Style.cornerRadius

      // A snippet is a piece of text with an edge around it, or a column of
      // them is one long paragraph with no way to tell where one ends.
      color: card.selected
        ? view.launcher.selectedBackground
        : Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                  view.launcher.foreground.b, 0.045)
    }

    MouseArea {
      anchors.fill: face
      hoverEnabled: true
      onEntered: view.launcher.select(card.index)
      onClicked: view.launcher.activate(card.modelData)
    }

    // The name, as a label on the text rather than as its title: caption size,
    // dimmed, out of the way. You typed it to get here and you do not need it
    // shouted back.
    Text {
      id: label
      anchors.left: face.left
      anchors.leftMargin: view.gutter
      anchors.right: size.left
      anchors.rightMargin: Style.space(8)
      anchors.top: face.top
      anchors.topMargin: view.cardPad
      text: String(card.modelData.title || "")
      color: card.selected ? view.launcher.selectedText : Color.accent
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 0.4
      elide: Text.ElideRight
    }

    // How big it is, so a snippet clipped at four lines does not look like the
    // whole of it. A one-line snippet says only its length: "1 line" beside one
    // visible line is a fact you can already see.
    Text {
      id: size
      anchors.right: face.right
      anchors.rightMargin: view.gutter
      anchors.top: face.top
      anchors.topMargin: view.cardPad
      text: {
        var n = Number(card.modelData.lines || 1)
        var chars = Number(card.modelData.chars || card.body.length)
        return n > 1 ? n + " lines  ·  " + chars : chars + ""
      }
      color: Qt.darker(view.launcher.foreground, card.selected ? 1.5 : 2.5)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
    }

    // The snippet. Fixed pitch and its own line breaks, because this is the
    // thing that lands in the clipboard and the row is the only chance to see
    // it before it does.
    Text {
      anchors.left: face.left
      anchors.leftMargin: view.gutter
      anchors.right: face.right
      anchors.rightMargin: view.gutter
      anchors.top: label.bottom
      anchors.topMargin: Style.space(2)
      height: card.shownLines * view.lineHeight
      text: card.body
      color: card.selected
        ? view.launcher.selectedText : Qt.darker(view.launcher.foreground, 1.25)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      // Wrapping anywhere, not at word boundaries: a snippet is as likely to be
      // a URL or a token as a sentence, and a long one that wraps only at
      // spaces draws one line and a lot of nothing.
      wrapMode: Text.WrapAnywhere
      maximumLineCount: card.shownLines
      elide: Text.ElideRight
      verticalAlignment: Text.AlignTop
    }
  }
}
