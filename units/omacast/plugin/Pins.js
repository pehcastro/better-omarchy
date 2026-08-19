.pragma library

// A row you pinned leads every query it matches.
//
// Frecency guesses what you want from what you have used. A pin is you saying
// it outright, so it has to beat the guess: the two are the same kind of lift,
// applied to the same row key, and the pin is simply bigger.

// The lift, in `local` points, against Frecency.MAX_BOOST of 9000. A pin at
// 20000 always wins that argument inside a tier, and the clamp below keeps it
// from ever winning across one: a tier is 100000 wide, so a name that starts
// with what you typed still beats a pinned substring, exactly as frecency does.
var BOOST = 20000

var TIER_WIDTH = 100000

function has(pins, key) {
  return !!(pins && key && pins[key] === true)
}

function toggle(pins, key) {
  var next = {}
  for (var existing in pins) next[existing] = pins[existing]

  if (next[key] === true) delete next[key]
  else next[key] = true

  return next
}

// Rows are reused between rebuilds, so `pinned` is written on every row rather
// than only on the pinned ones: set once and never cleared, a star would stay
// on a row after the pin came off.
function apply(rows, pins) {
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    if (!row.key) continue

    row.pinned = has(pins, row.key)
    if (!row.pinned) continue

    // Clamped to the top of the row's own tier. Adding blindly would push a
    // high `local` past the tier boundary, which is the one thing a lift inside
    // a tier must never do.
    var tier = Math.floor(row.score / TIER_WIDTH)
    row.score = Math.min(tier * TIER_WIDTH + (TIER_WIDTH - 1), row.score + BOOST)
  }
  return rows
}

function parse(text) {
  if (!text) return {}

  var data = null
  try {
    data = JSON.parse(text)
  } catch (e) {
    return {}
  }
  if (!data || !data.pins || typeof data.pins !== "object") return {}

  var out = {}
  for (var key in data.pins) {
    if (data.pins[key] === true) out[key] = true
  }
  return out
}
