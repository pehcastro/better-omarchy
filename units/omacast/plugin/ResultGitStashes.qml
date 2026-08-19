import QtQuick
import qs.Commons
import qs.Ui

// What is in this repo's stashes, without applying one to find out.
//
//   stash:            the repo you are in
//   stash:omarchy     the repo called omarchy
//
// `stash@{0}: WIP on main` is what git tells you, and every line of it says the
// same thing. The question being asked is "did I stash that", and the only
// answer to it is the files. So the row you are on opens: the message stays,
// and under it come the paths with what each gained and lost. Arrowing down
// walks the stashes and the contents follow, which is the whole reading.
//
// The rows you are not on stay one line with a file count, because a screen
// where everything is expanded is a screen with no selection in it.
//
// Rows carry:
//   ref branch message age files[] { path, added, deleted } added deleted
//   repo { name, path, count }   on the first row only
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
  readonly property int rowHeight: Style.space(44)
  readonly property int fileHeight: Style.space(20)

  // Six paths is a stash you can read. More than that and the answer to "did I
  // stash that" is yes, and the rest is a diff.
  readonly property int maxFiles: 6

  readonly property var selectedFiles: {
    var rows = view.launcher.rows
    var i = view.launcher.selectedIndex
    if (i < 0 || i >= rows.length) return []
    return rows[i].files || []
  }

  readonly property int openHeight: {
    var n = view.selectedFiles.length
    if (n === 0) return 0
    var lines = Math.min(n, view.maxFiles) + (n > view.maxFiles ? 1 : 0)
    return lines * view.fileHeight + Style.space(6)
  }

  spacing: 0

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
          return n + (n === 1 ? " stash" : " stashes")
            + "  ·  nothing here is applied until you say so"
        }
        color: Qt.darker(view.launcher.foreground, 2.2)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  ListView {
    id: list
    width: view.width
    height: {
      var rows = view.launcher.rows.length
      var wanted = rows * view.rowHeight + view.openHeight
      if (view.maxHeight <= 0) return wanted
      return Math.min(wanted, Math.max(view.rowHeight,
        view.maxHeight - view.headerHeight - Style.space(12)))
    }
    clip: true
    focus: false
    interactive: true
    currentIndex: view.launcher.selectedIndex
    highlightMoveDuration: 0
    model: view.launcher.rows

    delegate: Item {
      id: entry
      required property var modelData
      required property int index

      readonly property bool selected: index === view.launcher.selectedIndex
      readonly property var files: modelData.files || []

      width: list.width
      height: view.rowHeight + (entry.selected ? view.openHeight : 0)

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        anchors.topMargin: Style.space(2)
        anchors.bottomMargin: Style.space(2)
        radius: Style.cornerRadius
        color: entry.selected ? view.launcher.selectedBackground : "transparent"
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: view.launcher.select(index)
        onClicked: view.launcher.activate(modelData)
      }

      Item {
        id: line
        width: parent.width
        height: view.rowHeight

        Column {
          anchors.left: parent.left
          anchors.leftMargin: view.gutter
          anchors.right: right.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(1)

          Text {
            width: parent.width
            text: String(modelData.message || modelData.ref || "")
            color: view.launcher.foreground
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }

          // Which stash, and which branch it was taken on. A stash from another
          // branch is the one you forgot, and the one to think twice about.
          Text {
            width: parent.width
            text: String(modelData.ref || "")
              + (String(modelData.branch || "") === ""
                 ? "" : "  ·  on " + String(modelData.branch))
              + "  ·  " + entry.files.length
              + (entry.files.length === 1 ? " file" : " files")
            color: Qt.darker(view.launcher.foreground, 2.3)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }

        Row {
          id: right
          anchors.right: parent.right
          anchors.rightMargin: view.gutter
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: {
              var a = Number(modelData.added || 0)
              var d = Number(modelData.deleted || 0)
              if (a === 0 && d === 0) return ""
              return (a > 0 ? "+" + a : "") + (a > 0 && d > 0 ? " " : "") + (d > 0 ? "−" + d : "")
            }
            color: Qt.darker(view.launcher.foreground, 2.0)
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

      // The contents, under the row you are on.
      Column {
        anchors.top: line.bottom
        width: parent.width
        visible: entry.selected
        spacing: 0

        Repeater {
          model: entry.selected ? Math.min(entry.files.length, view.maxFiles) : 0

          Item {
            required property int index
            readonly property var file: entry.files[index]

            width: view.width
            height: view.fileHeight

            Text {
              anchors.left: parent.left
              anchors.leftMargin: view.gutter + Style.space(16)
              anchors.right: counts.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: String(file.path || "")
              color: Qt.darker(view.launcher.foreground, 1.6)
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideLeft
            }

            Text {
              id: counts
              anchors.right: parent.right
              anchors.rightMargin: view.gutter
              anchors.verticalCenter: parent.verticalCenter
              text: {
                var a = Number(file.added || 0)
                var d = Number(file.deleted || 0)
                return (a > 0 ? "+" + a : "") + (a > 0 && d > 0 ? " " : "") + (d > 0 ? "−" + d : "")
              }
              color: Qt.darker(view.launcher.foreground, 2.4)
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        Text {
          visible: entry.files.length > view.maxFiles
          x: view.gutter + Style.space(16)
          height: view.fileHeight
          verticalAlignment: Text.AlignVCenter
          text: "and " + (entry.files.length - view.maxFiles) + " more"
          color: Qt.darker(view.launcher.foreground, 2.8)
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
