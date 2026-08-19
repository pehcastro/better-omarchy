import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.Commons
import qs.Ui
import "Query.js" as Query
import "Rank.js" as Rank
import "Score.js" as Score
import "Calc.js" as Calc
import "Commands.js" as Commands
import "Actions.js" as Actions
import "Extensions.js" as Extensions
import "Settings.js" as Settings
import "Quicklinks.js" as Quicklinks
import "Frecency.js" as Frecency
import "Help.js" as Help
import "Recents.js" as Recents
import "Pins.js" as Pins
import "Accent.js" as Accent

// OmaCast: one box that answers with apps, arithmetic, Omarchy commands, or
// the web.
//
// The shell injects `shell`, `manifest` and `omarchyPath` by name, calls
// open(payloadJson) and close(), and reads `opened`. `keepLoaded: true` in the
// manifest keeps this instance alive between summons, so close() has to reset
// state and stop background work; nothing here is constructed fresh.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string queryText: ""
  property int selectedIndex: 0
  property bool cursorMoved: false
  property string selectedKey: ""

  // Bumped on every keystroke. Every async result carries the epoch it was
  // asked for and is dropped when it no longer matches, so a slow process
  // cannot repopulate the list two keystrokes later.
  property int epoch: 0

  // providerId -> { epoch, text, rows }
  property var buckets: ({})
  property var rows: []

  // Providers that have been asked and have not answered yet. A slow shell-out
  // otherwise looks identical to one that found nothing.
  property var waiting: ({})
  // Busy for long enough that saying so is information rather than noise.
  property bool slowBusy: false

  onBusyChanged: {
    if (root.busy) slowTimer.restart()
    else { slowTimer.stop(); root.slowBusy = false }
  }

  Timer {
    id: slowTimer
    interval: 400
    onTriggered: root.slowBusy = root.busy
  }

  readonly property bool busy: {
    for (var key in root.waiting) {
      if (root.waiting[key]) return true
    }
    return false
  }

  // Enter pressed on a placeholder row. The engine fires it once the real row
  // arrives, so typing 1+1 and hitting Enter never launches an app instead.
  property string pendingActivate: ""

  readonly property var appLibrary: root.shell ? root.shell.appLibrary : null

  // Extensions, loaded from ~/.config/omarchy/omacast/extensions/*.json.
  // A unit drops a file there through its config/ folder, so a new source of
  // results needs no QML and no rebuild.
  readonly property string extensionsDir: Quickshell.env("HOME") + "/.config/omarchy/omacast/extensions"
  property var extensions: []
  property var extensionProviders: []

  // User settings, watched so an edit takes effect on the next keystroke with
  // no reload. Assigned as one object, so bindings re-evaluate once.
  property var config: Settings.DEFAULTS

  // What you have launched, and when. Reordering only, never across a tier.
  property var frecency: ({})
  property bool frecencyLoaded: false
  readonly property string defaultEngine: String(root.config.defaultEngine || "google")

  // What you searched for, and what you pinned. Beside the frecency file rather
  // than inside it: that one is pruned by decay, and neither of these decays.
  property var recents: []
  property var pins: ({})

  // `?` on its own is help. `?dogs` stays a web search, because the sigil is
  // worth more as the shorthand people already use than as a help key, and a
  // `?` with nothing after it has nothing to search for anyway.
  // Three ways in, because people reach for different ones. `?` is the sigil,
  // `h:` reads like every other keyword, and a lone `:` is what you type when
  // you know the launcher takes `word:` and cannot remember which words.
  //
  // A lone colon only. `x:` is a filter and `:x` is text, so the moment there
  // is anything either side of it this stops being a question about keywords.
  readonly property bool helpMode: {
    var t = root.queryText.trim()
    return t === "?" || t === ":" || t === "h:" || t === "help:"
  }

  // An empty box offers what you ran last, so reaching yesterday's query is one
  // key rather than remembering how you phrased it.
  readonly property bool recentMode: root.queryText.trim() === ""

  // Which layout the current results want. A provider declares it, so `=2+2`
  // renders one big answer and `music:` renders cards, without the launcher
  // knowing what either of them is.
  property bool actionPanelOpen: false

  // Ctrl+Enter: ask a model, stream the answer here. This is the one thing in
  // the launcher that takes time on purpose, so it owns the card while it runs
  // rather than being a row that fills in later.
  property bool answerMode: false
  property bool answerAvailable: false
  property bool answerStreaming: false
  property string answerText: ""
  property string answerQuestion: ""
  property string answerError: ""
  // Which provider answered the availability probe first.
  property var answerProvider: null
  readonly property string answerModel: root.answerProvider
    ? String(root.answerProvider.title || root.answerProvider.id) : ""

  // Every keyword and alias anything has registered: the built-ins, whatever
  // the extensions declare, the extra filters those extensions read, and the
  // user's own quicklinks. Query.parse only treats a `word:` as a filter when
  // the word is in here.
  readonly property var knownKeywords: {
    var out = ["calc", "math", "run", "command", "commands", "web", "search",
               "google", "ddg", "apps", "app", "launch", "settings", "action",
               "h", "help",
               // Extra filters the built-ins read alongside their own keyword.
               "format", "in", "type"]

    for (var i = 0; i < root.extensions.length; i++) {
      out.push(root.extensions[i].keyword)
      var aliases = root.extensions[i].aliases || []
      for (var j = 0; j < aliases.length; j++) out.push(aliases[j])
    }

    var links = root.config.quicklinks || []
    for (var k = 0; k < links.length; k++) {
      if (links[k].keyword) out.push(String(links[k].keyword).toLowerCase())
    }
    return out
  }

  // What the active filter is called, for the chip in the header.
  readonly property string scopeLabel: {
    if (root.helpMode) return "Keywords"

    var query = Query.parse(root.queryText, root.epoch, root.knownKeywords)
    if (query.scope === "") return ""
    if (query.scope === "settings") return "Settings"

    for (var i = 0; i < root.extensions.length; i++) {
      var ext = root.extensions[i]
      if (ext.keyword === query.scope || ext.aliases.indexOf(query.scope) >= 0) return ext.title
    }

    var links = root.config.quicklinks || []
    for (var j = 0; j < links.length; j++) {
      if (String(links[j].keyword || "").toLowerCase() === query.scope) return String(links[j].title)
    }

    return Help.builtinTitle(query.scope) || query.scope
  }

  // ------------------------------------------------------------ sources

  // providerId -> what a person would call it, and the colour it asked for.
  // Built from what is loaded rather than from a table, so an extension that
  // arrived in an update names and colours itself with nothing written twice.
  readonly property var sources: {
    var out = {
      apps: { title: "Applications", accent: "" },
      commands: { title: "Commands", accent: "" },
      quicklinks: { title: "Quicklinks", accent: "" },
      calc: { title: "Calculator", accent: "" },
      web: { title: "Web", accent: "" },
      paste: { title: "Clipboard", accent: "" },
      settings: { title: "Settings", accent: "" }
    }
    for (var i = 0; i < root.extensions.length; i++) {
      var ext = root.extensions[i]
      out[ext.id] = { title: ext.title, accent: String(ext.accent || "") }
    }
    return out
  }

  // A declared accent, walked to something legible on this card, cached per
  // provider. Doing the contrast maths inside a delegate binding would repeat
  // it for every row on every rebuild, and the answer only changes when the
  // theme or the extension list does.
  property var accentCache: ({})
  onBackgroundChanged: root.accentCache = ({})
  onSourcesChanged: root.accentCache = ({})

  function accentFor(providerId) {
    var cached = root.accentCache[providerId]
    if (cached !== undefined) return cached

    var spec = root.sources[providerId]
    var declared = spec ? Accent.parse(spec.accent) : null
    var safe = Accent.readable(declared,
                               { r: root.background.r, g: root.background.g, b: root.background.b },
                               { r: Color.accent.r, g: Color.accent.g, b: Color.accent.b })

    var out = Qt.rgba(safe.r, safe.g, safe.b, 1)
    var next = root.accentCache
    next[providerId] = out
    root.accentCache = next
    return out
  }

  // Whether the answer came from more than one place. Naming the source on
  // every row is only worth the ink when there is something to tell apart:
  // saying "Applications" nine times down a list of nine apps is noise.
  function tagSources(list) {
    var seen = {}
    var count = 0
    for (var i = 0; i < list.length; i++) {
      var id = String(list[i].providerId || "")
      if (seen[id]) continue
      seen[id] = true
      count += 1
    }

    for (var j = 0; j < list.length; j++) {
      var row = list[j]
      var spec = root.sources[String(row.providerId || "")]
      var name = spec ? spec.title : ""

      // Left undefined rather than defaulted, so a view can tell "this source
      // asked for green" from "this source asked for nothing" and only colour
      // the first. Defaulting here would paint every glyph in the launcher.
      row.accent = (spec && spec.accent !== "")
        ? root.accentFor(String(row.providerId || "")) : undefined
      // A fill row is a keyword or a past query, not an answer anything found,
      // so there is nothing to attribute it to.
      row.source = (count > 1 && name !== "" && row.fill === undefined) ? name : ""
    }
    return list
  }

  // ------------------------------------------------------------ row tail

  // One chip per row, and only one: the source when the answer came from more
  // than one place, and otherwise whatever the row called itself. A source chip
  // and an accessory chip and a category chip stacked up say three things where
  // the eye only wanted to know one.
  function chipFor(row) {
    return String((row && (row.source || row.accessory)) || "")
  }

  // How wide that column is: the widest chip in the current answer, so every
  // chip shares a left edge as well as a right one and a row without one leaves
  // the slot blank rather than letting its neighbours slide across.
  //
  // Measured rather than fixed, because a fixed width is either too narrow for
  // "Applications" or too wide for "gh:", and which of those is on screen
  // changes with every query. Kept here rather than in a view: the rows are the
  // launcher's, and two views measuring the same list twice would eventually
  // disagree about where the column is.
  property int chipColumn: 0

  TextMetrics {
    id: chipMetrics
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 0.2
  }

  // A function, not a binding: measuring means assigning to the metrics object,
  // and a binding that writes something in order to read it re-enters itself.
  function measureChips() {
    var widest = 0
    for (var i = 0; i < root.rows.length; i++) {
      var label = root.chipFor(root.rows[i])
      if (label === "") continue
      chipMetrics.text = label
      widest = Math.max(widest, chipMetrics.width)
    }
    // Plus the padding a Chip puts around its own label, and zero when nothing
    // in this answer has a chip: an empty column no one can see the reason for
    // is just a margin in the wrong place.
    root.chipColumn = widest > 0 ? Math.ceil(widest) + Style.space(16) : 0
  }

  onRowsChanged: root.measureChips()

  readonly property string activeView: {
    if (root.answerMode) return "answer"

    // Nothing yet, and something is still looking. Saying "nothing matches"
    // here is a wrong answer rather than a missing one, and a card that
    // collapses now and jumps open when the rows land is worse than one that
    // holds its shape.
    if (root.rows.length === 0 && root.slowBusy && root.queryText.trim() !== "") return "loading"

    if (root.rows.length === 0) return "list"
    var wanted = String(root.rows[0].view || "list")
    return root.knownViews.indexOf(wanted) >= 0 ? wanted : "list"
  }

  // Every view that has a component below. This was a second list written by
  // hand, and adding a view meant remembering both: `timegrid` shipped with its
  // component wired up and its name missing here, so its rows silently drew as
  // a plain list and looked like the script was wrong.
  readonly property var knownViews: ["list", "hero", "cards", "split", "grid",
    "dashboard", "calendar", "player", "slider", "form", "timegrid", "zones",
    "gitrepo", "loading"]

  // The [menu] surface tokens, so a theme that styles the Omarchy menu styles
  // this too, with no extra work from the user.
  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color scrim: Color.menu.scrim
  readonly property color selectedBackground: Color.menu.selectedBackground
  readonly property color selectedText: Color.menu.selectedText
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
  readonly property string fontFamily: Style.font.menuFamily

  readonly property int cardWidth: Math.min(Style.space(Number(root.config.cardWidth) || 620), panel.width - Style.gapsOut * 2)
  readonly property int maxRows: Number(root.config.maxRows) || 9

  // ------------------------------------------------------------ lifecycle

  function open(payloadJson) {
    pinScreen()
    loadExtensions()
    readClipboard()
    root.opened = true
    if (root.config.resetOnOpen !== false) root.queryText = ""
    root.pendingActivate = ""
    resetSelection()
    setQuery(root.queryText)
    input.text = root.queryText
    if (root.appLibrary) root.appLibrary.refreshIcons()
    Qt.callLater(function () {
      input.forceActiveFocus()
      input.selectAll()
    })
  }

  function close() {
    root.opened = false
    calc.cancel()
    for (var i = 0; i < root.extensionProviders.length; i++) {
      root.extensionProviders[i].cancel()
    }
    root.buckets = ({})
    root.rows = []
    root.pendingActivate = ""
    root.actionPanelOpen = false
    root.clipboardUrl = ""
    root.flowStack = []
    leaveAnswer()
  }

  function toggle() {
    if (root.opened) dismiss()
    else open("")
  }

  // Tell the shell, do not just hide. It tracks open panels in its own set, and
  // a close that skips this leaves the entry stale, so the next toggle inverts.
  function dismiss() {
    close()
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide((root.manifest && root.manifest.id) || "bo.omacast")
    }
  }

  // A bare PanelWindow binds to Quickshell.screens[0], not the focused output.
  // Pin before `opened` goes true: reassigning `screen` on a mapped layer
  // surface recreates it and drops the keyboard grab.
  function pinScreen() {
    var monitor = Hyprland.focusedMonitor
    if (!monitor) return

    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (String(screens[i].name) === String(monitor.name)) {
        panel.screen = screens[i]
        return
      }
    }
  }

  // ------------------------------------------------------------ querying

  function setQuery(text) {
    // A confirmation belongs to the query that raised it. Typing anything else
    // is walking away from the question, and a banner that outlives the query
    // it asked about turns the next Enter into a surprise.
    if (root.pendingAction && text.trim() !== "/" + root.pendingAction.id) {
      root.pendingAction = null
    }

    root.queryText = text
    var query = Query.parse(text, ++root.epoch, root.knownKeywords)

    queryHelp(query)
    queryPaste(query)
    querySettings(query)
    queryRecent(query)
    queryActions(query)
    queryApps(query)
    queryCommands(query)
    queryQuicklinks(query)
    queryWeb(query)
    calc.run(query)

    for (var i = 0; i < root.extensionProviders.length; i++) {
      root.extensionProviders[i].query(query)
    }

    rebuild()
  }

  function put(providerId, query, producedRows) {
    putRaw(providerId, query.epoch, producedRows)
  }

  // Every result carries the epoch it was asked for. A slow extension finishing
  // two keystrokes late is dropped here, which is the whole staleness story.
  function putRaw(providerId, epoch, producedRows) {
    if (epoch !== root.epoch) return
    var next = root.buckets
    next[providerId] = { epoch: epoch, rows: producedRows }
    root.buckets = next

    var pending = root.waiting
    pending[providerId] = false
    root.waiting = pending

    root.rebuild()
  }

  function markWaiting(providerId, yes) {
    // A fresh object, not the same one mutated and put back. QML compares by
    // identity, so reassigning the object it already holds changes nothing and
    // `busy` never re-evaluated: the spinner almost never appeared and the
    // loading state never appeared at all.
    var pending = {}
    for (var key in root.waiting) pending[key] = root.waiting[key]
    pending[providerId] = yes === true
    root.waiting = pending
  }

  function rebuild() {
    var query = Query.parse(root.queryText, root.epoch, root.knownKeywords)
    var merged = Rank.merge(root.buckets, query.scope, 60)
    if (root.config.frecency !== false && root.frecencyLoaded) {
      Frecency.apply(merged, root.frecency, Date.now())
    }
    // Pins are not part of the frecency setting: ranking by use is a guess you
    // can switch off, and a pin is an instruction you gave on purpose.
    Pins.apply(merged, root.pins)
    merged.sort(Rank.byScore)
    // After the sort, because whether a row names its source depends on what
    // else survived into the answer beside it.
    root.tagSources(merged)
    root.rows = merged

    if (!root.cursorMoved) {
      root.selectedIndex = 0
    } else {
      var at = Rank.indexOfKey(root.rows, root.selectedKey)
      root.selectedIndex = at >= 0 ? at : 0
    }
    root.selectedKey = root.rows.length > 0 ? root.rows[root.selectedIndex].key : ""

    // A queued Enter fires as soon as its placeholder resolves.
    if (root.pendingActivate !== "") {
      var index = Rank.indexOfKey(root.rows, root.pendingActivate)
      if (index >= 0 && !root.rows[index].pending) {
        var target = root.pendingActivate
        root.pendingActivate = ""
        activate(root.rows[index])
        return
      }
    }
  }

  function resetSelection() {
    root.selectedIndex = 0
    root.cursorMoved = false
    root.selectedKey = ""
  }

  // ------------------------------------------------------------ providers

  // A row that only changes what is in the box. Enter on one leaves you typing
  // rather than running anything, which is what both `?` and the recent list
  // are for, so `activate` gives `fill` its own branch.
  function fillRow(providerId, key, group, title, subtitle, accessory, glyph, fill, rank, actionTitle) {
    var row = {
      key: key,
      providerId: providerId,
      group: group,
      title: title,
      subtitle: subtitle,
      detail: "",
      accessory: accessory,
      iconSource: "",
      iconGlyph: glyph,
      fill: fill,
      score: rank,
      pending: false
    }
    // A self-reference, so the footer names what Enter does and Ctrl+K on the
    // row leads back through activate rather than opening an empty panel.
    row.actions = [{ title: actionTitle, shortcut: "\u21B5", row: row }]
    return row
  }

  // Built from what is loaded, never from a table: an extension that arrived in
  // an update and a quicklink added a minute ago are both in the list without
  // anyone having written them down twice.
  function queryHelp(query) {
    if (!root.helpMode) return put("help", query, [])

    // `settings` is a built-in, but Help's own list of those is a table in
    // another file. Handed in beside the extensions instead, so the keyword
    // appears under `?` without two places disagreeing about what is built in.
    var listed = [{ keyword: "settings", title: "Settings", aliases: [], glyph: "" }]
      .concat(root.extensions)
    var entries = Help.entries(Query.SIGILS, listed, root.config.quicklinks)
    var out = []

    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      out.push(fillRow("help",
                       "help:" + entry.keyword,
                       entry.group,
                       entry.title,
                       entry.aliases.join(", "),
                       entry.keyword + ":",
                       entry.glyph,
                       entry.keyword + ":",
                       // Listed in the order Help built them, which is the
                       // order a reader expects, so the rank only preserves it.
                       Rank.score(Rank.TIER.forced, Math.max(0, 90000 - i * 200), 0),
                       "Use Keyword"))
    }
    put("help", query, out)
  }

  // Not "recent", which is an extension id and would share its bucket.
  function queryRecent(query) {
    if (!root.recentMode) return put("recents", query, [])

    var out = []
    for (var i = 0; i < root.recents.length; i++) {
      var entry = String(root.recents[i])
      out.push(fillRow("recents",
                       "past:" + entry,
                       "Recent",
                       entry,
                       "",
                       "",
                       "",
                       entry,
                       Rank.score(Rank.TIER.forced, Math.max(0, 90000 - i * 200), 0),
                       "Search Again"))
    }
    put("recents", query, out)
  }

  // ------------------------------------------------------------ settings

  // `settings:` lists the extensions that declare any, and picking one opens a
  // form over its fields. Two steps rather than one screen of everything,
  // because the launcher is a text box and a wall of forty fields in it would
  // be a config editor wearing a launcher's clothes.
  //
  // An extension declares what it wants in its own JSON file:
  //
  //   "settings": [
  //     { "key": "org", "label": "Organisation", "value": "pehcastro" },
  //     { "key": "token", "label": "API Token", "secret": true }
  //   ]
  //
  // and reads the answers back out of omacast.json under its own id. The
  // launcher never passes them to the search command: a token on a command line
  // is a token in everyone's process list.
  function extensionById(id) {
    for (var i = 0; i < root.extensions.length; i++) {
      if (root.extensions[i].id === id) return root.extensions[i]
    }
    return null
  }

  function querySettings(query) {
    if (query.scope !== "settings") return put("settings", query, [])

    var arg = Query.argFor(query, "settings", []).trim()
    var chosen = root.extensionById(arg)

    if (chosen && chosen.settings.length > 0) return put("settings", query, [settingsForm(chosen)])

    var out = []
    for (var i = 0; i < root.extensions.length; i++) {
      var ext = root.extensions[i]
      if (!ext.settings || ext.settings.length === 0) continue
      if (arg !== "" && ext.id.indexOf(arg.toLowerCase()) !== 0
          && ext.title.toLowerCase().indexOf(arg.toLowerCase()) < 0) continue

      var saved = Settings.settingsFor(root.config, ext.id)
      var filled = 0
      for (var j = 0; j < ext.settings.length; j++) {
        if (String(saved[String(ext.settings[j].key)] || "") !== "") filled += 1
      }

      out.push({
        key: "settings:" + ext.id,
        providerId: "settings",
        group: "Settings",
        title: ext.title,
        subtitle: "",
        // What is already filled in, so a half-configured extension is visible
        // from the list rather than only from inside its own form.
        detail: filled + " of " + ext.settings.length + " set",
        accessory: ext.keyword + ":",
        iconSource: "",
        iconGlyph: ext.glyph,
        score: Rank.score(Rank.TIER.forced, Math.max(0, 90000 - i * 200), 0),
        pending: false,
        // A query and nothing else: choosing one is a step further in, not a
        // command, and Escape is what undoes it.
        actions: [{ title: "Edit", shortcut: "↵", query: "settings:" + ext.id }]
      })
    }
    put("settings", query, out)
  }

  // The form row for one extension. Built here rather than by the extension,
  // because writing the config file is the launcher's job and a command line
  // that could do it would also be a command line that could do anything else.
  function settingsForm(ext) {
    var saved = Settings.settingsFor(root.config, ext.id)
    var fields = []

    for (var i = 0; i < ext.settings.length; i++) {
      var spec = ext.settings[i] || {}
      var key = String(spec.key || "")
      if (key === "") continue

      fields.push({
        name: key,
        label: String(spec.label || key),
        // What is saved wins over what the extension suggested: the suggestion
        // is a default, and a default that overwrote an answer would not be one.
        value: saved[key] !== undefined ? String(saved[key]) : String(spec.value || ""),
        placeholder: String(spec.placeholder || ""),
        secret: spec.secret === true
      })
    }

    return {
      key: "settings:form:" + ext.id,
      providerId: "settings",
      group: "Settings",
      view: "form",
      title: ext.title,
      subtitle: "Saved to ~/.config/omarchy/omacast.json",
      submit: "Save",
      fields: fields,
      // Back to the list, which the flow stack reads as walking back out.
      query: "settings:",
      onSubmit: (function (id) {
        return function (values) { root.saveExtensionSettings(id, values) }
      })(ext.id),
      score: Rank.score(Rank.TIER.forced, 99000, 0),
      pending: false
    }
  }

  // Through the file's own text, so nothing the user wrote is lost and nothing
  // we merely defaulted to is written down as though they had chosen it.
  //
  // omacast.json is watched, so this write comes straight back as a reload and
  // the form's next visit shows what was saved. That round trip is only safe
  // because this file is ours: the same write into shell.json would make the
  // shell recompute its panel list and destroy this overlay mid-edit.
  function saveExtensionSettings(id, values) {
    var next = Settings.withExtensionSettings(configFile.text(), id, values)
    if (next === "") return

    configFile.setText(next)
    // And applied here rather than waiting for the watch to report it back: a
    // FileView does not raise onFileChanged for its own write, so the list you
    // return to would still say nothing had been saved.
    root.config = Settings.merge(next)
  }

  // ------------------------------------------------------------ clipboard

  // A URL you just copied, offered as the first row of an empty box.
  //
  // Copying a link and then summoning a launcher is one gesture with one
  // obvious ending, and typing the link back in by hand to reach it is absurd.
  property string clipboardUrl: ""

  // Only an explicit scheme counts. A bare `github.com/x` is a plausible URL
  // and also a plausible thing to have copied for any other reason, and this
  // row appears without being asked for, so the test has to be one that a
  // sentence, a path or a snippet of code can never accidentally pass.
  function urlInClipboard(text) {
    var value = String(text || "").replace(/^\s+/, "").replace(/\s+$/, "")
    if (value === "") return ""
    // Truncated at the read limit: whatever this is, we are not looking at all
    // of it, so we do not know that it is one URL and nothing else.
    if (value.length >= 480) return ""
    if (/\s/.test(value)) return ""
    if (!/^https?:\/\/[^\s\/]+\.[^\s]*$/i.test(value)) return ""
    return value
  }

  // head -c bounds the read: a clipboard holding a 40MB screenshot's worth of
  // base64 costs one closed pipe rather than a string the launcher then has to
  // hold. `-t text/plain` makes an image clipboard cost nothing at all, since
  // wl-paste exits without writing anything.
  //
  // Once per summon, never per keystroke.
  function readClipboard() {
    root.clipboardUrl = ""
    if (clipboardReader.running) return
    clipboardReader.command = ["bash", "-lc",
      "wl-paste -n -t text/plain 2>/dev/null | head -c 512"]
    clipboardReader.running = true
  }

  Process {
    id: clipboardReader
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var found = root.urlInClipboard(text)
        if (found === "" || !root.opened) return
        root.clipboardUrl = found
        // The read finishes after the first paint, so the empty box has to
        // redraw to gain the row.
        if (root.recentMode) root.refresh()
      }
    }
  }

  // Only on an empty box. Once you have started typing you have said what you
  // want, and a row about something you copied earlier is in the way.
  function queryPaste(query) {
    if (!root.recentMode || root.clipboardUrl === "") return put("paste", query, [])

    var url = root.clipboardUrl
    put("paste", query, [{
      key: "paste:" + url,
      providerId: "paste",
      group: "Clipboard",
      title: url,
      subtitle: "",
      detail: "On the clipboard",
      accessory: "Open",
      iconSource: "",
      // A link glyph, so the row reads as something you copied before the URL
      // itself has been read at all.
      iconGlyph: "",
      // Above the recent queries: it is the newer intent of the two.
      score: Rank.score(Rank.TIER.forced, 95000, 0),
      pending: false,
      run: function () { root.openSearch(url) },
      actions: [
        { title: "Open Link", shortcut: "\u21B5",
          exec: "omarchy-launch-browser " + Util.shellQuote(url) },
        { title: "Search For It", exec: "omarchy-launch-browser "
          + Util.shellQuote(Settings.url(root.config, root.defaultEngine, url)) }
      ]
    }])
  }

  function queryApps(query) {
    if (!Query.routesTo(query, "apps", ["app", "launch"]) || query.empty || !root.appLibrary) {
      return put("apps", query, [])
    }

    var found = root.appLibrary.sortedEntries(Query.argFor(query, "apps", ["app", "launch"]))
    var out = []
    for (var i = 0; i < found.length && i < 20; i++) {
      var entry = found[i].entry
      out.push({
        key: "app:" + entry.id,
        providerId: "apps",
        group: "Applications",
        title: root.appLibrary.entryName(entry),
        subtitle: root.appLibrary.entrySubtext(entry),
        accessory: "",
        iconSource: root.appLibrary.iconSource(entry.icon),
        iconGlyph: "",
        score: Rank.score(Rank.tierFor(found[i].score), Rank.local(found[i].score), 0),
        pending: false,
        run: (function (id, name) {
          return function () { root.appLibrary.launch(id, name) }
        })(entry.id, root.appLibrary.entryName(entry)),
        actions: (function (id, name) {
          return [
            { title: "Open", shortcut: "\u21B5", run: function () { root.appLibrary.launch(id, name) } },
            { title: "Copy Name", exec: "printf %s " + Util.shellQuote(name) + " | wl-copy" }
          ]
        })(entry.id, root.appLibrary.entryName(entry))
      })
    }
    put("apps", query, out)
  }

  function queryCommands(query) {
    // `command` used to be an alias here. It is the `/` scope now, which is for
    // what the launcher does to itself, so an Omarchy menu route reached
    // through `/` would be two unrelated lists under one key.
    if (!Query.routesTo(query, "run", ["commands"]) || query.empty) {
      return put("commands", query, [])
    }

    var out = []
    for (var i = 0; i < Commands.COMMANDS.length; i++) {
      var command = Commands.COMMANDS[i]
      var fuzzy = Score.fuzzy(Commands.asEntry(command), Query.argFor(query, "run", ["commands"]))
      if (fuzzy < 0) continue

      out.push({
        key: "cmd:" + command.id,
        providerId: "commands",
        group: "Commands",
        title: command.title,
        subtitle: command.subtitle,
        accessory: "",
        iconSource: "",
        iconGlyph: command.glyph,
        // A command beats an app only at equal match quality: the bias moves it
        // inside a tier and can never lift it into a higher one. Typing "the"
        // puts Change Theme above Thunderbird; typing "thun" still puts
        // Thunderbird first, because a name prefix outranks a substring.
        score: Rank.score(Rank.tierFor(fuzzy), Rank.local(fuzzy), 3000),
        pending: false,
        run: (function (exec) {
          return function () { Util.execDetached(exec) }
        })(command.exec)
      })
    }
    put("commands", query, out)
  }

  // ------------------------------------------------------------ actions

  // `/` and nothing else lists everything the launcher can do to itself.
  // Scoped, always: an action is an instruction, and an instruction that turns
  // up uninvited beside your search results is a way to clear your history by
  // accident.
  function queryActions(query) {
    if (query.scope !== "command") return put("actions", query, [])

    var arg = Query.argFor(query, "command", []).trim()
    var list = Actions.all(root.extensions)
    var out = []

    for (var i = 0; i < list.length; i++) {
      var action = list[i]
      var fuzzy = arg === "" ? 0 : Score.fuzzy(Actions.asEntry(action), arg)
      if (fuzzy < 0) continue

      out.push({
        key: "action:" + action.id,
        providerId: "actions",
        group: "Commands",
        title: action.title,
        subtitle: action.subtitle,
        accessory: "",
        iconSource: "",
        iconGlyph: action.glyph,
        // Declared order always, with the match used only to decide whether a
        // row belongs in the answer at all. Ranking these by match quality put
        // "Clear Everything" above "Clear Recent Queries" for `/clear`, because
        // it is the shorter title, which is the opposite of what that typing
        // means. There are six of them and their order is a decision someone
        // made; a fuzzy score is not a better one.
        // One tier for all of them, so declared order is the only thing that
        // sorts. Deriving a tier from the match put "Clear Everything" above
        // "Clear Recent Queries" for `/clear`: tier beats local score, and a
        // shorter title matches a little better. Nothing else answers inside
        // `/`, so there is no tier for these to be ranked against anyway.
        score: Rank.score(Rank.TIER.forced, 900 - i, 0),
        pending: false,
        keepOpen: !action.exec,
        run: (function (a) {
          return function () { root.runLauncherAction(a) }
        })(action)
      })
    }
    put("actions", query, out)
  }

  // An action that cannot be undone asks first, in the launcher rather than in
  // a dialog: a dialog would take the keyboard from an overlay that holds it
  // exclusively, and the answer to "are you sure" belongs where the question
  // was asked.
  property var pendingAction: null

  function runLauncherAction(action) {
    if (action.confirm && root.pendingAction !== action) {
      root.pendingAction = action
      return root.setInput("/" + action.id + " ")
    }
    root.pendingAction = null

    switch (action.effect) {
    case "clear.recents":
      root.recents = []
      stateSave.restart()
      return root.notify("Recent queries cleared")
    case "clear.pins":
      root.pins = ({})
      stateSave.restart()
      return root.notify("Pins cleared")
    case "clear.all":
      root.recents = []
      root.pins = ({})
      stateSave.restart()
      return root.notify("History and pins cleared")
    case "reload.extensions":
      root.loadExtensions()
      return root.notify("Extensions reloaded")
    case "open.settings":
      return root.setInput("settings:")
    }

    if (action.exec) {
      Util.execDetached(action.exec)
      root.dismiss()
    }
  }

  // Say what happened without closing. An action with nothing to show would
  // otherwise look like a key that did nothing at all.
  property string notice: ""

  function notify(text) {
    root.notice = String(text)
    noticeTimer.restart()
    root.requery(root.queryText)
  }

  Timer {
    id: noticeTimer
    interval: 2400
    onTriggered: root.notice = ""
  }

  // Quicklinks are found two ways, because people reach for both: by typing
  // part of the title, and by typing the keyword and then the argument.
  function queryQuicklinks(query) {
    var links = root.config.quicklinks || []
    if (links.length === 0) return put("quicklinks", query, [])

    var out = []

    for (var i = 0; i < links.length; i++) {
      var link = links[i]
      if (!link || !link.title) continue

      var keyword = String(link.keyword || "").toLowerCase()
      var addressed = keyword !== "" && query.scope === keyword
      var argument = ""
      var fuzzy = -1

      if (addressed) {
        argument = Query.argFor(query, keyword, [])
      } else {
        if (query.scope !== "" && query.scope !== "quicklinks") continue
        if (query.empty) continue
        fuzzy = Score.fuzzy(Quicklinks.asEntry(link, i), query.text)
        if (fuzzy < 0) continue
        // Typing a name finds the link; it cannot also supply an argument,
        // since the words that found it are not what goes in the placeholder.
        argument = ""
      }

      var command = Quicklinks.command(link, argument, Util.shellQuote)
      if (!command) continue

      var needsArgument = Quicklinks.takesArgument(link)
      out.push({
        key: "ql:" + (link.keyword || link.title),
        providerId: "quicklinks",
        group: "Quicklinks",
        title: String(link.title),
        subtitle: (link.tags || []).join(", "),
        detail: addressed && argument ? argument : "",
        accessory: needsArgument && keyword ? keyword + ":" : "",
        iconSource: "",
        iconGlyph: String(link.glyph || ""),
        // Addressed by keyword it is the answer, so it pins above apps. Found
        // by name it competes with everything else on match quality alone.
        score: addressed
          ? Rank.score(Rank.TIER.forced, 90000, 0)
          : Rank.score(Rank.tierFor(fuzzy), Rank.local(fuzzy), 2000),
        pending: false,
        run: (function (cmd) { return function () { Util.execDetached(cmd) } })(command),
        actions: (function (cmd, url) {
          var list = [{ title: "Open", shortcut: "\u21B5", exec: cmd }]
          if (url) list.push({ title: "Copy Link", exec: "printf %s " + Util.shellQuote(url) + " | wl-copy" })
          return list
        })(command, Quicklinks.expand(link, argument))
      })
    }

    put("quicklinks", query, out)
  }

  function queryWeb(query) {
    if (!Query.routesTo(query, "web", ["search", "google", "ddg"]) || query.empty) {
      return put("web", query, [])
    }

    var text = Query.argFor(query, "web", ["search", "google", "ddg"])
    if (text === "") return put("web", query, [])
    put("web", query, [{
      key: "web:" + text,
      providerId: "web",
      group: "Web",
      title: "Search the web for “" + text + "”",
      subtitle: (function () {
        var engine = Settings.engine(root.config, root.defaultEngine)
        return engine ? engine.title : root.defaultEngine
      })(),
      accessory: "",
      iconSource: "",
      iconGlyph: "",
      score: Rank.score(Rank.TIER.web, 0, 0),
      pending: false,
      run: function () { root.openSearch(root.engineUrl(root.defaultEngine, text)) },
      actions: root.searchActions(text)
    }])
  }

  function engineUrl(id, query) {
    return Settings.url(root.config, id, query)
  }

  function openSearch(url) {
    if (!url) return
    Util.execDetached("omarchy-launch-browser " + Util.shellQuote(url))
  }

  // The default engine first, then whatever else is configured. Ctrl+K is how
  // "search Google" becomes "ask ChatGPT" without touching a config file.
  function searchActions(text) {
    var seen = {}
    var out = []

    function add(id, primary) {
      if (seen[id]) return
      var engine = Settings.engine(root.config, id)
      if (!engine) return
      seen[id] = true
      out.push({
        title: engine.title,
        shortcut: primary ? "\u21B5" : "",
        exec: "omarchy-launch-browser " + Util.shellQuote(Settings.url(root.config, id, text))
      })
    }

    add(root.defaultEngine, true)
    var listed = root.config.engineActions || []
    for (var i = 0; i < listed.length; i++) add(String(listed[i]), false)
    return out
  }

  // ------------------------------------------------------------ asking

  function ask(question) {
    if (!root.answerAvailable || !root.answerProvider || !question) return

    root.answerMode = true
    root.answerStreaming = true
    root.answerText = ""
    root.answerError = ""
    root.answerQuestion = question

    var spec = root.answerProvider
    var command = String(spec.command || "")
      .replace("{model}", String(spec.model || ""))
      .replace("{query}", Util.shellQuote(question))

    // stdbuf so a line-buffered model actually streams: without it the answer
    // sits in a pipe buffer and arrives all at once, which defeats the point.
    //
    // stdin from /dev/null because a CLI that reads it will otherwise wait, and
    // some print a warning about it into the answer. stderr is folded in so a
    // real failure is visible rather than silent.
    askProcess.command = ["bash", "-lc", "stdbuf -oL " + command + " < /dev/null 2>&1"]
    askProcess.running = true
  }

  function stopAsking() {
    root.answerStreaming = false
    if (askProcess.running) askProcess.running = false
  }

  function leaveAnswer() {
    stopAsking()
    root.answerMode = false
    root.answerText = ""
    root.answerError = ""
    root.answerQuestion = ""
  }

  Process {
    id: askProcess
    stdout: SplitParser {
      // Split on newline rather than collecting: this is what makes the answer
      // appear a line at a time instead of in one lump at the end.
      onRead: function (line) {
        root.answerText += (root.answerText === "" ? "" : "\n") + line
      }
    }
    onExited: function (code) {
      root.answerStreaming = false
      if (code !== 0 && root.answerText === "") {
        root.answerError = "That command exited " + code + ". Check ask.command in omacast.json."
      }
    }
  }

  property int askProbeIndex: 0

  Process {
    id: askAvailability
    onExited: function (code) {
      var list = Settings.providers(root.config)
      var spec = list[root.askProbeIndex]

      if (code === 0 && spec) {
        root.answerProvider = spec
        root.answerAvailable = true
        return
      }

      root.askProbeIndex += 1
      Qt.callLater(root.probeNextProvider)
    }
  }

  // One probe per provider, in order, stopping at the first that exists. This
  // runs once at startup, never per keystroke, so an absent CLI costs nothing.
  function probeNextProvider() {
    var list = Settings.providers(root.config)
    if (root.askProbeIndex >= list.length) {
      root.answerAvailable = false
      root.answerProvider = null
      return
    }

    var spec = list[root.askProbeIndex]
    if (!spec || !spec.command) {
      root.askProbeIndex += 1
      return Qt.callLater(root.probeNextProvider)
    }

    if (!spec.when) {
      root.answerProvider = spec
      root.answerAvailable = true
      return
    }

    if (askAvailability.running) return
    askAvailability.command = ["bash", "-lc", String(spec.when)]
    askAvailability.running = true
  }

  function checkAsk() {
    root.askProbeIndex = 0
    root.answerAvailable = false
    root.answerProvider = null
    probeNextProvider()
  }

  // ------------------------------------------------------------ flows

  // The queries you walked in from, oldest first.
  //
  // An action that carries a `query` lands you somewhere else instead of
  // closing, which is what makes `wifi:` lead to one network and that network
  // lead to a password form. Three steps in, the only honest way out is the way
  // you came, so the launcher keeps the trail and Escape walks it.
  //
  // Escape already means back: leave the answer, clear the box, close. This is
  // one more stage at the front of that ladder rather than a second key, so
  // there is still exactly one thing to press when you want out.
  property var flowStack: []

  // True while the launcher is writing the box itself. Typing means you have
  // abandoned the flow and the trail is worthless; a follow-up query writing the
  // same box means you are still walking it, and the two look identical to
  // onTextChanged without this.
  property bool navigating: false

  function pushFlow(from) {
    var text = String(from || "")
    var stack = root.flowStack
    if (stack.length > 0 && String(stack[stack.length - 1]) === text) return

    var next = stack.slice()
    next.push(text)
    // Deeper than anyone walks on purpose, shallow enough that a script whose
    // follow-up lands back on itself cannot grow the trail forever.
    if (next.length > 8) next.shift()
    root.flowStack = next
  }

  function flowBack() {
    if (root.flowStack.length === 0) return

    var next = root.flowStack.slice()
    var back = String(next.pop())
    root.flowStack = next
    goTo(back)
  }

  // Land on another query at once, without the box reading it as typing.
  function goTo(text) {
    root.navigating = true
    resetSelection()
    setInput(text)
    root.navigating = false
  }

  // ------------------------------------------------------------ activation

  function activate(row) {
    if (!row) return

    // A keyword from `?`, or a query you ran before. Neither runs anything: the
    // point of picking one is to carry on typing, so this stays open.
    if (row.fill !== undefined) return root.setInput(String(row.fill))

    // A row with actions runs its first one, so the query follow-up a script
    // asked for is honoured whether Enter or the panel fired it.
    if (row.actions && row.actions.length > 0 && row.actions[0].query !== undefined) {
      return runAction(row.actions[0])
    }

    if (row.pending) {
      // Hold Enter until the real answer replaces this placeholder.
      root.pendingActivate = row.key
      return
    }

    root.remember(row)
    root.rememberQuery(root.queryText)

    // A row that changes the launcher rather than leaving it stays open, and
    // runs before anything closes: clearing your history and having the window
    // vanish looks the same as clearing your history and having nothing happen.
    if (row.keepOpen === true) {
      if (typeof row.run === "function") row.run()
      return
    }

    // Dismiss before running. Launching while an exclusive-focus layer surface
    // is still mapped puts the new window behind it, and Omarchy's launch OSD
    // would render underneath this overlay.
    var action = row.run
    dismiss()
    if (typeof action === "function") Qt.callLater(action)
  }

  // Every row's actions. The first is the primary and already runs on Enter;
  // the panel exists for the rest.
  function currentActions() {
    var row = root.rows[root.selectedIndex]
    if (!row) return []

    var list = []
    if (row.actions) {
      for (var i = 0; i < row.actions.length; i++) list.push(row.actions[i])
    }

    // A row with a primary but no declared list still deserves one entry, so
    // Ctrl+K never opens an empty panel on a working result.
    if (list.length === 0 && (row.run || row.exec)) {
      list.push({ title: String(row.accessory || "Open"), shortcut: "Return", row: row })
    }
    return list
  }

  function runAction(action) {
    if (!action) return
    root.actionPanelOpen = false

    // An action may ask to stay open and land on another query instead. That is
    // what makes pressing play on a search result show the player rather than
    // throwing you into Spotify's own window: the thing you started is the
    // thing you want to look at next.
    var followUp = action.query !== undefined ? String(action.query) : ""

    // Remember where this step started, so the chain can be walked back out.
    // A follow-up that lands on the query you are already looking at is a
    // refresh, not a step, and adding it would make Escape do nothing visible.
    if (followUp !== "" && followUp !== root.queryText) {
      var stack = root.flowStack
      if (stack.length > 0 && String(stack[stack.length - 1]) === followUp) {
        // Landing on where you came from is leaving, not going further in. A
        // settings form saving and returning to its own list would otherwise
        // stack a step whose only effect is to reopen the form you just left.
        root.flowStack = stack.slice(0, stack.length - 1)
      } else {
        root.pushFlow(root.queryText)
      }
    }

    if (typeof action.run === "function") {
      if (followUp === "") dismiss()
      Qt.callLater(action.run)
      if (followUp !== "") requery(followUp)
      return
    }
    if (action.exec) {
      var command = String(action.exec)
      if (followUp === "") dismiss()
      Qt.callLater(function () { Util.execDetached(command) })
      if (followUp !== "") requery(followUp)
      return
    }
    if (action.row) return root.activate(action.row)

    // Nothing to run, only somewhere to go. `requery` exists for the other
    // case, where something did run and the answer needs several passes to
    // catch up with it; here the wait would just read as a slow launcher.
    if (followUp !== "") root.goTo(followUp)
  }

  // Ask again, several times, because what just ran takes an unknown while to
  // show up. Playing a search result can mean an ISRC lookup, then OpenUri,
  // then Spotify actually starting: one poll at a fixed delay reports the old
  // track often enough to look broken.
  function requery(text) {
    followUp.text = text
    followUp.round = 0
    followUpTimer.restart()
  }

  function refresh() {
    root.setQuery(root.queryText)
  }

  QtObject {
    id: followUp
    property string text: ""
    property int round: 0
  }

  Timer {
    id: followUpTimer
    interval: 900
    repeat: true
    onTriggered: {
      followUp.round += 1

      if (followUp.round === 1) {
        // Flagged, so the box changing under the user does not read as the user
        // typing and throw away the trail back.
        root.navigating = true
        input.text = followUp.text
        root.navigating = false
        resetSelection()
        Qt.callLater(function () { input.forceActiveFocus() })
      } else {
        root.refresh()
      }

      // Four passes over roughly four seconds, which covers the slowest path
      // seen: a MusicBrainz lookup plus Spotify starting a track.
      if (followUp.round >= 4) followUpTimer.stop()
    }
  }

  // How far one press of Up or Down travels. In a grid that is a whole row,
  // because moving one cell at a time down a wall of thumbnails is maddening.
  readonly property int verticalStep: {
    if (root.activeView === "grid") {
      return Math.max(1, Math.floor((root.cardWidth - Style.space(24)) / Style.space(168)))
    }
    if (root.activeView === "dashboard") {
      return Math.max(1, Math.floor((root.cardWidth - Style.space(24)) / Style.space(190)))
    }
    return 1
  }

  // Move the cursor without activating. A calendar tab needs this: clicking
  // "Next" should change which month is drawn, not copy it and close.
  function select(index) {
    if (index < 0 || index >= root.rows.length) return
    root.cursorMoved = true
    root.selectedIndex = index
    root.selectedKey = root.rows[index].key
  }

  // Rows whose key changes on every keystroke teach nothing: a calculator answer
  // is keyed by its expression and a web search by its terms, so recording them
  // would fill the file with entries that are never seen twice.
  function remember(row) {
    if (!row || !row.key) return
    if (root.config.frecency === false) return
    if (row.providerId === "calc" || row.providerId === "web") return

    root.frecency = Frecency.record(root.frecency, row.key, Date.now())
    frecencySave.restart()
  }

  // The question, not the answer. Recents.record drops a bare keyword and a
  // repeat, and returns the list unchanged when there is nothing to add, so the
  // save only fires when something really moved.
  function rememberQuery(text) {
    // A `/` action is an instruction, not a question, and `/clear` recording
    // itself means the history is never actually empty afterwards.
    if (text.replace(/^\s+/, "").charAt(0) === "/") return

    var next = Recents.record(root.recents, text)
    if (next === root.recents) return

    root.recents = next
    stateSave.restart()
  }

  // A view that took the keyboard is giving it back. Called from the view's
  // own destruction rather than from whatever replaced it, because only the
  // thing that took the focus knows for certain that it still has it.
  function focusInput() {
    Qt.callLater(function () { input.forceActiveFocus() })
  }

  // Escape, pressed inside a view that owns the keyboard. The same ladder the
  // box's own Escape climbs, minus the stage that only means anything with a
  // text cursor in the box.
  function escapeFrom() {
    if (root.flowStack.length > 0) root.flowBack()
    else if (root.queryText.length > 0) root.setInput("")
    else root.dismiss()
  }

  // Put text in the box and search it, without closing.
  function setInput(text) {
    input.text = text
    input.cursorPosition = input.text.length
    Qt.callLater(function () {
      // A view that took the keyboard keeps it. Writing the box schedules this
      // refocus, and landing on a form schedules the form's own: both are
      // queued during the same assignment, and the box's was queued second, so
      // without this it wins and the first thing typed into a password field
      // goes into the search box instead.
      if (root.activeView === "form") return
      input.forceActiveFocus()
    })
  }

  // Pin the selected row so it leads every query it matches. Keyed the way
  // frecency is keyed, so the pin follows the thing rather than the search that
  // happened to find it.
  //
  // A calculator answer and a web row are keyed by what you typed, so pinning
  // one would pin a string you will never type again.
  function togglePin() {
    var row = root.rows[root.selectedIndex]
    if (!row || !row.key) return
    if (row.fill !== undefined) return
    if (row.providerId === "calc" || row.providerId === "web") return

    root.pins = Pins.toggle(root.pins, row.key)
    stateSave.restart()

    // Follow the row rather than the position: pinning it moves it, and the
    // cursor should end up where the row went.
    root.cursorMoved = true
    root.selectedKey = row.key
    root.rebuild()
  }

  function move(delta) {
    if (root.rows.length === 0) return
    root.cursorMoved = true
    root.selectedIndex = Math.max(0, Math.min(root.rows.length - 1, root.selectedIndex + delta))
    root.selectedKey = root.rows[root.selectedIndex].key
  }

  // ------------------------------------------------------------ calculator

  QtObject {
    id: calc

    // qalc costs about 40ms cold, which is long enough to matter per keystroke
    // but short enough that a 90ms debounce hides it entirely.
    property int inflightEpoch: -1
    property int pendingEpoch: -1
    property string pendingText: ""

    function run(query) {
      if (!Query.routesTo(query, "calc", ["math", "="]) || query.empty) {
        cancel()
        return root.put("calc", query, [])
      }

      var expression = Query.argFor(query, "calc", ["math"])
      if (query.scope !== "calc" && !Calc.looksLikeMath(expression)) {
        cancel()
        return root.put("calc", query, [])
      }

      // Synchronous placeholder, scored to the top, so Enter cannot fall
      // through to an app while qalc is still running.
      var row = Calc.placeholder(expression)
      row.score = Rank.score(Rank.TIER.calc, 0, 0)
      row.view = "hero"
      root.put("calc", query, [row])

      calc.pendingEpoch = query.epoch
      calc.pendingText = expression
      debounce.restart()
    }

    function cancel() {
      calc.pendingEpoch = -1
      debounce.stop()
      if (process.running) process.running = false
    }

    function start() {
      if (calc.pendingEpoch < 0) return
      calc.inflightEpoch = calc.pendingEpoch
      calc.pendingEpoch = -1
      // -m bounds the calculation: qalc will otherwise chew on a pathological
      // expression for as long as it takes.
      process.command = ["qalc", "-t", "-m", "200", "--", calc.pendingText]
      process.running = true
    }

    function finish(text) {
      if (calc.inflightEpoch !== root.epoch) return

      var query = Query.parse(root.queryText, root.epoch, root.knownKeywords)
      var row = Calc.parse(calc.pendingText, text)
      if (!row) return root.put("calc", query, [])

      row.score = Rank.score(Rank.TIER.calc, 0, 0)
      row.view = "hero"
      // Copying the answer and remembering it are one gesture, so one command
      // does both. `calc:` reads the file this writes, and its `when` is a test
      // that the file has anything in it, so a launcher that only copied would
      // leave that keyword permanently invisible.
      var record = "omacast-calc-history record " + Util.shellQuote(calc.pendingText)
        + " " + Util.shellQuote(row.title)

      row.run = (function (command) {
        return function () { Util.execDetached(command) }
      })(record)
      row.actions = [
        { title: "Copy Result", shortcut: "\u21B5", exec: record },
        { title: "Copy Expression", exec: "printf %s " + Util.shellQuote(calc.pendingText) + " | wl-copy" }
      ]
      root.put("calc", query, [row])
      root.rebuild()
    }

    property Timer debounceTimer: Timer {
      id: debounce
      interval: 90
      onTriggered: {
        // Setting running false sends SIGTERM; onExited then restarts with the
        // newer expression. Assigning command while running does not restart.
        if (process.running) process.running = false
        else calc.start()
      }
    }

    property Process proc: Process {
      id: process
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: calc.finish(text)
      }
      // onExited and onStreamFinished have no guaranteed order, so the payload
      // is read above and this only ever restarts.
      onExited: if (calc.pendingEpoch >= 0) Qt.callLater(calc.start)
    }
  }


  // ------------------------------------------------------------ extensions

  // Read every extension file as one JSON object per line. jq does the
  // per-file parsing so a malformed extension fails alone rather than taking
  // the rest of the directory with it.
  function loadExtensions() {
    if (extensionLoader.running) return
    extensionLoader.command = ["bash", "-lc",
      "shopt -s nullglob; for f in " + Util.shellQuote(root.extensionsDir) + "/*.json; do " +
      "jq -c --arg src \"$f\" '. + {__source: $src}' \"$f\" 2>/dev/null; done"]
    extensionLoader.running = true
  }

  function applyExtensions(text) {
    var parsed = Extensions.parseRows(text)
    var loaded = []
    for (var i = 0; i < parsed.length; i++) {
      var ext = Extensions.normalize(parsed[i], parsed[i].__source)
      if (!ext) continue
      if (!Settings.extensionEnabled(root.config, ext.id)) continue

      // Read off the raw object rather than out of normalize. Both of these
      // are the launcher's business and not the provider's: the accent is only
      // ever used for drawing, and the settings list is only ever read by the
      // settings form, so neither has any reason to travel through the code
      // that builds search commands.
      ext.accent = String(parsed[i].accent || "")
      ext.settings = Array.isArray(parsed[i].settings) ? parsed[i].settings : []
      loaded.push(ext)
    }
    root.extensions = loaded

    // The list of keywords is only as good as what has loaded. Extensions
    // arrive after the first paint, so a `?` already on screen has to redraw.
    if (root.opened && root.helpMode) root.refresh()
  }

  FileView {
    id: frecencyFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/omacast-frecency.json"
    printErrors: false
    atomicWrites: true
    // Not watched: this file is written from here, and reacting to our own
    // write would reload the ranking mid-keystroke for no gain.
    onLoaded: {
      root.frecency = Frecency.parse(text())
      root.frecencyLoaded = true
    }
    onLoadFailed: {
      root.frecency = ({})
      root.frecencyLoaded = true
    }
  }

  // Debounced, because activating a row is immediately followed by dismissing,
  // and writing during that is the one moment the launcher should not be busy.
  Timer {
    id: frecencySave
    interval: 1200
    onTriggered: {
      var pruned = Frecency.prune(root.frecency, Date.now())
      root.frecency = pruned
      frecencyFile.setText(JSON.stringify(pruned))
    }
  }

  // Recent queries and pins. Not in omacast.json: that file is the user's to
  // edit, and a launcher rewriting it under them would lose their comments and
  // their formatting the first time they searched for anything.
  FileView {
    id: stateFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/omacast-state.json"
    printErrors: false
    atomicWrites: true
    // Not watched, for the reason the frecency file is not watched: this is the
    // only writer, and reloading our own write would reorder mid-keystroke.
    onLoaded: {
      root.recents = Recents.parse(text())
      root.pins = Pins.parse(text())
    }
    onLoadFailed: {
      root.recents = []
      root.pins = ({})
    }
  }

  Timer {
    id: stateSave
    interval: 1200
    onTriggered: stateFile.setText(JSON.stringify({
      version: 1,
      recents: root.recents,
      pins: root.pins
    }))
  }

  FileView {
    id: configFile
    path: Quickshell.env("HOME") + "/.config/omarchy/omacast.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.config = Settings.merge(text())
      root.checkAsk()
      root.loadExtensions()
    }
    onFileChanged: reload()
    // No file is the normal case, so fall back to the defaults rather than
    // writing one the user never asked for.
    onLoadFailed: {
      root.config = Settings.DEFAULTS
      root.checkAsk()
    }
  }

  Process {
    id: extensionLoader
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyExtensions(text)
    }
  }

  // One provider per extension. Instantiator rebuilds the set whenever the
  // extension list changes, which is how a newly linked unit shows up without
  // restarting the shell.
  Instantiator {
    model: root.extensions
    delegate: ExtensionProvider {
      required property var modelData
      launcher: root
      ext: modelData
    }
    onObjectAdded: function (index, object) {
      var next = root.extensionProviders.slice()
      next.push(object)
      root.extensionProviders = next
    }
    onObjectRemoved: function (index, object) {
      object.cancel()
      var next = []
      for (var i = 0; i < root.extensionProviders.length; i++) {
        if (root.extensionProviders[i] !== object) next.push(root.extensionProviders[i])
      }
      root.extensionProviders = next
    }
  }

  Component.onCompleted: root.loadExtensions()

  // ------------------------------------------------------------ window

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omacast"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      radius: Style.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: 0

      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(parent.height * 0.18)

      // Nothing else stops a view drawing past this border. A view sizes itself
      // from its own content, and a view that gets that sum wrong used to spill
      // its last rows over the rounded corner and onto the wallpaper.
      clip: true

      height: header.height
        + ((root.rows.length > 0 || root.answerMode || root.activeView === "loading")
           ? resultsArea.height + footer.height + Style.space(14) : 0)
        + emptyState.height

      Behavior on height {
        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
      }

      // Swallow clicks so they do not reach the dismissing MouseArea behind.
      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Style.space(58)

        Text {
          id: prompt
          anchors.left: parent.left
          anchors.leftMargin: Style.space(18)
          anchors.verticalCenter: parent.verticalCenter
          text: ""
          color: Qt.darker(root.foreground, 1.6)
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        // A chip for the active filter, so `file:` reads as a mode you are in
        // rather than as four characters to re-read in the input.
        Chip {
          id: scopeChip
          anchors.left: prompt.right
          anchors.leftMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          accented: true
          text: root.scopeLabel
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        // A dot that pulses while something is still answering. Quieter than a
        // spinner, and it sits where the eye already is.
        Rectangle {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(20)
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(6)
          height: width
          radius: width / 2
          color: Color.accent
          // Only once the wait is long enough to be worth mentioning. `repo:`
          // answers in about 250ms, so a dot tied straight to `busy` blinked on
          // every keystroke and reported nothing: a spinner that is always on
          // is decoration.
          visible: root.slowBusy && root.rows.length > 0

          SequentialAnimation on opacity {
            running: root.busy
            loops: Animation.Infinite
            NumberAnimation { to: 0.2; duration: 450 }
            NumberAnimation { to: 1.0; duration: 450 }
          }
        }

        TextInput {
          id: input
          anchors.left: scopeChip.visible ? scopeChip.right : prompt.right
          anchors.leftMargin: Style.space(12)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(20)
          anchors.verticalCenter: parent.verticalCenter

          color: root.foreground
          selectionColor: Style.selectionFillFor(root.foreground, Color.accent)
          selectedTextColor: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          clip: true
          focus: true

          onTextChanged: {
            if (root.answerMode) root.leaveAnswer()
            // Typing is leaving the flow, not walking back through it. Only the
            // launcher's own writes to the box keep the trail alive.
            if (!root.navigating) root.flowStack = []
            root.resetSelection()
            root.setQuery(text)
          }

          // BeforeItem so navigation keys never reach the editor, and everything
          // else does. Left, Right, Home, End, Backspace and the usual editing
          // chords are deliberately absent: they belong to the text cursor.
          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function (event) {
            if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
              if (root.currentActions().length > 0) root.actionPanelOpen = !root.actionPanelOpen
              event.accepted = true
            } else if (root.actionPanelOpen) {
              // While the panel is up it owns navigation, so Up and Down move
              // between actions rather than between results underneath it.
              if (event.key === Qt.Key_Escape) root.actionPanelOpen = false
              else if (event.key === Qt.Key_Down) actionPanel.move(1)
              else if (event.key === Qt.Key_Up) actionPanel.move(-1)
              else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) actionPanel.activate()
              else return
              event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
              // Four stages: leave the answer, step back out of a flow, clear
              // the box, then close. Each one is the smallest undo available at
              // that moment, so holding Escape unwinds everything in order.
              if (root.answerMode) root.leaveAnswer()
              else if (root.flowStack.length > 0) root.flowBack()
              else if (input.text.length > 0) input.text = ""
              else root.dismiss()
              event.accepted = true
            } else if (event.key === Qt.Key_Down
                       || (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier))) {
              root.move(root.verticalStep)
              event.accepted = true
            } else if (event.key === Qt.Key_Up
                       || (event.key === Qt.Key_P
                           && (event.modifiers & Qt.ControlModifier)
                           && (event.modifiers & Qt.ShiftModifier))) {
              root.move(-root.verticalStep)
              event.accepted = true
            } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
              // Ctrl+P is the pin, and moving up gained the Shift. Up, Backtab
              // and Ctrl+Shift+P all still do it, and Ctrl+N is untouched, so
              // the one hand that never leaves the keys keeps a way up.
              root.togglePin()
              event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
              root.move(1)
              event.accepted = true
            } else if (event.key === Qt.Key_Backtab) {
              root.move(-1)
              event.accepted = true
            } else if ((root.activeView === "slider" || root.activeView === "timegrid")
                       && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
              // Left and right belong to the text cursor everywhere else, and
              // are taken back only while the thing on screen is a row of
              // ranges, where they are the whole point of the view.
              if (resultsArea.item && typeof resultsArea.item.nudge === "function") {
                resultsArea.item.nudge(event.key === Qt.Key_Right ? 1 : -1)
              }
              event.accepted = true
            } else if ((root.activeView === "grid" || root.activeView === "dashboard" || root.activeView === "calendar")
                       && event.key === Qt.Key_Right) {
              root.move(1)
              event.accepted = true
            } else if ((root.activeView === "grid" || root.activeView === "dashboard" || root.activeView === "calendar")
                       && event.key === Qt.Key_Left) {
              root.move(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_PageDown) {
              root.move(root.maxRows)
              event.accepted = true
            } else if (event.key === Qt.Key_PageUp) {
              root.move(-root.maxRows)
              event.accepted = true
            } else if ((event.modifiers & Qt.ControlModifier)
                       && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
              // Run the nth row without walking to it. The dim numbers down the
              // left of the list are the other half of this: a shortcut nobody
              // can see is a shortcut nobody uses.
              var nth = event.key - Qt.Key_1
              if (nth < root.rows.length) root.activate(root.rows[nth])
              event.accepted = true
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                       && (event.modifiers & Qt.ControlModifier)) {
              root.ask(input.text.trim())
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              if (event.modifiers & Qt.ShiftModifier) {
                // The second action, by keystroke rather than through the
                // panel. On a web row that is "ask ChatGPT" instead of Google,
                // which is the swap people make constantly.
                var actions = root.currentActions()
                if (actions.length > 1) root.runAction(actions[1])
                else root.activate(root.rows[root.selectedIndex])
              } else {
                root.activate(root.rows[root.selectedIndex])
              }
              event.accepted = true
            }
          }

          Text {
            anchors.fill: parent
            visible: input.text.length === 0
            verticalAlignment: Text.AlignVCenter
            text: "Search apps, do maths, run a command"
            color: Qt.darker(root.foreground, 1.8)
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }
        }
      }

      Rectangle {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.rows.length > 0 ? Math.max(1, Style.space(1)) : 0
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
      }

      // One Loader picks the layout the results asked for. Each view reads the
      // same rows and reports the same selection, so navigation is identical
      // whichever one is on screen.
      // Nothing to show, and nothing still coming. Without this the card just
      // collapses to a box with a cursor in it, which reads as broken rather
      // than as no results.
      Item {
        id: emptyState
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: visible ? Style.space(64) : 0
        // A notice keeps this open even on an empty box: an action that clears
        // your history leaves nothing to show, and a launcher that answers a
        // keypress with a blank card has not told you it worked.
        visible: root.notice !== "" || root.pendingAction !== null
          || (root.activeView !== "loading" && root.rows.length === 0 && !root.answerMode && root.queryText.trim() !== "")

        Text {
          anchors.centerIn: parent
          horizontalAlignment: Text.AlignHCenter
          color: root.notice !== "" ? Color.accent : Qt.darker(root.foreground, 1.9)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          text: {
            if (root.notice !== "") return root.notice
            if (root.pendingAction) return String(root.pendingAction.confirm)
              + "   \u21B5 again to confirm"
            if (root.busy) return "Searching\u2026"
            if (root.scopeLabel === "") return "Nothing matches that"

            // A bare keyword has nothing to quote back. `docker:` on a machine
            // with no containers was reading `matches ""`, which blames the
            // query for an empty answer the query did not cause.
            var term = root.queryText.replace(/^[a-z0-9_-]+:\s*/i, "")
            return term === ""
              ? "Nothing in " + root.scopeLabel
              : "Nothing in " + root.scopeLabel + " matches \u201C" + term + "\u201D"
          }
        }
      }

      Loader {
        id: resultsArea
        anchors.top: header.bottom
        anchors.topMargin: Style.space(8)
        anchors.left: parent.left
        anchors.right: parent.right
        active: root.rows.length > 0 || root.answerMode || root.activeView === "loading"

        // A view asks for the height its content wants, and the card grows to
        // hold it. Neither of them knows about the screen, so a long answer put
        // the footer below the bottom edge, out of reach.
        //
        // The cap goes here rather than on the card, because the footer follows
        // this item's bottom: a shorter card would have hidden the footer
        // instead of shortening the list. Every view clips, so what does not
        // fit is cut cleanly.
        readonly property int room: panel.height - card.y - header.height
          - footer.height - Style.space(14) - Style.space(24)

        height: Math.max(0, Math.min(item ? item.implicitHeight : 0, resultsArea.room))

        sourceComponent: {
          switch (root.activeView) {
          case "hero": return heroView
          case "cards": return cardsView
          case "split": return splitView
          case "grid": return gridView
          case "dashboard": return dashboardView
          case "calendar": return calendarView
          case "timegrid": return timeGridView
          case "zones": return zonesView
          case "gitrepo": return gitRepoView
          case "loading": return loadingView
          case "player": return playerView
          case "slider": return sliderView
          case "form": return formView
          case "answer": return answerView
          default: return listView
          }
        }
      }

      Component { id: listView;  ResultList  { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }
      Component { id: heroView;  ResultHero  { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }
      Component { id: cardsView; ResultCards { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }
      Component { id: splitView; ResultSplit { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }
      Component { id: gridView;  ResultGrid  { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }
      Component { id: answerView; ResultAnswer { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }
      Component { id: dashboardView; ResultDashboard { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }
      Component { id: calendarView;  ResultCalendar  { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }
      Component { id: timeGridView;  ResultTimeGrid  { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }
      Component { id: zonesView;     ResultZones     { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }
      Component { id: gitRepoView;   ResultGitRepo   { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }
      Component { id: loadingView;   ResultLoading   { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }
      Component { id: playerView;    ResultPlayer    { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }
      Component { id: sliderView;    ResultSlider    { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }
      Component { id: formView;      ResultForm      { launcher: root; width: resultsArea.width; maxHeight: resultsArea.room } }

      // The hint bar: what Enter does, and that there is more on Ctrl+K.
      Item {
        id: footer
        anchors.top: resultsArea.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: (root.rows.length > 0 || root.answerMode) ? Style.space(30) : 0
        visible: root.rows.length > 0 || root.answerMode

        Rectangle {
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: Math.max(1, Style.space(1))
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(18)
          anchors.verticalCenter: parent.verticalCenter
          text: {
            // A form's Enter is its own submit, and the row's first action is
            // whatever the extension attached for the list view it came from.
            if (root.activeView === "form" && root.rows.length > 0) {
              return "\u21B5  " + String(root.rows[0].submit || "Submit")
            }
            if (root.activeView === "slider") return "\u2190 \u2192  Adjust"
            var actions = root.currentActions()
            return actions.length > 0 ? "\u21B5  " + String(actions[0].title || "Open") : ""
          }
          color: Qt.darker(root.foreground, 1.8)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(18)
          anchors.verticalCenter: parent.verticalCenter
          visible: root.currentActions().length > 1 || root.answerMode
                   || root.answerAvailable || root.flowStack.length > 0
          text: {
            if (root.answerMode) return root.answerStreaming ? "\u238B  Stop" : "\u238B  Back"
            var actions = root.currentActions()
            var parts = []
            // First, because it is the way out of somewhere you were led, and
            // nothing else on this bar is about leaving.
            if (root.flowStack.length > 0) parts.push("\u238B  Back")
            // Truncated here rather than elided by the Text, because this line
            // is three labels sharing one row: a long second action drew on top
            // of the first instead of running out of room on its own.
            if (actions.length > 1) {
              var second = String(actions[1].title)
              if (second.length > 22) second = second.slice(0, 21) + "\u2026"
              parts.push("\u21E7\u21B5  " + second)
            }
            if (root.answerAvailable && input.text.trim() !== "") parts.push("\u2303\u21B5  Ask " + root.answerModel)
            if (actions.length > 1) parts.push("\u2303K  Actions")
            return parts.join("     ")
          }
          color: Qt.darker(root.foreground, 1.8)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      ActionPanel {
        id: actionPanel
        launcher: root
        visible: root.actionPanelOpen && root.rows.length > 0
        anchors.right: parent.right
        anchors.rightMargin: Style.space(12)
        // Below the card, not above it: anchored upward it runs off the top of
        // the screen as soon as the results are short.
        anchors.top: footer.bottom
        anchors.topMargin: Style.space(6)
        maxHeight: panel.height - (card.y + card.height + Style.space(6)) - Style.space(12)
      }
    }
  }
}
