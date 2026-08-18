.pragma library

// An extension is a JSON file in ~/.config/omarchy/omarchycast/extensions/.
// It declares a keyword and a command that answers for it, so a new source of
// results is a shell script and a JSON file, in any language, with nothing
// compiled and no QML.
//
//   {
//     "id": "spotify",
//     "title": "Spotify",
//     "keyword": "music",
//     "aliases": ["song", "track"],
//     "search": "omarchycast-spotify search {query}",
//     "minChars": 2,
//     "debounceMs": 250,
//     "when": "playerctl --list-all | grep -q spotify",
//     "glyph": "",
//     "tier": "substring"
//   }
//
// `search` runs with {query} replaced by the shell-quoted search text, and any
// {filter} replaced by another filter's value, so `music:blue year:1959` can
// reach the script as two arguments. It prints JSON: either an array of rows,
// or one row per line.
//
// A row is { id, title, subtitle, exec }, plus optional icon, glyph, accessory
// and score. Nothing else is read, so a script can carry its own fields through
// for its own use.

var TIERS = { calc: 9, forced: 8, prefix: 7, substring: 6, weak: 5, file: 4, web: 1 }

function normalize(raw, sourcePath) {
  var ext = raw || {}
  var id = String(ext.id || "").trim()
  if (!id) return null

  var search = String(ext.search || "").trim()
  if (!search) return null

  return {
    id: id,
    title: String(ext.title || id),
    // The keyword defaults to the id, so a minimal extension needs neither.
    keyword: String(ext.keyword || id).toLowerCase(),
    aliases: (ext.aliases || []).map(function (a) { return String(a).toLowerCase() }),
    search: search,
    when: String(ext.when || ""),
    glyph: String(ext.glyph || ""),
    subtitle: String(ext.subtitle || ext.title || id),
    minChars: ext.minChars === undefined ? 1 : Number(ext.minChars),
    debounceMs: ext.debounceMs === undefined ? 200 : Number(ext.debounceMs),
    timeoutMs: ext.timeoutMs === undefined ? 4000 : Number(ext.timeoutMs),
    maxRows: ext.maxRows === undefined ? 8 : Number(ext.maxRows),
    tier: TIERS[String(ext.tier || "substring")] || TIERS.substring,
    // Unscoped, an extension stays quiet unless it says otherwise. A launcher
    // that shells out to six services on every keystroke is a launcher nobody
    // keeps, so answering a bare query is opt in.
    always: ext.always === true,
    source: sourcePath || ""
  }
}

// {query} and {any-filter} are replaced by shell-quoted values. Anything
// unmatched becomes an empty string rather than being left as a literal brace,
// so a script never receives "{year}" and treats it as a search term.
function buildCommand(ext, argText, filters, quote) {
  return ext.search.replace(/\{([a-z0-9_-]+)\}/gi, function (whole, key) {
    key = key.toLowerCase()
    if (key === "query") return quote(argText)
    if (filters && filters[key] !== undefined) return quote(filters[key])
    return quote("")
  })
}

// Accepts a JSON array, or one JSON object per line. Line mode matters for a
// script that streams, and costs nothing for one that does not.
function parseRows(text) {
  var trimmed = String(text || "").trim()
  if (trimmed === "") return []

  try {
    var whole = JSON.parse(trimmed)
    if (Array.isArray(whole)) return whole
    if (whole && typeof whole === "object") return [whole]
  } catch (e) {
    // Not one document. Fall through to line mode.
  }

  var rows = []
  var lines = trimmed.split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "") continue
    try {
      rows.push(JSON.parse(line))
    } catch (e2) {
      // One malformed line should not lose the rest of a long answer.
    }
  }
  return rows
}

// A script's own `score` orders its rows against each other. It never crosses
// tiers, so an extension cannot outrank a calculator answer by returning a big
// number.
function toRow(ext, raw, index) {
  var id = String(raw.id !== undefined ? raw.id : (raw.title || index))
  var local = raw.score !== undefined
    ? Math.max(0, Math.min(99999, Number(raw.score)))
    : Math.max(0, 90000 - index * 1000)

  return {
    key: "ext:" + ext.id + ":" + id,
    providerId: ext.id,
    group: ext.title,
    title: String(raw.title || ""),
    subtitle: String(raw.subtitle !== undefined ? raw.subtitle : ext.subtitle),
    accessory: String(raw.accessory || ""),
    iconSource: String(raw.icon || ""),
    iconGlyph: String(raw.glyph || ext.glyph),
    tier: ext.tier,
    local: local,
    exec: String(raw.exec || ""),
    pending: false
  }
}
