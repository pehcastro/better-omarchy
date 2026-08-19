import QtQuick
import qs.Commons
import qs.Ui

// The machine's keymap, drawn as keys.
//
// `shortcuts:` answers with two hundred and fifty bindings, and as a list that
// is two hundred and fifty lines reading "SUPER SHIFT + K   Something". The
// string is the wrong shape for the question: nobody asks what the characters
// are, they ask what is on Super, and whether Super Shift plus a letter is
// free. So the modifiers become the grouping and the combination becomes chips,
// one per key, with the last one lit.
//
// The chips are right-aligned, which is the whole trick. Inside a family every
// row has the same modifiers, so aligning on the right puts every key chip in
// one column: the family reads as a keyboard with the taken keys marked, and a
// gap in that column is a free binding. Left-aligned they staggered by the
// width of the modifier words and the column disappeared.
//
// The row carries:
//   keys[]     the combination, modifiers first, key last
//   group      the modifier family, or "Unmodified"
//   accessory  who owns the binding, when it is not the system
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

  readonly property int rowHeight: Style.space(30)

  // Deliberately the same as a row. A family header is drawn inside the first
  // delegate of its family, so the content is rows and headers interleaved, and
  // the only way a cut can be guaranteed to land between two of them at every
  // scroll position is for both to be the same height. Made shorter, the view
  // ends flush on first paint and then ends on a sliced row the moment anyone
  // scrolls, which reads as a rendering fault rather than as more below.
  readonly property int headerHeight: rowHeight

  readonly property int pad: Style.space(10)
  readonly property int margin: Style.space(18)

  // Wide enough for the widest combination on this machine, which is three
  // modifiers and a spelled-out key. Fixed rather than measured, because the
  // point is that the action text starts at the same x on every row: a column
  // that fitted itself to its contents would move every time the query changed.
  readonly property int keyColumn: Style.space(224)
  readonly property int chipGap: Style.space(4)

  // The first row of each family carries that family's header. Rows arrive
  // already sorted by family, so a change of group is a boundary and there is
  // never a second run of the same one.
  function headerFor(index) {
    var rows = view.launcher.rows
    if (index < 0 || index >= rows.length) return ""
    var group = String(rows[index].group || "")
    if (index === 0) return group
    return String(rows[index - 1].group || "") === group ? "" : group
  }

  // How many bindings the family holds, drawn next to its name. "Super · 49" is
  // the answer to "how full is this modifier", which is the question anyone
  // looking for somewhere to put a new binding is actually asking.
  readonly property var familySizes: {
    var sizes = {}
    var rows = view.launcher.rows
    for (var i = 0; i < rows.length; i++) {
      var g = String(rows[i].group || "")
      sizes[g] = (sizes[g] || 0) + 1
    }
    return sizes
  }

  readonly property int headerCount: {
    var seen = 0
    for (var i = 0; i < view.launcher.rows.length; i++)
      if (view.headerFor(i) !== "") seen += 1
    return seen
  }

  // Rows and headers are the same height, so the content is simply that many
  // bands of one height.
  readonly property int bands: view.launcher.rows.length + view.headerCount
  readonly property int wantedHeight: view.pad * 2 + view.bands * view.rowHeight

  // Capped by the screen and by nothing else. Every other view honours the
  // user's "how many rows at once" setting, and this one must not: a keymap cut
  // to nine lines is a keymap with one family in it, and the reason to open
  // this is to see more than nine at a time.
  readonly property int cap: view.maxHeight > 0
    ? view.maxHeight
    // Before the launcher has said how much room there is, guess at fourteen
    // bands rather than at the whole answer, so the first paint is never taller
    // than the card that has to hold it.
    : view.pad * 2 + 14 * view.rowHeight

  implicitHeight: {
    if (view.launcher.rows.length === 0) return 0
    if (view.wantedHeight <= view.cap) return view.wantedHeight
    var body = view.cap - view.pad
    return view.pad + Math.max(1, Math.floor(body / view.rowHeight)) * view.rowHeight
  }

  // Real margins rather than extra room inside the view: padding added to the
  // height alone leaves a gap the next band peeks through.
  topMargin: view.pad
  bottomMargin: view.pad

  focus: false
  interactive: true
  // Flicking settles on a band boundary, so the guarantee the equal heights buy
  // survives the mouse as well as the arrow keys.
  snapMode: ListView.SnapToItem
  boundsBehavior: Flickable.StopAtBounds
  currentIndex: view.launcher.selectedIndex
  highlightMoveDuration: 0
  model: view.launcher.rows

  delegate: Column {
    id: entry

    required property var modelData
    required property int index

    width: view.width
    spacing: 0

    readonly property bool selected: entry.index === view.launcher.selectedIndex
    readonly property string header: view.headerFor(entry.index)
    readonly property var keys: entry.modelData.keys || []

    Item {
      width: entry.width
      height: entry.header !== "" ? view.headerHeight : 0
      visible: entry.header !== ""

      // A line across the top of every family but the first, because the space
      // alone was not enough to separate two families of forty near-identical
      // rows.
      Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: view.margin
        anchors.right: parent.right
        anchors.rightMargin: view.margin
        height: Math.max(1, Style.space(1))
        color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                       view.launcher.foreground.b, 0.08)
        visible: entry.index > 0
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: view.margin
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(5)
        // The family, then how many keys it has spent.
        text: entry.header.toUpperCase() + "   ·   "
          + (view.familySizes[entry.header] || 0)
        color: Qt.darker(view.launcher.foreground, 2.1)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
      }
    }

    Item {
      id: band

      width: entry.width
      height: view.rowHeight

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        anchors.topMargin: Style.space(1)
        anchors.bottomMargin: Style.space(1)
        radius: Style.cornerRadius
        color: entry.selected ? view.launcher.selectedBackground : "transparent"
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: view.launcher.select(entry.index)
        onClicked: view.launcher.activate(entry.modelData)
      }

      // The column the combination is right-aligned inside. It does not clip:
      // a combination wider than the column grows left into the margin rather
      // than losing its first modifier, which is the one thing a clip here
      // could take away without saying so.
      Item {
        id: combo
        x: view.margin
        width: view.keyColumn
        height: parent.height

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: view.chipGap

          Repeater {
            model: entry.keys

            Chip {
              required property var modelData
              required property int index

              text: String(modelData || "")
              // Only the last chip is the key. Inside a family the modifiers
              // repeat on every row, so lighting them too would light the whole
              // card and say nothing.
              accented: index === entry.keys.length - 1
              foreground: view.launcher.foreground
              fontFamily: view.launcher.fontFamily
            }
          }
        }
      }

      Text {
        anchors.left: combo.right
        anchors.leftMargin: Style.space(16)
        anchors.right: owner.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        text: String(entry.modelData.title || "")
        color: entry.selected ? view.launcher.selectedText : view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      // Whose binding it is, on the ones that are not the system's. The
      // launcher's own keys are not in `hyprctl binds` and do not work outside
      // this window, and that is the one thing those rows have to say about
      // themselves that the combination does not.
      Chip {
        id: owner
        anchors.right: parent.right
        anchors.rightMargin: view.margin
        anchors.verticalCenter: parent.verticalCenter
        text: String(entry.modelData.accessory || "")
        foreground: view.launcher.foreground
        fontFamily: view.launcher.fontFamily
      }
    }
  }
}
