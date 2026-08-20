.pragma library

// qalc answers almost anything, which is the problem. `qalc -t firefox` returns
// "0 B", `qalc -t zzz` returns "z^3", and `5 km in miles` returns cubic metres
// because it reads `in` as inches. Its exit code is 0 for all of them, so the
// gate has to be here.

var CONVERSION = /\b(to|in|into|as|para|pra)\b/i
// `em` and `en` are both real units, so they only read as Portuguese and
// Spanish prepositions when the query already names a currency: `100 reais em
// dolares` is a conversion and `12 em` is twelve ems.
var MONEY_PREPOSITION = /\b(em|en)\b/i
var OPERATOR = /[+\-*/^%()]/
var DIGIT = /\d/

// A digit plus either an operator or a conversion word. Both halves matter: "5"
// alone is not a question, and "a + b" is not arithmetic. The third test is the
// number itself: a query whose digits could mean two different things does not
// get an answer at all, see `undecidable` below.
function looksLikeMath(text) {
  if (!DIGIT.test(text)) return false
  if (undecidable(text)) return false
  if (OPERATOR.test(text)) return true
  if (CONVERSION.test(text)) return true
  return MONEY_PREPOSITION.test(text) && namesCurrency(withCurrencies(text))
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
  f: "°F", "°f": "°F", degf: "°F", fahrenheit: "°F",
  c: "°C", "°c": "°C", degc: "°C", celsius: "°C",
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

// ------------------------------------------------------------------- money
//
// A currency symbol in front of the number is how a price is written in every
// language that has one, and qalc only reads the four it knows as single
// characters: `$100 to eur` is €86.26 and `R$ 50 to usd` is $5E28, because `R`
// is the roentgen and the two multiply. `US$ 50 to eur` is worse still, it
// answers in €·A²·s³/(g·m). Every one of these is a symbol that means exactly
// one currency, so it becomes that currency's code wherever it stands: qalc
// reads `BRL 50`, `50 BRL` and `to BRL` all the same way.
var SYMBOL = {
  "r$": "BRL", "us$": "USD", "u$s": "USD", "c$": "CAD", "ca$": "CAD",
  "a$": "AUD", "au$": "AUD", "nz$": "NZD", "hk$": "HKD", "s$": "SGD",
  "nt$": "TWD", "mx$": "MXN", "cn¥": "CNY", "₺": "TRY", "₩": "KRW",
  "₫": "VND", "₴": "UAH", "฿": "THB", "₪": "ILS"
}

// Currency names qalc does not know, or knows as something else. `100 reais to
// usd` answered `0 a·s`, `100 ienes to usd` answered `738.906in s`, and
// `100 rupees to usd` answered `1.04626 s·$`: three garbage answers with exit
// code 0 for three words that mean one currency and nothing else. Written out
// by hand, in the languages somebody at this keyboard types, because a name
// guessed at is a wrong answer with a straight face.
var CURRENCY_NAME = {
  dolar: "USD", dolares: "USD", "dólar": "USD", "dólares": "USD",
  dolari: "USD", dollari: "USD",
  reais: "BRL",
  iene: "JPY", ienes: "JPY", yens: "JPY", yenes: "JPY",
  esterlina: "GBP", esterlinas: "GBP", sterline: "GBP", sterlina: "GBP",
  franc: "CHF", francs: "CHF", franco: "CHF", francos: "CHF", franchi: "CHF",
  franken: "CHF",
  yuan: "CNY", yuanes: "CNY", renminbi: "CNY", rmb: "CNY",
  rupee: "INR", rupees: "INR", rupia: "INR", rupias: "INR", roupie: "INR",
  rupiah: "IDR",
  shekel: "ILS", shekels: "ILS", sheqel: "ILS",
  baht: "THB", ringgit: "MYR", dong: "VND", hryvnia: "UAH", hryvnias: "UAH",
  rublo: "RUB", rublos: "RUB", rubel: "RUB",
  zloty: "PLN", zlotys: "PLN", forint: "HUF", forints: "HUF",
  rands: "ZAR", wons: "KRW", dirham: "AED", dirhams: "AED",
  lira: "TRY", liras: "TRY"
}

// The same, for words that are also a unit of something else. `100 pounds to
// usd` answers `100 lb`, because pounds are mass until a currency says
// otherwise, and `libra` and `livre` are mass in the languages they come from.
// So these only become a currency when a *different* token in the query already
// is one: `100 pounds to usd` is sterling, `100 pounds to kg` is still mass.
var CURRENCY_IN_CONTEXT = {
  pound: "GBP", pounds: "GBP", libra: "GBP", libras: "GBP",
  livre: "GBP", livres: "GBP", pfund: "GBP",
  real: "BRL"
}

// Thousand and million, written the way people write them next to money. `k` is
// not here because qalc already reads it as kilo and `10k usd to eur` is
// €8625.89; `m` is here because it reads that as metre and `1.5m usd to eur`
// answered `1.29388 m·€`. Every one of these only applies when the query names
// a currency, which is what keeps `5m to feet` at five metres and `100mi to km`
// at a hundred miles.
var MAGNITUDE_SUFFIX = [
  ["mm", 6], ["mn", 6], ["mi", 6], ["bn", 9], ["bi", 9], ["m", 6], ["b", 9]
]
var MAGNITUDE_WORD = {
  mil: 3, mi: 6, mn: 6, mio: 6, mln: 6,
  milhao: 6, "milhão": 6, milhoes: 6, "milhões": 6,
  millon: 6, "millón": 6, millones: 6, milione: 6, milioni: 6,
  bi: 9, bn: 9, bilhao: 9, "bilhão": 9, bilhoes: 9, "bilhões": 9,
  billon: 9, "billón": 9, billones: 9, miliardo: 9, miliardi: 9
}

var PREPOSITION = {
  to: 1, "in": 1, into: 1, as: 1, para: 1, pra: 1, em: 1, en: 1, de: 1, of: 1
}

// The currencies people write out, minus the ones whose unit is worth more than
// a hundred of anything. A code missing from here costs two decimal places on
// an exotic currency, which is the mild half of being wrong.
var FIAT = {
  usd: 1, eur: 1, gbp: 1, jpy: 1, chf: 1, cad: 1, aud: 1, nzd: 1, cny: 1, rmb: 1,
  brl: 1, mxn: 1, ars: 1, clp: 1, cop: 1, pen: 1, uyu: 1, inr: 1, rub: 1, krw: 1,
  sek: 1, nok: 1, dkk: 1, pln: 1, czk: 1, huf: 1, ron: 1, "try": 1, zar: 1, ils: 1,
  aed: 1, sar: 1, egp: 1, ngn: 1, kes: 1, hkd: 1, sgd: 1, twd: 1, thb: 1, idr: 1,
  myr: 1, php: 1, vnd: 1, isk: 1, uah: 1,
  "$": 1, "€": 1, "£": 1, "¥": 1, "₹": 1, "₽": 1,
  "r$": 1, "us$": 1,
  dollar: 1, dollars: 1, euro: 1, euros: 1, pound: 1, pounds: 1, yen: 1,
  real: 1, reais: 1, peso: 1, pesos: 1, rupee: 1, rupees: 1
}

var CURRENCY_CHAR = "A-Za-z$¥£€₹₽₺₩₫₴₪฿À-ɏ"

function escapeForRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
}

function longestFirst(keys) {
  return keys.slice().sort(function (a, b) { return b.length - a.length })
}

var SYMBOL_RE = new RegExp(
  "(^|[^0-9A-Za-z])(" +
  longestFirst(Object.keys(SYMBOL)).map(escapeForRegex).join("|") +
  ")(?![A-Za-z])", "gi")

var NAME_RE = new RegExp(
  "\\b(" + longestFirst(Object.keys(CURRENCY_NAME)).join("|") + ")\\b", "gi")

var CONTEXT_NAME_RE = new RegExp(
  "\\b(" + longestFirst(Object.keys(CURRENCY_IN_CONTEXT)).join("|") + ")\\b", "gi")

// The gate runs on every keystroke, so the regexes it needs are built once.
var UNIT_BEFORE_RE = new RegExp("([" + CURRENCY_CHAR + "]+)\\s*$")
var UNIT_AFTER_RE = new RegExp("^\\s*([" + CURRENCY_CHAR + "]+)")
var WORD_AFTER_RE = new RegExp("^\\s+([" + CURRENCY_CHAR + "]+)(?![A-Za-z])")

// Is any token in here money, ignoring the ones that are only money in company?
// This is what decides whether `pounds` is sterling or mass, so it deliberately
// does not count the context names themselves.
function namesCurrency(text) {
  var tokens = String(text).toLowerCase().match(/[a-z$¥£€₹₽]+/g) || []
  for (var i = 0; i < tokens.length; i++) {
    if (FIAT[tokens[i]] === 1 && !CURRENCY_IN_CONTEXT[tokens[i]]) return true
    if (CURRENCY_NAME[tokens[i]]) return true
  }
  return false
}

// Symbols and names to ISO codes, so that everything downstream, the number
// reader included, is looking at one spelling of a currency.
function withCurrencies(text) {
  var out = String(text).replace(SYMBOL_RE, function (m, lead, sym) {
    return lead + SYMBOL[sym.toLowerCase()]
  })
  out = out.replace(NAME_RE, function (m, name) {
    return CURRENCY_NAME[name.toLowerCase()]
  })
  if (!namesCurrency(out)) return out
  return out.replace(CONTEXT_NAME_RE, function (m, name) {
    return CURRENCY_IN_CONTEXT[name.toLowerCase()]
  })
}

// ----------------------------------------------------------------- numbers
//
// qalc reads `,` as an argument separator and `.` as a decimal point, so a
// thousands separator in either convention is read as something else:
//
//   100,000 yen to usd    [100  $0]
//   1,5 kg to lbs         [1  (11.0231 lb)]
//   1.500,50 brl to usd   [1.50000  $9.57814]
//   3.000 yen to usd      $0.0188565
//
// Only the first three look broken on the row. The last one is three yen priced
// as if the question had been answered, which is the failure that matters, so
// every literal is rewritten into the one form qalc cannot misread: digits, one
// dot, no groups.
//
// Reading a literal is mostly forced. Both separators present, and the last one
// is the decimal point and the other is the group. One separator more than
// once, and it is the group. One separator with anything but three digits after
// it, and it is the decimal point, because a group is always exactly three.
//
// That leaves one shape genuinely ambiguous: a single separator with exactly
// three digits after it and one to three in front. `1.500` is 1500 to a
// Brazilian and 1.5 to an American, `100,000` is 100000 to an American and 100
// to a German, and nothing in the digits themselves decides it. Two things
// outside them can:
//
//   Another number in the same query. `1.500,50` says the comma is this
//   person's decimal point, so a `1.500` beside it is a group.
//
//   A currency on the number. A price is quoted to two decimals; three is not a
//   price. So `3.000 yen` is three thousand yen and `100,000 yen` is a hundred
//   thousand, and that is the whole of the evidence.
//
// With neither, there is no answer. `1.500 kg to lbs` and `10,000 miles to km`
// return nothing rather than a number that is wrong by a factor of a thousand,
// because a launcher that is silent costs a retype and a launcher that is
// confidently wrong costs whatever the number was for. `1500` and `1,5` both
// work; the ambiguous spelling is the only one refused.

function isDigit(ch) {
  return ch >= "0" && ch <= "9"
}

// Runs of digits and the separators between them. A comma inside parentheses is
// skipped, because there it is qalc's own argument separator: `gcd(12,18)` is 6
// and `log(8, 2)` is 3, and both have to stay that way.
function numberTokens(text) {
  var s = String(text)
  var out = []
  var depth = 0
  var i = 0
  while (i < s.length) {
    var ch = s.charAt(i)
    if (ch === "(") { depth++; i++; continue }
    if (ch === ")") { if (depth > 0) depth--; i++; continue }
    if (!isDigit(ch)) { i++; continue }
    var start = i
    while (i < s.length) {
      var c = s.charAt(i)
      if (isDigit(c)) { i++; continue }
      if ((c === "." || (c === "," && depth === 0)) && isDigit(s.charAt(i + 1))) { i++; continue }
      break
    }
    out.push({ start: start, end: i, text: s.slice(start, i) })
  }
  return out
}

function countOf(s, ch) {
  return s.split(ch).length - 1
}

// A group is one to three digits and then threes, all the way down.
function groupsOk(parts) {
  if (parts.length < 2) return false
  if (parts[0].length < 1 || parts[0].length > 3) return false
  for (var i = 1; i < parts.length; i++) {
    if (parts[i].length !== 3) return false
  }
  return true
}

// `{ value }` when the literal can only mean one thing, `{ ambiguous }` when it
// is the three-digit shape above, `{ bad: true }` when it is neither: `1.23.4`
// and `1,2345,6` are not a number in any convention, and a query carrying one
// gets no answer rather than qalc's reading of it.
//
// `convention` is what this literal proves about the person who typed it: which
// character they use as a decimal point. It is what resolves an ambiguous
// literal sitting beside it.
function readNumber(token) {
  var dots = countOf(token, ".")
  var commas = countOf(token, ",")
  if (!dots && !commas) return { value: token }

  if (dots && commas) {
    var decimal = token.lastIndexOf(".") > token.lastIndexOf(",") ? "." : ","
    var group = decimal === "." ? "," : "."
    if (countOf(token, decimal) !== 1) return { bad: true }
    var at = token.lastIndexOf(decimal)
    var parts = token.slice(0, at).split(group)
    if (!groupsOk(parts)) return { bad: true }
    return { value: parts.join("") + "." + token.slice(at + 1), convention: decimal }
  }

  var sep = dots ? "." : ","
  var pieces = token.split(sep)
  if (pieces.length > 2) {
    if (!groupsOk(pieces)) return { bad: true }
    return { value: pieces.join(""), convention: sep === "." ? "," : "." }
  }

  var whole = pieces[0], frac = pieces[1]
  // Not three digits after it, or more than three in front, or a leading zero:
  // a group cannot be any of those, so the separator is a decimal point. The
  // leading zero is what keeps `0,750 l` at three quarters of a litre.
  if (frac.length !== 3 || whole.length > 3 || whole.charAt(0) === "0") {
    return { value: whole + "." + frac, convention: sep }
  }
  return { ambiguous: true, sep: sep, grouped: whole + frac, decimal: whole + "." + frac }
}

// Is this literal a price? The unit written against it decides, and only a
// currency that is quoted to two decimals counts: `1.005 btc to usd` gets no
// answer, because a thousandth of a bitcoin is a real quantity and 1005 of them
// is a different real quantity. A literal with no unit of its own borrows the
// conversion target, which is what qalc does with it anyway.
function pricedIn(text, token) {
  var before = text.slice(0, token.start).match(UNIT_BEFORE_RE)
  if (before && FIAT[before[1].toLowerCase()] === 1) return true

  var after = text.slice(token.end).match(UNIT_AFTER_RE)
  if (after) {
    var word = after[1].toLowerCase()
    if (FIAT[word] === 1) return true
    if (!PREPOSITION[word]) return false
  }

  var target = String(text).toLowerCase().match(/\bto\s+([^\s]+)\s*$/)
  return !!(target && FIAT[target[1]] === 1)
}

// Move the decimal point right, without arithmetic: the string is the truth
// here and 1.5 * 1e6 in floating point is not always 1500000.
function shiftDecimal(literal, places) {
  var dot = literal.indexOf(".")
  var whole = dot < 0 ? literal : literal.slice(0, dot)
  var frac = dot < 0 ? "" : literal.slice(dot + 1)
  while (places > 0) {
    if (frac === "") { whole += "0" } else { whole += frac.charAt(0); frac = frac.slice(1) }
    places--
  }
  return frac === "" ? whole : whole + "." + frac
}

// `1.5m`, `2bn`, `100 mil`, `1.5 milhoes de`: how many zeros, and where the
// text picks up again. Only called when the query names a currency.
function magnitudeAfter(text, end) {
  var rest = text.slice(end)
  for (var i = 0; i < MAGNITUDE_SUFFIX.length; i++) {
    var suffix = MAGNITUDE_SUFFIX[i][0]
    if (rest.slice(0, suffix.length).toLowerCase() === suffix
        && !/^[A-Za-z0-9]/.test(rest.slice(suffix.length))) {
      return { zeros: MAGNITUDE_SUFFIX[i][1], end: end + suffix.length }
    }
  }
  var word = rest.match(WORD_AFTER_RE)
  if (word) {
    var zeros = MAGNITUDE_WORD[word[1].toLowerCase()]
    if (zeros) {
      // `1.5 milhoes de reais`: the preposition belongs to the number word, and
      // qalc has no use for it.
      var tail = rest.slice(word[0].length).match(/^\s+(de|of)(?![A-Za-z])/i)
      return { zeros: zeros, end: end + word[0].length + (tail ? tail[0].length : 0) }
    }
  }
  return null
}

// Every literal in plain form, or null when one of them cannot be read with
// certainty. Null is the whole point: it is how the calculator declines.
//
// `notes` collects the literals that were ambiguous and got read anyway, so the
// row can say which way it took them. `omacast-unit` does the same thing for
// the `unit` keyword and for the same reason: somebody who meant the other
// reading deserves to see that, rather than to find out from the number.
function withNumbers(text, notes) {
  var s = String(text)
  var tokens = numberTokens(s)
  if (!tokens.length) return s

  var reads = []
  var convention = ""
  var i
  for (i = 0; i < tokens.length; i++) {
    var read = readNumber(tokens[i].text)
    if (read.bad) return null
    if (read.convention) {
      if (convention && convention !== read.convention) return null
      convention = read.convention
    }
    reads.push(read)
  }

  var scaling = namesCurrency(s)
  var out = ""
  var at = 0
  for (i = 0; i < tokens.length; i++) {
    var token = tokens[i], r = reads[i], value
    if (r.ambiguous) {
      if (convention) value = r.sep === convention ? r.decimal : r.grouped
      else if (pricedIn(s, token)) value = r.grouped
      else return null
      // Nothing to say when the reading is the spelling: `1.500` taken as a
      // decimal point is already what it looks like.
      if (notes && value !== token.text) notes.push(token.text + " read as " + value)
    } else {
      value = r.value
    }
    var magnitude = scaling ? magnitudeAfter(s, token.end) : null
    if (magnitude) value = shiftDecimal(value, magnitude.zeros)
    out += s.slice(at, token.start) + value
    at = magnitude ? magnitude.end : token.end
  }
  return out + s.slice(at)
}

// The one question the gate asks about the digits themselves.
function undecidable(text) {
  return withNumbers(withCurrencies(String(text))) === null
}

// `1.500 usd to eur` is answered as fifteen hundred dollars, and the row says
// so under the answer. An empty string hides the line.
function reading(text) {
  var notes = []
  if (withNumbers(withCurrencies(String(text)), notes) === null) return ""
  return notes.join(" · ")
}

// What to hand qalc. Every rewrite here exists because qalc answered something
// wrong with exit code 0, and none of them touch plain arithmetic:
//
//   `12% of 250` was rem(12, 1 B).
//   `R$ 50 to usd` was $5E28, and `100 reais to usd` was `0 a·s`.
//   `3.000 yen to usd` was two cents.
//   `1.5m usd to eur` was `1.29388 m·€`.
//   `100 usd into brl` was `19.1931 × int(8 bit) × $²`, and `100 usd as brl`
//   was `14.2808 as·€²`, because `into` is `int`+`o` and `as` is attoseconds.
//   `40 miles in km` was 1635094 m³.
//
// A query without a quantity in front of the preposition is left alone, so
// `3 in` is still three inches.
function forQalc(text) {
  var out = String(text).replace(/%\s+of\s+/i, "% * ")

  out = withCurrencies(out)
  var numbered = withNumbers(out)
  if (numbered !== null) out = numbered

  out = out.replace(/(\d\s*[^\s]*)\s+into\s+(?=[A-Za-z°])/i, "$1 to ")
  out = out.replace(/(\d\s*[^\s]+)\s+(?:as|para|pra)\s+(?=[A-Za-z°])/i, "$1 to ")
  if (namesCurrency(out)) {
    out = out.replace(/(\d\s*[^\s]+)\s+(?:em|en)\s+(?=[A-Za-z°])/i, "$1 to ")
  }
  out = out.replace(/(\d\s*[^\s]*)\s+in\s+(?=[A-Za-z°])/i, "$1 to ")

  var split = out.match(/^(.*?)\s+to\s+(\S+)\s*$/i)
  if (!split) return out

  var left = split[1].replace(/([\d.]\s*)([A-Za-z°]+)\s*$/, function (m, num, unit) {
    return num + canonUnit(unit)
  })
  return left + " to " + canonUnit(split[2])
}

// ---------------------------------------------------------------- formatting
//
// How qalc says a number is a setting, not a fact, and out of the box it reads
// that setting from ~/.config/qalculate/qalc.cfg. This one had precision 6 in
// it, which is why `2^32` answered `4.29497E9`: not a wrong number, but an
// exact one rounded to six figures and then written in exponent form because it
// no longer fitted. A launcher cannot depend on a file it does not own, so
// every option that decides the shape of an answer is passed per call.
//
//   exp 21    Exponent notation only past 10^21, either direction. Below that
//             an exact integer prints in full: 2^32 is 4294967296 and 2^64 is
//             18446744073709551616, which is what somebody typing a power of
//             two came for. 21 digits is about where a number stops being
//             readable as a number, and past it 1.18059E21 says more than
//             twenty-two digits do. The same threshold runs the small end, so
//             0.000001234 prints in full and 1E-30 does not.
//
//   precision Significant digits, both for display and for the approximate
//             part of the calculation. Fixed at six it destroyed 1234567.891;
//             fixed high it answered 1/3 with twenty threes. So it follows the
//             question: no answer carries fewer significant digits than the
//             number that was typed into it, and nothing else asks for more.
//             1/3 is 0.333333, 1234567.891 is itself. It counts the literals in
//             the *rewritten* expression, because `100,000` is one six-figure
//             number and not a three-figure one beside a zero.
//
//   maxdeci 2 Only when the answer is money. Six significant figures on a
//             currency is €86.2589, and nobody has ever wanted that. It is not
//             a global setting because two decimals would flatten 0.000001234
//             to 0.000001, and it is off for crypto because 100 USD in bitcoin
//             is not ₿0.00.
//
//   conv 0    Only when a unit was named. Automatic conversion is what answers
//             `5 N * 2 m` with 10 J instead of 10 kg·m²/s², so it stays on for
//             anything without a target; it is also what answers `5 km to
//             miles` with `3 mi + 188 yd + 2.39370 in`, and somebody who names
//             a unit has said which one they want the number in. Off, that is
//             3.10686 mi, and `to hex`, `to fraction` and `to time` are
//             untouched either way.
var PRECISION_FLOOR = 6
var PRECISION_CEILING = 20
var EXPONENT_FROM = 21

// Digits that carry meaning: leading zeros do not, so 0.000001234 is four and
// 1234567.891 is ten.
function significantDigits(literal) {
  var digits = String(literal).replace(/[^0-9]/g, "").replace(/^0+/, "")
  return digits.length
}

function precisionFor(text) {
  var literals = String(text).match(/\d+(?:\.\d+)?/g) || []
  var want = PRECISION_FLOOR
  for (var i = 0; i < literals.length; i++) {
    want = Math.max(want, significantDigits(literals[i]))
  }
  return Math.min(PRECISION_CEILING, want)
}

// Money, and specifically money the answer will be *in*: the right-hand side of
// a conversion decides, because `100 usd to btc` is a bitcoin answer however
// many dollars are in the question.
function isMoney(text) {
  var t = String(text).toLowerCase()
  var split = t.match(/\bto\s+([^\s]+)\s*$/)
  if (split) return FIAT[split[1]] === 1

  var tokens = t.match(/[a-z$€£¥₹₽]+/g) || []
  for (var i = 0; i < tokens.length; i++) {
    if (FIAT[tokens[i]] === 1) return true
  }
  return false
}

// The whole call, so the question and the way the answer is written are decided
// in one place. -m bounds the calculation: qalc will otherwise chew on a
// pathological expression for as long as it takes.
function command(text) {
  var expression = forQalc(text)
  var argv = ["qalc", "-t", "-m", "200",
              "-set", "exp " + EXPONENT_FROM,
              "-set", "precision " + precisionFor(expression)]
  if (isMoney(expression)) argv = argv.concat(["-set", "maxdeci 2"])
  if (/\bto\b/i.test(expression)) argv = argv.concat(["-set", "conv 0"])
  return argv.concat(["--", expression])
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
  var raw = normalize(stdout)
  // The echo test runs against what qalc actually said, before the fix below
  // rewrites a character of it: `1e-30` answered `1E−30`, and normalising the
  // minus first turned a real answer into an apparent echo of the question.
  if (raw === "" || isEcho(query, raw)) return null
  // The `=` keyword skips the gate, so the refusal is repeated here: a number
  // nobody can read has no answer however the query got to qalc.
  if (undecidable(query)) return null

  // The one thing about qalc's output that no setting fixes: the minus in an
  // exponent is U+2212, so the row said 1E−30 and pasted something no shell,
  // spreadsheet or language will read back as a number. Unicode can be turned
  // off wholesale, but that also costs μs its μ, ohms their Ω and m² its
  // square, so it is this character and nothing else.
  var answer = raw.replace(/−/g, "-")

  return {
    key: "calc:" + query,
    providerId: "calc",
    group: "Calculator",
    title: answer,
    subtitle: query,
    detail: reading(query),
    accessory: "Copy",
    iconGlyph: "",
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
    iconGlyph: "",
    pending: true
  }
}
