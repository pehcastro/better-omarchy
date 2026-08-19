.pragma library

// Extension answers held in memory, so reopening the launcher on a query you
// just ran is instant instead of another shell-out.
//
// This is a library and not a property on the provider, because the provider
// does not live as long as it looks like it does: Launcher.open() calls
// loadExtensions(), which reassigns `root.extensions`, and the Instantiator
// built from that array destroys and rebuilds every ExtensionProvider when it
// changes. A cache stored on the Item would be empty at exactly the moment it
// is worth having, which is the second time you open the launcher.
//
// Entries are keyed by the exact command that would have run (or, for a socket
// extension, by the exact question that would have been asked), so two queries
// that happen to differ only in a filter never share an answer.

// An entry holds the *parsed* rows a script printed, not the rows the provider
// built from them. Built rows carry a `run` closure, and keeping closures in a
// library that outlives the provider they were made in is how you hold a
// destroyed QML context alive by accident.
var store = ({})

// Bounds, because a shell stays up for days and a launcher that leaks one
// entry per distinct query is a launcher that leaks. Both are per-session
// counts, not sizes: `maxRows` already caps how big a single answer gets.
var MAX_PER_PROVIDER = 16
var MAX_PROVIDERS = 48

function bucketFor(providerId) {
  var bucket = store[providerId]
  if (bucket) return bucket

  // Dropping the whole map when a session has somehow touched fifty extensions
  // is blunt, but the alternative is tracking provider recency for a case that
  // costs one extra shell-out when it fires.
  var count = 0
  for (var _ in store) count++
  if (count >= MAX_PROVIDERS) store = ({})

  bucket = { keys: [], entries: ({}) }
  store[providerId] = bucket
  return bucket
}

// Returns the parsed rows, or null for a miss. A hit is moved to the front, so
// the eviction below is least-recently-used rather than first-in.
function get(providerId, key, now) {
  var bucket = store[providerId]
  if (!bucket) return null

  var entry = bucket.entries[key]
  if (!entry) return null

  if (entry.expires <= now) {
    drop(providerId, key)
    return null
  }

  var at = bucket.keys.indexOf(key)
  if (at > 0) {
    bucket.keys.splice(at, 1)
    bucket.keys.unshift(key)
  }
  return entry.rows
}

// ttlMs <= 0 means the extension did not ask to be cached, so nothing is
// stored. That is the default, and it is the default on purpose: an answer
// about live state is wrong the moment the user acts on it, and only the
// extension author knows which of their answers those are.
function put(providerId, key, rows, ttlMs, now) {
  if (!(ttlMs > 0)) return
  if (!key) return

  var bucket = bucketFor(providerId)
  if (!bucket.entries[key]) bucket.keys.unshift(key)
  else {
    var at = bucket.keys.indexOf(key)
    if (at > 0) {
      bucket.keys.splice(at, 1)
      bucket.keys.unshift(key)
    }
  }

  bucket.entries[key] = { rows: rows, expires: now + ttlMs }

  while (bucket.keys.length > MAX_PER_PROVIDER) {
    var evicted = bucket.keys.pop()
    delete bucket.entries[evicted]
  }
}

function drop(providerId, key) {
  var bucket = store[providerId]
  if (!bucket) return

  if (key === undefined) {
    delete store[providerId]
    return
  }

  delete bucket.entries[key]
  var at = bucket.keys.indexOf(key)
  if (at >= 0) bucket.keys.splice(at, 1)
}

function clear() {
  store = ({})
}

// Only for checking, from a console or a test. Counting is cheap and the
// alternative is proving a cache works by watching a process not start.
function stats(providerId) {
  if (providerId !== undefined) {
    var bucket = store[providerId]
    return { providers: 1, entries: bucket ? bucket.keys.length : 0 }
  }
  var providers = 0
  var entries = 0
  for (var id in store) {
    providers++
    entries += store[id].keys.length
  }
  return { providers: providers, entries: entries }
}
