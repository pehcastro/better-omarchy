.pragma library

// The answer to "is the software this extension needs actually here", kept
// across provider rebuilds.
//
// This is a library and not a property on the provider, for the same reason
// Cache.js is: the provider does not live as long as it looks like it does.
// Launcher.open() calls loadExtensions(), which reassigns `root.extensions`,
// and the Instantiator built from that array destroys and rebuilds every
// ExtensionProvider. Held on the Item, a `when` result was forgotten on every
// summon, so every summon re-ran every check: 33 of the 58 shipped extensions
// declare one, each is a `bash -lc`, and 33 login shells measured 1.86s of CPU
// and 33 processes for an answer that had not changed since the last time the
// user pressed the key.
//
// Keyed by the check itself and not by the extension id, so the four keywords
// that all ask `command -v gh` cost one check between them.

var store = ({})

// A passing check is never re-run: software rarely goes away mid-session, and
// the cost of being wrong is one empty answer. A failing one is re-run when
// somebody types the keyword, at most this often, because writing an
// ~/.ssh/config or starting a docker daemon should make a keyword real without
// restarting the shell.
var RECHECK_MS = 15000

// Bounds, because a shell stays up for days. There is one entry per distinct
// `when` string across every loaded extension, which is a few dozen; this only
// exists so a config that is edited into producing new checks all day cannot
// grow the map without limit. Dropping the map costs one round of re-checks.
var MAX_ENTRIES = 128

// null means "no answer yet, go and ask". true and false are answers.
function get(check, now) {
  if (!check) return true

  var entry = store[check]
  if (!entry) return null
  if (entry.ok) return true
  if (now - entry.at < RECHECK_MS) return false
  return null
}

function put(check, ok, now) {
  if (!check) return

  if (!store[check]) {
    var count = 0
    for (var _ in store) count++
    if (count >= MAX_ENTRIES) store = ({})
  }

  store[check] = { ok: ok, at: now }
}

// Only for checking, from a console or a test.
function stats() {
  var entries = 0
  var passing = 0
  for (var key in store) {
    entries++
    if (store[key].ok) passing++
  }
  return { entries: entries, passing: passing }
}

function clear() {
  store = ({})
}
