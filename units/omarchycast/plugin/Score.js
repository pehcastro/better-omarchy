.pragma library

// Fuzzy scoring for anything shaped like a desktop entry: { id, name,
// genericName, comment, keywords }.
//
// This is Omarchy's own AppSearch.js scoring, copied rather than imported. Two
// reasons: that file is not `.pragma library` and has no stable import URL from
// a user plugin, and commands here are ranked by the same function as apps, so
// the two must not drift apart at the next Omarchy update.
//
// The bands are the contract. 10000 name prefix, 9500 id prefix, 8000 name
// infix, 7600 id infix, 6000 any haystack hit, 5000/4600 acronym, 4000
// fallback. Rank.js maps them onto tiers.

function entryName(entry) {
  return String((entry && entry.name) || (entry && entry.id) || "")
}

function keywordText(entry) {
  if (entry && entry.keywords && typeof entry.keywords.join === "function") {
    return entry.keywords.join(" ")
  }
  return ""
}

function searchText(entry) {
  if (!entry) return ""
  return [entry.name, entry.genericName, entry.comment, keywordText(entry), entry.id]
    .join(" ")
    .toLowerCase()
}

function wordText(value) {
  return String(value || "")
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .replace(/[._:/\\-]+/g, " ")
    .toLowerCase()
}

function words(value) {
  var parts = wordText(value).split(/[^a-z0-9]+/)
  var out = []
  for (var i = 0; i < parts.length; i++) {
    if (parts[i]) out.push(parts[i])
  }
  return out
}

function acronym(entry) {
  var parts = words([entry && entry.name, entry && entry.genericName, keywordText(entry), entry && entry.id].join(" "))
  var out = ""
  for (var i = 0; i < parts.length; i++) out += parts[i].charAt(0)
  return out
}

function termMatches(entry, term) {
  if (!term) return true

  var name = entryName(entry).toLowerCase()
  var id = String((entry && entry.id) || "").toLowerCase()

  if (name.indexOf(term) >= 0) return true
  if (id.indexOf(term) >= 0) return true
  if (searchText(entry).indexOf(term) >= 0) return true

  // An acronym match on a long term is almost always noise.
  return term.length <= 5 && acronym(entry).indexOf(term) >= 0
}

function allTermsMatch(entry, query) {
  var terms = String(query || "").toLowerCase().trim().split(/\s+/)
  for (var i = 0; i < terms.length; i++) {
    if (terms[i] && !termMatches(entry, terms[i])) return false
  }
  return true
}

// Returns -1 when the entry does not match at all.
function fuzzy(entry, query) {
  var q = String(query || "").trim().toLowerCase()
  if (!q) return 0
  if (!allTermsMatch(entry, q)) return -1

  var name = entryName(entry).toLowerCase()
  var id = String((entry && entry.id) || "").toLowerCase()
  var directName = name.indexOf(q)
  var directId = id.indexOf(q)

  if (directName === 0) return 10000 - name.length
  if (directId === 0) return 9500 - id.length
  if (directName > 0) return 8000 - directName * 10 - name.length
  if (directId > 0) return 7600 - directId * 10 - id.length

  var hay = searchText(entry).indexOf(q)
  if (hay >= 0) return 6000 - hay

  var letters = acronym(entry)
  var at = letters.indexOf(q)
  if (at === 0) return 5000 - letters.length
  if (at > 0) return 4600 - at * 10 - letters.length

  return 4000 - name.length
}
