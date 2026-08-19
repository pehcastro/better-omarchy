import QtQuick
import qs.Commons
import qs.Ui

// One repo, drawn as a repo.
//
// A bare `git:` is not a search. It is "show me where I am", and answering it
// with six unrelated rows in a list makes the reader assemble the picture from
// parts: the branch in one row, what changed in another, the last commits in a
// third, all at the same weight, all needing to be read in order.
//
// So it is a panel. The repo and its branch across the top, what is uncommitted
// as counts rather than a sentence, and the recent commits under that. What you
// look at first is drawn first and largest; the rest is there to be glanced at.
//
// The row carries:
//   repo     { name, path, branch, upstream, ahead, behind,
//              staged, changed, conflicted, remote }
//   commits  [ { hash, subject, author, age } ]
Item {
  clip: true
  id: view

  required property var launcher

  property int maxHeight: 0

  readonly property var row: launcher.rows.length > 0 ? launcher.rows[0] : null
  readonly property var repo: (view.row && view.row.repo) ? view.row.repo : ({})
  readonly property var commits: (view.row && view.row.commits) ? view.row.commits : []

  readonly property int gutter: Style.space(18)
  readonly property int headHeight: Style.space(72)
  readonly property int statHeight: Style.space(46)
  readonly property int commitHeight: Style.space(34)

  readonly property bool clean: Number(repo.staged || 0) === 0
    && Number(repo.changed || 0) === 0 && Number(repo.conflicted || 0) === 0

  readonly property int shownCommits: {
    if (view.maxHeight <= 0) return Math.min(6, view.commits.length)
    var room = view.maxHeight - view.headHeight - view.statHeight - Style.space(16)
    return Math.max(1, Math.min(view.commits.length, Math.floor(room / view.commitHeight)))
  }

  implicitHeight: view.headHeight + view.statHeight
    + view.shownCommits * view.commitHeight + Style.space(16)

  function ago(seconds) {
    var s = Number(seconds || 0)
    if (s < 60) return "now"
    if (s < 3600) return Math.floor(s / 60) + "m"
    if (s < 86400) return Math.floor(s / 3600) + "h"
    if (s < 2592000) return Math.floor(s / 86400) + "d"
    return Math.floor(s / 2592000) + "mo"
  }

  Column {
    width: view.width
    spacing: 0

    // The repo, and the one thing you always want to know about it: which
    // branch, and how far it has drifted from the remote.
    Item {
      width: parent.width
      height: view.headHeight

      Column {
        anchors.left: parent.left
        anchors.leftMargin: view.gutter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(3)

        Text {
          text: String(view.repo.name || "")
          color: view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.large
        }

        Text {
          text: String(view.repo.path || "")
          color: Qt.darker(view.launcher.foreground, 2.3)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Row {
        anchors.right: parent.right
        anchors.rightMargin: view.gutter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(10)

        // Ahead and behind as their own marks. A branch that is eighteen
        // commits from its remote is the most actionable thing on this screen
        // and it used to be three characters inside a longer string.
        Chip {
          visible: Number(view.repo.ahead || 0) > 0
          text: "↑" + Number(view.repo.ahead || 0)
          accented: true
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }

        Chip {
          visible: Number(view.repo.behind || 0) > 0
          text: "↓" + Number(view.repo.behind || 0)
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: String(view.repo.branch || "")
          color: view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
        }
      }
    }

    // What is uncommitted, as counts. "24 changed, 12 staged" is a sentence to
    // read; three numbers with labels under them is a thing to glance at.
    Item {
      width: parent.width
      height: view.statHeight

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: view.gutter
        anchors.rightMargin: view.gutter
        anchors.topMargin: Style.space(2)
        anchors.bottomMargin: Style.space(8)
        radius: Style.cornerRadius
        color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                       view.launcher.foreground.b, 0.05)
      }

      Text {
        visible: view.clean
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Style.space(3)
        text: "nothing to commit"
        color: Qt.darker(view.launcher.foreground, 2.0)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }

      Row {
        visible: !view.clean
        anchors.left: parent.left
        anchors.leftMargin: view.gutter + Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Style.space(3)
        spacing: Style.space(34)

        Repeater {
          model: [
            { label: "changed", value: Number(view.repo.changed || 0) },
            { label: "staged", value: Number(view.repo.staged || 0) },
            { label: "conflicted", value: Number(view.repo.conflicted || 0) }
          ]

          Row {
            required property var modelData
            visible: modelData.value > 0
            spacing: Style.space(6)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: String(modelData.value)
              color: view.launcher.foreground
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.body
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              color: Qt.darker(view.launcher.foreground, 2.0)
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }

    // What happened lately. Hash, subject, how long ago: the three things that
    // decide whether you want to look at it.
    Repeater {
      model: view.shownCommits

      Item {
        required property int index
        readonly property var commit: view.commits[index]

        width: view.width
        height: view.commitHeight

        Text {
          id: hash
          anchors.left: parent.left
          anchors.leftMargin: view.gutter + Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(58)
          text: String(commit.hash || "")
          color: Qt.darker(view.launcher.foreground, 2.2)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          anchors.left: hash.right
          anchors.leftMargin: Style.space(8)
          anchors.right: age.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          text: String(commit.subject || "")
          color: view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        Text {
          id: age
          anchors.right: parent.right
          anchors.rightMargin: view.gutter + Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
          text: view.ago(commit.age)
          color: Qt.darker(view.launcher.foreground, 2.4)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
