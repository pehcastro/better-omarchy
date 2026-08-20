import QtQuick
import qs.Commons
import qs.Ui

// `do:` — a conversation with an agent that is allowed to act.
//
//   do: open a new workspace and split it into four terminals
//   do: now put the editor in the top left one
//
// This is a chat, and the shape follows from that. Enter sends and empties the
// box; what you sent stays here above the answer, so the second sentence can
// say "that file" and mean something. Older exchanges collapse to what you said
// and what came back, because the steps of a finished job are not what anybody
// re-reads.
//
// The live turn is three lines and no more:
//
//   ● Open 4 × terminal              ← what it is doing, with the clock
//   · Go to an empty workspace       ← the last few things it did
//   · Read Launcher.qml
//
// Deliberately not: a spinner, which answers no question; the raw stream, which
// is a transcript rather than an answer; and a step list thirty lines long,
// where the two lines that matter are the current one and the one before it.
// What scrolled off is counted rather than dropped.
//
// Refusals are drawn, in red, with the reason. An agent that quietly could not
// do the thing and then wrote a confident paragraph about it is how somebody
// comes to believe the launcher did something it did not. A run that stopped or
// failed ends in the same red, because "12s · failed" in grey beside the
// sentence reads exactly like a run that worked.
//
// `turns` is this visit's conversation and nothing older. The daemon drops it a
// few seconds after the last time this card asked for it, so opening `do:`
// tomorrow opens on the examples rather than on a list of what was run
// yesterday. Nothing here is a log: an instruction is on screen while it runs
// and while its answer is still being read, and then it is over.
//
// Two kinds of promise, drawn differently. Most sentences go to an agent, which
// will probably do what was asked. A few have exactly one reading and are done
// here instead, step by step, with no model in the middle: those say so, and the
// card lists the steps before Enter, because "this will do exactly that" and
// "this will probably do that" should not look alike.
//
// The row carries:
//   state      idle | draft | policy | missing
//   turns[]    { you, state, now, did[], earlier, steps, answer, blocked[],
//                note, elapsed, startedAt, direct }
//   draft      the instruction typed but not yet sent
//   direct     true when Enter runs the steps below rather than an agent
//   plan[]     exactly what Enter will do, in order          (direct only)
//   hints[]    example instructions, shown on an empty conversation
//   allows     what it may do without asking          (state "policy")
//   denies     what needs a terminal                  (state "policy")
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
  readonly property string phase: view.row ? String(view.row.state || "idle") : "idle"
  readonly property var turns: (view.row && view.row.turns) ? view.row.turns : []
  readonly property var hints: (view.row && view.row.hints) ? view.row.hints : []
  readonly property string draft: view.row ? String(view.row.draft || "") : ""
  readonly property bool direct: view.row ? view.row.direct === true : false
  readonly property var plan: (view.row && view.row.plan) ? view.row.plan : []

  readonly property var live: view.turns.length > 0
    ? view.turns[view.turns.length - 1] : null
  readonly property bool running: view.live
    && String(view.live.state) === "running"

  readonly property int gutter: Style.space(20)

  // The clock ticks here rather than arriving with each poll, so it counts in
  // seconds instead of in whatever interval the launcher last asked at.
  property int nowSeconds: 0
  Timer {
    running: view.running
    interval: 500
    repeat: true
    triggeredOnStart: true
    onTriggered: view.nowSeconds = Math.floor(Date.now() / 1000)
  }

  function clock(seconds) {
    var s = Math.max(0, Math.floor(seconds))
    if (s < 60) return s + "s"
    return Math.floor(s / 60) + "m " + (s % 60) + "s"
  }

  function elapsedOf(turn) {
    if (!turn) return 0
    if (String(turn.state) !== "running") return Number(turn.elapsed || 0)
    var started = Number(turn.startedAt || 0)
    if (started <= 0) return Number(turn.elapsed || 0)
    return Math.max(Number(turn.elapsed || 0), view.nowSeconds - started)
  }

  function tint(kind, state) {
    if (state === "blocked" || state === "failed") return Color.urgent
    if (kind === "desk") return Color.accent
    return Qt.darker(view.launcher.foreground, 1.7)
  }

  function mark(kind, state) {
    if (state === "blocked") return "⊘"
    if (state === "failed") return "×"
    if (kind === "read") return "◧"
    if (kind === "find") return "⌕"
    if (kind === "shell") return "›"
    if (kind === "desk") return "◰"
    if (kind === "web") return "◌"
    if (kind === "write") return "✎"
    return "·"
  }

  function ending(turn) {
    var state = String(turn.state)
    if (state === "running") return ""
    var bits = []
    // "1 steps" is the kind of thing that makes a tool look unfinished.
    if (Number(turn.steps || 0) > 0)
      bits.push(turn.steps + (Number(turn.steps) === 1 ? " step" : " steps"))
    bits.push(view.clock(view.elapsedOf(turn)))
    if (state === "stopped") bits.push("stopped")
    if (state === "failed") bits.push("failed")
    return bits.join(" · ")
  }

  // A run that did not finish says so in the same colour as everything else
  // that went wrong on this card. Grey "12s · failed" beside the sentence read
  // as a normal ending, and the only red on the card was a line of the CLI's
  // own error text, which is not where anybody looks first.
  function ended(turn) {
    var state = String(turn.state)
    if (state === "failed" || state === "stopped") return Color.urgent
    return Qt.darker(view.launcher.foreground, 2.0)
  }

  implicitHeight: Math.min(
    Math.max(Style.space(96), body.implicitHeight + Style.space(26)),
    view.maxHeight > 0 ? view.maxHeight : Style.space(420))

  Flickable {
    id: scroll
    anchors.fill: parent
    anchors.leftMargin: view.gutter
    anchors.rightMargin: view.gutter
    anchors.topMargin: Style.space(10)
    anchors.bottomMargin: Style.space(8)
    contentWidth: width
    contentHeight: body.implicitHeight + Style.space(12)
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
    onContentHeightChanged: if (following) {
      contentY = Math.max(0, contentHeight - height)
    }

    Column {
      id: body
      width: scroll.width
      spacing: Style.space(10)

      // ------------------------------------------------------- what was said

      Repeater {
        model: view.turns

        Column {
          id: turnBlock
          width: body.width
          spacing: Style.space(3)

          required property var modelData
          required property int index

          readonly property bool newest: index === view.turns.length - 1
          readonly property bool active: String(modelData.state) === "running"
          // Only the newest exchange shows its work. The steps of something
          // that finished four sentences ago are not what anybody scrolls back
          // for; what they said and what came back is.
          readonly property bool detailed: newest
          readonly property var did: modelData.did || []
          readonly property var blocked: modelData.blocked || []

          // What you said. Set apart by a rule down its left rather than by a
          // bubble, because a bubble in a launcher card costs half the width
          // for the same information.
          Row {
            width: parent.width
            spacing: Style.space(8)

            Rectangle {
              width: Style.space(2)
              height: youText.implicitHeight
              radius: 1
              color: Color.accent
              opacity: turnBlock.active ? 1.0 : 0.45
            }

            Text {
              id: youText
              width: Math.max(0, parent.width - Style.space(66))
              text: String(turnBlock.modelData.you || "")
              color: view.launcher.foreground
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.Wrap
              maximumLineCount: turnBlock.detailed ? 3 : 1
              elide: Text.ElideRight
            }

            Text {
              text: turnBlock.active ? view.clock(view.elapsedOf(turnBlock.modelData))
                                     : view.ending(turnBlock.modelData)
              color: turnBlock.active ? Qt.darker(view.launcher.foreground, 2.0)
                                      : view.ended(turnBlock.modelData)
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // Which of the two ran. Only ever drawn on a run that was done here,
          // because the honest claim is the narrow one: this went step by step
          // and nothing decided anything on the way.
          Text {
            visible: turnBlock.modelData.direct === true
            text: turnBlock.active ? "◰  doing this here, no model"
                                   : "◰  done here, no model"
            color: Color.accent
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
            opacity: turnBlock.active ? 1.0 : 0.75
          }

          // What scrolled off, counted rather than dropped.
          Text {
            visible: turnBlock.detailed && Number(turnBlock.modelData.earlier || 0) > 0
            text: "… " + turnBlock.modelData.earlier + " earlier"
            color: Qt.darker(view.launcher.foreground, 2.3)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
          }

          // The last few things it did.
          Repeater {
            model: turnBlock.detailed ? turnBlock.did : []

            Item {
              required property var modelData
              width: body.width
              height: Style.space(19)

              readonly property string kind: String(modelData.kind || "think")
              readonly property string state: String(modelData.state || "did")

              Text {
                id: bullet
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(18)
                text: view.mark(parent.kind, parent.state)
                color: view.tint(parent.kind, parent.state)
                font.family: view.launcher.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                anchors.left: bullet.right
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: String(modelData.text || "")
                color: view.tint(parent.kind, parent.state)
                font.family: view.launcher.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }
          }

          // What it is doing right now. One line, named, with the only
          // animation on this card: a dot that stops when the work does.
          Item {
            visible: turnBlock.active && String(turnBlock.modelData.now || "") !== ""
            width: body.width
            height: Style.space(19)

            Text {
              id: liveDot
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(18)
              text: "●"
              color: Color.accent
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption

              SequentialAnimation on opacity {
                running: turnBlock.active
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 550 }
                NumberAnimation { to: 1.0; duration: 550 }
              }
            }

            Text {
              anchors.left: liveDot.right
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: String(turnBlock.modelData.now || "")
              color: view.launcher.foreground
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          // Starting: a process exists and has not said anything yet. Without
          // this the card is blank for the two seconds an agent takes to wake
          // up, which reads as Enter having done nothing.
          Text {
            visible: turnBlock.active
              && String(turnBlock.modelData.now || "") === ""
              && String(turnBlock.modelData.answer || "") === ""
            text: "starting"
            color: Color.accent
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption

            SequentialAnimation on opacity {
              running: turnBlock.active
              loops: Animation.Infinite
              NumberAnimation { to: 0.25; duration: 500 }
              NumberAnimation { to: 1.0; duration: 500 }
            }
          }

          // Refused, and why.
          Repeater {
            model: turnBlock.blocked

            Column {
              required property var modelData
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

          // What came back.
          Text {
            width: parent.width
            visible: String(turnBlock.modelData.answer || "") !== ""
            text: String(turnBlock.modelData.answer || "")
            color: view.launcher.foreground
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            maximumLineCount: turnBlock.detailed ? 40 : 3
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            visible: String(turnBlock.modelData.note || "") !== ""
            text: String(turnBlock.modelData.note || "")
            color: Color.urgent
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }
        }
      }

      // -------------------------------------------------- what happens next

      Text {
        visible: view.turns.length === 0 && view.phase !== "policy"
        width: parent.width
        text: view.row ? String(view.row.title || "") : ""
        color: view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }

      Text {
        visible: view.phase === "policy"
        width: parent.width
        text: view.row ? String(view.row.title || "") : ""
        color: view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
      }

      // `do: /policy`. Two lines, because "what is this allowed to do on my
      // machine" is a question with a specific answer and the last version of
      // this keyword answered it wrong.
      Column {
        visible: view.phase === "policy"
        width: parent.width
        spacing: Style.space(4)

        Text {
          width: parent.width
          text: "Runs: " + (view.row ? String(view.row.allows || "") : "")
          color: Qt.darker(view.launcher.foreground, 1.5)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
        }
        Text {
          width: parent.width
          text: "Needs a terminal: " + (view.row ? String(view.row.denies || "") : "")
          color: Color.urgent
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          maximumLineCount: 4
          elide: Text.ElideRight
        }
      }

      Column {
        visible: view.hints.length > 0
        width: parent.width
        spacing: Style.space(3)

        Repeater {
          model: view.hints
          Text {
            required property var modelData
            width: body.width
            text: view.phase === "policy" ? String(modelData)
                                          : "do: " + String(modelData)
            color: Qt.darker(view.launcher.foreground, 2.1)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
      }

      // The sentence typed and not yet sent, under everything that came before
      // it, where a chat puts the thing you are writing.
      Row {
        visible: view.draft !== ""
        width: parent.width
        spacing: Style.space(8)

        Rectangle {
          width: Style.space(2)
          height: draftText.implicitHeight
          radius: 1
          color: Color.accent
          opacity: 0.35
        }

        Text {
          id: draftText
          width: Math.max(0, parent.width - Style.space(10))
          text: view.draft
          color: Qt.darker(view.launcher.foreground, 1.4)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
          maximumLineCount: 3
          elide: Text.ElideRight
        }
      }

      // Exactly what Enter will do, in order, on a sentence that has one
      // reading. A list of steps under the sentence is the whole difference
      // between a promise and a guess, and it is drawn before anything runs so
      // that a wrong reading is something you see rather than something you
      // find out afterwards.
      Column {
        visible: view.direct && view.plan.length > 0 && view.phase === "draft"
        width: parent.width
        spacing: Style.space(2)

        Repeater {
          model: view.plan

          Item {
            required property var modelData
            required property int index
            width: body.width
            height: Style.space(17)

            Text {
              id: planMark
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(18)
              text: "◰"
              color: Color.accent
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption
              opacity: 0.8
            }

            Text {
              anchors.left: planMark.right
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: String(parent.modelData)
              color: Qt.darker(view.launcher.foreground, 1.5)
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }
      }

      // ------------------------------------------------------- the last line

      Text {
        width: parent.width
        wrapMode: Text.Wrap
        color: Qt.darker(view.launcher.foreground, 2.0)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        text: {
          if (view.phase === "missing") return ""
          if (view.running) return "Esc stops it"
          if (view.phase === "draft" && view.direct)
            return "↵ does exactly this, here · ⌃K hands it to the agent instead"
          if (view.phase === "draft") return "↵ sends it · ⌃K to run it in a terminal instead"
          if (view.phase === "policy") return "do: /new starts the conversation over"
          if (view.turns.length > 0)
            return (view.row ? String(view.row.agentName || "") + " · " : "")
              + (view.row ? String(view.row.cwd || "") : "")
              + " · keep typing, or do: /new to start over"
          return view.row ? String(view.row.subtitle || "") : ""
        }
      }
    }
  }
}
