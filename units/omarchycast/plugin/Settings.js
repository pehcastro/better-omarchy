.pragma library

// Everything the user can change, in ~/.config/omarchy/omarchycast.json.
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
