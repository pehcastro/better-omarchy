import QtQuick
import qs.Commons
import qs.Ui

// One repository on GitHub, drawn as one.
//
// Typing a repository's name into a launcher is usually a tab you are about to
// open. What you were going to look at once it opened is nearly always the same
// three things: is the default branch broken, is there anything waiting to be
// merged, and what is the newest release. Those are three tabs, and none of
// them is worth a tab.
//
// So the counts sit where a list would have put a subtitle, and the open pull
// requests sit under them, each with the mark that says whether it is passing.
// Enter still opens the repository, because most of the time that is what you
// came for and this panel is what you get on the way.
//
// The row carries:
//   repo    { slug, description, language, stars, forks, private, archived,
//             fork, branch, headline, headHash, headAge, headMark, prs,
//             issues, release, releaseAge, pushed, url }
//   prs[]   { number, title, author, draft, mark, review, age }
Item {
  clip: true
  id: view

  required property var launcher

  property int maxHeight: 0

  readonly property var row: launcher.rows.length > 0 ? launcher.rows[0] : null
  readonly property var repo: (view.row && view.row.repo) ? view.row.repo : ({})
  readonly property var prs: (view.row && view.row.prs) ? view.row.prs : []
  readonly property bool waiting: view.row ? view.row.waiting === true : false

  readonly property int gutter: Style.space(18)
  readonly property int inset: Style.space(16)
  readonly property int headHeight: Style.space(72)
  readonly property int statHeight: Style.space(46)
  readonly property int prHeight: Style.space(32)

  readonly property color good: Qt.rgba(0.40, 0.78, 0.45, 1.0)
  readonly property color bad: Qt.rgba(0.90, 0.38, 0.38, 1.0)
  readonly property color busy: Qt.rgba(0.92, 0.72, 0.30, 1.0)

  function tint(m) {
    if (m === "✓") return view.good
    if (m === "✗") return view.bad
    if (m === "●") return view.busy
    return Qt.darker(view.launcher.foreground, 2.2)
  }

  readonly property int shownPrs: {
    var have = view.waiting ? 3 : view.prs.length
    if (have === 0) return 0
    if (view.maxHeight <= 0) return Math.min(6, have)
    var room = view.maxHeight - view.headHeight - view.statHeight - Style.space(16)
    return Math.max(1, Math.min(have, Math.floor(room / view.prHeight)))
  }

  implicitHeight: view.headHeight + view.statHeight
    + view.shownPrs * view.prHeight + Style.space(16)

  Column {
    width: view.width
    spacing: 0

    Item {
      width: parent.width
      height: view.headHeight

      Column {
        anchors.left: parent.left
        anchors.leftMargin: view.gutter
        anchors.right: badges.left
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(3)

        Text {
          width: parent.width
          text: String(view.repo.slug || "")
          color: view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.large
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: String(view.repo.description || "")
          color: Qt.darker(view.launcher.foreground, 2.3)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Row {
        id: badges
        anchors.right: parent.right
        anchors.rightMargin: view.gutter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        Chip {
          anchors.verticalCenter: parent.verticalCenter
          text: view.repo.archived === true ? "archived" : ""
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }

        Chip {
          anchors.verticalCenter: parent.verticalCenter
          text: view.repo.private === true ? "private" : (view.repo.fork === true ? "fork" : "")
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }

        Chip {
          anchors.verticalCenter: parent.verticalCenter
          text: String(view.repo.language || "")
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: Number(view.repo.stars || 0) > 0
          text: "★ " + Number(view.repo.stars || 0)
          color: Qt.darker(view.launcher.foreground, 1.8)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    // The default branch and whether it is broken, then the counts. The branch
    // mark is the one fact on this panel that is genuinely urgent, so it is on
    // the left where reading starts.
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
        visible: view.waiting
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Style.space(3)
        text: "asking GitHub"
        color: Qt.darker(view.launcher.foreground, 2.2)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }

      Row {
        visible: !view.waiting
        anchors.left: parent.left
        anchors.leftMargin: view.gutter + view.inset
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Style.space(3)
        spacing: Style.space(8)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: String(view.repo.headMark || "") !== ""
          text: String(view.repo.headMark || "")
          color: view.tint(String(view.repo.headMark || ""))
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: String(view.repo.branch || "")
          color: view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: String(view.repo.headAge || "") === "" ? "" : ("· " + String(view.repo.headAge))
          color: Qt.darker(view.launcher.foreground, 2.2)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Row {
        visible: !view.waiting
        anchors.right: parent.right
        anchors.rightMargin: view.gutter + view.inset
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Style.space(3)
        spacing: Style.space(22)

        Repeater {
          model: [
            { label: "open PRs", value: String(Number(view.repo.prs || 0)) },
            { label: "issues", value: String(Number(view.repo.issues || 0)) },
            { label: String(view.repo.releaseAge || ""), value: String(view.repo.release || "") }
          ]

          Row {
            required property var modelData
            visible: modelData.value !== "" && modelData.value !== "0"
            spacing: Style.space(6)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.value
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

    // What is waiting to be merged. Ctrl+K steps into the full list; this is
    // the glance that decides whether you want to.
    Repeater {
      model: view.waiting ? 0 : view.shownPrs

      Item {
        required property int index
        readonly property var pull: view.prs[index]

        width: view.width
        height: view.prHeight

        Text {
          id: prMark
          anchors.left: parent.left
          anchors.leftMargin: view.gutter + view.inset
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(18)
          text: String(pull.mark || "")
          color: view.tint(String(pull.mark || ""))
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          id: prNumber
          anchors.left: prMark.right
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(52)
          text: "#" + String(pull.number || "")
          color: Qt.darker(view.launcher.foreground, 2.2)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          anchors.left: prNumber.right
          anchors.leftMargin: Style.space(6)
          anchors.right: prAge.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          text: (pull.draft === true ? "draft  " : "") + String(pull.title || "")
          color: Qt.darker(view.launcher.foreground, 1.3)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        Text {
          id: prAge
          anchors.right: parent.right
          anchors.rightMargin: view.gutter + view.inset
          anchors.verticalCenter: parent.verticalCenter
          text: String(pull.age || "")
          color: Qt.darker(view.launcher.foreground, 2.4)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    Repeater {
      model: view.waiting ? view.shownPrs : 0

      Item {
        required property int index
        width: view.width
        height: view.prHeight

        Rectangle {
          anchors.left: parent.left
          anchors.leftMargin: view.gutter + view.inset
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(160) + (index % 2 === 0 ? Style.space(60) : 0)
          height: Style.space(10)
          radius: Style.space(3)
          color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                         view.launcher.foreground.b, 0.08)
        }
      }
    }
  }
}
