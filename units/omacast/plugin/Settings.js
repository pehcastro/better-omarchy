.pragma library

// Everything the user can change, in ~/.config/omarchy/omacast.json.
//
// Not in shell.json: any write to that file makes the shell recompute its panel
// list, which destroys and recreates every overlay, so an unrelated bar edit
// would tear the launcher down mid-use.

var DEFAULTS = {
  version: 1,

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
    { id: "claude", title: "Claude", command: "claude -p {query}", when: "command -v claude" },
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
