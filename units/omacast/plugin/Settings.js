.pragma library

// Everything the user can change, in ~/.config/omarchy/omacast.json.
//
// Not in shell.json: any write to that file makes the shell recompute its panel
// list, which destroys and recreates every overlay, so an unrelated bar edit
// would tear the launcher down mid-use.

var DEFAULTS = {
  version: 1,

  // The last few things you typed, shown on an empty box. Off, because half of
  // them are partial words from a query you abandoned and none of them is what
  // you opened the launcher to do. `true` turns it on.
  recents: false,

  // Which engine Enter uses on a web row. The rest become actions on Ctrl+K, so
  // the second choice is one keystroke away rather than a config edit.
  defaultEngine: "google",

  engines: [
    { id: "google", title: "Google", url: "https://www.google.com/search?q={}" },
    { id: "ddg", title: "DuckDuckGo", url: "https://duckduckgo.com/?q={}" },
    { id: "chatgpt", title: "Ask ChatGPT", url: "https://chatgpt.com/?q={}" },
    { id: "perplexity", title: "Ask Perplexity", url: "https://www.perplexity.ai/search?q={}" },
    { id: "youtube", title: "YouTube", url: "https://www.youtube.com/results?search_query={}" },
    { id: "github", title: "GitHub", url: "https://github.com/search?q={}" }
  ],

  // Which engines appear as actions, in this order. The default is added first
  // whether or not it is listed here.
  engineActions: ["google", "chatgpt", "ddg", "youtube", "github"],

  // Your own links, searchable by title and tag, and addressable by keyword.
  // A url with {} takes an argument: `gh omarchy` opens the search, `gh` alone
  // opens the placeholder-free part of the site.
  //
  //   { "title": "GitHub Issues", "keyword": "issues", "tags": ["dev"],
  //     "url": "https://github.com/pehcastro/{}/issues" }
  //
  // `open` replaces `url` when the link should run something instead, which is
  // how a quicklink becomes a shortcut to a folder or a script.
  quicklinks: [],

  // Ctrl+Enter asks a model and streams the answer into the card.
  //
  // Providers are tried in order and the first whose `when` succeeds is used,
  // so a machine with the Claude CLI signed in needs no configuration at all.
  // Set `askProvider` to force one by id.
  //
  // A provider's command gets {query} shell-quoted and {model} unquoted, must
  // write to stdout as it goes, and must exit when it is done. Anything with
  // that shape works, including a curl to an API you host.
  askProvider: "",

  askProviders: [
    // Sonnet at medium effort. The default model thinks for longer than anyone
    // waiting in a launcher will tolerate: a question that took twelve seconds
    // to start answering is a question the user has already given up on, and
    // one recording caught it never answering at all.
    { id: "claude", title: "Claude", model: "sonnet",
      command: "claude -p --model {model} --effort medium {query}",
      when: "command -v claude" },
    { id: "codex", title: "Codex", command: "codex exec --skip-git-repo-check {query}", when: "command -v codex" },
    { id: "gemini", title: "Gemini", command: "gemini -p {query}", when: "command -v gemini" },
    { id: "ollama", title: "Ollama", model: "llama3.2", command: "ollama run {model} {query}", when: "command -v ollama" },
    { id: "aichat", title: "aichat", command: "aichat {query}", when: "command -v aichat" },
    { id: "mods", title: "mods", command: "mods {query}", when: "command -v mods" }
  ],

  // Which built-in extensions answer. They ship with the launcher because none
  // of them works without it, so turning one off belongs here rather than in
  // `bo`: `bo remove files` would have meant uninstalling half a launcher.
  //
  // Absent means on. Name one false to silence it.
  //
  //   "extensions": { "radio": false, "theme": false }
  extensions: {},

  // What each extension was configured with, by extension id. An extension
  // declares the settings it wants in its own JSON file; `settings:` in the
  // launcher fills them in and writes them here.
  //
  //   "extensionSettings": { "gh": { "org": "pehcastro" } }
  //
  // A script reads its own back out of this file, which is why they live under
  // the id rather than being flattened into the top level: two extensions both
  // wanting a `token` must not be able to read each other's.
  extensionSettings: {},

  // Rank by what you actually use. Set false to rank purely on match quality.
  frecency: true,

  maxRows: 9,
  cardWidth: 620,

  // Clear the box between summons. Off means a re-summon reopens on the last
  // query, which suits a workflow of refining one search over several visits.
  resetOnOpen: true
}

function merge(text) {
  var config = {}
  for (var key in DEFAULTS) config[key] = DEFAULTS[key]

  if (!text) return config

  var user = null
  try {
    user = JSON.parse(text)
  } catch (e) {
    // A half-written file during an edit must not blank the settings.
    return config
  }
  if (!user || typeof user !== "object") return config

  for (var k in user) {
    if (user[k] !== null && user[k] !== undefined) config[k] = user[k]
  }

  // A user adding one engine should not have to restate the built-in list, so
  // theirs are merged over ours by id rather than replacing the array.
  if (user.engines) {
    var byId = {}
    var merged = []
    for (var i = 0; i < DEFAULTS.engines.length; i++) {
      byId[DEFAULTS.engines[i].id] = merged.length
      merged.push(DEFAULTS.engines[i])
    }
    for (var j = 0; j < user.engines.length; j++) {
      var engine = user.engines[j]
      if (!engine || !engine.id) continue
      if (byId[engine.id] !== undefined) merged[byId[engine.id]] = engine
      else merged.push(engine)
    }
    config.engines = merged
  }

  return config
}

// The provider to ask, honouring an explicit choice and otherwise leaving the
// order in the list to decide. Availability is settled at runtime, since only
// the shell can answer whether a command exists.
function providers(config) {
  var chosen = String(config.askProvider || "")
  var all = config.askProviders || []
  if (!chosen) return all

  var ordered = []
  for (var i = 0; i < all.length; i++) {
    if (String(all[i].id) === chosen) ordered.push(all[i])
  }
  // An id that matches nothing is a typo, not an instruction to ask nothing,
  // so fall back to the full list rather than going silent.
  return ordered.length > 0 ? ordered : all
}

// An extension is on unless the settings say otherwise, so a new one that ships
// in an update starts working rather than waiting to be listed.
function extensionEnabled(config, id) {
  var listed = config.extensions || {}
  return listed[id] !== false
}

// What one extension was configured with, as a plain object. Never null, so a
// caller can read a key off it without checking first.
function settingsFor(config, id) {
  var all = (config && config.extensionSettings) || {}
  var one = all[String(id)]
  return (one && typeof one === "object") ? one : {}
}

// The whole config file, with one extension's settings replaced.
//
// This is the only thing in the launcher that writes the user's own config, and
// it goes through the file's existing text rather than through the merged
// object it was parsed into: writing the merge back would bake every default
// into the file, so a later change to a default would silently not reach anyone
// who had ever opened a settings form.
//
// A file that will not parse is left alone. Returning "" rather than a fresh
// document is the point: someone is mid-edit in a text editor, and replacing
// their half-written JSON with ours would take the rest of it with it.
function withExtensionSettings(text, id, values) {
  var data = {}

  if (text && String(text).trim() !== "") {
    try {
      data = JSON.parse(text)
    } catch (e) {
      return ""
    }
    if (!data || typeof data !== "object" || Array.isArray(data)) return ""
  }

  var all = (data.extensionSettings && typeof data.extensionSettings === "object")
    ? data.extensionSettings : {}

  var one = {}
  for (var key in values) one[key] = String(values[key])
  all[String(id)] = one

  data.extensionSettings = all
  // Two-space indent and a trailing newline, because this file is meant to be
  // opened and read by hand after we have written it.
  return JSON.stringify(data, null, 2) + "\n"
}

function engine(config, id) {
  for (var i = 0; i < config.engines.length; i++) {
    if (config.engines[i].id === id) return config.engines[i]
  }
  return null
}

function url(config, id, query) {
  var found = engine(config, id)
  if (!found) return ""
  return String(found.url).replace("{}", encodeURIComponent(query))
}
