import QtQuick
import qs.Commons
import qs.Ui

// Agents, sorted by what they need from you.
//
// Somebody running five coding agents does not want a roster. They want the
// one that stopped to ask a question, and they want it before they have read
// anything. A list of rows with the state written on the right cannot do that:
// every row is the same size, the same colour and the same weight, so finding
// the blocked one means reading five lines of which four were irrelevant.
//
// So the state is the shape. A blocked agent gets a taller row, a red edge and
// the question it is actually asking; one that finished behind your back gets
// the accent; one that is working gets a rail that breathes and nothing to
// read; the idle ones shrink to a single dim line and the workspaces with no
// agent in them shrink again. Nowhere on the card is there a column of the
// words idle, working and blocked, and the counts across the top say which of
// those three you are about to spend time on before the eye has reached a row.
//
// The line across the top under the headline is the same information a third
// time, as a proportion: a bar that is mostly red is a bad morning, and that
// reads at a glance from further away than any number does.
//
// Rows carry:
//   band 0..5  status name kind note what path session
//   wsLabel tabLabel tabCount here since paneId
//   counts { blocked, done, working, idle, unknown, agents, spaces,
//            sessions, matched }   on the first row only
//   offline    on the one row that replaces everything
Item {
  // The card cannot hold a view that draws past its own height, and every view
  // here computes that height from its content. Clipping at the root is what
  // makes a wrong sum a short answer rather than rows spilling over the footer.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property var rows: launcher.rows
  readonly property var head: rows.length > 0 ? rows[0] : null
  readonly property bool offline: view.head !== null && view.head.offline === true
  readonly property var counts: (view.head && view.head.counts) ? view.head.counts : ({})
  // The session name is noise on a machine with one session and the only way
  // to tell two `main` workspaces apart on a machine with several.
  readonly property bool manySessions: Number(view.counts.sessions || 1) > 1

  readonly property int gutter: Style.space(18)
  readonly property int headHeight: Style.space(62)
  readonly property int textLeft: view.gutter + Style.space(16)
  // Wide enough for "waiting" over "better-omarchy · review" at caption size.
  readonly property int rightWidth: Style.space(168)

  readonly property color dim: Qt.darker(view.launcher.foreground, 2.1)
  readonly property color dimmer: Qt.darker(view.launcher.foreground, 2.5)

  function faint(alpha) {
    return Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                   view.launcher.foreground.b, alpha)
  }

  // Only two colours exist in a theme here, and both are spent on the two
  // states that are asking for your attention. Everything else is the text
  // colour at a lower opacity, which is what stops the card from being a
  // traffic light where nothing means anything.
  function railColor(band) {
    if (band === 0) return Color.urgent
    if (band === 1) return Color.accent
    if (band === 2) return view.faint(0.5)
    if (band === 3) return view.faint(0.18)
    if (band === 4) return view.faint(0.1)
    return "transparent"
  }

  // Blocked reads at two lines and idle reads at one, because the row's height
  // is the first thing seen about it and a state nobody has to act on should
  // not take the same room as one they do.
  function rowHeight(band) {
    if (band === 0) return Style.space(54)
    if (band === 1 || band === 2) return Style.space(44)
    if (band === 5) return Style.space(30)
    return Style.space(32)
  }

  function ago(seconds) {
    var s = Math.max(0, Number(seconds || 0))
    if (s < 60) return Math.floor(s) + "s"
    if (s < 3600) return Math.floor(s / 60) + "m"
    if (s < 86400) {
      var h = Math.floor(s / 3600)
      var m = Math.floor((s % 3600) / 60)
      return m > 0 ? h + "h " + m + "m" : h + "h"
    }
    return Math.floor(s / 86400) + "d"
  }

  // How many rows fit if the first one drawn is `start`. Rows are different
  // heights, so this cannot be a division: it adds them up and stops before the
  // one that would not fit whole. A row cut in half at the bottom edge reads as
  // a rendering fault, and the counts in the header already say how many exist,
  // so dropping the tail loses nothing that was not already said.
  function fits(start) {
    if (view.rows.length === 0) return 0
    var room = view.maxHeight > 0
      ? view.maxHeight - view.headHeight - Style.space(10)
      : 100000
    var used = 0
    var n = 0
    for (var i = start; i < view.rows.length; i++) {
      var h = view.rowHeight(Number(view.rows[i].band))
      if (used + h > room && n > 0) break
      used += h
      n++
    }
    return n
  }

  // The window slides down only far enough to keep the selection inside it.
  // Arrowing past the bottom of a fixed window selects a row nobody can see,
  // and the launcher's own footer would then be describing something invisible.
  readonly property int firstRow: {
    var sel = Math.max(0, Math.min(view.rows.length - 1, view.launcher.selectedIndex))
    var start = 0
    while (sel >= start + Math.max(1, view.fits(start))) start++
    return start
  }

  readonly property int shownRows: Math.min(view.rows.length - view.firstRow,
                                            view.fits(view.firstRow))

  readonly property int bodyHeight: {
    var used = 0
    for (var i = view.firstRow; i < view.firstRow + view.shownRows; i++) {
      used += view.rowHeight(Number(view.rows[i].band))
    }
    return used
  }

  implicitHeight: view.offline
    ? Style.space(104)
    : (view.rows.length === 0 ? 0 : view.headHeight + view.bodyHeight + Style.space(10))

  // ------------------------------------------------------------------ offline
  //
  // The binary is installed, which is why the keyword is here at all, and no
  // session has a server behind it. Drawing an empty card would be read as "no
  // agents", which is a different and much more reassuring thing than "nothing
  // is being watched".
  Item {
    visible: view.offline
    anchors.fill: parent

    Column {
      anchors.left: parent.left
      anchors.leftMargin: view.gutter
      anchors.right: parent.right
      anchors.rightMargin: view.gutter
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      Text {
        text: String(view.head ? view.head.title : "")
        color: view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.large
      }

      Text {
        width: parent.width
        text: String(view.head ? view.head.subtitle : "")
        color: view.dim
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }
    }
  }

  // ------------------------------------------------------------------- header
  Item {
    visible: !view.offline && view.rows.length > 0
    width: view.width
    height: view.headHeight

    Text {
      id: headline
      anchors.left: parent.left
      anchors.leftMargin: view.gutter
      anchors.top: parent.top
      anchors.topMargin: Style.space(10)
      anchors.right: parent.right
      anchors.rightMargin: view.gutter
      // The one sentence this card exists to say. Waiting outranks finished
      // outranks running, in the same order as the rows below, so the headline
      // and the top of the list are never about different things.
      text: {
        var c = view.counts
        var blocked = Number(c.blocked || 0)
        var done = Number(c.done || 0)
        var working = Number(c.working || 0)
        if (blocked > 0) return blocked === 1 ? "1 agent is waiting on you"
                                              : blocked + " agents are waiting on you"
        if (done > 0) return done === 1 ? "1 agent finished" : done + " agents finished"
        if (working > 0) return working === 1 ? "1 agent working" : working + " agents working"
        if (Number(c.agents || 0) > 0) return "nothing needs you"
        return "no agents running"
      }
      color: {
        var c = view.counts
        if (Number(c.blocked || 0) > 0) return Color.urgent
        if (Number(c.done || 0) > 0) return Color.accent
        return view.launcher.foreground
      }
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.large
      elide: Text.ElideRight
    }

    Text {
      anchors.left: parent.left
      anchors.leftMargin: view.gutter
      anchors.top: headline.bottom
      anchors.topMargin: Style.space(2)
      text: {
        var c = view.counts
        var agents = Number(c.agents || 0)
        var spaces = Number(c.spaces || 0)
        var out = agents === 1 ? "1 agent" : agents + " agents"
        out += spaces === 1 ? " · 1 workspace" : " · " + spaces + " workspaces"
        if (view.manySessions) out += " · " + Number(c.sessions || 0) + " sessions"
        return out
      }
      color: view.dimmer
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
    }

    // The same counts as a proportion. Nobody reads this; they see whether it
    // is mostly red, and that is the whole job.
    Row {
      id: bar
      anchors.left: parent.left
      anchors.leftMargin: view.gutter
      anchors.right: parent.right
      anchors.rightMargin: view.gutter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(8)
      height: Style.space(4)
      spacing: Style.space(2)

      readonly property int total: Math.max(1, Number(view.counts.agents || 0))

      Repeater {
        model: [
          { n: Number(view.counts.blocked || 0), band: 0 },
          { n: Number(view.counts.done || 0), band: 1 },
          { n: Number(view.counts.working || 0), band: 2 },
          { n: Number(view.counts.idle || 0), band: 3 },
          { n: Number(view.counts.unknown || 0), band: 4 }
        ]

        Rectangle {
          required property var modelData
          visible: modelData.n > 0
          width: visible
            ? Math.max(Style.space(4), Math.round((bar.width - Style.space(8))
                                                  * modelData.n / bar.total))
            : 0
          height: bar.height
          radius: height / 2
          color: view.railColor(modelData.band)
        }
      }

      // An empty track rather than no track, so the header does not change
      // height the moment the last agent exits.
      Rectangle {
        visible: Number(view.counts.agents || 0) === 0
        width: bar.width
        height: bar.height
        radius: height / 2
        color: view.faint(0.08)
      }
    }
  }

  // --------------------------------------------------------------------- rows
  Column {
    y: view.headHeight
    width: view.width
    visible: !view.offline
    spacing: 0

    Repeater {
      model: view.shownRows

      delegate: Item {
        id: entry

        required property int index

        // The window and the model are two bindings and a repopulation can land
        // between them for one frame, which is a delegate asking for a row that
        // is not there yet rather than an error anyone would see.
        readonly property var row: view.rows[view.firstRow + entry.index] || ({})
        readonly property int band: Number(entry.row.band || 0)
        readonly property bool selected: (view.firstRow + entry.index) === view.launcher.selectedIndex
        readonly property bool twoLine: entry.band <= 2
        readonly property real seconds: Number(entry.row.since)

        width: parent.width
        height: view.rowHeight(entry.band)

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
          onClicked: view.launcher.activate(entry.row)
        }

        Rectangle {
          id: rail
          x: view.gutter
          y: Style.space(7)
          width: Style.space(3)
          height: parent.height - Style.space(14)
          radius: width / 2
          color: view.railColor(entry.band)

          // A working agent is the one thing on this card that is changing
          // while you look at it, and the only honest way to draw that is
          // motion. It also keeps working apart from idle without spending a
          // colour on it.
          SequentialAnimation on opacity {
            running: entry.band === 2
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
          }
        }

        Column {
          id: left
          anchors.left: parent.left
          anchors.leftMargin: view.textLeft
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          readonly property int room: Math.max(Style.space(60),
            entry.width - view.textLeft - view.rightWidth - view.gutter)

          Row {
            spacing: Style.space(7)

            Text {
              id: name
              anchors.verticalCenter: parent.verticalCenter
              text: String(entry.row.name || "")
              color: entry.selected ? view.launcher.selectedText
                                    : (entry.twoLine ? view.launcher.foreground : view.dim)
              font.family: view.launcher.fontFamily
              font.pixelSize: entry.twoLine ? Style.font.body : Style.font.caption
              elide: Text.ElideRight
              width: Math.min(implicitWidth, left.room * 0.6)
            }

            // What kind of agent it is, and only when that is not already the
            // name: an agent nobody renamed is called "Claude Code" already,
            // and a chip repeating it is a chip saying nothing.
            Chip {
              id: kind
              anchors.verticalCenter: parent.verticalCenter
              visible: entry.twoLine && text !== "" && text !== String(entry.row.name || "")
              text: String(entry.row.kind || "")
              foreground: view.launcher.foreground
              fontFamily: view.launcher.fontFamily
            }

            // A one-line row has no second line to put this on, and a bare
            // list of agent names with no idea where they are working is not
            // worth the height it takes.
            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: !entry.twoLine
              width: Math.max(0, left.room - name.width - Style.space(14))
              text: {
                var path = String(entry.row.path || "")
                if (path !== "") return path
                return entry.band === 5 ? "no agent in it" : String(entry.row.what || "")
              }
              color: view.dimmer
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          // The question, when there is one. A blocked agent that says what it
          // is blocked on can often be answered from here without going and
          // looking, which is the difference between this card and a list of
          // names.
          Text {
            visible: entry.twoLine
            width: left.room
            text: {
              var note = String(entry.row.note || "")
              if (note !== "") return note
              var what = String(entry.row.what || "")
              if (what !== "") return what
              return String(entry.row.path || "")
            }
            color: entry.band === 0 ? view.dim : view.dimmer
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }

        // Where it is, and how long it has been like this. Both belong on the
        // right because both are answers to "is this the one", asked after the
        // name has already been read.
        Column {
          anchors.right: parent.right
          anchors.rightMargin: view.gutter
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            width: view.rightWidth
            horizontalAlignment: Text.AlignRight
            visible: entry.band <= 2
            // Nothing in the herdr API timestamps a state change, so this is
            // measured by the script from the first run that saw the change.
            // An agent that was already blocked the first time anything looked
            // has no start to count from, and says the state in words rather
            // than inventing a zero.
            text: entry.seconds >= 0 ? view.ago(entry.seconds)
                                     : (entry.band === 0 ? "waiting" : "")
            color: entry.band === 0 ? Color.urgent
                                    : (entry.band === 1 ? Color.accent : view.dimmer)
            font.family: view.launcher.fontFamily
            font.pixelSize: entry.band === 0 ? Style.font.body : Style.font.caption
          }

          Text {
            width: view.rightWidth
            horizontalAlignment: Text.AlignRight
            text: {
              var parts = []
              // A workspace row is already named after its workspace on the
              // left, so repeating it here would be the same word twice.
              var where = entry.band === 5 ? "" : String(entry.row.wsLabel || "")
              var tab = String(entry.row.tabLabel || "")
              // A workspace with one tab has nothing to disambiguate, and its
              // tab is called "1" anyway.
              if (where !== "" && tab !== "" && Number(entry.row.tabCount || 1) > 1) {
                where += " · " + tab
              }
              if (view.manySessions) {
                var session = String(entry.row.session || "")
                where = where === "" ? session : session + "/" + where
              }
              if (where !== "") parts.push(where)
              // Where the herdr focus already is. Enter on this row is a no-op
              // for the session and still raises the window, which is worth
              // knowing before pressing it.
              if (entry.row.here === true) parts.push("here")
              return parts.join(" · ")
            }
            color: entry.row.here === true ? Color.accent : view.dimmer
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideLeft
          }
        }
      }
    }
  }
}
