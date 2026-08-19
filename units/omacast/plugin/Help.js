.pragma library

// Every keyword the launcher knows, listed by typing `?` on its own.
//
// A launcher whose whole interface is a text box has one honest question: what
// can I type? The answer has to come from what is actually loaded, so an
// extension that arrives in an update and a quicklink added a minute ago are
// both in the list without anyone remembering to write them down.

// The four built-in scopes. These are the same names Launcher registers in
// knownKeywords; this is the only place they carry a title a person would read.
var BUILTIN = [
  { keyword: "calc", title: "Calculator", aliases: ["math"] },
  { keyword: "run", title: "Commands", aliases: ["command", "commands"] },
  { keyword: "apps", title: "Applications", aliases: ["app", "launch"] },
  { keyword: "web", title: "Web Search", aliases: ["search", "google", "ddg"] },
  // This list itself. Somebody who found it once should not have to remember
  // which of the three ways in they used.
  { keyword: "h", title: "Keywords", aliases: ["help", "?", ":"] }
]

// What to call a scope in the header chip. Aliases answer too, so `google:`
// says Web Search rather than repeating the word back.
function builtinTitle(scope) {
  var name = String(scope || "").toLowerCase()

  for (var i = 0; i < BUILTIN.length; i++) {
    if (BUILTIN[i].keyword === name) return BUILTIN[i].title
    if (BUILTIN[i].aliases.indexOf(name) >= 0) return BUILTIN[i].title
  }
  return ""
}

// The one-character shorthands that reach this keyword, so `/` shows up beside
// Files rather than being a thing you have to already know.
function sigilsFor(sigils, keyword) {
  var out = []
  if (!sigils) return out

  for (var character in sigils) {
    if (sigils[character] === keyword) out.push(character)
  }
  return out
}

// Built-ins first, then extensions, then the user's quicklinks: most general to
// most personal, which is also the order someone reading the list expects.
//
// `sigils` is Query.SIGILS, passed in rather than restated here, because two
// copies of that table would eventually disagree.
function entries(sigils, extensions, quicklinks) {
  var out = []
  var seen = {}

  function add(group, keyword, title, aliases, glyph) {
    var name = String(keyword || "").toLowerCase()
    if (name === "" || seen[name]) return
    seen[name] = true

    out.push({
      group: group,
      keyword: name,
      title: String(title || name),
      aliases: (aliases || []).concat(sigilsFor(sigils, name)),
      glyph: String(glyph || "")
    })
  }

  for (var i = 0; i < BUILTIN.length; i++) {
    add("Built In", BUILTIN[i].keyword, BUILTIN[i].title, BUILTIN[i].aliases, "")
  }

  var loaded = extensions || []
  for (var j = 0; j < loaded.length; j++) {
    var ext = loaded[j]
    if (!ext) continue
    add("Extensions", ext.keyword, ext.title, ext.aliases, ext.glyph)
  }

  var links = quicklinks || []
  for (var k = 0; k < links.length; k++) {
    var link = links[k]
    if (!link || !link.keyword) continue
    add("Quicklinks", link.keyword, link.title, [], link.glyph)
  }

  return out
}
