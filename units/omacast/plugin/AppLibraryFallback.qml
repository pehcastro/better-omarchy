import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Score.js" as Score

// Stands in for the host's `shell.appLibrary` when the shell hands this plugin
// none.
//
// Omarchy 4.0.3 replaced the real shell object with a capability-scoped one and
// injects the application library only for a plugin that declares the `menu`
// kind. The kind check reads the manifest that reached it through the panel
// loader's model, where `kinds` is no longer a plain array, so `Array.isArray`
// is false and every third-party plugin is told it has no menu. `appLibrary`
// arrives as null and the `apps` keyword answers with nothing.
//
// This is the same seven calls over the same DesktopEntries the host reads, so
// the provider above does not care which one it got. What it does not carry is
// the host's launch OSD: a launch here is silent, as it was before 4.0.0.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  // Ids from ~/.local/share/omarchy/default/omarchy/launcher.hides, which is
  // what the user edits, and from the desktop-environment scan, which resolves
  // OnlyShowIn/NotShowIn. Two maps rather than one merged map, because the two
  // scans finish independently and neither may clear the other's result.
  property var configuredHiddenIds: ({})
  property var desktopHiddenIds: ({})

  // icon name -> file on disk. Qt's themed lookup never re-scans after the
  // process starts, so an app installed since then has no icon without this.
  property var iconIndex: ({})
  property var pendingIconIndex: ({})

  property bool started: false

  // Nothing scans until something asks. When the host does provide a library,
  // this object is never reached and must cost nothing.
  function start() {
    if (root.started) return
    root.started = true
    hiddenScan.running = true
    iconScan.running = true
  }

  function entryName(entry) {
    return Score.entryName(entry)
  }

  function entrySubtext(entry) {
    return String((entry && entry.genericName) || "")
  }

  function normalizeId(id) {
    var value = String(id || "").trim()
    if (value.slice(-8) === ".desktop") value = value.slice(0, -8)
    return value
  }

  function isHidden(entry) {
    var id = String((entry && entry.id) || "")
    return root.configuredHiddenIds[id] === true || root.desktopHiddenIds[id] === true
  }

  // Rows shaped like the host's: { entry, score }, scored on the same bands,
  // sorted by score and then by name so an empty query is alphabetical.
  function sortedEntries(query) {
    root.start()
    var q = String(query || "").trim()
    var values = DesktopEntries.applications.values || []
    var rows = []
    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      if (!entry || entry.noDisplay) continue
      if (root.isHidden(entry)) continue
      var name = root.entryName(entry)
      if (!name) continue
      var score = Score.fuzzy(entry, q)
      if (score < 0) continue
      rows.push({ entry: entry, score: score, key: name.toLowerCase() })
    }
    rows.sort(function (a, b) {
      if (q && a.score !== b.score) return b.score - a.score
      if (a.key < b.key) return -1
      if (a.key > b.key) return 1
      return 0
    })
    return rows
  }

  function iconSource(icon) {
    var value = String(icon || "")
    if (value.length === 0) return Quickshell.iconPath("application-x-executable", true)
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    // The app/device index answers first. An unconstrained themed lookup can
    // resolve a name like "zoom" to an action icon instead of the application.
    var found = root.iconIndex[value]
    if (found) return Util.fileUrl(found)
    var themed = Quickshell.iconPath(value, true)
    if (themed.length > 0) return themed
    return Quickshell.iconPath("application-x-executable", true)
  }

  function refreshIcons() {
    root.start()
    if (!iconScan.running) iconScan.running = true
  }

  function launch(desktopId, name) {
    var id = root.normalizeId(desktopId)
    if (!id) return
    // gtk-launch resolves the entry, which keeps ids with spaces and entries
    // UWSM rejects working. The .desktop suffix has to stay or an id like
    // org.telegram.desktop never resolves. uwsm-app puts the app in
    // app-graphical.slice instead of under the compositor's own unit.
    Util.execArgv(["uwsm-app", "--", "gtk-launch", id + ".desktop"])
  }

  // One id per line, from either scan. Returns a set, so a lookup is a key.
  function parseHiddenIds(rawText) {
    var next = ({})
    var lines = String(rawText || "").split(/\n/)
    for (var i = 0; i < lines.length; i++) {
      var id = root.normalizeId(lines[i])
      if (id.length > 0) next[id] = true
    }
    return next
  }

  function hiddenScanCommand() {
    var desktop = [Quickshell.env("XDG_CURRENT_DESKTOP"), Quickshell.env("XDG_SESSION_DESKTOP"), Quickshell.env("DESKTOP_SESSION")]
      .filter(function (value) { return String(value || "").length > 0 }).join(":")
    var script = root.omarchyPath + "/shell/services/hidden-entries.sh"
    return Util.shellQuote(script) + " " + Util.shellQuote(desktop)
  }

  function iconScanCommand() {
    // Every app/device icon across the XDG icon dirs and /usr/share/pixmaps,
    // one path per line. SVG before PNG, and the parser keeps the first hit for
    // a name, so a scalable icon wins.
    return [
      'dirs="$HOME/.icons $HOME/.local/share/icons";',
      'IFS=":"; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs $d/icons"; done; unset IFS;',
      'for ext in svg png; do',
      '  for base in $dirs; do',
      '    [[ -d $base ]] && find "$base" \\( -path "*/apps/*" -o -path "*/devices/*" \\) -name "*.$ext" 2>/dev/null;',
      '  done;',
      '  find /usr/share/pixmaps -maxdepth 1 -name "*.$ext" 2>/dev/null;',
      'done'
    ].join(' ')
  }

  function indexIconLine(path) {
    var value = String(path || "").trim()
    if (value.length === 0) return
    var slash = value.lastIndexOf("/")
    var file = slash >= 0 ? value.slice(slash + 1) : value
    var dot = file.lastIndexOf(".")
    var name = dot > 0 ? file.slice(0, dot) : file
    if (name.length > 0 && root.pendingIconIndex[name] === undefined)
      root.pendingIconIndex[name] = value
  }

  QtObject {
    id: hiddenOutput
    property string text: ""
  }

  // Both scans run in a non-login shell on purpose. A login shell sources the
  // profile, and a tool like mise touches ~/.local/share on activation, which
  // the desktop-entry watcher monitors, so each scan would start the next one.
  Process {
    id: hiddenScan
    command: ["bash", "-c", root.hiddenScanCommand()]
    stdout: SplitParser { onRead: function (line) { hiddenOutput.text += line + "\n" } }
    onStarted: hiddenOutput.text = ""
    onExited: root.desktopHiddenIds = root.parseHiddenIds(hiddenOutput.text)
  }

  Process {
    id: iconScan
    command: ["bash", "-c", root.iconScanCommand()]
    stdout: SplitParser { onRead: function (line) { root.indexIconLine(line) } }
    onStarted: root.pendingIconIndex = ({})
    // Swapping the whole object re-evaluates every iconSource() call site, so
    // an icon found late appears without the list being rebuilt.
    onExited: root.iconIndex = root.pendingIconIndex
  }

  // A package install touches many entries at once. Coalesce the burst.
  Timer {
    id: iconDebounce
    interval: 750
    onTriggered: if (!iconScan.running) iconScan.running = true
  }

  FileView {
    // Empty until something asks, so an unused fallback watches no file.
    path: root.started ? root.omarchyPath + "/default/omarchy/launcher.hides" : ""
    watchChanges: true
    printErrors: false
    onLoaded: root.configuredHiddenIds = root.parseHiddenIds(text())
    onFileChanged: root.configuredHiddenIds = root.parseHiddenIds(text())
    onLoadFailed: root.configuredHiddenIds = ({})
  }

  Connections {
    target: DesktopEntries.applications
    enabled: root.started
    function onValuesChanged() {
      hiddenScan.running = true
      iconDebounce.restart()
    }
  }
}
