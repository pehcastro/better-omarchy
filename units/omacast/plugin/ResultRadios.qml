import QtQuick
import qs.Commons
import qs.Ui

// What is on the air around you, and which one of it you are joined to.
//
//   wifi:            networks in range
//   bt:              devices paired or nearby
//
// A Wi-Fi network and a Bluetooth device are the same kind of thing: something
// nearby, at some strength, that you are either on or not. So they share a
// view, and the two scripts differ only in what they put in it.
//
// As a list this told you almost nothing. "75%" on the right of a row is a
// number you have to read, convert and compare against the number two rows
// down, and the one row that actually matters, the one you are connected to,
// looked exactly like the eleven you are not. Here signal is a meter, so five
// networks sort themselves by eye before a single name is read; being connected
// is a panel of its own rather than a chip on an identical row; and saved and
// secured are marks, because "Enter joins this one instantly" and "Enter opens
// a password prompt" are different promises and should not look the same.
//
// Rows carry:
//   kind         network | device | radio
//   joined       true for the one connection that exists right now
//   known        saved profile (Wi-Fi) or paired (Bluetooth)
//   mark         the word on the membership chip: saved, paired, nearby
//   signal       0..100, or absent when nothing has been heard from it
//   signalLabel  what that reading actually is: "75%", "-52 dBm"
//   secure       "" for an open network, else "WPA2", "WPA3", ...
//   battery      0..100 when the device reports one
//   deviceKind   headset, mouse, keyboard, phone, ...
//   meta         the dim line: band and rate, or address and kind
//   radioOn      false only on the single row a switched-off radio emits
//   radioLabel   "Wi-Fi" or "Bluetooth"
//   iface        the adapter, on the radio row only
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

  readonly property int gutter: Style.space(18)
  readonly property int heroHeight: Style.space(86)
  readonly property int rowHeight: Style.space(32)
  readonly property int labelHeight: Style.space(22)
  readonly property int stripHeight: Style.space(34)
  readonly property int offHeight: Style.space(150)
  readonly property int padY: Style.space(12)

  // The row and its index in the launcher's list, kept together. The view draws
  // three groups in an order of its own, and every one of them still has to be
  // able to say "select me" and "run me" in the launcher's own numbering.
  readonly property var entries: {
    var out = []
    var rows = view.launcher.rows
    for (var i = 0; i < rows.length; i++) out.push({ row: rows[i], index: i })
    return out
  }

  function pick(test) {
    var out = []
    for (var i = 0; i < view.entries.length; i++) {
      if (test(view.entries[i].row)) out.push(view.entries[i])
    }
    return out
  }

  readonly property var joined: view.pick(function (r) {
    return r.joined === true && String(r.kind || "") !== "radio"
  })
  readonly property var rest: view.pick(function (r) {
    return r.joined !== true && String(r.kind || "") !== "radio"
  })
  readonly property var radios: view.pick(function (r) {
    return String(r.kind || "") === "radio"
  })

  readonly property var hero: view.joined.length > 0 ? view.joined[0] : null
  readonly property var radio: view.radios.length > 0 ? view.radios[0] : null

  // A radio that is off is not a device in a list of devices, it is the reason
  // the list is empty. The script says so by emitting that one row and nothing
  // else, and the whole view becomes the answer rather than a line in one.
  readonly property bool off: view.launcher.rows.length > 0
    && view.launcher.rows[0].radioOn === false

  readonly property string label: {
    var rows = view.launcher.rows
    if (rows.length === 0) return ""
    return String(rows[0].radioLabel || "")
  }
  readonly property bool bluetooth: view.label === "Bluetooth"

  readonly property int heroBlock: view.hero ? view.heroHeight : 0
  readonly property int labelBlock: view.rest.length > 0 ? view.labelHeight : 0
  readonly property int stripBlock: view.radio ? view.stripHeight : 0

  // Whole rows only. The list is the one part that can be cut, and a list that
  // ends on half a meter reads as a rendering fault rather than as "there is
  // more below".
  readonly property int listHeight: {
    var wanted = view.rest.length * view.rowHeight
    if (view.maxHeight <= 0) return wanted
    var left = view.maxHeight - view.heroBlock - view.labelBlock
      - view.stripBlock - view.padY * 2
    var whole = Math.floor(left / view.rowHeight) * view.rowHeight
    return Math.max(0, Math.min(wanted, whole))
  }

  // Five bars rather than a number, because the question is never "is it 62"
  // but "is this one better than that one", and two adjacent meters answer it
  // without arithmetic. An unheard-from entry draws the empty track: a paired
  // headset that is not in the room and a network at 4% look different, which
  // they are.
  component Bars: Item {
    id: bars

    property int level: -1
    property int barWidth: Style.space(3)
    property int barGap: Style.space(2)
    property int fullHeight: Style.space(14)
    property color tint: Color.accent

    readonly property int filled: bars.level < 0
      ? 0 : Math.max(1, Math.min(5, Math.ceil(bars.level / 20)))

    width: bars.barWidth * 5 + bars.barGap * 4
    height: bars.fullHeight

    Repeater {
      model: 5

      Rectangle {
        required property int index

        x: index * (bars.barWidth + bars.barGap)
        y: bars.fullHeight - height
        width: bars.barWidth
        height: Math.max(Style.space(2),
                         Math.round(bars.fullHeight * (0.28 + 0.18 * index)))
        radius: Style.space(1)
        color: index < bars.filled
          ? bars.tint
          : Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                    view.launcher.foreground.b, bars.level < 0 ? 0.08 : 0.16)
      }
    }
  }

  // A battery is a battery. Drawn rather than written, so "nearly empty" lands
  // before the digits do, and coloured urgent only where that is the point.
  component Cell: Item {
    id: cell

    property int percent: -1

    visible: cell.percent >= 0
    width: cell.visible ? shell.width + Style.space(6) + reading.width : 0
    height: Style.space(12)

    Rectangle {
      id: shell
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(18)
      height: Style.space(10)
      radius: Style.space(2)
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                            view.launcher.foreground.b, 0.35)

      Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(2)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(1, Math.round((shell.width - Style.space(4))
                                      * Math.max(0, Math.min(100, cell.percent)) / 100))
        height: shell.height - Style.space(4)
        radius: Style.space(1)
        color: cell.percent <= 20 ? Color.urgent : Color.accent
      }
    }

    Rectangle {
      anchors.left: shell.right
      anchors.verticalCenter: shell.verticalCenter
      width: Style.space(2)
      height: Style.space(4)
      radius: Style.space(1)
      color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                     view.launcher.foreground.b, 0.35)
    }

    Text {
      id: reading
      anchors.left: shell.right
      anchors.leftMargin: Style.space(6)
      anchors.verticalCenter: shell.verticalCenter
      text: cell.percent >= 0 ? cell.percent + "%" : ""
      color: Qt.darker(view.launcher.foreground, 2.0)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  spacing: 0

  Item {
    width: view.width
    height: view.padY
    visible: !view.off
  }

  // ---- the radio, when it is off: the whole card, not a row

  Item {
    width: view.width
    height: view.off ? view.offHeight : 0
    visible: view.off

    MouseArea {
      anchors.fill: parent
      onClicked: {
        if (view.radio) view.launcher.activate(view.radio.row)
      }
    }

    Column {
      anchors.centerIn: parent
      spacing: Style.space(8)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        // The extension's own glyph, which is already whatever the JSON says
        // this keyword looks like, so the off state cannot drift from the on
        // state's icon.
        text: view.radio ? String(view.radio.row.iconGlyph || "") : ""
        color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                       view.launcher.foreground.b, 0.35)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.displayLarge
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: view.radio ? String(view.radio.row.title || "") : ""
        color: view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.heading
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: view.bluetooth
          ? "Nothing pairs or connects while the adapter is off."
          : "Nothing is in range while the radio is off."
        color: Qt.darker(view.launcher.foreground, 2.2)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // ---- the one you are on

  Item {
    id: heroBox
    width: view.width
    height: view.heroBlock
    visible: view.hero !== null && !view.off

    readonly property var row: view.hero ? view.hero.row : null
    readonly property bool selected: view.hero
      && view.hero.index === view.launcher.selectedIndex

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      anchors.bottomMargin: Style.space(6)
      radius: Style.cornerRadius
      // Accent-tinted rather than merely selected: this panel is the answer to
      // "which one am I on" whether or not the cursor happens to be sitting on
      // it, so it stays loud when the selection moves away.
      color: heroBox.selected
        ? view.launcher.selectedBackground
        : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
      border.width: heroBox.selected ? Math.max(1, Style.space(1)) : 0
      border.color: Color.accent
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onEntered: { if (view.hero) view.launcher.select(view.hero.index) }
      onClicked: { if (view.hero) view.launcher.activate(view.hero.row) }
    }

    Column {
      anchors.left: parent.left
      anchors.leftMargin: view.gutter
      anchors.right: parent.right
      anchors.rightMargin: view.gutter
      anchors.top: parent.top
      anchors.topMargin: Style.space(11)
      spacing: Style.space(5)

      Text {
        text: view.bluetooth ? "CONNECTED" : "ON THIS NETWORK"
        color: Color.accent
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.9
      }

      Text {
        width: parent.width
        text: heroBox.row ? String(heroBox.row.title || "") : ""
        color: heroBox.selected ? view.launcher.selectedText : view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.heading
        font.bold: true
        elide: Text.ElideRight
      }

      Row {
        spacing: Style.space(8)

        Bars {
          anchors.verticalCenter: parent.verticalCenter
          level: heroBox.row && heroBox.row.signal !== undefined
            ? Number(heroBox.row.signal) : -1
          fullHeight: Style.space(16)
          barWidth: Style.space(4)
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: {
            if (!heroBox.row) return ""
            var bits = []
            var reading = String(heroBox.row.signalLabel || "")
            if (reading !== "") bits.push(reading)
            var meta = String(heroBox.row.meta || "")
            if (meta !== "") bits.push(meta)
            return bits.join("  ·  ")
          }
          color: Qt.darker(view.launcher.foreground, 1.7)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        // U+F023, the padlock. Secured is the common case, so it is the quiet
        // mark and "open" is the one spelled out: a network with no lock on it
        // is the one worth reading a word about.
        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: !view.bluetooth
          text: (heroBox.row && String(heroBox.row.secure || "") !== "")
            ? "  " + String(heroBox.row.secure) : "open"
          color: Qt.darker(view.launcher.foreground, 1.9)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        // What the thing is. A Bluetooth row has no security to report and a
        // Wi-Fi row has no kind, so the two share the slot.
        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: text !== ""
          text: heroBox.row ? String(heroBox.row.deviceKind || "") : ""
          color: Qt.darker(view.launcher.foreground, 1.9)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        Cell {
          anchors.verticalCenter: parent.verticalCenter
          percent: (heroBox.row && heroBox.row.battery !== undefined)
            ? Number(heroBox.row.battery) : -1
        }
      }
    }
  }

  // ---- everything else

  Item {
    width: view.width
    height: view.labelBlock
    visible: view.labelBlock > 0 && !view.off

    Text {
      anchors.left: parent.left
      anchors.leftMargin: view.gutter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(4)
      text: {
        var n = view.rest.length
        if (view.bluetooth) return (view.hero ? "ALSO PAIRED" : "PAIRED") + "  ·  " + n
        return (view.hero ? "ALSO IN RANGE" : "IN RANGE") + "  ·  " + n
      }
      color: Qt.darker(view.launcher.foreground, 2.4)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 0.8
    }
  }

  ListView {
    id: list
    width: view.width
    height: view.off ? 0 : view.listHeight
    visible: !view.off
    clip: true
    focus: false
    interactive: true
    highlightMoveDuration: 0
    model: view.rest
    // The model holds { row, index } pairs, so currentIndex is a position in
    // this list and the launcher's selectedIndex is not. Walking the model to
    // find it is what keeps the two numberings from being quietly confused.
    currentIndex: {
      for (var i = 0; i < view.rest.length; i++) {
        if (view.rest[i].index === view.launcher.selectedIndex) return i
      }
      return -1
    }

    delegate: Item {
      id: entry

      required property var modelData

      readonly property var row: entry.modelData.row
      readonly property bool selected: entry.modelData.index === view.launcher.selectedIndex

      width: list.width
      height: view.rowHeight

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        anchors.topMargin: Style.space(1)
        anchors.bottomMargin: Style.space(1)
        radius: Style.cornerRadius
        color: entry.selected ? view.launcher.selectedBackground : "transparent"
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: view.launcher.select(entry.modelData.index)
        onClicked: view.launcher.activate(entry.row)
      }

      Bars {
        id: meter
        anchors.left: parent.left
        anchors.leftMargin: view.gutter
        anchors.verticalCenter: parent.verticalCenter
        level: entry.row.signal !== undefined ? Number(entry.row.signal) : -1
      }

      Text {
        id: name
        anchors.left: meter.right
        anchors.leftMargin: Style.space(12)
        anchors.right: marks.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        text: String(entry.row.title || "")
        // A network you have a profile for is one keypress away and one you do
        // not is a password prompt. That difference is worth a whole step of
        // contrast, not just a word on the right.
        color: entry.selected
          ? view.launcher.selectedText
          : (entry.row.known === true
             ? view.launcher.foreground
             : Qt.darker(view.launcher.foreground, 1.6))
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Row {
        id: marks
        anchors.right: parent.right
        anchors.rightMargin: view.gutter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: !view.bluetooth
          text: String(entry.row.secure || "") !== "" ? "" : "open"
          color: Qt.darker(view.launcher.foreground, 2.2)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: text !== ""
          text: String(entry.row.deviceKind || "")
          color: Qt.darker(view.launcher.foreground, 2.4)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }

        Cell {
          anchors.verticalCenter: parent.verticalCenter
          percent: entry.row.battery !== undefined ? Number(entry.row.battery) : -1
        }

        Chip {
          anchors.verticalCenter: parent.verticalCenter
          text: String(entry.row.mark || "")
          accented: entry.row.known === true
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }
      }
    }
  }

  // ---- the radio itself, when it is on

  Item {
    id: strip
    width: view.width
    height: view.stripBlock
    visible: view.radio !== null && !view.off

    readonly property var row: view.radio ? view.radio.row : null
    readonly property bool selected: view.radio
      && view.radio.index === view.launcher.selectedIndex

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      anchors.topMargin: Style.space(3)
      radius: Style.cornerRadius
      color: strip.selected ? view.launcher.selectedBackground : "transparent"
    }

    // A hairline, so the radio reads as the frame around the list rather than
    // as its last entry.
    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.leftMargin: view.gutter
      anchors.right: parent.right
      anchors.rightMargin: view.gutter
      height: 1
      color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                     view.launcher.foreground.b, 0.10)
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onEntered: { if (view.radio) view.launcher.select(view.radio.index) }
      onClicked: { if (view.radio) view.launcher.activate(view.radio.row) }
    }

    Text {
      anchors.left: parent.left
      anchors.leftMargin: view.gutter
      anchors.right: pill.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: Style.space(2)
      text: {
        var bits = [String(strip.row ? (strip.row.title || "") : "")]
        var iface = strip.row ? String(strip.row.iface || "") : ""
        if (iface !== "") bits.push(iface)
        return bits.join("  ·  ")
      }
      color: Qt.darker(view.launcher.foreground, 1.8)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    // A switch, drawn as one. The strip is the only row here that changes the
    // state of the whole view, so it does not look like the entries above it.
    Rectangle {
      id: pill
      anchors.right: parent.right
      anchors.rightMargin: view.gutter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: Style.space(2)
      width: Style.space(26)
      height: Style.space(14)
      radius: height / 2
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.30)

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: parent.width - width - Style.space(2)
        width: Style.space(10)
        height: Style.space(10)
        radius: height / 2
        color: Color.accent
      }
    }
  }

  Item {
    width: view.width
    height: view.padY
    visible: !view.off
  }
}
