.pragma library

// An extension's own colour, made safe to put on a user's theme.
//
// Spotify green and kill red are worth having: they name the source faster than
// any word does. But an extension author picks a colour against their own
// screenshot, not against the theme you happen to be running, and a launcher
// that lets a JSON file render its own rows unreadable has handed a stranger
// control of your contrast.
//
// So a declared accent is a request, not an instruction. It is checked against
// the card it will actually sit on, walked toward legibility if it fails, and
// dropped for the theme's own accent if it cannot get there.

// 3.0 is the WCAG bar for large and non-body text, which is what an accent is
// used for here: a chip, a glyph, a border. Body text is never accented.
var MIN_CONTRAST = 3.0

// How far one nudge moves the colour toward the light or dark end. Small enough
// that a colour needing only a little help keeps its hue.
var STEP = 0.12
var MAX_STEPS = 8

// #rgb, #rrggbb, or a bare rrggbb. Anything else is not a colour we can reason
// about, and guessing at a name would put us back to trusting the file.
function parse(text) {
  var raw = String(text || "").trim().replace(/^#/, "")

  if (/^[0-9a-f]{3}$/i.test(raw)) {
    return {
      r: parseInt(raw.charAt(0) + raw.charAt(0), 16) / 255,
      g: parseInt(raw.charAt(1) + raw.charAt(1), 16) / 255,
      b: parseInt(raw.charAt(2) + raw.charAt(2), 16) / 255
    }
  }
  if (/^[0-9a-f]{6}$/i.test(raw)) {
    return {
      r: parseInt(raw.substr(0, 2), 16) / 255,
      g: parseInt(raw.substr(2, 2), 16) / 255,
      b: parseInt(raw.substr(4, 2), 16) / 255
    }
  }
  return null
}

function channel(value) {
  return value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
}

function luminance(c) {
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
}

function contrast(a, b) {
  var high = Math.max(luminance(a), luminance(b))
  var low = Math.min(luminance(a), luminance(b))
  return (high + 0.05) / (low + 0.05)
}

function mix(c, target, amount) {
  return {
    r: c.r + (target - c.r) * amount,
    g: c.g + (target - c.g) * amount,
    b: c.b + (target - c.b) * amount
  }
}

// Walk the colour away from the background until it reads, then stop. Moving
// toward white on a dark card and toward black on a light one is the only
// direction that can ever help: the other one converges on the background.
function readable(accent, background, fallback) {
  if (!accent) return fallback
  if (contrast(accent, background) >= MIN_CONTRAST) return accent

  var toward = luminance(background) < 0.5 ? 1 : 0
  var walked = accent

  for (var i = 0; i < MAX_STEPS; i++) {
    walked = mix(walked, toward, STEP)
    if (contrast(walked, background) >= MIN_CONTRAST) return walked
  }

  // A colour that cannot reach the bar even at the end of that walk is one the
  // theme should be picking, not the extension.
  return fallback
}
