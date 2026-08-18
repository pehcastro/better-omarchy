import QtQuick
import qs.Commons
import qs.Ui

// One answer, large. A sum, a conversion, a track that is playing right now:
// things where there is exactly one result and reading it is the whole point,
// so a 44px row wastes the space and makes you squint.
//
// Anything after the first result still lists underneath, because "3 metres"
// is the answer but "convert to feet" might be the next thing you want.
Column {
  id: view

  required property var launcher

  readonly property var hero: launcher.rows.length > 0 ? launcher.rows[0] : null
  readonly property var rest: launcher.rows.slice(1)

  spacing: 0

  Item {
    width: view.width
    height: Style.space(120)
    visible: view.hero !== null

    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.space(8)
      radius: Style.cornerRadius
      color: view.launcher.selectedBackground
    }

    Image {
      id: art
      visible: String((view.hero && view.hero.art) || "") !== ""
      source: (view.hero && view.hero.art) || ""
      width: Style.space(84)
      height: Style.space(84)
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: width * Screen.devicePixelRatio
      sourceSize.height: height * Screen.devicePixelRatio
      anchors.left: parent.left
      anchors.leftMargin: Style.space(24)
      anchors.verticalCenter: parent.verticalCenter

      layer.enabled: true
      layer.effect: null
    }

    Column {
      anchors.left: art.visible ? art.right : parent.left
      anchors.leftMargin: Style.space(24)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(24)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      Text {
        width: parent.width
        text: String((view.hero && view.hero.title) || "")
        color: view.launcher.foreground
        font.family: view.launcher.fontFamily
        // A short answer gets the big treatment. A long one steps down rather
        // than eliding, because "3.2808 feet" and a track title are both heroes
        // and only one of them fits at display size.
        font.pixelSize: text.length > 28 ? Style.font.title : Style.font.displayLarge
        font.bold: true
        elide: Text.ElideRight
        opacity: (view.hero && view.hero.pending) ? 0.4 : 1
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: String((view.hero && view.hero.subtitle) || "")
        color: Qt.darker(view.launcher.foreground, 1.5)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: String((view.hero && view.hero.detail) || "")
        color: Qt.darker(view.launcher.foreground, 1.9)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: view.launcher.activate(view.hero)
    }
  }

  // A progress bar, when the row carries one. Zero to one.
  Item {
    width: view.width
    height: visible ? Style.space(14) : 0
    visible: view.hero !== null && view.hero.progress !== undefined

    Rectangle {
      id: track
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: Style.space(24)
      anchors.rightMargin: Style.space(24)
      anchors.verticalCenter: parent.verticalCenter
      height: Style.space(3)
      radius: height / 2
      color: Qt.rgba(view.launcher.foreground.r, view.launcher.foreground.g, view.launcher.foreground.b, 0.15)
    }

    Rectangle {
      anchors.left: track.left
      anchors.verticalCenter: track.verticalCenter
      height: track.height
      radius: track.radius
      width: track.width * Math.max(0, Math.min(1, Number((view.hero && view.hero.progress) || 0)))
      color: Color.accent
    }
  }

  ListView {
    id: tail
    width: view.width
    height: Math.min(count, view.launcher.maxRows - 2) * Style.space(40)
    visible: count > 0
    clip: true
    focus: false
    // Index 0 is the hero, so the list underneath is offset by one.
    currentIndex: view.launcher.selectedIndex - 1
    highlightMoveDuration: 0
    model: view.rest

    delegate: Item {
      required property var modelData
      required property int index

      width: tail.width
      height: Style.space(40)

      readonly property bool selected: (index + 1) === view.launcher.selectedIndex

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        radius: Style.cornerRadius
        color: parent.selected ? view.launcher.selectedBackground : "transparent"
      }

      MouseArea {
        anchors.fill: parent
        onClicked: view.launcher.activate(modelData)
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(24)
        anchors.right: hint.left
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        text: String(modelData.title || "")
        color: parent.selected ? view.launcher.selectedText : view.launcher.foreground
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        id: hint
        anchors.right: parent.right
        anchors.rightMargin: Style.space(24)
        anchors.verticalCenter: parent.verticalCenter
        text: String(modelData.subtitle || "")
        color: Qt.darker(view.launcher.foreground, 1.7)
        font.family: view.launcher.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        width: Math.min(implicitWidth, tail.width * 0.4)
      }
    }
  }
}
