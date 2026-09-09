import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var settings: ({})

  // Process is alive. This alone is not enough to say dispatch works, but it
  // is the cheap signal and it is never wrong in the negative direction.
  property bool running: false
  // Bridge is registered AND consented. Read from Claude Desktop's own state
  // file, which is undocumented — see bridgeReadable before trusting it.
  property bool bridgeEnabled: false
  property bool bridgeReadable: false
  property string environmentId: ""
  property int pid: 0

  // Dispatch only actually works when the process is up and the bridge agrees.
  // When the state file cannot be parsed we fall back to process-only, so a
  // Claude Desktop update that renames these fields degrades to "probably up"
  // rather than to a permanently dark icon.
  readonly property bool active: running && (bridgeReadable ? bridgeEnabled : true)
  readonly property bool degraded: running && bridgeReadable && !bridgeEnabled

  readonly property string statusText: {
    if (!running) return "Claude Desktop not running — dispatch unavailable"
    if (degraded) return "Running, but bridge is not enabled"
    if (!bridgeReadable) return "Running (bridge state unreadable)"
    return "Bridge up — this machine is reachable for dispatch"
  }

  readonly property int refreshIntervalSec: {
    var v = settings && settings.refreshIntervalSec ? settings.refreshIntervalSec : 5
    return Math.max(2, Math.min(300, v))
  }
  readonly property bool autostart: boolSetting("autostart", true)
  readonly property bool keepAlive: boolSetting("keepAlive", true)

  function boolSetting(name, fallback) {
    if (!settings) return fallback
    var v = settings[name]
    if (v === undefined || v === null) return fallback
    if (typeof v === "string") return v === "true" || v === "1" || v === "yes"
    return v ? true : false
  }

  // A quit from this widget is deliberate, so keepAlive must not immediately
  // undo it. The suppression lasts until something launches the app again.
  // Reported by status.sh from a shared file, so every monitor's instance of
  // this widget agrees. Per-instance state did not work: only the instance you
  // clicked knew about the quit, and its peers relaunched the app.
  property bool suppressAutoLaunch: false
  readonly property string specialWorkspace: {
    var v = settings && settings.specialWorkspace ? settings.specialWorkspace : "claude"
    return String(v)
  }

  property string lastCommand: ""
  // Claude Desktop's user-data directory, discovered rather than assumed, so
  // a Flatpak or XDG_CONFIG_HOME install is found too.
  property string configDir: ""
  readonly property string helperDir: Qt.resolvedUrl(".").toString().replace("file://", "")
  property string _pidOut: ""
  property string _bridgeOut: ""

  function refresh() {
    if (!pidProcess.running) {
      _pidOut = ""
      pidProcess.command = ["sh", helperDir + "status.sh"]
      pidProcess.running = true
    }
  }

  // Show the window if hidden, hide it if visible. The window lives on a
  // special workspace, so this never restarts Claude Desktop and never drops
  // the bridge — the whole point of not doing kill-and-relaunch.
  function toggleWindow() {
    if (actionProcess.running) return
    // Both hyprctl dispatch syntaxes are handled by the helper; see toggle.sh.
    var argv = ["sh", helperDir + "toggle.sh", String(specialWorkspace)]
    lastCommand = JSON.stringify(argv)
    actionProcess.command = argv
    actionProcess.running = true
  }

  // Quit Claude Desktop. Closing its window only hides it to the tray, so a
  // real quit has to signal the main process — and it must be the main one:
  // killing a helper just makes Electron respawn it.
  function quit() {
    if (!running || actionProcess.running) return
    if (pid <= 0) return
    var argv = ["sh", helperDir + "quit.sh", String(pid)]
    lastCommand = JSON.stringify(argv)
    actionProcess.command = argv
    actionProcess.running = true
  }

  // Called on every poll that finds Claude Desktop down. autostart covers the
  // first sighting after login; keepAlive covers a later crash. Neither fires
  // while a deliberate quit is being held, or inside the launch cooldown.
  function superviseDown() {
    if (suppressAutoLaunch) return
    if (!autostart && !keepAlive) return
    // launch.sh owns the cooldown, shared across instances.
    launch()
  }

  function launch() {
    if (launchProcess.running) return
    var argv = ["sh", helperDir + "launch.sh"]
    lastCommand = JSON.stringify(argv)
    launchProcess.command = argv
    launchProcess.running = true
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: pidProcess
    running: false
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root._pidOut = text
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var kv = lines[i].split("=")
          if (kv.length < 2) continue
          var key = kv[0].trim()
          var value = lines[i].substring(lines[i].indexOf("=") + 1).trim()
          if (key === "dir") root.configDir = value
          else if (key === "running") root.running = value === "1"
          else if (key === "pid") root.pid = parseInt(value, 10) || 0
          else if (key === "suppressed") root.suppressAutoLaunch = value === "1"
        }
        if (root.running) {
          root.readBridge()

        } else {
          root.bridgeEnabled = false
          root.bridgeReadable = false
          root.environmentId = ""
          root.superviseDown()
        }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.running = false
    }
  }

  function readBridge() {
    if (bridgeProcess.running) return
    _bridgeOut = ""
    if (configDir === "") { bridgeReadable = false; return }
    bridgeProcess.command = ["cat", configDir + "/bridge-state.json"]
    bridgeProcess.running = true
  }

  Process {
    id: bridgeProcess
    running: false
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root._bridgeOut = text }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.bridgeReadable = false
        return
      }
      try {
        var doc = JSON.parse(root._bridgeOut)
        var enabled = false
        var env = ""
        // Keys are "<deviceId>:<accountId>" pairs; any consented entry counts.
        for (var k in doc) {
          var e = doc[k]
          if (e && e.enabled && e.userConsented) {
            enabled = true
            if (e.environmentId) env = e.environmentId
            break
          }
        }
        root.bridgeEnabled = enabled
        root.environmentId = env
        root.bridgeReadable = true
      } catch (err) {
        root.bridgeReadable = false
      }
    }
  }

  Process {
    id: launchProcess
    running: false
    command: []
    onExited: root.refresh()
  }

  Process {
    id: actionProcess
    running: false
    command: []
    onExited: root.refresh()
  }
}
