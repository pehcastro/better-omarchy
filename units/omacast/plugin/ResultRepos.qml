import QtQuick
import qs.Commons
import qs.Ui

// Local checkouts, drawn as checkouts.
//
// A repo has a state, and the state is four facts read together: which branch,
// how much is uncommitted, how far it has drifted from its remote, when it was
// last touched. `repo:` used to hand all four over as one string of symbols in
// a subtitle, "master ● ↑42", which is a sentence you have to parse per row.
// With twelve checkouts that is twelve parses to answer one question, and the
// question is always the same one: which of these did I leave work in.
//
// So the facts get columns, and the columns hold their place whether or not the
// row has anything to put in them. Down the left is a rail that is coloured
// only when something is unfinished, so a screen of clean repos is a screen of
// names and nothing else, and the two that need attention are visible before
// anything has been read. Quiet is the whole design: a repo that is clean and
// in sync should look like it has nothing to say, because it has not.
//
// The path is not on the row. Twelve full paths is twelve lines of noise for a
// fact you want about one repo at a time, so it moves to the strip at the
// bottom along with the upstream and the GitHub slug, and follows the cursor.
//
// The row carries:
//   title  repo name          branch  current branch, or "detached"
//   dirty  changed file count (0 is clean; untracked files are not counted)
//   ahead / behind  commits either side of the upstream, 0 when in sync
//   upstream  "origin/main", empty when the branch tracks nothing
//   path   the checkout, with $HOME as ~      slug  owner/name       age  "4h"
Column {
  // Without this, a height computed from content draws past the card's border
  // when the sum is wrong, rather than being cut off inside it.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property var current: launcher.rows.length > launcher.selectedIndex
    ? launcher.rows[launcher.selectedIndex] : null

  readonly property int rowHeight: Style.space(34)
  readonly property int stripHeight: Style.space(42)
  readonly property int gutter: Style.space(16)
  readonly property int pad: Style.space(8)

  // Fixed slots, because a column that moves is not a column. The drift marks
  // sit in the same place on every row whether or not that row has any, which
  // is what makes a page of them scannable top to bottom.
  readonly property int dirtWidth: Style.space(54)
  readonly property int aheadWidth: Style.space(42)
  readonly property int behindWidth: Style.space(42)
  readonly property int ageWidth: Style.space(38)

  readonly property int wantedRows: launcher.rows.length
  readonly property int roomForRows: {
    var room = (view.maxHeight > 0 ? view.maxHeight : 100000)
      - view.stripHeight - view.pad * 2
    return Math.max(1, Math.floor(room / view.rowHeight))
  }
  // Whole rows only. A half-drawn repo at the bottom edge reads as a rendering
  // fault, not as "there are more".
  readonly property int shownRows: Math.min(view.wantedRows,
    Math.min(view.launcher.maxRows, view.roomForRows))

  // No implicitHeight binding here on purpose. A Column writes its own
  // implicitHeight from C++, which silently overwrites a QML binding on the
  // same property, and the height then stops tracking the row count. The row
  // limit is applied to the Repeater's model instead, so what the Column adds
  // up is already the right answer.

  spacing: 0

  Item { width: 1; height: view.pad }

  Repeater {
    model: view.shownRows

    delegate: Item {
      id: row

      required property int index
      readonly property var repo: view.launcher.rows[index]

      width: view.width
      height: view.rowHeight

      readonly property bool selected: index === view.launcher.selectedIndex
      readonly property int dirty: Number((repo && repo.dirty) || 0)
      readonly property int ahead: Number((repo && repo.ahead) || 0)
      readonly property int behind: Number((repo && repo.behind) || 0)
      readonly property bool drifted: row.ahead > 0 || row.behind > 0

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
        onClicked: view.launcher.activate(row.repo)
      }

      // The one mark that is read before anything else, and it is drawn as an
      // absence: nothing at all when the repo is clean and in sync. Uncommitted
      // work outranks drift because it is the thing that is only on this
      // machine, so it takes the colour the theme reserves for "look here".
      Rectangle {
        id: rail
        anchors.left: parent.left
        anchors.leftMargin: view.gutter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(2, Style.space(3))
        height: parent.height - Style.space(12)
        radius: width / 2
        visible: row.dirty > 0 || row.drifted
        color: row.dirty > 0 ? Color.urgent : Color.accent
      }

      Text {
        id: name
        anchors.left: rail.right
        anchors.leftMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(view.width * 0.30)
        text: String((row.repo && row.repo.title) || "")
        color: row.selected ? view.launcher.selectedText : view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      // Quieter than the name on purpose. Nine repos out of ten are on the
      // branch you expect, and the branch only becomes interesting when you
      // are already looking at the row.
      Text {
        id: branch
        anchors.left: name.right
        anchors.leftMargin: Style.space(14)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(view.width * 0.20)
        text: String((row.repo && row.repo.branch) || "")
        color: Qt.darker(view.launcher.foreground, 1.9)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      // How much is uncommitted, as a number rather than a dot. One bit makes
      // every unfinished repo look alike; the count is what separates a stray
      // whitespace change from the afternoon you walked away from.
      Row {
        id: dirt
        anchors.left: branch.right
        anchors.leftMargin: Style.space(14)
        anchors.verticalCenter: parent.verticalCenter
        width: view.dirtWidth
        spacing: Style.space(5)
        visible: row.dirty > 0

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "●"
          color: Color.urgent
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: String(row.dirty)
          color: Qt.darker(view.launcher.foreground, 1.5)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      // Ahead is accented and behind is not, because they are not the same
      // news: commits that exist only here are work at risk, and commits you
      // have not pulled are somebody else's work waiting.
      Text {
        id: ahead
        anchors.left: dirt.right
        anchors.verticalCenter: parent.verticalCenter
        width: view.aheadWidth
        visible: row.ahead > 0
        text: "↑" + row.ahead
        color: Color.accent
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.left: ahead.right
        anchors.verticalCenter: parent.verticalCenter
        width: view.behindWidth
        visible: row.behind > 0
        text: "↓" + row.behind
        color: Qt.darker(view.launcher.foreground, 1.6)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(18)
        anchors.verticalCenter: parent.verticalCenter
        width: view.ageWidth
        horizontalAlignment: Text.AlignRight
        text: String((row.repo && row.repo.age) || "")
        color: Qt.darker(view.launcher.foreground, 2.4)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  Item { width: 1; height: view.pad }

  // Where the selected repo lives, and what it is tracking. One repo's worth of
  // detail, following the cursor, instead of twelve paths competing above.
  Item {
    width: view.width
    height: view.current ? view.stripHeight : 0
    visible: view.current !== null

    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: Math.max(1, Style.space(1))
      color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                     view.launcher.foreground.b, 0.08)
    }

    // Elided from the left: the end of a path is the part that identifies it.
    Text {
      anchors.left: parent.left
      anchors.leftMargin: view.gutter + Style.space(12)
      anchors.right: tags.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      text: String((view.current && view.current.path) || "")
      color: Qt.darker(view.launcher.foreground, 2.0)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideLeft
    }

    Row {
      id: tags
      anchors.right: parent.right
      anchors.rightMargin: Style.space(18)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      // An empty upstream is a state, not a gap: a branch that tracks nothing
      // can never be ahead or behind, which is why those columns were blank.
      // Saying so beats leaving the reader to infer it from two absences.
      Chip {
        anchors.verticalCenter: parent.verticalCenter
        text: String((view.current && view.current.upstream) || "no upstream")
        foreground: view.launcher.foreground
        fontFamily: view.launcher.fontFamily
      }

      Chip {
        anchors.verticalCenter: parent.verticalCenter
        text: String((view.current && view.current.slug) || "")
        accented: true
        foreground: view.launcher.foreground
        fontFamily: view.launcher.fontFamily
      }
    }
  }
}
