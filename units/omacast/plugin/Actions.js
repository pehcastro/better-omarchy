.pragma library

// Things the launcher does to itself.
//
// A filter narrows what answers a question: `git:` means the git provider and
// nothing else. An action is not a narrowing, it is an instruction, and giving
// the two the same shape would mean `clear:` reads like a search for the word
// clear. So actions live behind `/`, the way they do in every other tool with a
// text box, and they never appear unless you ask for them.
//
// An action declares what it changes rather than a command to run, because most
// of them change the launcher's own state and there is nothing to exec. The
// launcher matches on `effect` and does the work; anything with an `exec`
// instead is a shell command, which is how an extension adds one.

var ACTIONS = [
  { id: "clear", title: "Clear Recent Queries", subtitle: "History", glyph: "",
    keywords: ["clear", "recent", "recents", "history", "forget"],
    effect: "clear.recents",
    confirm: "" },

  { id: "clear-pins", title: "Clear Pinned Results", subtitle: "History", glyph: "",
    keywords: ["clear", "pins", "pinned", "unpin"],
    effect: "clear.pins",
    confirm: "" },

  { id: "clear-all", title: "Clear Everything", subtitle: "History", glyph: "",
    keywords: ["clear", "all", "reset", "everything", "wipe"],
    effect: "clear.all",
    // Recents come back on their own; pins do not, and a pin is something the
    // user chose on purpose. One keypress should not throw that away silently.
    confirm: "Clear recent queries and every pin?" },

  { id: "reload", title: "Reload Extensions", subtitle: "Launcher", glyph: "",
    keywords: ["reload", "refresh", "extensions", "rescan"],
    effect: "reload.extensions",
    confirm: "" },

  { id: "settings", title: "Extension Settings", subtitle: "Launcher", glyph: "",
    keywords: ["settings", "config", "preferences", "options"],
    effect: "open.settings",
    confirm: "" },

  { id: "config", title: "Edit omacast.json", subtitle: "Launcher", glyph: "",
    keywords: ["config", "json", "edit", "file"],
    exec: "omarchy-launch-editor ~/.config/omarchy/omacast.json",
    confirm: "" }
]

// An extension may declare its own, so a keyword can carry a setup step rather
// than only answering questions:
//
//   "actions": [
//     { "id": "auth", "title": "Sign in to Spotify",
//       "exec": "omacast-spotify-auth" }
//   ]
//
// Namespaced by extension id, so two extensions may both offer "auth" without
// one shadowing the other, and shown as `/spotify auth`.
function fromExtensions(extensions) {
  var out = []
  for (var i = 0; i < (extensions || []).length; i++) {
    var ext = extensions[i]
    var declared = ext.actions || []
    for (var j = 0; j < declared.length; j++) {
      var a = declared[j]
      if (!a || !a.title) continue
      out.push({
        id: ext.id + "." + String(a.id || j),
        title: String(a.title),
        subtitle: String(a.subtitle || ext.title || ext.id),
        glyph: String(a.glyph || ext.glyph || ""),
        keywords: [String(ext.keyword)].concat(a.keywords || []),
        exec: String(a.exec || ""),
        confirm: String(a.confirm || "")
      })
    }
  }
  return out
}

function all(extensions) { return ACTIONS.concat(fromExtensions(extensions)) }

// Actions are matched on their words rather than fuzzily on the title, because
// `/clear` should find "Clear Recent Queries" first and the title alone would
// rank three clears equally.
function asEntry(action) {
  return {
    name: action.title,
    genericName: action.subtitle,
    keywords: action.keywords || [],
    comment: ""
  }
}
