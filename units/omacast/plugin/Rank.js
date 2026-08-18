.pragma library

// One integer orders results from every provider: tier * 100000 + local.
//
// The tier is the kind of match, and it always wins. `local` breaks ties inside
// a tier and is where a provider's own bias lives, so a bias can reorder equals
// but can never lift a weak match above a strong one.

var TIER = {
  calc: 9,     // a calculator answer is what you asked for, so it pins to the top
  forced: 8,   // a sigil said "only this provider"
  prefix: 7,   // the name starts with what you typed
  substring: 6,
  weak: 5,     // an acronym or a keyword hit
  file: 4,
  web: 1       // always present, always last
}

// Omarchy's AppSearch.fuzzyScore returns 4000 to 10000. Map its bands onto
// tiers so apps and commands, scored by the same function, mean the same thing.
function tierFor(fuzzy) {
  if (fuzzy >= 9500) return TIER.prefix        // 10000 name prefix, 9500 id prefix
  if (fuzzy >= 6000) return TIER.substring     // 8000 name infix, 7600 id infix, 6000 haystack
  return TIER.weak                             // 5000/4600 acronym, 4000 fallback
}

function local(fuzzy) {
  return Math.max(0, Math.min(99999, Math.round((fuzzy - 4000) * 16.666)))
}

function score(tier, loc, bias) {
  return tier * 100000 + Math.max(0, Math.min(99999, loc + (bias || 0)))
}

function byScore(a, b) {
  if (b.score !== a.score) return b.score - a.score
  return String(a.title).localeCompare(String(b.title))
}

// Merge every provider's bucket into one ranked list.
//
// The web row is a fallback, so it is dropped whenever anything real matched.
// `mode` forces one provider, and a forced web row survives.
function merge(buckets, mode, limit) {
  var rows = []
  for (var id in buckets) {
    var bucket = buckets[id]
    if (!bucket || !bucket.rows) continue
    for (var i = 0; i < bucket.rows.length; i++) rows.push(bucket.rows[i])
  }

  var hasReal = false
  for (var j = 0; j < rows.length; j++) {
    if (rows[j].providerId !== "web") { hasReal = true; break }
  }

  if (hasReal && mode !== "web") {
    rows = rows.filter(function (r) { return r.providerId !== "web" })
  }

  rows.sort(byScore)
  return limit > 0 ? rows.slice(0, limit) : rows
}

// Selection follows a row's identity, never its position. A late async result
// filling in above the cursor must not move what is under it.
function indexOfKey(rows, key) {
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].key === key) return i
  }
  return -1
}
