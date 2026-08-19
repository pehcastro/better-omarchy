import QtQuick
import qs.Commons
import qs.Ui

// An agent working, drawn while it works.
//
//   do: open a new workspace and split the terminal into four
//   do: find every TODO in this repo and list them
//
// Two things this deliberately is not. It is not a spinner: forty seconds of a
// rotating dot tells you nothing, and the one question anybody has while an
// agent runs is "what is it touching right now". And it is not the raw stream
// either: a wall of JSON events, or of a terminal's own decoration, is a
// transcript rather than an answer, and nobody reads it.
//
// So it is a short ledger. One line per tool call, in the order they happened,
// each naming the thing rather than the tool: "Read Launcher.qml", "Search
// TODO", "workspace 9". The newest is at the bottom with a live dot on it. The
// prose the agent writes grows underneath, following its own tail. When it
// finishes, the ledger collapses to a count and the answer is what is left.
//
// Refusals are the half of this that has to be drawn. An agent quietly unable
// to do the thing, followed by a confident paragraph about it, is how somebody
// comes to believe the launcher did something it did not, so every blocked step
// is red, named, and carries the reason.
//
// The row carries:
//   state      hint | ready | running | done | failed | stopped | missing
//   agentName  which CLI, for the chip
//   cwd        where it runs, shortened to ~
//   steps[]    { kind, text }  kind is read|find|shell|desk|web|think|
//                              write|blocked|failed
//   answer     the prose so far
//   blocked[]  { text, why }
//   hints[]    example instructions, shown before anything has run
//   startedAt  unix seconds, so the clock ticks here rather than on the poll
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
  readonly property string phase: view.row ? String(view.row.state || "ready") : "ready"
  readonly property var steps: (view.row && view.row.steps) ? view.row.steps : []
  readonly property var blocked: (view.row && view.row.blocked) ? view.row.blocked : []
  readonly property var hints: (view.row && view.row.hints) ? view.row.hints : []
  readonly property string answer: view.row ? String(view.row.answer || "") : ""
  readonly property string note: view.row ? String(view.row.note || "") : ""

  readonly property bool running: view.phase === "running"
  readonly property bool finished: view.phase === "done" || view.phase === "failed"
    || view.phase === "stopped"

  readonly property int gutter: Style.space(20)
  readonly property int stepHeight: Style.space(22)

  // Only the tail of the ledger. An agent that reads thirty files has thirty
  // lines nobody wants, and the two that matter are the one it is doing now and
  // the one before it. The count of what scrolled off is kept in the header, so
  // nothing disappears without being accounted for.
  readonly property int stepWindow: 7
  readonly property var shownSteps: view.steps.length > view.stepWindow
    ? view.steps.slice(view.steps.length - view.stepWindow) : view.steps
  readonly property int hiddenSteps: view.steps.length - view.shownSteps.length

  // The clock ticks here rather than arriving with each poll, so it counts in
  // seconds instead of in whatever interval the launcher last asked at.
  property int now: 0
  Timer {
    running: view.running
    interval: 500
    repeat: true
    triggeredOnStart: true
    onTriggered: view.now = Math.floor(Date.now() / 1000)
  }

  readonly property int elapsed: {
    if (!view.row) return 0
    var started = Number(view.row.startedAt || 0)
    if (started <= 0) return Number(view.row.elapsed || 0)
    if (!view.running) return Number(view.row.elapsed || 0)
    return Math.max(0, view.now - started)
  }

  function clock(seconds) {
    var s = Math.max(0, Math.floor(seconds))
    if (s < 60) return s + "s"
    return Math.floor(s / 60) + "m " + (s % 60) + "s"
  }

  function tint(kind) {
    if (kind === "blocked") return Color.urgent
    if (kind === "failed") return Color.urgent
    if (kind === "desk") return Color.accent
    return Qt.darker(view.launcher.foreground, 1.5)
  }

  function mark(kind) {
    if (kind === "read") return "◧"
    if (kind === "find") return "⌕"
    if (kind === "shell") return "›"
    if (kind === "desk") return "◰"
    if (kind === "web") return "◌"
    if (kind === "write") return "✎"
    if (kind === "blocked") return "⊘"
    if (kind === "failed") return "×"
    return "·"
  }

  implicitHeight: Math.min(
    Math.max(Style.space(110), body.implicitHeight + Style.space(28)),
    Style.space(420))

  Flickable {
    id: scroll
    anchors.fill: parent
    anchors.leftMargin: view.gutter
    anchors.rightMargin: view.gutter
    anchors.topMargin: Style.space(10)
    anchors.bottomMargin: Style.space(8)
    contentWidth: width
    contentHeight: body.implicitHeight + Style.space(16)
    clip: true
    interactive: true

    // Follow the tail while it writes, and stop following the moment the reader
    // scrolls up, because yanking somebody back to the bottom mid-sentence is
    // worse than making them scroll down again.
    property bool following: true
    onContentYChanged: {
      if (!view.running) return
      following = contentY >= contentHeight - height - Style.space(40)
    }
    onContentHeightChanged: if (following && view.running) {
      contentY = Math.max(0, contentHeight - height)
    }

    Column {
      id: body
      width: scroll.width
      spacing: Style.space(8)

      // ---------------------------------------------------------- the header

      Row {
        width: parent.width
        spacing: Style.space(8)

        Chip {
          anchors.verticalCenter: parent.verticalCenter
          text: view.row ? String(view.row.agentName || "") : ""
          accented: true
          foreground: view.launcher.foreground
          fontFamily: view.launcher.fontFamily
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(0, parent.width - Style.space(190))
          text: view.row ? String(view.row.title || "") : ""
          color: view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: {
            if (view.running) return view.clock(view.elapsed)
            if (view.finished) return view.steps.length > 0
              ? view.steps.length + " steps · " + view.clock(view.elapsed)
              : view.clock(view.elapsed)
            return view.row ? String(view.row.cwd || "") : ""
          }
          color: Qt.darker(view.launcher.foreground, 1.9)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideLeft
          width: Math.min(implicitWidth, Style.space(170))
        }
      }

      // ------------------------------------------------- before anything runs

      Text {
        visible: view.phase === "hint" || view.phase === "ready"
          || view.phase === "missing"
        width: parent.width
        text: view.row ? String(view.row.subtitle || "") : ""
        color: Qt.darker(view.launcher.foreground, 1.7)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }

      Column {
        visible: view.hints.length > 0 && view.phase === "hint"
        width: parent.width
        spacing: Style.space(3)

        Repeater {
          model: view.hints
          Text {
            width: body.width
            text: "do: " + modelData
            color: Qt.darker(view.launcher.foreground, 2.1)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
      }

      // ------------------------------------------------------- the ledger

      Text {
        visible: view.hiddenSteps > 0
        text: "… " + view.hiddenSteps + " earlier"
        color: Qt.darker(view.launcher.foreground, 2.2)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
      }

      Column {
        visible: view.shownSteps.length > 0
        width: parent.width
        spacing: Style.space(2)

        Repeater {
          model: view.shownSteps

          Item {
            width: body.width
            height: view.stepHeight

            readonly property bool last: index === view.shownSteps.length - 1
            readonly property string kind: String(modelData.kind || "think")

            Text {
              id: bullet
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(18)
              text: view.mark(parent.kind)
              color: view.tint(parent.kind)
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption

              // The live one, and only while it is live. A pulse on a finished
              // ledger is decoration; on the current step it is the answer to
              // "is this still going".
              SequentialAnimation on opacity {
                running: view.running && bullet.parent.last
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 550 }
                NumberAnimation { to: 1.0; duration: 550 }
              }
            }

            Text {
              anchors.left: bullet.right
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: String(modelData.text || "")
              color: (view.running && parent.last)
                ? view.launcher.foreground : view.tint(parent.kind)
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }
      }

      // ---------------------------------------------------------- refusals

      Column {
        visible: view.blocked.length > 0
        width: parent.width
        spacing: Style.space(2)

        Repeater {
          model: view.blocked
          Column {
            width: body.width
            spacing: 0

            Text {
              width: parent.width
              text: "⊘  " + String(modelData.text || "")
              color: Color.urgent
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: String(modelData.why || "")
              visible: text !== ""
              color: Qt.darker(Color.urgent, 1.3)
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }
          }
        }
      }

      // ----------------------------------------------------------- the answer

      Text {
        visible: view.answer !== ""
        width: parent.width
        text: view.answer
        color: view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
      }

      Text {
        visible: view.running && view.answer === "" && view.steps.length === 0
        text: "starting"
        color: Color.accent
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body

        SequentialAnimation on opacity {
          running: view.running
          loops: Animation.Infinite
          NumberAnimation { to: 0.25; duration: 500 }
          NumberAnimation { to: 1.0; duration: 500 }
        }
      }

      // ------------------------------------------------------- the last line

      Text {
        width: parent.width
        wrapMode: Text.Wrap
        color: view.phase === "failed" || view.phase === "stopped"
          ? Color.urgent : Qt.darker(view.launcher.foreground, 2.0)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        text: {
          if (view.note !== "") return view.note
          if (view.phase === "missing") return ""
          if (view.phase === "hint") return ""
          if (view.running) return "Esc stops it · ↵ stops it"
          if (view.phase === "ready")
            return "↵ runs it here · nothing has started yet"
          if (view.blocked.length > 0)
            return "⌃K to carry on in a terminal, where you answer the prompts"
          return "↵ runs it again"
        }
      }
    }
  }
}
