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

  // A `when` condition is checked on load, not per keystroke: an extension for
  // software you do not have should cost nothing at all. But a machine changes
  // under a shell that stays up for days. Writing an ~/.ssh/config, logging in
  // with gh, starting a docker daemon: each of those makes a keyword real, and
  // the keyword stayed silent until the next restart, which reads as broken
  // rather than as unavailable.
  //
  // So a failed check is re-run when you actually type the keyword, at most
  // every fifteen seconds. A passing check is never re-run: software rarely goes
  // away mid-session, and the cost of being wrong there is one empty answer.
  property bool available: true
  property bool checked: false
  property double lastCheck: 0
  readonly property int recheckMs: 15000

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
    if (!ext) return emit(q, [])

    if (!prov.available) {
      // Only a query that names this keyword pays for a re-check, so an
      // unavailable extension still costs nothing while you type anything else.
      if (ext.when !== "" && claims(q) && !availability.running
          && Date.now() - prov.lastCheck > prov.recheckMs) {
        prov.recheckQuery = q
        prov.lastCheck = Date.now()
        availability.command = ["bash", "-lc", ext.when]
        availability.running = true
      }
      return emit(q, [])
    }

    // Unscoped and not opted in: stay quiet. Shelling out to every extension on
    // every keystroke is how a launcher becomes slow enough to abandon.
    if (q.scope === "" && !ext.always) return emit(q, [])
    if (!claims(q)) return emit(q, [])

    var arg = Query.argFor(q, ext.keyword, ext.aliases)
    if (arg.length < ext.minChars) return emit(q, [])

    if (prov.launcher) prov.launcher.markWaiting(prov.id, true)

    prov.pendingEpoch = q.epoch
    prov.pendingArg = arg
    prov.pendingFilters = Query.extras(q, ext.keyword, ext.aliases)
    debounce.interval = ext.debounceMs
    debounce.restart()
  }

  function cancel() {
    if (prov.launcher) prov.launcher.markWaiting(prov.id, false)
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

  // The query that triggered a re-check, replayed if the check now passes so
  // the keystroke that made the extension available is also the one it answers.
  property var recheckQuery: null

  Component.onCompleted: {
    if (!ext) return
    if (ext.when === "") {
      prov.checked = true
      return
    }
    prov.lastCheck = Date.now()
    availability.command = ["bash", "-lc", ext.when]
    availability.running = true
  }

  Process {
    id: availability
    onExited: function (code) {
      prov.available = code === 0
      prov.checked = true

      var replay = prov.recheckQuery
      prov.recheckQuery = null
      if (prov.available && replay && prov.launcher
          && replay.epoch === prov.launcher.epoch) prov.query(replay)
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
