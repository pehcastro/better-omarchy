import QtQuick
import qs.Commons

// The shape of a reading that has not arrived yet.
//
// Several views answer in two beats: the cheap facts come back in tens of
// milliseconds and one expensive number follows a second or two later.
// `docker:` is the loud case, where `docker stats` costs a second and the
// sampler that runs it is detached so the list can draw without it. Whatever
// waits for that number draws nothing in the meantime, and nothing is the one
// thing that reads as finished. An empty meter track with no figure beside it
// looks like a container doing nothing, not like a container not yet measured.
//
// So the gap gets a placeholder the size and position of the value that is
// coming. Set a width, a height and a radius; that is the whole contract. It
// knows nothing about what the value will be, which is the point: every view
// with a slow field has this problem and none of them should own its own
// answer to it.
//
// It breathes, and only just. ResultLoading is deliberately still and says so,
// for a good reason: a whole card of placeholders that never stops moving
// cannot be watched for stillness, and the recorder that waits for an answer to
// settle would sit through the timeout on every query. This is the other case.
// One or two small blocks inside an otherwise finished tile, on screen for
// about as long as one breath, where stillness would be indistinguishable from
// a value of nothing. The cycle is slow on purpose: at 1800ms a tile is
// noticeably alive without any tile ever snapping, and a grid of twelve of them
// reads as one surface waiting rather than twelve things flashing.
//
// `running` is there so a caller that must hold a frame still can stop it.
Rectangle {
  id: skeleton

  // Whose colour this is drawn from. The launcher's foreground, normally, so a
  // placeholder sits at the same weight as the faint surfaces around it.
  property color tint: Color.menu.text

  property bool running: true

  radius: height / 2

  // Faint enough to be a hole in the layout rather than an element in it. The
  // pulse below carries the meaning; the fill only gives it somewhere to
  // happen.
  color: Qt.rgba(skeleton.tint.r, skeleton.tint.g, skeleton.tint.b, 0.11)

  // Both halves of the cycle are eased, so there is no moment where the block
  // changes direction sharply. A linear fade is what makes a placeholder look
  // like it is blinking at you.
  SequentialAnimation on opacity {
    running: skeleton.running && skeleton.visible
    loops: Animation.Infinite
    NumberAnimation { from: 1.0; to: 0.4; duration: 900; easing.type: Easing.InOutSine }
    NumberAnimation { from: 0.4; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
  }
}
