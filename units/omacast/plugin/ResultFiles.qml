import QtQuick
import qs.Commons
import qs.Ui

// Files, drawn as files. Serves both `file:` and `recent:`.
//
// A filename in a plain row throws away everything that makes a file
// recognisable. You do not pick a photo out of a list by reading "IMG_4471.jpg",
// and you do not tell this week's export from last year's by reading a name at
// all: you look at the picture, at the size, at how long ago it was touched.
// The list view had all four of those facts and drew three of them as grey text
// under a title, which is the same as not having them.
//
// Rows, not a grid. A grid is right when every result is a picture, which is
// what `img:` is for; `file:` answers with a PDF, a shell script and a photo in
// the same breath, and a wall of identical generic icons is worse than a row.
// The row earns its shape instead: a 36px slot on the left that is either the
// picture itself or the type spelled out, the name on its own line, the folder
// as a path underneath, and size and age as two right-aligned columns that line
// up down the whole answer so they can be compared without being read.
//
// The row carries:
//   title  base name        dir   folder, with $HOME as ~
//   ext    "PDF", "" for a file with none
//   kind   image|video|audio|doc|sheet|code|data|archive|folder|file
//   size   "1.2M", empty for a folder
//   age    "3d"
//   art    file:// URL, only ever for an image
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

  // Two lines of text plus air. Tighter than this and the path collides with
  // the name; looser and eight results stop fitting on a laptop screen.
  readonly property int rowHeight: Style.space(48)
  // Big enough that a screenshot is recognisable and small enough that the row
  // is still a row. Below about 30px a thumbnail is a coloured smudge.
  readonly property int slot: Style.space(36)
  readonly property int gutter: Style.space(16)
  // One width for size and age both, so the two readings form columns rather
  // than two ragged edges. "437M" and "12mo" are the longest either gets.
  readonly property int metaWidth: Style.space(52)
  readonly property int pad: Style.space(10)

  readonly property int wantedHeight: view.pad + launcher.rows.length * rowHeight + view.pad

  // Two limits: how many rows the user asked for at once, and how much screen
  // is left. Whichever is smaller wins.
  readonly property int cap: {
    var byRows = view.pad * 2 + launcher.maxRows * view.rowHeight
    return view.maxHeight > 0 ? Math.min(view.maxHeight, byRows) : byRows
  }

  // When the answer is longer than the room, the view ends on a row boundary.
  // Without the exact arithmetic the next row peeks over the bottom edge and
  // the card reads as broken rather than as scrollable.
  implicitHeight: {
    if (view.wantedHeight <= view.cap) return view.wantedHeight
    var body = view.cap - view.pad
    return view.pad + Math.max(1, Math.floor(body / view.rowHeight)) * view.rowHeight
  }

  // Real margins, not extra room inside the view: space added to implicitHeight
  // alone leaves a gap the next row peeks through.
  topMargin: view.pad
  bottomMargin: view.pad

  focus: false
  interactive: true
  currentIndex: launcher.selectedIndex
  highlightMoveDuration: 0
  model: launcher.rows

  delegate: Item {
    id: row

    required property var modelData
    required property int index

    width: view.width
    height: view.rowHeight

    readonly property bool selected: index === view.launcher.selectedIndex
    readonly property string kind: String(modelData.kind || "file")
    readonly property string ext: String(modelData.ext || "")
    // An image that failed to decode falls back to the type mark rather than
    // leaving a hole. A file:// URL can point at a JPEG that is really a
    // truncated download, and a blank square looks like the view is broken.
    readonly property bool hasArt: String(modelData.art || "") !== ""
      && thumb.status !== Image.Error

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      anchors.topMargin: Style.space(1)
      anchors.bottomMargin: Style.space(1)
      radius: Style.cornerRadius
      color: row.selected ? view.launcher.selectedBackground : "transparent"
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onEntered: view.launcher.select(row.index)
      onClicked: view.launcher.activate(row.modelData)
    }

    // The left rail: a picture, or the type spelled out. Square, both of them.
    // Rounding a thumbnail needs a MultiEffect layer per delegate, and this
    // list is rebuilt on every keystroke over the home directory, so the corner
    // is not worth a mask per row. Squares at least agree with each other.
    Item {
      id: markSlot
      width: view.slot
      height: view.slot
      anchors.left: parent.left
      anchors.leftMargin: view.gutter
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.fill: parent
        visible: !row.hasArt
        color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                       view.launcher.foreground.b, 0.07)

        // The extension, because "PDF" and "SVG" say more than any one glyph
        // for a generic document does, and because inventing a colour per file
        // type is a promise no theme can keep. Differentiation is the letters.
        Text {
          anchors.centerIn: parent
          visible: row.ext !== "" && row.kind !== "folder"
          text: row.ext.slice(0, 4)
          color: Qt.darker(view.launcher.foreground, 1.7)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 0.4
        }

        // Only where there is no extension to show: a folder, or a script
        // called `backup` with nothing after a dot.
        Text {
          anchors.centerIn: parent
          visible: row.ext === "" || row.kind === "folder"
          text: row.kind === "folder" ? "" : ""
          color: Qt.darker(view.launcher.foreground, 1.9)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.subtitle
        }
      }

      Image {
        id: thumb
        anchors.fill: parent
        visible: row.hasArt
        source: String(row.modelData.art || "")
        // Cropped, not fitted. At 36px a letterboxed landscape photo is a
        // stripe with two empty bands; the middle of the picture is what makes
        // it recognisable.
        fillMode: Image.PreserveAspectCrop
        // Off the main thread and decoded at the size it is drawn, or typing
        // one more letter stalls the launcher while a 40 megapixel photo is
        // read at full resolution to fill a square the size of a stamp.
        asynchronous: true
        cache: true
        sourceSize.width: view.slot * Screen.devicePixelRatio
        sourceSize.height: view.slot * Screen.devicePixelRatio
      }
    }

    // Size and age, right-aligned in one fixed slot so they read as two
    // columns. Reserved whether or not this row has both: a folder with no size
    // must not let its age slide up into the name's line.
    Column {
      id: meta
      width: view.metaWidth
      anchors.right: parent.right
      anchors.rightMargin: Style.space(18)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(3)

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignRight
        text: String(row.modelData.size || "")
        color: Qt.darker(view.launcher.foreground, 1.7)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignRight
        text: String(row.modelData.age || "")
        color: Qt.darker(view.launcher.foreground, 2.3)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Column {
      anchors.left: markSlot.right
      anchors.leftMargin: Style.space(12)
      anchors.right: meta.left
      anchors.rightMargin: Style.space(14)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(3)

      Text {
        width: parent.width
        text: String(row.modelData.title || "")
        color: row.selected ? view.launcher.selectedText : view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Row {
        width: parent.width
        spacing: Style.space(5)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: ""
          color: Qt.darker(view.launcher.foreground, 2.6)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        // Elided from the left, which is the opposite of everywhere else on
        // this card and is correct here: the useful end of a path is the end.
        // "…/units/omacast/bin" tells you where you are; "~/localhost/bet…"
        // tells you nothing you did not already know.
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.space(18)
          text: String(row.modelData.dir || "")
          color: Qt.darker(view.launcher.foreground, 2.2)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideLeft
        }
      }
    }
  }
}
