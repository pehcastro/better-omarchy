.pragma library

// What you actually use, so the app you open twenty times a day stops ranking
// level with one you have never opened.
//
// Frequency alone is wrong: it takes weeks to forget a tool you stopped using.
// Recency alone is wrong too: whatever you touched last is not what you want
// next. Frecency is both, with recency decaying, which is how a launcher ends
// up agreeing with you after about a day of use.

// Half-life in days. A launch is worth half as much a week after you made it,
// so a burst of use during one project fades rather than ranking forever.
var HALF_LIFE_DAYS = 7
var DAY_MS = 86400000

// The most a boost can move a row inside its tier. It never crosses one, so a
// name that starts with what you typed always beats a substring you use often.
var MAX_BOOST = 9000

function decayed(entry, nowMs) {
  if (!entry || !entry.count) return 0

  var ageDays = Math.max(0, (nowMs - (entry.last || 0)) / DAY_MS)
  var weight = Math.pow(0.5, ageDays / HALF_LIFE_DAYS)

  // Diminishing returns on count: the tenth launch says much less than the
  // second, and without this one habitual app would bury everything else.
  return Math.log(1 + entry.count) * weight
}

function boost(store, key, nowMs) {
  var score = decayed(store[key], nowMs)
  if (score <= 0) return 0

  // log(1 + count) tops out around 4.6 for a hundred launches, so scaling by
  // 2000 puts a well-used entry near the ceiling without ever reaching it.
  return Math.min(MAX_BOOST, Math.round(score * 2000))
}

function record(store, key, nowMs) {
  var entry = store[key]

  if (!entry) {
    store[key] = { count: 1, last: nowMs }
    return store
  }

  entry.count = (entry.count || 0) + 1
  entry.last = nowMs
  return store
}

// Drop what has decayed to nothing, so the file does not grow forever with
// things used once a year ago.
function prune(store, nowMs) {
  var kept = {}
  for (var key in store) {
    if (decayed(store[key], nowMs) > 0.01) kept[key] = store[key]
  }
  return kept
}

function parse(text) {
  if (!text) return {}
  try {
    var data = JSON.parse(text)
    return (data && typeof data === "object") ? data : {}
  } catch (e) {
    // A half-written file during a save must not lose the ranking; the next
    // launch rewrites it anyway.
    return {}
  }
}

// Rows arrive already scored by match quality. This only reorders within a
// tier, so what you use rises among equals and never above a better match.
// Some rows are a fixed list in a deliberate order, not a set of things you
// launch. The `/` actions are six items someone arranged, and letting use
// reorder them meant "Clear Everything" climbed above "Clear Recent Queries"
// because it had been run once during testing. A destructive action drifting to
// the top of the list, under the cursor, is exactly the wrong reward for having
// used it.
var NEVER_REORDER = { actions: true }

function apply(rows, store, nowMs) {
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    if (!row.key) continue
    if (NEVER_REORDER[row.providerId]) continue

    var extra = boost(store, row.key, nowMs)
    if (extra > 0) row.score += extra
  }
  return rows
}
