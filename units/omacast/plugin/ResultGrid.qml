import QtQuick
import qs.Commons
import qs.Ui

// A grid of thumbnails with the selected one's details underneath.
//
// For results you pick by looking rather than by reading. A list of forty
// filenames tells you nothing about which picture is which; four rows of
// thumbnails answers it at a glance, and the strip below carries the facts a
// thumbnail cannot show.
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

  readonly property var current: launcher.rows.length > launcher.selectedIndex
    ? launcher.rows[launcher.selectedIndex] : null

  // Big enough to tell one screenshot from another. A thumbnail you have to
  // squint at is just a filename with extra steps. This is the smallest a cell
  // may be, not the size it ends up: the row is divided by however many fit,
  // so the last column reaches the edge instead of leaving a gutter.
  readonly property int minCell: Style.space(150)
  readonly property int gutter: Style.space(12)
  readonly property int inner: Math.max(1, width - gutter * 2)
  readonly property int columns: Math.max(1, Math.floor(inner / minCell))
  readonly property int cellSize: Math.floor(inner / columns)
  // Pictures are wider than they are tall far more often than not, so a square
  // cell spends its height on empty background above and below every one.
  readonly property int cellHeight: Math.round(view.cellSize * 0.78)

  spacing: 0

  // The rows of the moment, by key, so a delegate can find its own row without
  // the model holding it. See sync() for why the model holds only keys.
  property var rowIndex: ({})

  // Keys in display order. This is the model, and it is deliberately not the
  // launcher's row array.
  //
  // The launcher rebuilds `rows` from scratch on every keystroke: a new array
  // of new objects, even when the same files matched. A GridView bound to a JS
  // array cannot tell that apart from a different result set, so it destroys
  // every delegate and builds new ones. A new delegate's Image starts empty and
  // loads again, and the whole grid blinks under each letter typed.
  //
  // Holding keys and moving them lets an unchanged picture keep the delegate it
  // already had, and a picture that keeps its delegate keeps its pixels.
  ListModel { id: shown }

  function sync() {
    var rows = view.launcher.rows || []
    var map = ({})
    var keys = []
    for (var i = 0; i < rows.length; i++) {
      // A row from an extension has no `key` of its own, so the id stands in.
      // The index is the last resort and also the tie-break: two rows sharing
      // an id would otherwise collapse into one delegate and lose a picture.
      var k = String(rows[i].key || rows[i].id || i)
      if (k in map) k = k + "#" + i
      map[k] = rows[i]
      keys.push(k)
    }
    view.rowIndex = map

    // What left, removed from the back so the indices ahead stay valid.
    for (var j = shown.count - 1; j >= 0; j--) {
      if (!(shown.get(j).rowKey in map)) shown.remove(j)
    }

    // Then the wanted order, by moving what is already here rather than
    // replacing it.
    for (var n = 0; n < keys.length; n++) {
      if (n >= shown.count) { shown.append({ rowKey: keys[n] }); continue }
      if (shown.get(n).rowKey === keys[n]) continue
      var at = -1
      for (var m = n + 1; m < shown.count; m++) {
        if (shown.get(m).rowKey === keys[n]) { at = m; break }
      }
      if (at >= 0) shown.move(at, n, 1)
      else shown.insert(n, { rowKey: keys[n] })
    }
    while (shown.count > keys.length) shown.remove(shown.count - 1)
  }

  Component.onCompleted: view.sync()

  Connections {
    target: view.launcher
    function onRowsChanged() { view.sync() }
  }

  GridView {
    id: grid
    width: view.width
    // Three rows of pictures is a grid; two is a strip. The cap is on rows
    // rather than pixels because a half-drawn row of thumbnails reads as a
    // rendering fault.
    height: Math.min(Math.ceil(shown.count / view.columns), 3) * view.cellHeight + Style.space(8)
    leftMargin: view.gutter
    rightMargin: view.gutter
    topMargin: Style.space(4)
    cellWidth: view.cellSize
    cellHeight: view.cellHeight
    clip: true
    focus: false
    currentIndex: view.launcher.selectedIndex
    highlightMoveDuration: 0
    model: shown

    delegate: Item {
      required property string rowKey
      required property int index

      readonly property var modelData: view.rowIndex[rowKey] || null

      width: grid.cellWidth
      height: grid.cellHeight

      readonly property bool selected: index === view.launcher.selectedIndex

      Rectangle {
        anchors.fill: parent
        anchors.margins: Style.space(3)
        radius: Style.cornerRadius
        color: parent.selected ? view.launcher.selectedBackground : "transparent"
        border.width: parent.selected ? Math.max(1, Style.space(2)) : 0
        border.color: Color.accent
        z: 2
      }

      Image {
        anchors.fill: parent
        anchors.margins: Style.space(4)
        // Reads the same string on every rebuild of the row object, so an
        // unchanged file never reloads.
        source: parent.modelData
          ? String(parent.modelData.art || parent.modelData.iconSource || "")
          : ""
        // Filled, not fitted. A fitted thumbnail leaves a band of background on
        // two sides of every picture, and fifteen of those turn a grid into a
        // scatter of floating rectangles with no shared edges to read along.
        fillMode: Image.PreserveAspectCrop
        clip: true
        // Thumbnails are the whole point here, so they load off the main thread
        // and at the size they are drawn rather than full resolution.
        asynchronous: true

        // Not cached. Qt keeps every decoded image by URL for the life of the
        // process, and these are thumbnails of a picture from one search:
        // the odds of drawing this exact file again are low and the cost of
        // holding it is permanent. Ten queries over a home directory retained
        // 30MB that never came back, while keywords that draw no images
        // retained nothing at all.
        cache: false
        sourceSize.width: view.cellSize * Screen.devicePixelRatio
        sourceSize.height: view.cellHeight * Screen.devicePixelRatio
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: view.launcher.select(index)
        onClicked: {
          if (parent.modelData) view.launcher.activate(parent.modelData)
        }
      }
    }
  }

  // What the thumbnail cannot tell you: the name, where it lives, how big it is.
  Item {
    width: view.width
    height: view.current ? Style.space(46) : 0
    visible: view.current !== null

    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: Math.max(1, Style.space(1))
      color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g, view.launcher.foreground.b, 0.08)
    }

    Column {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(20)
      anchors.right: meta.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        width: parent.width
        text: String((view.current && view.current.title) || "")
        color: view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: String((view.current && view.current.subtitle) || "")
        color: Qt.darker(view.launcher.foreground, 1.9)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Row {
      id: meta
      anchors.right: parent.right
      anchors.rightMargin: Style.space(20)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      Chip {
        anchors.verticalCenter: parent.verticalCenter
        text: String((view.current && view.current.detail) || "")
        foreground: view.launcher.foreground
        fontFamily: view.launcher.fontFamily
      }

      Chip {
        anchors.verticalCenter: parent.verticalCenter
        text: String((view.current && view.current.accessory) || "")
        foreground: view.launcher.foreground
        fontFamily: view.launcher.fontFamily
      }
    }
  }
}
