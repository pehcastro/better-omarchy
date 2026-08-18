.pragma library

// A query is free text plus zero or more `keyword:value` filters.
//
//   firefox                       text only
//   file:report.pdf               a filter, and no text
//   music:"kind of blue" jazz     a quoted value, and text beside it
//   =2+2                          a sigil, shorthand for calc:2+2
//
// A filter is how a provider is addressed by name. `file:x` means the file
// provider and nothing else, which is both a narrowing and an instruction: a
// user who types it has told you what they want, and no heuristic gets to
// second-guess that.

// Sigils are one-character shorthands for the filters people reach for most.
var SIGILS = {
  "=": "calc",
  ">": "run",
  "?": "web",
  "/": "file"
}

// keyword:"quoted value", keyword:bare, or a bare keyword: with nothing after
// it. The empty form matters: `win:` on its own means "every window", and a
// provider that lists things needs a way to be asked for all of them.
var FILTER = /([a-z][a-z0-9_-]*):(?:"([^"]*)"|'([^']*)'|(\S*))/gi

function parse(raw, epoch) {
  var text = String(raw || "")
  var filters = {}
  var order = []

  // A leading sigil is rewritten into its filter, so everything downstream sees
  // one shape rather than two.
  var trimmed = text.replace(/^\s+/, "")
  if (trimmed.length > 0 && SIGILS[trimmed.charAt(0)]) {
    var keyword = SIGILS[trimmed.charAt(0)]
    var rest = trimmed.slice(1).trim()
    filters[keyword] = rest
    order.push(keyword)
    return build(raw, "", filters, order, epoch)
  }

  // Pull the filters out, and whatever is left is the free text.
  var rest = text.replace(FILTER, function (whole, key, dq, sq, bare) {
    var value = dq !== undefined ? dq : (sq !== undefined ? sq : (bare || ""))
    key = key.toLowerCase()
    filters[key] = value
    if (order.indexOf(key) < 0) order.push(key)
    return " "
  })

  return build(raw, rest, filters, order, epoch)
}

function build(raw, rest, filters, order, epoch) {
  var text = String(rest).replace(/\s+/g, " ").trim()

  return {
    epoch: epoch,
    raw: String(raw || ""),
    text: text,
    lower: text.toLowerCase(),
    filters: filters,
    // The first filter named. Providers that are not it stay quiet, so typing
    // `file:` never floods the list with apps.
    scope: order.length > 0 ? order[0] : "",
    empty: text.length === 0 && order.length === 0
  }
}

// Should this provider answer?
//
// Unscoped, everyone who can answer does. Scoped, only the named provider does,
// plus anything that declared the same keyword as an alias.
function routesTo(query, providerId, aliases) {
  if (query.scope === "") return true
  if (query.scope === providerId) return true

  if (aliases) {
    for (var i = 0; i < aliases.length; i++) {
      if (aliases[i] === query.scope) return true
    }
  }
  return false
}

// The text a scoped provider should search: the filter's own value when it has
// one, and the free text otherwise. `file:report budget` searches for
// "report budget", which is what the typing looks like it means.
function argFor(query, providerId, aliases) {
  var value = query.filters[providerId]

  if (value === undefined && aliases) {
    for (var i = 0; i < aliases.length; i++) {
      if (query.filters[aliases[i]] !== undefined) {
        value = query.filters[aliases[i]]
        break
      }
    }
  }

  if (value === undefined) return query.text
  if (value === "" ) return query.text
  return query.text ? value + " " + query.text : value
}

// Filters nobody claimed. A provider reads these as extra conditions, so
// `file:report format:pdf` reaches the file provider with format in hand.
function extras(query, providerId, aliases) {
  var out = {}
  var claimed = [providerId].concat(aliases || [])

  for (var key in query.filters) {
    if (claimed.indexOf(key) < 0) out[key] = query.filters[key]
  }
  return out
}
