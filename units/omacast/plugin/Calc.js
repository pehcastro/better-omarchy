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
var DATA_UNITS = {
  kb: "kilobyte", mb: "megabyte", gb: "gigabyte", tb: "terabyte", pb: "petabyte",
  kib: "kibibyte", mib: "mebibyte", gib: "gibibyte", tib: "tebibyte",
  kbit: "kilobit", mbit: "megabit", gbit: "gigabit"
}

function forQalc(text) {
  var out = String(text).replace(/(\d\s*[^\s]*)\s+in\s+(?=[A-Za-z])/i, "$1 to ")

  // And `mb` is millibar to qalc, `gb` is gram·bel: `2 gb to mb` answers
  // 2000 mb·g. Data sizes are typed in lower case more than any other unit, so
  // the short spellings are written out.
  return out.replace(/\b([kmgtp]i?b(?:it)?)\b/gi, function (m) {
    var full = DATA_UNITS[m.toLowerCase()]
    return full === undefined ? m : full
  })
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
