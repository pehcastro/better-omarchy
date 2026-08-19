import QtQuick
import qs.Commons
import qs.Ui

// Hosts, drawn as machines rather than as the lines of the file they came from.
//
// `ssh:` used to answer with an alias and the string "deploy@10.0.0.4:2222"
// underneath it. That string is three separate facts glued together, and the
// glue is the part a reader has to undo: which of those words is the machine,
// which is the account, which is the port. A row that puts them in three places
// is read at a glance, and two rows that differ only in the account differ
// visibly instead of at character eleven.
//
// So: the alias is the name, badged, because that is what you type. The address
// is the loud thing on the right, because that is what the machine is. The
// account and the port sit beside it, quieter, because they qualify it. The
// file the entry came from is drawn only when the answer spans more than one
// file, since otherwise it is the same path repeated down the card.
//
// The dot before the address is the one thing here that is not in the config:
// whether this machine is in known_hosts, which is to say whether you have ever
// actually connected. It is offline and free. A real reachability probe is not:
// see the note in omacast-ssh for why there is no green light here.
//
// Rows carry:
//   alias hostName user port sourceFile identity proxyJump known
Column {
  // Without this a height computed from a row count draws past the card's
  // border whenever the count is wrong, instead of being cut off inside it.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property int gutter: Style.space(18)
  readonly property int rowHeight: Style.space(54)
  readonly property int pad: Style.space(10)

  // One file is context nobody needs repeated; two is the reason a host is
  // where it is. Included configs are the common case for anything work
  // related, so this switches itself on exactly when it starts to matter.
  readonly property bool manyFiles: {
    var seen = ""
    var rows = view.launcher.rows
    for (var i = 0; i < rows.length; i++) {
      var file = String(rows[i].sourceFile || "")
      if (file === "") continue
      if (seen === "") seen = file
      else if (seen !== file) return true
    }
    return false
  }

  readonly property int shownRows: {
    var n = view.launcher.rows.length
    if (view.maxHeight <= 0) return n
    var room = view.maxHeight - view.pad * 2
    return Math.max(1, Math.min(n, Math.floor(room / view.rowHeight)))
  }

  // No implicitHeight: the root is a Column and computes its own, so assigning
  // it makes QML refuse the whole file and the launcher quietly falls back to a
  // list. `shownRows` still caps what is drawn, which is the part that mattered.

  spacing: 0

  Item {
    width: view.width
    height: view.pad
  }

  ListView {
    id: list
    width: view.width
    height: view.shownRows * view.rowHeight
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
      // Absent rather than false when known_hosts is hashed: the script sends
      // null there, and a hollow dot on every row would be a claim the file
      // cannot support.
      readonly property bool tellsKnown: entry.modelData.known !== undefined
        && entry.modelData.known !== null

      width: list.width
      height: view.rowHeight

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
        onEntered: view.launcher.select(entry.index)
        onClicked: view.launcher.activate(entry.modelData)
      }

      // A letter in a box. Machines do not have icons and every one of these
      // would otherwise open with the same generic terminal glyph; the initial
      // is at least different per host, which is all a left-hand mark has to be
      // for the eye to use it as a place-keeper down the column.
      Rectangle {
        id: badge
        anchors.left: parent.left
        anchors.leftMargin: view.gutter
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(30)
        height: width
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : width / 6
        color: entry.selected
          ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
          : Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                    view.launcher.foreground.b, 0.07)

        Text {
          anchors.centerIn: parent
          text: String(entry.modelData.alias || entry.modelData.title || "?")
            .charAt(0).toUpperCase()
          color: entry.selected ? Color.accent : Qt.darker(view.launcher.foreground, 1.6)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
      }

      Column {
        anchors.left: badge.right
        anchors.leftMargin: Style.space(12)
        anchors.right: destination.left
        anchors.rightMargin: Style.space(14)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
          width: parent.width
          text: String(entry.modelData.alias || entry.modelData.title || "")
          color: entry.selected ? view.launcher.selectedText : view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.subtitle
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          visible: view.manyFiles && text !== ""
          text: String(entry.modelData.sourceFile || "")
          color: Qt.darker(view.launcher.foreground, 2.4)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideLeft
        }
      }

      // The destination, in pieces. The address leads because it is the
      // machine; the account and the port are conditions on reaching it and are
      // drawn as such rather than punctuated into the same word.
      Column {
        id: destination
        anchors.right: parent.right
        anchors.rightMargin: view.gutter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(3)

        Row {
          anchors.right: parent.right
          spacing: Style.space(8)

          // Filled: you have connected before. Hollow: this entry has never
          // been used. Drawn rather than set in a font, because a missing glyph
          // would take the whole signal with it.
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: entry.tellsKnown
            width: Style.space(6)
            height: width
            radius: width / 2
            color: entry.modelData.known === true ? Color.accent : "transparent"
            border.width: entry.modelData.known === true ? 0 : Math.max(1, Style.space(1))
            border.color: Qt.darker(view.launcher.foreground, 2.6)
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: String(entry.modelData.hostName || "")
            color: entry.selected ? view.launcher.selectedText : view.launcher.foreground
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.body
          }

          // 22 on every row is the port column saying nothing. A port that is
          // not 22 is half the reason the entry exists.
          Chip {
            anchors.verticalCenter: parent.verticalCenter
            text: Number(entry.modelData.port || 22) === 22
              ? "" : "port " + Number(entry.modelData.port)
            foreground: view.launcher.foreground
            fontFamily: view.launcher.fontFamily
          }
        }

        Row {
          anchors.right: parent.right
          spacing: Style.space(8)

          // Empty when the config names no user, because ssh would then use
          // the local account and printing that here would look like a setting
          // somebody made.
          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: String(entry.modelData.user || "")
            color: Qt.darker(view.launcher.foreground, 2.0)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
          }

          // Which bastion this one goes through. A connection that fails for
          // reasons that are not about this machine is worth a word in advance.
          Chip {
            anchors.verticalCenter: parent.verticalCenter
            text: String(entry.modelData.proxyJump || "") === ""
              ? "" : "via " + String(entry.modelData.proxyJump)
            foreground: view.launcher.foreground
            fontFamily: view.launcher.fontFamily
          }

          // A pinned identity file, said once. Which key it is belongs in the
          // config, not on a launcher row: what the reader needs to know here
          // is that the host will not fall back to whatever the agent holds.
          Chip {
            anchors.verticalCenter: parent.verticalCenter
            text: String(entry.modelData.identity || "") === "" ? "" : "key"
            accented: true
            foreground: view.launcher.foreground
            fontFamily: view.launcher.fontFamily
          }
        }
      }
    }
  }

  Item {
    width: view.width
    height: view.pad
  }
}
