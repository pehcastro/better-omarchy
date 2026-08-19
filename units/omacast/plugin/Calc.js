.pragma library

// qalc answers almost anything, which is the problem. `qalc -t firefox` returns
// "0 B", `qalc -t zzz` returns "z^3", and `5 km in miles` returns cubic metres
// because it reads `in` as inches. Its exit code is 0 for all of them, so the
// gate has to be here.

var CONVERSION = /\b(to|in|as)\b/i
var OPERATOR = /[+\-*/^%()]/
var DIGIT = /\d/

// A digit plus either an operator or a conversion word. Both halves matter: "5"
// alone is not a question, and "a + b" is not arithmetic.
function looksLikeMath(text) {
  if (!DIGIT.test(text)) return false
  if (OPERATOR.test(text)) return true
  return CONVERSION.test(text)
}

// qalc reads a lone `in` as inches, so `5 km in miles` comes back as 204387 m³
// and `40 miles in km` as 1635094 m³. Both are wrong with exit code 0, and both
// are how a person writes a conversion. `to` means only one thing to qalc, so
// the word is swapped on the way in. Anything without a digit in front of it is
// left alone, because `3 in` really is three inches.
// The units qalc reads as something else. `c` is the speed of light, `f` is
// farad, `mb` is millibar, `gb` is gram·bel, and every one of them is how a
// person writes the unit they mean. `180f in c` answered 6.00415E-7 c.
var AMBIGUOUS = {
  f: "\u00B0F", "\u00B0f": "\u00B0F", degf: "\u00B0F", fahrenheit: "\u00B0F",
  c: "\u00B0C", "\u00B0c": "\u00B0C", degc: "\u00B0C", celsius: "\u00B0C",
  k: "K", kelvin: "K",
  kb: "kilobyte", mb: "megabyte", gb: "gigabyte", tb: "terabyte", pb: "petabyte",
  kib: "kibibyte", mib: "mebibyte", gib: "gibibyte", tib: "tebibyte",
  kbit: "kilobit", mbit: "megabit", gbit: "gigabit",
  "in": "inch"
}

function canonUnit(token) {
  var full = AMBIGUOUS[String(token).toLowerCase()]
  return full === undefined ? token : full
}

// What to hand qalc. Two rewrites, both only where a conversion is being asked:
//
//   `in` becomes `to`, because qalc reads a lone `in` as inches and answered
//   `40 miles in km` with 1635094 m³, exit code 0.
//
//   an ambiguous unit becomes its full name, on both sides of the `to`.
//
// Neither touches plain arithmetic, and neither touches a query without a
// quantity in front, so `3 in` is still three inches.
function forQalc(text) {
  var out = String(text).replace(/(\d\s*[^\s]*)\s+in\s+(?=[A-Za-z\u00B0])/i, "$1 to ")

  var split = out.match(/^(.*?)\s+to\s+(\S+)\s*$/i)
  if (!split) return out

  var left = split[1].replace(/([\d.]\s*)([A-Za-z\u00B0]+)\s*$/, function (m, num, unit) {
    return num + canonUnit(unit)
  })
  return left + " to " + canonUnit(split[2])
}

function normalize(s) {
  return String(s).replace(/\s+/g, " ").trim()
}

// Reject an answer that only restates the question. qalc echoes its input when
// it does not understand, so this catches most of what the gate above misses.
function isEcho(query, answer) {
  return normalize(query).toLowerCase() === normalize(answer).toLowerCase()
}

function parse(query, stdout) {
  var answer = normalize(stdout)
  if (answer === "" || isEcho(query, answer)) return null

  return {
    key: "calc:" + query,
    providerId: "calc",
    group: "Calculator",
    title: answer,
    subtitle: query,
    accessory: "Copy",
    iconGlyph: "",
    pending: false
  }
}

// Shown the instant a query looks like maths, so Enter cannot launch an app
// while qalc is still thinking. It carries no action; the engine holds Enter
// until the real row replaces it.
function placeholder(query) {
  return {
    key: "calc:" + query,
    providerId: "calc",
    group: "Calculator",
    title: query,
    subtitle: "calculating",
    accessory: "",
    iconGlyph: "",
    pending: true
  }
}
