import QtQuick
import qs.Commons
import qs.Ui

// Level three of `bo:`: one unit, and the one decision you make about it.
//
// The first version of this page was eight lines at the same size, the same
// weight and the same left edge, with three lines of metadata standing in front
// of the only sentence that says what the thing does. Nothing was first, the
// right half of every row was empty, and it ended in three grey lines that all
// looked alike.
//
// What this does instead:
//
// A panel at the top holds the name, the sentence, the switch and what flipping
// it will cost. That block is the page: it is the only thing with a fill, so
// the eye lands on it before reading anything, and it puts the decision and the
// consequence of the decision in one place instead of at opposite ends. The
// summary sits directly under the name at body size and the highest contrast on
// the page, because it is the only line a person actually needs.
//
// Under it the provenance is a strip of cells across the full width, each a
// small quiet label with its value beneath: version, kind, category, author,
// then what the unit claims and needs. Four narrow cells to a row, two wide
// ones for the lists. That is what fills 780px; a label column and a value
// column left the right two thirds of every row empty.
//
// Colour is spent twice and no more. The accent is the state, on the switch and
// on the word beside it, and nothing else on the page is accented. Urgent is
// the warning colour: a `needs` line this machine cannot satisfy, and the panel
// naming what the unit will run when it is not yet installed. The runs-code
// block is tinted rather than listed, because it is a warning and the facts
// around it are not.
//
// Nothing here has a border, an edge or a rule.
//
// Rows: index 0 is the way back and carries the whole page; index 1 is the
// switch. Two rows, so arriving selects the way out and the switch is one Down
// away, which is the whole of the interaction.
Item {
  // The card cannot hold a view that draws past its own height. Clipping at the
  // root is what makes a wrong sum a short answer rather than text spilling over
  // the footer and onto the wallpaper.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property var rows: launcher.rows

  // Rows are found by what they are, never by where they are. The launcher is
  // free to reorder them and does: Frecency.js adds up to 9000 to a row the
  // user has activated, so one press of the switch lifted it above the way-out
  // row and everything that read rows[0] was then reading the wrong one. The
  // page drew the switch as its header and the switch stopped being selectable,
  // which is the same defect showing up twice.
  function indexOfPart(want) {
    for (var i = 0; i < view.rows.length; i++) {
      if (String(view.rows[i].part || "") === want) return i
    }
    return -1
  }

  readonly property int backIndex: view.indexOfPart("back")
  readonly property int switchIndex: view.indexOfPart("switch")

  readonly property var row: view.backIndex >= 0 ? view.rows[view.backIndex]
    : (view.rows.length > 0 ? view.rows[0] : null)
  readonly property bool switchSelected: view.switchIndex >= 0
    && launcher.selectedIndex === view.switchIndex

  readonly property int pad: Style.space(16)
  readonly property int inner: Math.max(1, view.width - view.pad * 2)
  readonly property int gap: Style.space(11)

  readonly property string unitState: view.row ? String(view.row.state || "off") : "off"
  readonly property bool isOn: view.unitState === "on"
  readonly property bool blocked: view.unitState === "unavailable"
  // The unit that ships this launcher, and a unit whose needs are not met, both
  // have a state to show and no switch to offer.
  readonly property bool lockedOut: view.blocked || (view.row !== null && view.row.self === true)
  readonly property bool queuedToggle: view.row !== null && view.row.queued === true

  // On is the foreground at full strength, off is the same colour at 42%, and
  // unavailable is the warning hue. The accent is not here: it belongs to the
  // cursor now, and a page where the state and the focus are the same colour is
  // a page where neither means anything.
  readonly property color stateColor: view.blocked ? Color.urgent
    : view.isOn ? view.launcher.foreground : view.faint(0.42)

  readonly property var facts: (view.row && view.row.facts) ? view.row.facts : []
  readonly property var claims: (view.row && view.row.claims) ? view.row.claims : []
  readonly property var runsLines: (view.row && view.row.runsLines) ? view.row.runsLines : []

  function faint(alpha) {
    return Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g,
                   view.launcher.foreground.b, alpha)
  }

  // ------------------------------------------------------------ the budget
  //
  // Predicted heights, always at or above what the block really draws, used
  // only to decide what fits. Measuring the real thing and then hiding it would
  // be a binding loop; over-estimating costs a block that would just have
  // squeezed in and buys a page that never ends mid-sentence.
  readonly property int lineCap: Math.round(Style.font.caption * 1.5)
  readonly property int lineSmall: Math.round(Style.font.bodySmall * 1.45)
  readonly property int lineBody: Math.round(Style.font.body * 1.5)

  readonly property int hBack: Style.space(26)
  readonly property int hPanel: Style.space(15) * 2 + Math.round(Style.font.title * 1.4)
    + Style.space(5) + view.lineBody * 2 + Style.space(12) + Style.space(26)
    + Style.space(5) + view.lineCap
  readonly property int hFactRow: view.lineCap + Style.space(2) + view.lineSmall
  readonly property int hClaims: view.claims.length > 0
    ? Math.ceil(view.claims.length / 2) * view.hFactRow
      + (Math.ceil(view.claims.length / 2) - 1) * Style.space(7) : 0
  readonly property int hRuns: view.runsLines.length > 0
    ? Style.space(11) * 2 + Style.space(20) + Style.space(3)
      + view.runsLines.length * view.lineCap : 0
  readonly property int hPath: view.lineCap

  readonly property int room: (view.maxHeight > 0 ? view.maxHeight : 100000) - view.pad * 2

  // Kept longest to dropped first. The panel is the page and never goes. What
  // the unit runs is a warning, so it outranks every fact. What it claims and
  // needs outranks where it came from, and the two quietest lines at the bottom
  // are the two that go first.
  readonly property int usedBase: view.hBack + view.gap + view.hPanel
  readonly property bool showRuns: view.hRuns > 0
    && view.usedBase + view.gap + view.hRuns <= view.room
  readonly property int usedRuns: view.usedBase
    + (view.showRuns ? view.gap + view.hRuns : 0)
  readonly property bool showClaims: view.hClaims > 0
    && view.usedRuns + view.gap + view.hClaims <= view.room
  readonly property int usedClaims: view.usedRuns
    + (view.showClaims ? view.gap + view.hClaims : 0)

  // The facts grid gives up a row at a time rather than all at once, and the
  // cells are ordered so the row that goes first is the one carrying the commit
  // and the file count. A page that loses its provenance is still a page; one
  // that loses what the unit needs is not.
  readonly property int factRowsWanted: Math.ceil(view.facts.length / 4)
  readonly property int factRowsShown: {
    if (view.facts.length === 0) return 0
    var left = view.room - view.usedClaims - view.gap
    if (left < view.hFactRow) return 0
    return Math.max(0, Math.min(view.factRowsWanted,
      1 + Math.floor((left - view.hFactRow) / (view.hFactRow + Style.space(7)))))
  }
  readonly property int usedFacts: view.usedClaims
    + (view.factRowsShown > 0
       ? view.gap + view.factRowsShown * view.hFactRow
         + (view.factRowsShown - 1) * Style.space(7) : 0)

  readonly property bool showPath: view.usedFacts + view.gap + view.hPath <= view.room

  implicitHeight: view.row ? view.pad * 2 + page.height : 0

  Column {
    id: page
    x: view.pad
    y: view.pad
    width: view.inner
    spacing: view.gap

    // ----------------------------------------------------------- the way out
    MarketplaceBack {
      launcher: view.launcher
      label: view.row ? String(view.row.backLabel || "") : ""
      selected: view.backIndex >= 0
        && view.launcher.selectedIndex === view.backIndex
      width: page.width
    }

    // ------------------------------------------------------------ the panel
    Rectangle {
      id: panel
      width: page.width
      height: block.height + Style.space(15) * 2
      radius: Style.cornerRadius
      // The one fill on the page, and the reason the eye lands here first. No
      // border: a filled shape is already a shape.
      color: view.faint(0.05)

      Column {
        id: block
        x: Style.space(15)
        y: Style.space(15)
        width: panel.width - Style.space(30)
        spacing: Style.space(5)

        Text {
          width: parent.width
          text: view.row ? String(view.row.title || "") : ""
          color: view.launcher.foreground
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          elide: Text.ElideRight
        }

        // The only line anybody needs, at the highest contrast on the page and
        // the only text above caption size apart from the name.
        Text {
          width: parent.width
          text: view.row ? String(view.row.subtitle || "") : ""
          color: view.faint(0.78)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
          maximumLineCount: 2
          elide: Text.ElideRight
          lineHeight: 1.3
        }

        // -------------------------------------------------------- the switch
        Item {
          id: control
          width: parent.width
          height: Style.space(38)

          // The hit area is the control and its word, not the width of the
          // row: hovering anywhere along an empty line should not move the
          // cursor onto a switch.
          MouseArea {
            x: 0
            y: Style.space(6)
            width: stateWord.x + stateWord.width + Style.space(6)
            height: Style.space(32)
            hoverEnabled: true
            onEntered: if (view.switchIndex >= 0) view.launcher.select(view.switchIndex)
            onClicked: if (view.switchIndex >= 0) view.launcher.activate(view.rows[view.switchIndex])
          }

          // The focus hugs the control instead of filling the row behind it.
          // A halo rather than an outline, because an outline on a switch that
          // already sits on the panel fill is a third edge in eight pixels.
          Rectangle {
            x: track.x - Style.space(5)
            y: track.y - Style.space(5)
            width: track.width + Style.space(10)
            height: track.height + Style.space(10)
            radius: height / 2
            visible: view.switchSelected
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
          }

          Rectangle {
            id: track
            y: Style.space(12)
            width: Style.space(42)
            height: Style.space(22)
            radius: height / 2
            // Grey until the cursor is on it, then the accent. The colour says
            // where you are, not what the unit is: which way the knob is
            // sitting says that, and the word beside it says it in letters.
            // Spending the accent on the state meant the switch was already
            // lit before anyone had moved to it, so arriving looked the same
            // as aiming.
            color: view.blocked
              ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.16)
              : view.switchSelected
                ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.34)
                : view.faint(0.13)

            Rectangle {
              id: knob
              width: Style.space(16)
              height: width
              radius: width / 2
              y: Math.round((track.height - height) / 2)
              x: view.isOn ? track.width - width - Style.space(3) : Style.space(3)
              visible: !view.blocked
              color: view.switchSelected ? Color.accent
                   : view.isOn ? view.faint(0.55) : view.faint(0.34)

              // The knob slides because a toggle that applies at once needs
              // something on screen saying the press was the cause, and a
              // queued one needs to show where it is going to end up.
              Behavior on x {
                NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
              }
            }

            // A unit this machine cannot run has a state and no switch. The
            // track stays so the page keeps its shape, and the mark says there
            // is nothing to press rather than leaving an empty slot.
            Text {
              anchors.centerIn: parent
              visible: view.blocked
              text: "✕"
              color: Color.urgent
              font.family: view.launcher.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          Text {
            id: stateWord
            anchors.left: track.right
            anchors.leftMargin: Style.space(11)
            anchors.verticalCenter: track.verticalCenter
            text: view.unitState.toUpperCase()
            color: view.stateColor
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            font.letterSpacing: 1.0
          }

          // How to work it, and only while it is not the thing selected. Once
          // the switch has the cursor the launcher footer already says what
          // Enter does, and saying it twice is how a page starts repeating
          // itself at the reader.
          Text {
            anchors.left: stateWord.right
            anchors.leftMargin: Style.space(14)
            anchors.baseline: stateWord.baseline
            visible: !view.switchSelected && !view.lockedOut
            text: "↓ then ↵ to change"
            color: view.faint(0.30)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        // What flipping it costs, under the thing that flips it.
        Text {
          width: parent.width
          text: view.row ? String(view.row.consequence || "") : ""
          color: view.blocked ? Color.urgent : view.faint(0.44)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }
      }
    }

    // -------------------------------------------------------- what it runs
    Rectangle {
      width: page.width
      height: runsBlock.height + Style.space(11) * 2
      radius: Style.cornerRadius
      visible: view.showRuns
      // Tinted, so it reads as a different kind of thing from the cells above
      // it. Urgent while the unit is off, because that is the moment somebody
      // is deciding whether to let it run; neutral once it is already running,
      // when the same words are a description rather than a warning.
      color: view.isOn ? view.faint(0.04)
        : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.07)

      Column {
        id: runsBlock
        x: Style.space(11)
        y: Style.space(11)
        width: parent.width - Style.space(22)
        spacing: Style.space(3)

        MarketplaceLabel {
          launcher: view.launcher
          label: "runs code on this machine"
          width: parent.width
        }

        Repeater {
          model: view.showRuns ? view.runsLines : []

          delegate: Text {
            required property var modelData

            width: runsBlock.width
            text: String(modelData)
            color: view.isOn ? view.faint(0.50)
              : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.85)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
      }
    }

    // ------------------------------------------------------ what it claims
    Column {
      width: parent.width
      spacing: Style.space(7)
      visible: view.showClaims

      Repeater {
        model: view.showClaims ? Math.ceil(view.claims.length / 2) : 0

        delegate: Row {
          id: claimRow

          required property int index

          width: page.width
          spacing: Style.space(14)

          Repeater {
            model: 2

            delegate: Item {
              id: claimCell

              required property int index

              readonly property var cell:
                view.claims[claimRow.index * 2 + claimCell.index] || null

              width: Math.floor((page.width - Style.space(14)) / 2)
              height: view.hFactRow

              Text {
                id: claimLabel
                width: claimCell.width
                visible: claimCell.cell !== null
                text: claimCell.cell ? String(claimCell.cell.label || "").toUpperCase() : ""
                color: view.faint(0.24)
                font.family: view.launcher.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 0.7
              }

              Text {
                anchors.top: claimLabel.bottom
                anchors.topMargin: Style.space(2)
                width: claimCell.width
                visible: claimCell.cell !== null
                text: claimCell.cell ? String(claimCell.cell.value || "") : ""
                // The one fact that stops the decision keeps its hue.
                color: (claimCell.cell && claimCell.cell.urgent === true)
                  ? Color.urgent : view.faint(0.72)
                font.family: view.launcher.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }
          }
        }
      }
    }

    // ------------------------------------------------------- where it came
    Column {
      width: parent.width
      spacing: Style.space(7)
      visible: view.factRowsShown > 0

      Repeater {
        model: view.factRowsShown

        delegate: Row {
          id: factRow

          required property int index

          width: page.width
          spacing: Style.space(14)

          Repeater {
            model: 4

            delegate: Item {
              id: factCell

              required property int index

              readonly property var cell:
                view.facts[factRow.index * 4 + factCell.index] || null

              width: Math.floor((page.width - Style.space(42)) / 4)
              height: view.hFactRow

              Text {
                id: factLabel
                width: factCell.width
                visible: factCell.cell !== null
                text: factCell.cell ? String(factCell.cell.label || "").toUpperCase() : ""
                color: view.faint(0.24)
                font.family: view.launcher.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 0.7
              }

              Text {
                anchors.top: factLabel.bottom
                anchors.topMargin: Style.space(2)
                width: factCell.width
                visible: factCell.cell !== null
                text: factCell.cell ? String(factCell.cell.value || "") : ""
                color: view.faint(0.72)
                font.family: view.launcher.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }
          }
        }
      }
    }

    // ---------------------------------------------------------- the address
    //
    // One line, the quietest thing on the page, and the first to go when the
    // card runs out of room. Where the unit lives is worth knowing and is
    // never why anybody came here.
    Text {
      width: parent.width
      visible: view.showPath
      text: view.row ? String(view.row.path || "") : ""
      color: view.faint(0.18)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideLeft
    }
  }
}
