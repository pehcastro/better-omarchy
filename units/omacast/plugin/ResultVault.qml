import QtQuick
import qs.Commons
import qs.Ui

// Your password store, drawn as a store.
//
// The list drew an entry the way it draws an application: a title, a grey word
// under it, an icon. That is wrong twice. It loses the shape of the store, and
// a password store is a filing cabinet whose folders are the whole reason you
// can find anything in it. And it says nothing about the one question anyone
// looking at a launcher full of credentials asks first, which is whether any of
// this is on screen.
//
// So the folder is drawn as a place, in front of the name, and every row ends
// in a run of dots that is not the secret and is not the length of the secret.
// The dots are the same on every row on purpose: a masked field that varied
// with what it masks would be telling you something about it.
//
// The strip along the top says which store answered and how long the clipboard
// keeps what you copy. It says it before you press Return rather than after,
// because pressing Return closes the launcher: by the time the notification
// arrives this view is gone, so the one place the timeout can inform a decision
// is here.
//
// Nothing in this file reads a secret. The value is fetched inside
// `omacast-pass copy`, goes down a pipe into wl-copy, and never becomes a row,
// an argument, or a string in this process.
//
// The row carries, beyond the usual title:
//   folder        the path above the entry, "" at the top of the store
//   name          the entry itself
//   store         "Password Store" or "1Password"
//   tool          "pass" or "op"
//   clearSeconds  how long before the clipboard is emptied again
Item {
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

  readonly property int pad: Style.space(8)
  readonly property int gutter: Style.space(16)
  readonly property int headHeight: Style.space(32)
  readonly property int rowHeight: Style.space(34)

  // Whole rows only, under the strip. A row cut through the middle at the
  // bottom edge reads as a rendering fault rather than as "the store goes on".
  readonly property int rowsShown: {
    var total = Math.min(view.launcher.rows.length, view.launcher.maxRows)
    if (view.maxHeight <= 0) return total
    var room = view.maxHeight - view.headHeight - view.pad * 2
    return Math.max(1, Math.min(total, Math.floor(room / view.rowHeight)))
  }

  implicitHeight: view.launcher.rows.length === 0
    ? 0 : view.headHeight + view.rowsShown * view.rowHeight + view.pad * 2

  // Which store answered, and what pressing Return costs you in time. Both are
  // properties of the whole answer rather than of a row, so they are said once.
  Item {
    id: strip
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: view.headHeight

    Text {
      id: vaultMark
      anchors.left: parent.left
      anchors.leftMargin: view.gutter
      anchors.verticalCenter: parent.verticalCenter
      text: "󰌾"
      color: Color.accent
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.icon
    }

    Text {
      id: storeName
      anchors.left: vaultMark.right
      anchors.leftMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: String((view.head && view.head.store) || "Vault")
      color: view.launcher.foreground
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.subtitle
    }

    Text {
      anchors.left: storeName.right
      anchors.leftMargin: Style.space(10)
      anchors.right: clears.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      // How many, and honestly. The launcher truncates at maxRows before this
      // view ever sees the answer, so a full page is "20 shown" and not a claim
      // that the store holds twenty things.
      text: {
        var n = view.launcher.rows.length
        if (n >= view.launcher.maxRows) return n + " shown"
        return n === 1 ? "1 entry" : n + " entries"
      }
      color: Qt.darker(view.launcher.foreground, 2.4)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    // The one thing a launcher can say about a clipboard it is about to write
    // to and then close over. A row with no clearSeconds gets no promise rather
    // than a made-up one.
    Chip {
      id: clears
      anchors.right: parent.right
      anchors.rightMargin: view.gutter
      anchors.verticalCenter: parent.verticalCenter
      text: (view.head && Number(view.head.clearSeconds || 0) > 0)
        ? "clipboard clears in " + Number(view.head.clearSeconds) + "s" : ""
      accented: true
      foreground: view.launcher.foreground
      fontFamily: view.launcher.fontFamily
    }

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: view.gutter
      anchors.rightMargin: view.gutter
      height: Math.max(1, Style.space(1))
      color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                     view.launcher.foreground.b, 0.09)
    }
  }

  ListView {
    id: list
    anchors.top: strip.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    clip: true
    topMargin: view.pad
    bottomMargin: view.pad
    focus: false
    interactive: true
    currentIndex: view.launcher.selectedIndex
    highlightMoveDuration: 0
    model: view.launcher.rows

    delegate: Item {
      id: entry

      required property var modelData
      required property int index

      readonly property bool selected: entry.index === view.launcher.selectedIndex
      readonly property string folder: String(entry.modelData.folder || "")

      width: list.width
      height: view.rowHeight

      Rectangle {
        id: bar
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        anchors.topMargin: Style.space(1)
        anchors.bottomMargin: Style.space(1)
        radius: Style.cornerRadius
        color: entry.selected ? view.launcher.selectedBackground : "transparent"
      }

      MouseArea {
        anchors.fill: bar
        hoverEnabled: true
        onEntered: view.launcher.select(entry.index)
        onClicked: view.launcher.activate(entry.modelData)
      }

      // The folder, kept as the store writes it, slashes and all. Rewriting
      // `github/work` into `github › work` would be prettier and would stop it
      // matching what you see when you look at the store on disk.
      Text {
        id: place
        anchors.left: bar.left
        anchors.leftMargin: view.gutter + Style.space(6)
        anchors.verticalCenter: bar.verticalCenter
        visible: entry.folder !== ""
        text: entry.folder + "/"
        color: Qt.darker(view.launcher.foreground, entry.selected ? 1.5 : 2.5)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideLeft
        // A deep folder never pushes the entry's own name off the row.
        width: Math.min(implicitWidth, Math.max(0, bar.width * 0.38))
      }

      Text {
        anchors.left: place.visible ? place.right : bar.left
        anchors.leftMargin: place.visible ? Style.space(1) : view.gutter + Style.space(6)
        anchors.right: masked.left
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: bar.verticalCenter
        text: String(entry.modelData.name || entry.modelData.title || "")
        color: entry.selected ? view.launcher.selectedText : view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.subtitle
        elide: Text.ElideRight
      }

      // Where the secret is not. A fixed run of dots, the same on every row: as
      // many dots as the password has characters would be a row telling anyone
      // looking over your shoulder how long it is.
      Text {
        id: masked
        anchors.right: bar.right
        anchors.rightMargin: view.gutter
        anchors.verticalCenter: bar.verticalCenter
        text: "••••••••"
        color: Qt.darker(view.launcher.foreground, entry.selected ? 1.8 : 2.8)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        font.letterSpacing: 1.2
      }
    }
  }
}
