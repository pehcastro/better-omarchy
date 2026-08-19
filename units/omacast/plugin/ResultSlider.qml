import QtQuick
import qs.Commons
import qs.Ui

// Rows you drag rather than press.
//
// Volume, brightness, a gap width: things whose answer is a number in a range,
// where the useful gesture is "a bit more" and not "type 63 and hit Enter".
//
// A row carries:
//   value     the current number
//   min, max  the range, defaulting to 0 and 100
//   step      how far one arrow press moves it, defaulting to 1
//   title     the label
//   accessory the formatted reading, which the script owns because only it
//             knows whether 63 is a percentage, a decibel or a pixel
//   setExec   a command containing the literal token {value}
//
// The command runs while the slider moves, not when it is let go. A volume
// control you cannot hear until you release is not a volume control, it is a
// form field about volume. Runs are rate limited instead, because the other
// half of that bargain is not spawning a process per pixel of travel.
Item {
  // Without this, a height computed from content draws past the card's border
  // when the sum is wrong, rather than being cut off inside it.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property int rowHeight: Style.space(54)

  // The slider being dragged or nudged, and where it has got to. Only one moves
  // at a time, so this is a pair rather than a table.
  property var pendingRow: null
  property real pendingValue: 0

  implicitHeight: Math.max(1, Math.min(launcher.rows.length, launcher.maxRows)) * rowHeight
    + Style.space(12)

  function floorOf(row) {
    return row.min !== undefined ? Number(row.min) : 0
  }

  function ceilingOf(row) {
    var top = row.max !== undefined ? Number(row.max) : 100
    var low = view.floorOf(row)
    return top > low ? top : low + 1
  }

  function bound(row, value) {
    return Math.max(view.floorOf(row), Math.min(view.ceilingOf(row), value))
  }

  // Snapped to the grid the step describes, counted from the floor rather than
  // from zero: brightness that stops at 1 steps 1, 6, 11, and a grid anchored
  // anywhere else would put its own floor off the grid.
  //
  // Only what the hand moved is snapped. The value the script reported is left
  // exactly as it sent it, because a slider that reads 41% the instant it opens
  // on a screen set to 40% has lied about something nobody touched.
  function clampTo(row, value) {
    var low = view.floorOf(row)
    var size = row.step !== undefined && Number(row.step) > 0 ? Number(row.step) : 1
    return view.bound(row, low + Math.round((value - low) / size) * size)
  }

  // Left and right on the selected slider. The launcher owns the selection, so
  // it calls in here rather than this view growing its own idea of a cursor.
  function nudge(direction) {
    var item = repeater.itemAt(view.launcher.selectedIndex)
    if (item) item.step(direction)
  }

  function queue(row, value) {
    view.pendingRow = row
    view.pendingValue = value

    // Leading edge: the first move of a drag is applied at once, so the slider
    // answers immediately and only the flood behind it is throttled.
    if (!limiter.running) {
      view.flush()
      limiter.restart()
    }
  }

  function flush() {
    var row = view.pendingRow
    view.pendingRow = null
    if (!row) return

    var command = String(row.setExec || "")
    if (command === "") return
    // Replaced everywhere rather than once: a command that both sets a value
    // and echoes it back names the token twice.
    Util.execDetached(command.replace(/\{value\}/g, String(view.pendingValue)))
  }

  // 90ms is about as fast as a hand moves a slider one perceptible notch, and
  // slow enough that a full sweep of the card costs a dozen processes rather
  // than several hundred.
  Timer {
    id: limiter
    interval: 90
    repeat: true
    onTriggered: {
      if (view.pendingRow) view.flush()
      else limiter.stop()
    }
  }

  // A drag that ends between ticks would otherwise leave the last few pixels
  // unapplied, which is exactly the position the hand chose.
  Component.onDestruction: view.flush()

  Column {
    width: view.width
    y: Style.space(6)
    spacing: 0

    Repeater {
      id: repeater
      model: view.launcher.rows

      delegate: Item {
        id: slot

        required property var modelData
        required property int index

        readonly property bool selected: index === view.launcher.selectedIndex

        readonly property real low: view.floorOf(slot.modelData)
        readonly property real high: view.ceilingOf(slot.modelData)

        // The delegate holds the live value, not the row. Rows are rebuilt by
        // the ranking engine and a dragged position written into one would be
        // thrown away the next time anything requeried; held here it survives
        // until the answer itself changes shape.
        property real current: view.bound(slot.modelData,
                                          Number(slot.modelData.value !== undefined ? slot.modelData.value : 0))

        readonly property real fraction: (slot.current - slot.low) / (slot.high - slot.low)

        // The script formats its own reading, because only it knows whether 63
        // is a percentage or a decibel. But it formatted the value it sent, and
        // nothing re-asks it while the handle is moving, so the number inside
        // that formatting is replaced and the units around it are kept.
        readonly property string readout: {
          var given = String(slot.modelData.accessory || "")
          if (given === "" || !/\d/.test(given)) return given || String(Math.round(slot.current))
          return given.replace(/-?\d+(\.\d+)?/, String(Math.round(slot.current)))
        }

        function set(value) {
          var next = view.clampTo(slot.modelData, value)
          if (next === slot.current) return
          slot.current = next
          view.queue(slot.modelData, next)
        }

        function step(direction) {
          var size = slot.modelData.step !== undefined && Number(slot.modelData.step) > 0
            ? Number(slot.modelData.step) : 1
          slot.set(slot.current + size * direction)
        }

        width: view.width
        height: view.rowHeight

        Rectangle {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          anchors.topMargin: Style.space(2)
          anchors.bottomMargin: Style.space(2)
          radius: Style.cornerRadius
          color: slot.selected ? view.launcher.selectedBackground : "transparent"
        }

        Text {
          id: label
          anchors.left: parent.left
          anchors.leftMargin: Style.space(24)
          anchors.top: parent.top
          anchors.topMargin: Style.space(9)
          anchors.right: reading.left
          anchors.rightMargin: Style.space(12)
          text: String(slot.modelData.title || "")
          color: slot.selected ? view.launcher.selectedText : view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          id: reading
          anchors.right: parent.right
          anchors.rightMargin: Style.space(24)
          anchors.baseline: label.baseline
          text: slot.readout
          color: slot.modelData.accent || Color.accent
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        // The rail is the hit target, padded well past its own three pixels:
        // a 3px line is not something a mouse can be expected to find.
        Item {
          id: rail
          anchors.left: parent.left
          anchors.leftMargin: Style.space(24)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(24)
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(10)
          height: Style.space(14)

          Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Style.space(4)
            radius: height / 2
            color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                           view.launcher.foreground.b, 0.15)
          }

          Rectangle {
            id: filled
            anchors.left: track.left
            anchors.verticalCenter: track.verticalCenter
            height: track.height
            radius: track.radius
            width: track.width * Math.max(0, Math.min(1, slot.fraction))
            color: slot.modelData.accent || Color.accent
          }

          Rectangle {
            x: filled.width - width / 2
            anchors.verticalCenter: track.verticalCenter
            width: Style.space(12)
            height: width
            radius: width / 2
            color: slot.modelData.accent || Color.accent
            // Only the selected slider grows a handle. Five identical knobs
            // down a card tell you nothing about which one the keys move.
            scale: slot.selected ? 1 : 0.6
            Behavior on scale { NumberAnimation { duration: 90 } }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // Without this a drag started here is handed to the enclosing
            // flickable partway through and the slider stops following.
            preventStealing: true

            function seek(x) {
              slot.set(slot.low + (x / Math.max(1, track.width)) * (slot.high - slot.low))
            }

            onPressed: function (mouse) {
              view.launcher.select(slot.index)
              seek(mouse.x)
            }
            onPositionChanged: function (mouse) {
              if (pressed) seek(mouse.x)
            }
            onReleased: view.flush()
          }
        }
      }
    }
  }
}
