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
import "Extensions.js" as Extensions
import "Settings.js" as Settings
import "Quicklinks.js" as Quicklinks

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
  readonly property string defaultEngine: String(root.config.defaultEngine || "google")

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

  // What the active filter is called, for the chip in the header.
  readonly property string scopeLabel: {
    var query = Query.parse(root.queryText, root.epoch)
    if (query.scope === "") return ""

    for (var i = 0; i < root.extensions.length; i++) {
      var ext = root.extensions[i]
      if (ext.keyword === query.scope || ext.aliases.indexOf(query.scope) >= 0) return ext.title
    }

    var links = root.config.quicklinks || []
    for (var j = 0; j < links.length; j++) {
      if (String(links[j].keyword || "").toLowerCase() === query.scope) return String(links[j].title)
    }

    var builtin = { calc: "Calculator", run: "Commands", web: "Web", apps: "Applications" }
    return builtin[query.scope] || query.scope
  }

  readonly property string activeView: {
    if (root.answerMode) return "answer"
    if (root.rows.length === 0) return "list"
    var wanted = String(root.rows[0].view || "list")
    return ["list", "hero", "cards", "split", "grid", "dashboard", "calendar"].indexOf(wanted) >= 0 ? wanted : "list"
  }

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
    root.queryText = text
    var query = Query.parse(text, ++root.epoch)

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
    root.rebuild()
  }

  function rebuild() {
    var query = Query.parse(root.queryText, root.epoch)
    root.rows = Rank.merge(root.buckets, query.scope, 60)

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
    if (!Query.routesTo(query, "run", ["command", "commands"]) || query.empty) {
      return put("commands", query, [])
    }

    var out = []
    for (var i = 0; i < Commands.COMMANDS.length; i++) {
      var command = Commands.COMMANDS[i]
      var fuzzy = Score.fuzzy(Commands.asEntry(command), Query.argFor(query, "run", ["command", "commands"]))
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

  // ------------------------------------------------------------ activation

  function activate(row) {
    if (!row) return

    if (row.pending) {
      // Hold Enter until the real answer replaces this placeholder.
      root.pendingActivate = row.key
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

    if (typeof action.run === "function") {
      dismiss()
      Qt.callLater(action.run)
      return
    }
    if (action.exec) {
      var command = String(action.exec)
      dismiss()
      Qt.callLater(function () { Util.execDetached(command) })
      return
    }
    if (action.row) root.activate(action.row)
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

      var query = Query.parse(root.queryText, root.epoch)
      var row = Calc.parse(calc.pendingText, text)
      if (!row) return root.put("calc", query, [])

      row.score = Rank.score(Rank.TIER.calc, 0, 0)
      row.view = "hero"
      row.run = (function (answer) {
        return function () {
          Util.execDetached("printf %s " + Util.shellQuote(answer) + " | wl-copy")
        }
      })(row.title)
      row.actions = [
        { title: "Copy Result", shortcut: "\u21B5", exec: "printf %s " + Util.shellQuote(row.title) + " | wl-copy" },
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
      if (ext) loaded.push(ext)
    }
    root.extensions = loaded
  }

  FileView {
    id: configFile
    path: Quickshell.env("HOME") + "/.config/omarchy/omacast.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.config = Settings.merge(text())
      root.checkAsk()
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
      height: header.height + ((root.rows.length > 0 || root.answerMode)
        ? resultsArea.height + footer.height + Style.space(14) : 0)

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
              // Three stages: leave the answer, clear the box, then close.
              if (root.answerMode) root.leaveAnswer()
              else if (input.text.length > 0) input.text = ""
              else root.dismiss()
              event.accepted = true
            } else if (event.key === Qt.Key_Down
                       || (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier))) {
              root.move(root.verticalStep)
              event.accepted = true
            } else if (event.key === Qt.Key_Up
                       || (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier))) {
              root.move(-root.verticalStep)
              event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
              root.move(1)
              event.accepted = true
            } else if (event.key === Qt.Key_Backtab) {
              root.move(-1)
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
      Loader {
        id: resultsArea
        anchors.top: header.bottom
        anchors.topMargin: Style.space(8)
        anchors.left: parent.left
        anchors.right: parent.right
        active: root.rows.length > 0 || root.answerMode

        sourceComponent: {
          switch (root.activeView) {
          case "hero": return heroView
          case "cards": return cardsView
          case "split": return splitView
          case "grid": return gridView
          case "dashboard": return dashboardView
          case "calendar": return calendarView
          case "answer": return answerView
          default: return listView
          }
        }
      }

      Component { id: listView;  ResultList  { launcher: root; width: resultsArea.width } }
      Component { id: heroView;  ResultHero  { launcher: root; width: resultsArea.width } }
      Component { id: cardsView; ResultCards { launcher: root; width: resultsArea.width } }
      Component { id: splitView; ResultSplit { launcher: root; width: resultsArea.width } }
      Component { id: gridView;  ResultGrid  { launcher: root; width: resultsArea.width } }
      Component { id: answerView; ResultAnswer { launcher: root; width: resultsArea.width } }
      Component { id: dashboardView; ResultDashboard { launcher: root; width: resultsArea.width } }
      Component { id: calendarView;  ResultCalendar  { launcher: root; width: resultsArea.width } }

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
          visible: root.currentActions().length > 1 || root.answerMode || root.answerAvailable
          text: {
            if (root.answerMode) return root.answerStreaming ? "\u238B  Stop" : "\u238B  Back"
            var actions = root.currentActions()
            var parts = []
            if (actions.length > 1) parts.push("\u21E7\u21B5  " + String(actions[1].title))
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
      }
    }
  }
}
