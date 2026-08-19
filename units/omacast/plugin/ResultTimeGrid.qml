import QtQuick
import qs.Commons
import qs.Ui

// A day, drawn, so a meeting time can be seen rather than worked out.
//
//   tz: john:tokyo maria:spain ana:sp
//
// One row per person, one cell per hour over the next twenty-four. Each cell is
// shaded by what that hour is where they are: asleep, early, working, evening.
// Nobody reads twenty-four numbers per person and computes the overlap. They
// look for the band of colour that runs all the way down, and that is the
// answer. Four rows with no shared band is also an answer, and one you want to
// see in a glance rather than deduce.
//
// The row carries:
//   people[]   { name, city, delta, cells[] }
//   cells[]    { hour, label, band, day }  band is asleep|early|work|evening
//   best[]     column indexes where everyone is working
//   ok[]       column indexes where nobody is asleep
//   startsAt   unix seconds of column zero, in the reader's own zone
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

  readonly property var row: launcher.rows.length > 0 ? launcher.rows[0] : null
  readonly property var people: (view.row && view.row.people) ? view.row.people : []
  readonly property var best: (view.row && view.row.best) ? view.row.best : []
  readonly property var ok: (view.row && view.row.ok) ? view.row.ok : []

  readonly property int columns: 24
  // Wide enough for a name over "Sao Paulo · 12h ahead". At 120 the shift was
  // cut to "12h ahe…", which is the one number the row exists to tell you.
  readonly property int labelWidth: Style.space(168)
  readonly property int gutter: Style.space(24)
  readonly property int cellGap: Style.space(2)
  readonly property int rowHeight: Style.space(52)
  readonly property int headerHeight: Style.space(34)
  readonly property int summaryHeight: Style.space(56)

  // The card grows to hold this, and the launcher caps it against the screen.
  implicitHeight: view.summaryHeight + view.headerHeight
    + view.people.length * view.rowHeight + Style.space(18)

  readonly property real cellWidth: {
    var usable = view.width - view.labelWidth - view.gutter * 2
    return Math.max(1, (usable - view.cellGap * (view.columns - 1)) / view.columns)
  }

  // Which hour the reader is inspecting. Left and right walk it, and every
  // number on screen follows, so the grid answers "and what time is that for
  // Maria" without a second query.
  property int cursor: view.best.length > 0 ? view.best[0]
                     : (view.ok.length > 0 ? view.ok[0] : 0)

  function step(delta) {
    view.cursor = Math.max(0, Math.min(view.columns - 1, view.cursor + delta))
  }

  // A band is a judgement about someone's day, so it is drawn as one: the hours
  // you can ask for are solid, the ones you should not are barely there.
  function bandColor(band, inCursor) {
    var base
    if (band === "work") base = Color.accent
    else if (band === "early") base = Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.42)
    else if (band === "evening") base = Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.26)
    else base = Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                        view.launcher.foreground.b, 0.07)

    if (!inCursor) return base
    return Qt.lighter(base, 1.25)
  }

  // The launcher routes left and right here and keeps every other key,
  // including Escape. Taking the focus for the arrows meant Escape never
  // reached the launcher and the overlay would not close.
  function nudge(delta) { view.step(delta) }

  Column {
    width: view.width
    spacing: 0

    // What the reader came for, before the grid rather than after it: the grid
    // is the evidence, and the evidence goes under the finding.
    Item {
      width: parent.width
      height: view.summaryHeight

      Column {
        anchors.left: parent.left
        anchors.leftMargin: view.gutter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        Text {
          text: String((view.row && view.row.title) || "")
          color: view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Text {
          text: {
            var stamp = (view.row && view.row.startsAt) ? Number(view.row.startsAt) : 0
            if (stamp === 0) return String((view.row && view.row.detail) || "")
            var at = new Date((stamp + view.cursor * 3600) * 1000)
            var hh = ("0" + at.getHours()).slice(-2)
            var mm = ("0" + at.getMinutes()).slice(-2)
            return "Your " + hh + ":" + mm
              // What is true, not what to do. Whether an evening call is fine
              // is between the reader and the person they are calling.
              + (view.best.indexOf(view.cursor) >= 0 ? "   everyone at work"
                 : (view.ok.indexOf(view.cursor) >= 0 ? "   everyone awake"
                    : "   someone asleep"))
          }
          color: Qt.darker(view.launcher.foreground, 1.7)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    // Hour labels, every third one. Twenty-four numbers across is a ruler
    // nobody reads; four is a scale.
    Item {
      width: parent.width
      height: view.headerHeight

      Repeater {
        model: view.columns

        Text {
          required property int index
          visible: index % 3 === 0
          x: view.gutter + view.labelWidth + index * (view.cellWidth + view.cellGap)
          anchors.verticalCenter: parent.verticalCenter
          text: {
            var stamp = (view.row && view.row.startsAt) ? Number(view.row.startsAt) : 0
            if (stamp === 0) return ""
            var at = new Date((stamp + index * 3600) * 1000)
            return ("0" + at.getHours()).slice(-2)
          }
          color: index === view.cursor ? Color.accent : Qt.darker(view.launcher.foreground, 2.1)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    Repeater {
      model: view.people

      Item {
        required property var modelData
        required property int index

        width: view.width
        height: view.rowHeight

        Column {
          anchors.left: parent.left
          anchors.leftMargin: view.gutter
          anchors.verticalCenter: parent.verticalCenter
          width: view.labelWidth - Style.space(8)
          spacing: 0

          Text {
            text: String(modelData.name || "")
            color: view.launcher.foreground
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            // The city and the shift, because a name alone does not say why the
            // row looks the way it does.
            text: String(modelData.city || "") + "  ·  " + String(modelData.delta || "")
            color: Qt.darker(view.launcher.foreground, 2.0)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
          }
        }

        Repeater {
          model: modelData.cells || []

          Item {
            required property var modelData
            required property int index

            x: view.gutter + view.labelWidth + index * (view.cellWidth + view.cellGap)
            anchors.verticalCenter: parent.verticalCenter
            width: view.cellWidth
            height: view.rowHeight - Style.space(8)

            Rectangle {
              anchors.top: parent.top
              width: parent.width
              height: Style.space(24)
              radius: Style.space(3)
              color: view.bandColor(String(modelData.band || "asleep"), index === view.cursor)
            }

            // The hour, in this person's own time, under their own cell. Every
            // third column so the numbers have room, and always the same
            // columns as the header, so a number never moves as you look along
            // the row: a colour says whether an hour is reasonable, a number
            // says which hour it is, and the second question is the one you
            // have to answer out loud to somebody.
            Text {
              visible: index % 3 === 0 || index === view.cursor
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              text: String(modelData.label || "").slice(0, 2)
              color: index === view.cursor
                ? Color.accent : Qt.darker(view.launcher.foreground, 2.0)
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }

    // The cursor, drawn once over the whole grid rather than per cell, so it
    // reads as one column and not as a row of separately highlighted squares.
    Item {
      width: parent.width
      height: Style.space(10)
    }
  }

  Rectangle {
    // Sits above the rows and marks the hour under inspection.
    x: view.gutter + view.labelWidth + view.cursor * (view.cellWidth + view.cellGap) - Style.space(2)
    y: view.summaryHeight + view.headerHeight - Style.space(4)
    width: view.cellWidth + Style.space(4)
    height: view.people.length * view.rowHeight + Style.space(4)
    radius: Style.space(4)
    color: "transparent"
    border.width: 1
    border.color: Color.accent
    visible: view.people.length > 0
  }
}
