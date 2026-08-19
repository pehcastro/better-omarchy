.pragma library

// The last queries that led somewhere, newest first, offered when the box is
// empty. Re-running yesterday's search should cost one key, not the typing.
//
// What is kept is the text, never the row it matched. A query is a question and
// its answer changes: the file has moved, the window has closed, the track is
// no longer playing. Replaying the question is honest; replaying last week's
// answer is a lie the user cannot see.

var LIMIT = 20

// A bare `file:` is a mode you are entering, not a search you made, and a list
// of those teaches nothing you did not already type. The sigils are the same
// thing one character shorter.
function worthKeeping(text) {
  var entry = clean(text)
  if (entry === "") return false
  if (/^[a-z][a-z0-9_-]*:$/i.test(entry)) return false
  if (/^[=>?\/]$/.test(entry)) return false
  return true
}

function clean(text) {
  return String(text || "").replace(/^\s+/, "").replace(/\s+$/, "")
}

// Newest first, and one entry per query. Without the dedupe, refining one
// search over six keystrokes would take a third of the list.
function record(list, text) {
  if (!worthKeeping(text)) return list

  var entry = clean(text)
  var current = list || []
  if (current.length > 0 && String(current[0]) === entry) return current

  var out = [entry]
  for (var i = 0; i < current.length && out.length < LIMIT; i++) {
    if (String(current[i]) !== entry) out.push(String(current[i]))
  }
  return out
}

function parse(text) {
  if (!text) return []

  var data = null
  try {
    data = JSON.parse(text)
  } catch (e) {
    // A half-written file during a save must not lose the list; the next
    // activation rewrites it anyway.
    return []
  }
  if (!data || !Array.isArray(data.recents)) return []

  var out = []
  for (var i = 0; i < data.recents.length && out.length < LIMIT; i++) {
    var entry = clean(data.recents[i])
    if (entry !== "") out.push(entry)
  }
  return out
}
