.pragma library

// A leading sigil narrows the search to one provider. Every gate elsewhere is a
// guess about what you meant; a sigil is you saying it, so it always wins.
var MODES = {
  "=": "calc",
  ">": "commands",
  "?": "web"
}

function parse(raw, epoch) {
  var text = String(raw || "").trim()
  var mode = ""

  if (text.length > 0 && MODES[text.charAt(0)]) {
    mode = MODES[text.charAt(0)]
    text = text.slice(1).trim()
  }

  return {
    epoch: epoch,
    text: text,
    lower: text.toLowerCase(),
    mode: mode,
    empty: text.length === 0
  }
}

function routesTo(query, providerId) {
  return query.mode === "" || query.mode === providerId
}
