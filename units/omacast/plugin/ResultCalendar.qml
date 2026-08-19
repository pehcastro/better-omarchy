import QtQuick
import qs.Commons
import qs.Ui

// A month laid out as a month.
//
// `cal` already draws one, but it draws it out of spaces, which means the
// columns only line up if the font cooperates and today can only be marked with
// an escape code. Given the year, the month and the day, the same seven columns
// become real cells: today is a filled circle, a marked day carries a dot, and
// the whole thing is typeset like the rest of the card instead of like a
// terminal that wandered into it.
//
// Every row is a month, so the row you have selected is the month on screen and
// the tabs across the top are the rest of the answer.
Item {
  // Without this, a height computed from content draws past the card's border
  // when the sum is wrong, rather than being cut off inside it.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property var current: launcher.rows.length > launcher.selectedIndex
    ? launcher.rows[launcher.selectedIndex] : null

  readonly property int year: view.number(current && current.year, 0)
  readonly property int month: view.number(current && current.month, 0)
  readonly property int today: view.number(current && current.today, 0)
  // 0 for a week that starts on Sunday, 1 for one that starts on Monday.
  readonly property int weekStart: view.number(current && current.weekStart, 0)
  readonly property var marks: (current && current.marks) || []

  readonly property var weekdayNames: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

  readonly property int daysInMonth: (year > 0 && month > 0) ? new Date(year, month, 0).getDate() : 0
  // Which column the 1st falls in, after the week has been rotated to start on
  // the day this locale starts on.
  readonly property int offset: daysInMonth > 0
    ? (new Date(year, month - 1, 1).getDay() - weekStart + 7) % 7 : 0
  readonly property int weeks: daysInMonth > 0 ? Math.ceil((offset + daysInMonth) / 7) : 0

  // Everything above and below the grid. The grid gets what is left of the room
  // the launcher gave us, and this is what "left" means.
  readonly property int chrome: Style.space(36) + Style.space(40) + Style.space(22) + Style.space(14)

  // A day is a square, because a month drawn out of wide short cells reads as a
  // table of numbers rather than as a month. Three things argue over how big
  // that square is and the smallest wins:
  //
  //   the card's width, divided seven ways, so the row always fits across;
  //   the room left under the tabs, divided by the weeks, so a six-week month
  //     on a short screen shrinks instead of running off the bottom;
  //   a ceiling, because a 620-wide card divided seven ways is a 111px square,
  //     and six rows of those is a month that fills the screen.
  //
  // Under the floor the square stops shrinking and the view clips, which is the
  // only honest thing left to do with a month that does not fit at all.
  readonly property int cellCeiling: Style.space(56)
  readonly property int cellFloor: Style.space(22)
  readonly property int widthLimit: Math.floor((width - Style.space(36)) / 7)
  readonly property int heightLimit: (maxHeight > 0 && weeks > 0)
    ? Math.floor((maxHeight - chrome) / weeks) : cellCeiling
  readonly property int cellSize: Math.max(cellFloor,
    Math.min(widthLimit, heightLimit, cellCeiling))

  implicitHeight: tabs.height + heading.height + weekdays.height + weeks * cellSize + Style.space(14)

  function number(value, fallback) {
    var n = Number(value)
    return isFinite(n) ? n : fallback
  }

  // Empty outside the month, so a cell that is not a day is nothing at all
  // rather than a number belonging to a month you did not ask for.
  function dayAt(index) {
    var day = index - view.offset + 1
    return (day >= 1 && day <= view.daysInMonth) ? day : 0
  }

  // A tab moves the cursor, it does not fire the row: the tabs are how you get
  // to another month, and activating a month copies it and closes the launcher.
  // These are the same three writes the arrow keys make.
  function select(index) {
    var rows = view.launcher.rows
    if (index < 0 || index >= rows.length) return
    view.launcher.cursorMoved = true
    view.launcher.selectedIndex = index
    view.launcher.selectedKey = rows[index].key
  }

  Item {
    id: tabs
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.space(36)

    Row {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(18)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      Repeater {
        model: view.launcher.rows

        delegate: Chip {
          required property var modelData
          required property int index

          // The short label when the row has one: twelve months of a year need
          // to fit across the card, and "January 2027" twelve times does not.
          text: String(modelData.accessory || modelData.title || "")
          accented: index === view.launcher.selectedIndex
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily

          MouseArea {
            anchors.fill: parent
            onClicked: view.select(parent.index)
          }
        }
      }
    }
  }

  Item {
    id: heading
    anchors.top: tabs.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.space(40)

    Text {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(18)
      anchors.right: week.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      text: String((view.current && view.current.title) || "")
      color: view.launcher.foreground
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.heading
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      id: week
      anchors.right: parent.right
      anchors.rightMargin: Style.space(18)
      anchors.verticalCenter: parent.verticalCenter
      text: String((view.current && view.current.subtitle) || "")
      color: Qt.darker(view.launcher.foreground, 1.8)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      width: Math.min(implicitWidth, view.width * 0.4)
      horizontalAlignment: Text.AlignRight
    }
  }

  Row {
    id: weekdays
    anchors.top: heading.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    height: Style.space(22)

    Repeater {
      model: 7

      delegate: Text {
        required property int index

        width: view.cellSize
        height: weekdays.height
        text: view.weekdayNames[(index + view.weekStart) % 7]
        color: Qt.darker(view.launcher.foreground, 2.1)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  Grid {
    anchors.top: weekdays.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    columns: 7

    Repeater {
      model: view.weeks * 7

      delegate: Item {
        id: cell

        required property int index

        readonly property int day: view.dayAt(index)
        readonly property bool isToday: day > 0 && day === view.today
        readonly property bool marked: day > 0 && view.marks.indexOf(day) >= 0

        width: view.cellSize
        height: view.cellSize

        // The dot hangs under the number, so the number sits that much above
        // centre and the two of them read as one mark on the square rather than
        // as a number with something loose beneath it.
        readonly property int dotSize: Math.max(Style.space(3), Math.round(view.cellSize * 0.08))
        readonly property int dotGap: Math.max(Style.space(2), Math.round(view.cellSize * 0.06))

        Rectangle {
          anchors.centerIn: number
          // Proportional, because a fixed circle in a square that changes size
          // is either a ring around the number or a blob behind the whole cell.
          width: Math.max(Style.space(20), Math.round(view.cellSize * 0.62))
          height: width
          radius: width / 2
          visible: cell.isToday
          color: Color.accent
        }

        Text {
          id: number
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -Math.round((cell.dotSize + cell.dotGap) / 2)
          anchors.horizontalCenter: parent.horizontalCenter
          text: cell.day > 0 ? String(cell.day) : ""
          // On the accent circle the day reads against the card's own
          // background, which is the one color guaranteed to sit under it.
          color: cell.isToday ? view.launcher.background : view.launcher.foreground
          font.family: view.launcher.fontFamily
          // The square grew, so the number in it grows too. Left at the body
          // size, a 75px cell is mostly empty and the month reads as a sparse
          // table again, which is the thing the square was meant to fix.
          font.pixelSize: Math.max(Style.font.body, Math.round(view.cellSize * 0.26))
        }

        Rectangle {
          anchors.top: number.bottom
          anchors.topMargin: cell.dotGap
          anchors.horizontalCenter: parent.horizontalCenter
          width: cell.dotSize
          height: width
          radius: width / 2
          visible: cell.marked
          color: Color.accent
        }
      }
    }
  }
}
