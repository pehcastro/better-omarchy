import QtQuick
import Quickshell.Io
import qs.Commons
import "Query.js" as Query
import "Rank.js" as Rank
import "Extensions.js" as Extensions

// One instance per extension. It owns a Process, a debounce timer, and the
// epoch bookkeeping that keeps a slow answer from arriving after the question
// changed.
Item {
  id: prov

  property var launcher: null
  property var ext: null

  // A `when` condition is checked once, on load, not per keystroke. An
  // extension for software you do not have should cost nothing at all.
  property bool available: true
  property bool checked: false

  property int inflightEpoch: -1
  property int pendingEpoch: -1
  property string pendingArg: ""
  property var pendingFilters: ({})

  readonly property string id: ext ? ext.id : ""

  function claims(query) {
    if (!ext) return false
    return Query.routesTo(query, ext.keyword, ext.aliases)
  }

  function query(q) {
    if (!ext || !prov.available) return emit(q, [])

    // Unscoped and not opted in: stay quiet. Shelling out to every extension on
    // every keystroke is how a launcher becomes slow enough to abandon.
    if (q.scope === "" && !ext.always) return emit(q, [])
    if (!claims(q)) return emit(q, [])

    var arg = Query.argFor(q, ext.keyword, ext.aliases)
    if (arg.length < ext.minChars) return emit(q, [])

    prov.pendingEpoch = q.epoch
    prov.pendingArg = arg
    prov.pendingFilters = Query.extras(q, ext.keyword, ext.aliases)
    debounce.interval = ext.debounceMs
    debounce.restart()
  }

  function cancel() {
    prov.pendingEpoch = -1
    debounce.stop()
    killer.stop()
    if (process.running) process.running = false
  }

  function emit(q, rows) {
    if (!prov.launcher) return
    prov.launcher.put(prov.id, q, rows)
  }

  function start() {
    if (prov.pendingEpoch < 0) return
    prov.inflightEpoch = prov.pendingEpoch
    prov.pendingEpoch = -1

    var command = Extensions.buildCommand(ext, prov.pendingArg, prov.pendingFilters, Util.shellQuote)
    process.command = ["bash", "-lc", command]
    process.running = true
    killer.interval = ext.timeoutMs
    killer.restart()
  }

  function finish(text) {
    killer.stop()
    if (!prov.launcher) return
    if (prov.inflightEpoch !== prov.launcher.epoch) return

    var parsed = Extensions.parseRows(text)
    var rows = []
    for (var i = 0; i < parsed.length && i < ext.maxRows; i++) {
      var row = Extensions.toRow(ext, parsed[i], i)
      if (row.title === "") continue
      row.score = Rank.score(row.tier, row.local, 0)
      row.run = (function (exec) {
        return function () { if (exec) Util.execDetached(exec) }
      })(row.exec)
      rows.push(row)
    }

    prov.launcher.putRaw(prov.id, prov.inflightEpoch, rows)
  }

  Component.onCompleted: {
    if (!ext) return
    if (ext.when === "") {
      prov.checked = true
      return
    }
    availability.command = ["bash", "-lc", ext.when]
    availability.running = true
  }

  Process {
    id: availability
    onExited: function (code) {
      prov.available = code === 0
      prov.checked = true
    }
  }

  Timer {
    id: debounce
    onTriggered: {
      // running = false sends SIGTERM; onExited restarts with the newer query.
      // Assigning command while running does not restart on its own.
      if (process.running) process.running = false
      else prov.start()
    }
  }

  // A script that never returns must not hold the slot forever.
  Timer {
    id: killer
    onTriggered: if (process.running) process.running = false
  }

  Process {
    id: process
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: prov.finish(text)
    }
    // onExited and onStreamFinished have no guaranteed order, so the payload is
    // read above and this only ever restarts.
    onExited: if (prov.pendingEpoch >= 0) Qt.callLater(prov.start)
  }
}
