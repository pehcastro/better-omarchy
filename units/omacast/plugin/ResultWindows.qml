import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The session, drawn as the desktop it describes.
//
// Somebody typing `win:` has lost a window. A flat list answers that with the
// one thing they already knew, the name, and throws away the thing that would
// find it: windows live on workspaces, and a workspace has a place and often a
// name. Sixteen equal rows is a phone book. The same sixteen under three
// headings is a map, and the reader is looking for a place on it.
//
// So the rows keep the script's order, workspace by workspace, and a heading is
// drawn wherever the workspace changes. The workspace you are on takes the
// accent, because "not that one, the other one" is most of what this view is
// asked. The window that currently has focus takes a dot, for the same reason
// in reverse: it is the row worth skipping.
//
// Everything else on a row exists to separate two windows of the same
// application. The icon says which program, the title says which document, and
// the chips say the three ways a window can be somewhere other than where its
// tile is: floating over the layout, filling the screen, or hidden behind
// another tab of the same group. A floating window also shows its size, which
// is the only thing that tells two of them apart when both are called
// "Untitled".
//
// Left and right move a whole workspace at a time, so a long session is walked
// by place rather than by row.
//
// Rows carry:
//   cls wsId wsName wsActive wsWindows special monitor
//   focused floating fullscreen xwayland pinned grouped width height
//   session { windows, matched, workspaces, monitors }
Column {
  // The card cannot hold a view that draws past its own height, and this one
  // computes its height from a row count that a header can invalidate. Clipping
  // at the root is what makes a wrong sum a short answer rather than rows
  // spilling over the footer.
  clip: true
  id: view

  required property var launcher

  // Room left in the card. Set by the launcher; this view only clips to it.
  property int maxHeight: 0

  readonly property var session: launcher.rows.length > 0 && launcher.rows[0].session
    ? launcher.rows[0].session : ({})

  readonly property int gutter: Style.space(18)
  readonly property int summaryHeight: Style.space(30)
  readonly property int headerHeight: Style.space(26)
  readonly property int rowHeight: Style.space(46)
  readonly property int pad: Style.space(8)

  // A second monitor gives every workspace a place as well as a number, and
  // that is the whole point of naming it in the heading. On one screen the
  // name is the same word on every line, so it is not drawn at all.
  readonly property bool manyMonitors: Number(view.session.monitors || 1) > 1
  readonly property bool filtered: Number(view.session.matched || 0)
    < Number(view.session.windows || 0)

  spacing: 0

  // True when this row opens a new workspace run. Runs, not groups: the rows
  // arrive ranked, and ranking can in principle split a workspace in two. A
  // heading drawn twice is honest about that; a heading drawn once above rows
  // that are no longer contiguous would not be.
  function startsGroup(index) {
    var rows = view.launcher.rows
    if (index <= 0 || index >= rows.length) return index === 0
    return String(rows[index - 1].wsId) !== String(rows[index].wsId)
  }

  // Walk the rows adding a heading wherever one falls, and stop at the last row
  // that fits whole. Counting rows and headings separately cannot do this: how
  // many headings there are depends on how many rows fit, and how many rows fit
  // depends on the headings.
  function fits(room) {
    var rows = view.launcher.rows
    var used = 0
    var n = 0
    for (var i = 0; i < rows.length; i++) {
      var step = (view.startsGroup(i) ? view.headerHeight : 0) + view.rowHeight
      if (room >= 0 && used + step > room) break
      used += step
      n += 1
    }
    if (rows.length === 0) return { count: 0, height: 0 }
    // At least one row, even in a card too short for it. A view that answers
    // zero height here is a card that collapses to its own header and looks
    // broken rather than cramped.
    return { count: Math.max(1, n), height: used > 0 ? used : view.rowHeight }
  }

  readonly property var fitted: view.fits(view.maxHeight > 0
    ? view.maxHeight - view.summaryHeight - view.pad * 2 : -1)

  // No implicitHeight here. The root is a Column, which computes its own from
  // its children and refuses the assignment: setting it makes QML reject the
  // whole file, so the view is simply unavailable and the launcher silently
  // falls back to a list. The list below already takes `fitted.height`, so the
  // sum this was trying to state happens anyway.

  // Themed lookup first, because a class is nearly always its own icon name.
  // "dev.zed.Zed" is the case that is not: the reverse-DNS class is the app id
  // and the icon on disk is called "zed", so the last segment is tried too.
  // appLibrary answers last: it never returns nothing, so anything after it
  // would be unreachable.
  function iconFor(cls) {
    var name = String(cls || "")
    if (name === "") return ""

    var found = Quickshell.iconPath(name, true)
    if (found.length > 0) return found

    var lower = name.toLowerCase()
    if (lower !== name) {
      found = Quickshell.iconPath(lower, true)
      if (found.length > 0) return found
    }

    var parts = lower.split(".")
    var tail = parts[parts.length - 1]
    if (tail !== "" && tail !== lower) {
      found = Quickshell.iconPath(tail, true)
      if (found.length > 0) return found
    }

    return view.launcher.appLibrary ? view.launcher.appLibrary.iconSource(name) : ""
  }

  // A numbered workspace reads as a stray digit on its own line. The word in
  // front of it costs nothing and a named workspace does not get one, because
  // "WORKSPACE GENERAL" is the word twice.
  function headingFor(row) {
    var name = String(row.wsName || "")
    if (row.special === true) return name === "" ? "SPECIAL" : "SPECIAL " + name.toUpperCase()
    if (/^\d+$/.test(name)) return "WORKSPACE " + name
    return name.toUpperCase()
  }

  // Left and right jump by workspace. Right goes to the top of the next one;
  // left goes to the top of this one first and only then to the one before, so
  // a press in the middle of a long workspace is never a jump past it.
  function nudge(delta) {
    var rows = view.launcher.rows
    if (rows.length === 0) return
    var here = view.launcher.selectedIndex
    var i

    if (delta > 0) {
      for (i = here + 1; i < rows.length; i++) {
        if (view.startsGroup(i)) return view.launcher.select(i)
      }
      return view.launcher.select(rows.length - 1)
    }

    var start = here
    while (start > 0 && !view.startsGroup(start)) start -= 1
    if (start < here) return view.launcher.select(start)
    for (i = start - 1; i >= 0; i--) {
      if (view.startsGroup(i)) return view.launcher.select(i)
    }
    return view.launcher.select(0)
  }

  // The shape of the session in one line, above everything. Without it a
  // filtered answer looks like the whole desktop, and three headings look like
  // three workspaces when there may be six.
  Item {
    width: view.width
    height: view.summaryHeight

    Text {
      anchors.left: parent.left
      anchors.leftMargin: view.gutter
      anchors.verticalCenter: parent.verticalCenter
      text: {
        var total = Number(view.session.windows || view.launcher.rows.length)
        var matched = Number(view.session.matched || total)
        var noun = matched === 1 ? " window" : " windows"
        if (view.filtered) return matched + " of " + total + noun
        return total + noun
      }
      color: Qt.darker(view.launcher.foreground, 1.8)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      anchors.right: parent.right
      anchors.rightMargin: view.gutter
      anchors.verticalCenter: parent.verticalCenter
      visible: Number(view.session.workspaces || 0) > 0
      text: {
        var n = Number(view.session.workspaces || 0)
        return "on " + n + (n === 1 ? " workspace" : " workspaces")
      }
      color: Qt.darker(view.launcher.foreground, 1.8)
      font.family: view.launcher.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Item {
    width: view.width
    height: view.pad
  }

  ListView {
    id: list
    width: view.width
    height: view.fitted.height
    clip: true
    focus: false
    interactive: true
    currentIndex: view.launcher.selectedIndex
    highlightMoveDuration: 0
    model: view.launcher.rows

    delegate: Column {
      id: entry

      required property var modelData
      required property int index

      readonly property bool selected: index === view.launcher.selectedIndex
      readonly property bool opensGroup: view.startsGroup(index)

      width: list.width
      spacing: 0

      // The workspace, once, above its windows.
      Item {
        width: parent.width
        height: entry.opensGroup ? view.headerHeight : 0
        visible: entry.opensGroup

        Row {
          anchors.left: parent.left
          anchors.leftMargin: view.gutter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(4)
          spacing: Style.space(7)

          // Drawn rather than set in a font: a glyph the user's font is missing
          // is a blank, and this mark is the only thing saying which of these
          // workspaces you are standing on.
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(6)
            height: width
            radius: width / 2
            visible: entry.modelData.wsActive === true
            color: Color.accent
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: view.headingFor(entry.modelData)
            color: entry.modelData.wsActive === true
              ? Color.accent
              : Qt.darker(view.launcher.foreground, 2.1)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.8
          }

          // How many of this workspace's windows are on screen out of how many
          // it holds. Under a query the two differ, and a heading that only
          // counted the matches would read as an empty workspace next door.
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
              var here = 0
              var rows = view.launcher.rows
              for (var i = 0; i < rows.length; i++) {
                if (String(rows[i].wsId) === String(entry.modelData.wsId)) here += 1
              }
              var total = Number(entry.modelData.wsWindows || here)
              return here < total ? here + " of " + total : String(total)
            }
            color: Qt.darker(view.launcher.foreground, 2.6)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: view.gutter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(4)
          visible: view.manyMonitors
          text: String(entry.modelData.monitor || "")
          color: Qt.darker(view.launcher.foreground, 2.6)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      // One window.
      Item {
        width: parent.width
        height: view.rowHeight

        Rectangle {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          anchors.topMargin: Style.space(2)
          anchors.bottomMargin: Style.space(2)
          radius: Style.cornerRadius
          color: entry.selected ? view.launcher.selectedBackground : "transparent"
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: view.launcher.select(entry.index)
          onClicked: view.launcher.activate(entry.modelData)
        }

        // The window you are already in. Worth a mark and not worth a word:
        // it is the one row here that Enter would do nothing useful to.
        Rectangle {
          id: hereDot
          anchors.left: parent.left
          anchors.leftMargin: view.gutter
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(6)
          height: width
          radius: width / 2
          visible: entry.modelData.focused === true
          color: Color.accent
        }

        Image {
          id: icon
          anchors.left: parent.left
          anchors.leftMargin: view.gutter + Style.space(14)
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(22)
          height: width
          fillMode: Image.PreserveAspectFit
          sourceSize.width: width * Screen.devicePixelRatio
          sourceSize.height: height * Screen.devicePixelRatio
          source: view.iconFor(entry.modelData.cls)
        }

        // A class with no icon anywhere, or a shell that has not injected its
        // app library, leaves the row with nothing on the left at all. The
        // extension's own glyph is a poor icon and a fine placeholder.
        Text {
          anchors.centerIn: icon
          visible: String(icon.source) === "" || icon.status === Image.Error
          text: String(entry.modelData.iconGlyph || "")
          color: Qt.darker(view.launcher.foreground, 1.6)
          font.family: view.launcher.fontFamily
          font.pixelSize: Style.font.body
        }

        Column {
          anchors.left: icon.right
          anchors.leftMargin: Style.space(12)
          anchors.right: marks.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            width: parent.width
            text: String(entry.modelData.title || "")
            color: entry.selected ? view.launcher.selectedText : view.launcher.foreground
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }

          // The class, which is what actually distinguishes two windows with
          // the same title, plus the size for a floating one. A tiled window's
          // size is the layout's business and says nothing about the window;
          // a floating one's size is the window itself.
          Text {
            width: parent.width
            text: {
              var m = entry.modelData
              var line = String(m.cls || "")
              if (m.floating === true && Number(m.width || 0) > 0) {
                var geometry = Math.round(Number(m.width)) + " × " + Math.round(Number(m.height))
                line = line === "" ? geometry : line + "  ·  " + geometry
              }
              return line
            }
            color: Qt.darker(view.launcher.foreground, 2.1)
            font.family: view.launcher.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }

        // The ways a window is not simply a tile on this workspace. Every one
        // of these is rare, so the right-hand edge is empty on most rows and a
        // chip there means something when it appears.
        Row {
          id: marks
          anchors.right: parent.right
          anchors.rightMargin: view.gutter
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          Chip {
            anchors.verticalCenter: parent.verticalCenter
            // 1 is maximised inside the gaps, 2 covers the monitor. The second
            // is the one that hides everything else, so it gets the accent.
            visible: Number(entry.modelData.fullscreen || 0) > 0
            text: Number(entry.modelData.fullscreen || 0) >= 2 ? "fullscreen" : "maximised"
            accented: Number(entry.modelData.fullscreen || 0) >= 2
            foreground: view.launcher.foreground
            fontFamily: view.launcher.fontFamily
          }

          Chip {
            anchors.verticalCenter: parent.verticalCenter
            visible: entry.modelData.floating === true
            text: "floating"
            foreground: view.launcher.foreground
            fontFamily: view.launcher.fontFamily
          }

          // A tab group draws as one window. Focusing this row swaps which of
          // them is visible, which is a surprise unless the row says so first.
          Chip {
            anchors.verticalCenter: parent.verticalCenter
            visible: Number(entry.modelData.grouped || 0) > 1
            text: Number(entry.modelData.grouped || 0) + " tabs"
            foreground: view.launcher.foreground
            fontFamily: view.launcher.fontFamily
          }

          // A pinned window follows you everywhere, so the workspace it is
          // filed under here is the least true fact on its row.
          Chip {
            anchors.verticalCenter: parent.verticalCenter
            visible: entry.modelData.pinned === true
            text: "pinned"
            foreground: view.launcher.foreground
            fontFamily: view.launcher.fontFamily
          }

          Chip {
            anchors.verticalCenter: parent.verticalCenter
            visible: entry.modelData.xwayland === true
            text: "x11"
            foreground: view.launcher.foreground
            fontFamily: view.launcher.fontFamily
          }
        }
      }
    }
  }

  Item {
    width: view.width
    height: view.pad
  }
}
