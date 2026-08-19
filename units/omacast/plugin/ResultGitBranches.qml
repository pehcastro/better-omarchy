import QtQuick
import qs.Commons
import qs.Ui

// Every local branch of one repo, drawn so that picking one is a decision
// rather than a guess.
//
//   branch:            the repo you are in
//   branch:omarchy     the repo called omarchy
//
// A list of branch names is not worth building. Three things decide which
// branch you want, and none of them is the name: which one you are on, whether
// it has work that is not pushed, and how far it has fallen behind the trunk.
// So each is a mark of its own weight. The checkout dot is accented and first,
// because it is the row you are not looking for. Ahead of the upstream is
// accented too, because unpushed work is the thing you can lose. Behind the
// trunk is quiet, because it is a fact and not a warning.
//
// Across the top: the repo, and whether the tree is dirty. That line is the
// confirmation. `git switch` refuses to overwrite uncommitted work and the
// refusal comes back as a notification, but being told after you pressed Enter
// is worse than knowing before, and it is also what makes the second action on
// every row, "Stash and Switch", make sense when you reach for it.
//
// Rows carry:
//   name current upstream gone ahead behind trunk trunkAhead trunkBehind
//   subject author accessory
//   repo   { name, path, branch, trunk, staged, changed, conflicted, count }
//          on the first row only
Column {
  // The card cannot hold a view that draws past its own height, and every view
  // here computes that height from its content. Clipping at the root is the one
  // thing that makes a wrong sum a short answer rather than rows spilling over
  // the footer and onto the wallpaper.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property var head: launcher.rows.length > 0 ? launcher.rows[0] : null
  readonly property var repo: (view.head && view.head.repo) ? view.head.repo : ({})

  readonly property int gutter: Style.space(18)
  readonly property int headerHeight: Style.space(52)
  readonly property int rowHeight: Style.space(46)

  readonly property int dirtyCount: Number(view.repo.staged || 0)
    + Number(view.repo.changed || 0) + Number(view.repo.conflicted || 0)

  readonly property int shown: {
    var rows = view.launcher.rows.length
    if (view.maxHeight <= 0) return Math.min(rows, 8)
    var room = view.maxHeight - view.headerHeight - Style.space(12)
    return Math.max(1, Math.min(rows, Math.floor(room / view.rowHeight)))
  }

  spacing: 0

  // The repo, and the one fact that changes what happens when you press Enter.
  Item {
    width: view.width
    height: view.headerHeight

    Column {
      anchors.left: parent.left
      anchors.leftMargin: view.gutter
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        text: String(view.repo.name || "")
        color: view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        text: {
          var n = view.launcher.rows.length
          var branches = n + (n === 1 ? " branch" : " branches")
          if (view.dirtyCount === 0) return branches + "  ·  nothing uncommitted"
          return branches + "  ·  " + view.dirtyCount + " uncommitted, so a switch may be refused"
        }
        color: view.dirtyCount > 0
          ? Color.accent : Qt.darker(view.launcher.foreground, 2.2)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Text {
      visible: String(view.repo.trunk || "") !== ""
      anchors.right: parent.right
      anchors.rightMargin: view.gutter
      anchors.verticalCenter: parent.verticalCenter
      text: "vs " + String(view.repo.trunk || "")
      color: Qt.darker(view.launcher.foreground, 2.6)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  ListView {
    id: list
    width: view.width
    height: view.shown * view.rowHeight
    clip: true
    focus: false
    interactive: true
    currentIndex: view.launcher.selectedIndex
    highlightMoveDuration: 0
    model: view.launcher.rows

    delegate: Item {
      required property var modelData
      required property int index

      readonly property bool selected: index === view.launcher.selectedIndex
      readonly property bool current: modelData.current === true

      width: list.width
      height: view.rowHeight

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        anchors.topMargin: Style.space(2)
        anchors.bottomMargin: Style.space(2)
        radius: Style.cornerRadius
        color: parent.selected ? view.launcher.selectedBackground : "transparent"
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: view.launcher.select(index)
        onClicked: view.launcher.activate(modelData)
      }

      // Where you are now. One dot, in the accent, in the same column on every
      // row: the marker is the first thing scanned and it should never have to
      // be read.
      Rectangle {
        id: dot
        anchors.left: parent.left
        anchors.leftMargin: view.gutter
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(7)
        height: Style.space(7)
        radius: width / 2
        color: Color.accent
        visible: parent.current
      }

      Column {
        id: names
        anchors.left: parent.left
        anchors.leftMargin: view.gutter + Style.space(16)
        anchors.right: marks.left
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          width: parent.width
          text: String(modelData.name || "")
          color: view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        // What the branch was last doing, which is how you recognise it when
        // the name is `wip` or a ticket number.
        Text {
          width: parent.width
          text: String(modelData.subject || "")
          color: Qt.darker(view.launcher.foreground, 2.3)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Row {
        id: marks
        anchors.right: parent.right
        anchors.rightMargin: view.gutter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        // Unpushed work. Accented, because it is the only thing on this row
        // that exists nowhere else.
        Chip {
          text: "↑" + Number(modelData.ahead || 0)
          visible: Number(modelData.ahead || 0) > 0
          accented: true
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }

        Chip {
          text: "↓" + Number(modelData.behind || 0)
          visible: Number(modelData.behind || 0) > 0
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }

        Chip {
          text: modelData.gone === true ? "gone"
            : (String(modelData.upstream || "") === "" ? "local" : "")
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }

        // Against the trunk. Quiet: it says how stale the branch is, which is
        // context for the decision rather than the decision.
        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: text !== ""
          text: {
            var a = Number(modelData.trunkAhead || 0)
            var b = Number(modelData.trunkBehind || 0)
            var trunk = String(view.repo.trunk || "")
            if (trunk === "" || String(modelData.name || "") === trunk) return ""
            if (a === 0 && b === 0) return "even"
            return (a > 0 ? "+" + a : "") + (a > 0 && b > 0 ? " " : "") + (b > 0 ? "−" + b : "")
          }
          color: Qt.darker(view.launcher.foreground, 2.4)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(34)
          horizontalAlignment: Text.AlignRight
          text: String(modelData.accessory || "")
          color: Qt.darker(view.launcher.foreground, 2.6)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  Item {
    width: view.width
    height: Style.space(12)
  }
}
