import QtQuick
import qs.Commons
import qs.Ui

// One pull request, drawn as one.
//
// "Is my PR green yet" is a question asked twenty times a day, and a list row
// answers it with a tick. A tick is not the answer. The answer is which check
// is red, whether anybody has looked at it, and how big the thing is, and none
// of the three fits in a title and a number.
//
// So the mark is drawn once and large, because it is the thing being asked
// about, and everything under it exists to say why it is that colour. Failing
// checks are sorted to the top by the script, so the row that explains a red
// mark is the first row under it.
//
// Nothing here waits on a request. A pull request is a URL as soon as its
// number is typed, so the panel is drawn from the text alone and filled in when
// the answer arrives, which is what `waiting` marks.
//
// The row carries:
//   pr        { repo, number, title, author, head, base, draft, state,
//               mergeable, review, additions, deletions, files, comments,
//               age, opened, mark, failing, running, total, url }
//   checks[]  { name, mark, state, took }
//   reviews[] { who, state, mark, age }
Item {
  clip: true
  id: view

  required property var launcher

  property int maxHeight: 0

  readonly property var row: launcher.rows.length > 0 ? launcher.rows[0] : null
  readonly property var pr: (view.row && view.row.pr) ? view.row.pr : ({})
  readonly property var checks: (view.row && view.row.checks) ? view.row.checks : []
  readonly property var reviews: (view.row && view.row.reviews) ? view.row.reviews : []
  readonly property bool waiting: view.row ? view.row.waiting === true : false

  readonly property int gutter: Style.space(18)
  readonly property int inset: Style.space(16)
  readonly property int headHeight: Style.space(76)
  readonly property int statHeight: Style.space(46)
  readonly property int checkHeight: Style.space(30)

  // The mark, in one place, so the head and the empty state agree about it.
  readonly property string mark: String(view.pr.mark || "")

  readonly property color good: Qt.rgba(0.40, 0.78, 0.45, 1.0)
  readonly property color bad: Qt.rgba(0.90, 0.38, 0.38, 1.0)
  readonly property color busy: Qt.rgba(0.92, 0.72, 0.30, 1.0)

  function tint(m) {
    if (m === "✓") return view.good
    if (m === "✗") return view.bad
    if (m === "●") return view.busy
    return Qt.darker(view.launcher.foreground, 2.2)
  }

  readonly property int shownChecks: {
    var have = view.waiting ? 3 : view.checks.length
    if (have === 0) return 0
    if (view.maxHeight <= 0) return Math.min(8, have)
    var room = view.maxHeight - view.headHeight - view.statHeight - Style.space(16)
    return Math.max(1, Math.min(have, Math.floor(room / view.checkHeight)))
  }

  implicitHeight: view.headHeight + view.statHeight
    + view.shownChecks * view.checkHeight + Style.space(16)

  Column {
    width: view.width
    spacing: 0

    // The title, who wrote it and where it is going, and the one mark the
    // whole panel is about.
    Item {
      width: parent.width
      height: view.headHeight

      Column {
        anchors.left: parent.left
        anchors.leftMargin: view.gutter
        anchors.right: rollup.left
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        Text {
          width: parent.width
          text: String(view.pr.title || view.pr.repo || "")
          color: view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.large
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: {
            var bits = []
            if (view.pr.repo) bits.push(String(view.pr.repo) + " #" + String(view.pr.number || ""))
            if (view.pr.author) bits.push(String(view.pr.author))
            if (view.pr.head && view.pr.base)
              bits.push(String(view.pr.head) + " → " + String(view.pr.base))
            return bits.join("   ")
          }
          color: Qt.darker(view.launcher.foreground, 2.3)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      // Big, because it is the question. The word beside it says what the
      // people think; the mark says what the machines think.
      Row {
        id: rollup
        anchors.right: parent.right
        anchors.rightMargin: view.gutter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(10)

        Chip {
          anchors.verticalCenter: parent.verticalCenter
          visible: view.pr.draft === true
          text: "draft"
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }

        Chip {
          anchors.verticalCenter: parent.verticalCenter
          text: String(view.pr.review || "")
          accented: String(view.pr.review || "") === "approved"
          tint: view.good
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: view.mark !== ""
          text: view.mark
          color: view.tint(view.mark)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.large + Style.space(6)
        }
      }
    }

    // How big it is, how many checks are out, how much has been said about it.
    // Numbers with labels under them rather than a sentence, for the same
    // reason `git:` counts its changed files that way.
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
        spacing: Style.space(24)

        Row {
          spacing: Style.space(6)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "+" + Number(view.pr.additions || 0)
            color: view.good
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "−" + Number(view.pr.deletions || 0)
            color: view.bad
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        Repeater {
          model: [
            { label: "files", value: Number(view.pr.files || 0) },
            { label: "failing", value: Number(view.pr.failing || 0) },
            { label: "running", value: Number(view.pr.running || 0) },
            { label: "comments", value: Number(view.pr.comments || 0) }
          ]

          Row {
            required property var modelData
            visible: modelData.value > 0
            spacing: Style.space(6)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: String(modelData.value)
              color: modelData.label === "failing" ? view.bad : view.launcher.foreground
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

      // Who has looked at it, on the same line, because a review is a fact
      // about the pull request rather than a list of its own.
      Row {
        visible: !view.waiting && view.reviews.length > 0
        anchors.right: parent.right
        anchors.rightMargin: view.gutter + view.inset
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Style.space(3)
        spacing: Style.space(8)

        Repeater {
          model: Math.min(3, view.reviews.length)

          Text {
            required property int index
            readonly property var entry: view.reviews[index]
            anchors.verticalCenter: parent.verticalCenter
            text: String(entry.mark || "") + " " + String(entry.who || "")
            color: view.tint(String(entry.mark || ""))
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }

    // The checks themselves. Failing first, because a list of twenty greens
    // with one red in the middle is a list you have to read, and the red one is
    // the only reason anybody asked.
    Repeater {
      model: view.waiting ? 0 : view.shownChecks

      Item {
        required property int index
        readonly property var check: view.checks[index]

        width: view.width
        height: view.checkHeight

        Text {
          id: checkMark
          anchors.left: parent.left
          anchors.leftMargin: view.gutter + view.inset
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(20)
          text: String(check.mark || "")
          color: view.tint(String(check.mark || ""))
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          anchors.left: checkMark.right
          anchors.leftMargin: Style.space(6)
          anchors.right: took.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          text: String(check.name || "")
          color: String(check.mark || "") === "✗"
            ? view.launcher.foreground
            : Qt.darker(view.launcher.foreground, 1.4)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        Text {
          id: took
          anchors.right: parent.right
          anchors.rightMargin: view.gutter + view.inset
          anchors.verticalCenter: parent.verticalCenter
          text: String(check.took || "")
          color: Qt.darker(view.launcher.foreground, 2.4)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    // While the answer is out, the shape of it. Same heights, same places, so
    // nothing moves when the real checks land.
    Repeater {
      model: view.waiting ? view.shownChecks : 0

      Item {
        required property int index
        width: view.width
        height: view.checkHeight

        Rectangle {
          anchors.left: parent.left
          anchors.leftMargin: view.gutter + view.inset
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(140) + (index % 2 === 0 ? Style.space(50) : 0)
          height: Style.space(10)
          radius: Style.space(3)
          color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                         view.launcher.foreground.b, 0.08)
        }
      }
    }
  }
}
