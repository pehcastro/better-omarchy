.pragma library

// Quicklinks: the user's own destinations, in the settings file.
//
// Two ways in, because people reach for both. Typing part of the title finds it
// among everything else, and typing its keyword addresses it directly and hands
// it the rest of the line as an argument.

// Kept on the link, so Score's caches are worth having: a fresh entry per call
// meant every quicklink had its search text and its acronym rebuilt for every
// word of every keystroke. Links are parsed out of the settings file, so
// editing one produces a new object and the old cache goes with the old link.
//
// The index is part of the id for a link with no keyword, and a link can move,
// so the position it was built at is checked as well as its presence.
function asEntry(link, index) {
  if (!link) return null
  if (link._entry && link._entryIndex === index) return link._entry

  link._entryIndex = index
  link._entry = {
    id: "ql." + (link.keyword || index),
    name: String(link.title || ""),
    genericName: String(link.subtitle || ""),
    comment: String(link.url || link.open || ""),
    keywords: (link.tags || []).concat(link.keyword ? [String(link.keyword)] : [])
  }
  return link._entry
}

// {} is the argument. A link without one ignores whatever was typed after its
// keyword, so `gh` and `gh anything` both just open GitHub.
function expand(link, argument) {
  var target = String(link.url || link.open || "")
  if (target.indexOf("{}") < 0) return target

  // An empty argument would leave a bare .../search?q= , which is a worse page
  // than the site root. Trim the placeholder and everything after it instead.
  if (!argument) return target.split("{}")[0].replace(/[?&/]+$/, "")

  return target.replace("{}", encodeURIComponent(argument))
}

function command(link, argument, quote) {
  var expanded = expand(link, argument)
  if (!expanded) return ""

  if (link.open) return String(link.open).indexOf("{}") >= 0 ? expanded : String(link.open)
  return "omarchy-launch-browser " + quote(expanded)
}

function takesArgument(link) {
  return String(link.url || link.open || "").indexOf("{}") >= 0
}
