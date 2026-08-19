import QtQuick
import qs.Commons
import qs.Ui

// A view that asks before it acts.
//
// Some things cannot be answered by picking a row. Joining a network needs the
// password, and filing a note needs a title, and neither of those is a search
// term: typing them into the launcher's own box would run them through the
// ranking engine, shell them out to every extension that answers bare queries,
// and put a wifi password in the recent-query file.
//
// So the form takes the keyboard. While it is on screen the box above it is
// inert, Tab walks the fields, Enter submits, and Escape leaves through the
// same flow stack everything else leaves through.
//
// ---------------------------------------------------------------- contract
//
// The first row of the answer sets `view: "form"` and carries:
//
//   title      the heading, e.g. "Join Home-WiFi"
//   subtitle   one quiet line under it, optional
//   submit     the label on the confirm action, defaulting to "Submit"
//   fields     an array, in the order they should be filled:
//                name         the token this field fills in `exec` (required)
//                label        what to call it
//                value        what it starts as, optional
//                placeholder  greyed text for an empty field, optional
//                secret       true to mask it and offer a reveal, optional
//                readonly     true to show it without letting it be edited
//   exec       the command to run, with every {name} replaced by that field's
//              value, shell-quoted. A {name} matching no field is left alone.
//   query      optional: the query to land on after submitting. Without it the
//              launcher closes, as any other action does.
//
// A field named in `fields` but not in `exec` is still collected, so a script
// can read them in whatever order its command line wants.
//
//   { "view": "form", "title": "Join Home-WiFi", "submit": "Connect",
//     "fields": [ { "name": "psk", "label": "Password", "secret": true } ],
//     "exec": "nmcli device wifi connect Home-WiFi password {psk}",
//     "query": "wifi:" }
//
// A row built inside the launcher may carry `onSubmit` instead of `exec`: a
// function taking the collected values. That is how the settings form writes to
// omacast.json without inventing a shell command to do it.
Item {
  // Without this, a height computed from content draws past the card's border
  // when the sum is wrong, rather than being cut off inside it.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property var row: launcher.rows.length > 0 ? launcher.rows[0] : null
  readonly property var fields: (view.row && Array.isArray(view.row.fields)) ? view.row.fields : []

  // Which field the keyboard is in. Held here rather than read off activeFocus
  // so Tab knows where to go next even in the instant between the two.
  property int cursor: 0

  readonly property int fieldHeight: Style.space(58)

  implicitHeight: Style.space(56) + view.fields.length * fieldHeight + Style.space(14)

  function focusField(index) {
    if (view.fields.length === 0) return
    view.cursor = Math.max(0, Math.min(view.fields.length - 1, index))
    var item = repeater.itemAt(view.cursor)
    if (item) item.grab()
  }

  function move(delta) {
    // Wraps, because a three-field form is a loop you tab around rather than a
    // list you walk off the end of.
    if (view.fields.length === 0) return
    var next = (view.cursor + delta + view.fields.length) % view.fields.length
    focusField(next)
  }

  function values() {
    var out = {}
    for (var i = 0; i < view.fields.length; i++) {
      var name = String(view.fields[i].name || "")
      if (name === "") continue
      var item = repeater.itemAt(i)
      out[name] = item ? String(item.value) : String(view.fields[i].value || "")
    }
    return out
  }

  function submit() {
    if (!view.row) return
    var collected = view.values()

    // Built as an action and handed to the launcher, so a form lands in a
    // follow-up query the same way pressing play does, and the trail back is
    // kept by the one piece of code that keeps it.
    var action = {}
    if (view.row.query !== undefined) action.query = String(view.row.query)

    if (typeof view.row.onSubmit === "function") {
      var handler = view.row.onSubmit
      action.run = function () { handler(collected) }
    } else if (String(view.row.exec || "") !== "") {
      action.exec = String(view.row.exec).replace(/\{([a-z0-9_-]+)\}/gi, function (whole, key) {
        // An unmatched token is left as it was written. Substituting an empty
        // string would silently run `nmcli ... password ''`, and a command that
        // quietly does the wrong thing is worse than one that visibly fails.
        return collected[key] !== undefined ? Util.shellQuote(collected[key]) : whole
      })
    } else {
      return
    }

    view.launcher.runAction(action)
  }

  Component.onCompleted: Qt.callLater(function () { view.focusField(0) })

  // The box above regains the keyboard whichever way the form left: submitted,
  // escaped, or replaced because the answer changed shape underneath it.
  Component.onDestruction: if (view.launcher) view.launcher.focusInput()

  Column {
    width: view.width
    spacing: 0

    Item {
      width: parent.width
      height: Style.space(52)

      Text {
        id: heading
        anchors.left: parent.left
        anchors.leftMargin: Style.space(24)
        anchors.right: parent.right
        anchors.rightMargin: Style.space(24)
        anchors.top: parent.top
        anchors.topMargin: Style.space(4)
        text: String((view.row && view.row.title) || "")
        color: view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.heading
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        anchors.left: heading.left
        anchors.right: heading.right
        anchors.top: heading.bottom
        anchors.topMargin: Style.space(2)
        visible: text !== ""
        text: String((view.row && view.row.subtitle) || "")
        color: Qt.darker(view.launcher.foreground, 1.8)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Repeater {
      id: repeater
      model: view.fields

      delegate: Item {
        id: slot

        required property var modelData
        required property int index

        readonly property bool secret: slot.modelData.secret === true
        readonly property bool locked: slot.modelData.readonly === true

        // Read by values(), so the collected answer never depends on which
        // field happens to be realised.
        readonly property string value: field.text

        // Revealing is per field and resets with the view, so a password is
        // never left legible on a card someone else walks up to.
        property bool revealed: false

        function grab() { field.forceActiveFocus(); field.selectAll() }

        width: view.width
        height: view.fieldHeight

        Text {
          id: caption
          anchors.left: parent.left
          anchors.leftMargin: Style.space(24)
          anchors.top: parent.top
          text: String(slot.modelData.label || slot.modelData.name || "")
          color: slot.index === view.cursor
            ? view.launcher.foreground : Qt.darker(view.launcher.foreground, 1.9)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 0.6
        }

        TextField {
          id: field
          anchors.left: parent.left
          anchors.leftMargin: Style.space(24)
          anchors.right: eye.visible ? eye.left : parent.right
          anchors.rightMargin: Style.space(12)
          anchors.top: caption.bottom
          anchors.topMargin: Style.space(4)

          text: String(slot.modelData.value || "")
          placeholderText: String(slot.modelData.placeholder || "")
          readOnly: slot.locked
          password: slot.secret && !slot.revealed
          foreground: view.launcher.foreground
          font.family: view.launcher.fontFamily

          onActiveFocusChanged: if (activeFocus) view.cursor = slot.index

          // BeforeItem for the same reason the launcher's own input uses it:
          // navigation and submission must never reach the editor, and every
          // ordinary editing key must.
          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
              view.launcher.escapeFrom()
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              view.submit()
              event.accepted = true
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Down) {
              view.move(1)
              event.accepted = true
            } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Up) {
              view.move(-1)
              event.accepted = true
            }
          }
        }

        // The reveal, on masked fields only. Typing a passphrase you cannot see
        // into a box you cannot correct is how people give up and use the
        // network manager instead.
        Text {
          id: eye
          visible: slot.secret
          anchors.right: parent.right
          anchors.rightMargin: Style.space(24)
          anchors.verticalCenter: field.verticalCenter
          text: slot.revealed ? "󰈉" : "󰈈"
          color: slot.revealed ? Color.accent : Qt.darker(view.launcher.foreground, 1.6)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.title

          MouseArea {
            anchors.fill: parent
            anchors.margins: -Style.space(6)
            cursorShape: Qt.PointingHandCursor
            onClicked: slot.revealed = !slot.revealed
          }
        }
      }
    }
  }
}
