import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})

  property bool installed: false
  property bool running: false
  property bool needsLogin: false

  // Optimistic off state so the UI reacts the instant you click, rather than
  // waiting for the next status refresh. _desired is -1 while we just follow
  // the real state, or 0/1 while a toggle is still catching up.
  property int _desired: -1
  readonly property bool active: _desired === -1 ? running : (_desired === 1)
  property bool refreshing: false
  property string daemonStatus: "Unknown"
  property string statusText: "Checking…"
  property string selfName: ""
  property string selfFqdn: ""
  property string selfIp: ""
  property string profileName: ""
  property bool managementConnected: false
  property bool signalConnected: false
  property int peersConnected: 0
  property int peersTotal: 0
  property var peers: []
  property var networks: []
  property var profiles: []
  property string activeProfile: ""
  property string switchingProfile: ""
  property string settingNetworkId: ""
  property string actionStatus: ""
  property string lastError: ""

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 30, 5, 3600)
  readonly property bool busy: whichProcess.running || statusProcess.running || networksProcess.running
    || profilesProcess.running || actionProcess.running || upProcess.running
    || profileSwitchProcess.running || networkProcess.running
  readonly property var selectedNetworks: {
    var result = []
    for (var i = 0; i < networks.length; i++) {
      if (networks[i].selected) result.push(networks[i])
    }
    return result
  }

  property string _statusOutput: ""
  property string _statusError: ""
  property string _networksOutput: ""
  property string _profilesOutput: ""
  property string _actionOutput: ""
  property string _actionError: ""
  property string _upOutput: ""
  property string _upError: ""
  property bool _loginInProgress: false
  property bool _loginUrlOpened: false
  property double _lastProfilesRefreshMs: 0

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    if (n < min) n = min
    if (n > max) n = max
    return n
  }

  function shortName(fqdn) {
    return Model.shortName(fqdn)
  }

  function copyToClipboard(value) {
    var text = String(value || "")
    if (text === "") return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(text) + " | wl-copy"])
  }

  function copyPeerIp(peer) {
    if (!peer) return
    copyToClipboard(peer.ip)
  }

  function copyPeerName(peer) {
    if (!peer) return
    copyToClipboard(peer.name)
  }

  function copyPeerFqdn(peer) {
    if (!peer) return
    copyToClipboard(peer.fqdn)
  }

  function refresh(forceProfiles) {
    if (installed) {
      refreshAll(forceProfiles === true)
      return
    }
    if (!whichProcess.running) {
      refreshing = true
      whichProcess.command = ["which", "netbird"]
      whichProcess.running = true
    }
  }

  function refreshAll(forceProfiles) {
    if (!installed) return
    var launched = false
    if (!statusProcess.running) {
      _statusOutput = ""
      _statusError = ""
      refreshing = true
      statusProcess.command = ["netbird", "status", "--json"]
      statusProcess.running = true
      launched = true
    }
    if (!networksProcess.running) {
      _networksOutput = ""
      networksProcess.command = ["netbird", "networks", "list"]
      networksProcess.running = true
      launched = true
    }
    var now = Date.now()
    var shouldRefreshProfiles = forceProfiles === true || profiles.length === 0
      || now - _lastProfilesRefreshMs > 60000
    if (shouldRefreshProfiles && !profilesProcess.running) {
      _profilesOutput = ""
      _lastProfilesRefreshMs = now
      profilesProcess.command = ["netbird", "profile", "list"]
      profilesProcess.running = true
      launched = true
    }
    // Arm on the launch that needs watching and leave it alone after that.
    // Restarting it every refresh pushes the deadline out ahead of a hung
    // process forever once the refresh interval is shorter than the timeout,
    // and refreshIntervalSec goes down to five seconds.
    if (launched && !pollWatchdog.running) pollWatchdog.start()
  }

  function elideStatus(text) {
    var value = String(text || "").replace(/\s+/g, " ").trim()
    return value.length > 140 ? value.substring(0, 137) + "…" : value
  }

  function resetUnavailable(message) {
    running = false
    needsLogin = false
    _desired = -1
    daemonStatus = "Unavailable"
    statusText = message
    selfName = ""
    selfFqdn = ""
    selfIp = ""
    profileName = ""
    managementConnected = false
    signalConnected = false
    peersConnected = 0
    peersTotal = 0
    peers = []
    networks = []
    settingNetworkId = ""
  }

  function parseStatus(raw) {
    var parsed = Model.parseStatus(raw)
    if (!parsed.ok) {
      resetUnavailable(parsed.message || "Status error")
      lastError = parsed.error || "Failed to parse netbird status"
      console.warn("netbird", lastError)
      return
    }
    if (parsed.unavailable) {
      resetUnavailable(parsed.message || "Disconnected")
      return
    }

    daemonStatus = parsed.daemonStatus
    running = parsed.running
    // Reality caught up to the pending toggle — stop overriding.
    if (_desired !== -1 && running === (_desired === 1)) _desired = -1
    needsLogin = parsed.needsLogin
    selfName = parsed.selfName
    selfFqdn = parsed.selfFqdn
    selfIp = parsed.selfIp
    profileName = parsed.profileName
    managementConnected = parsed.managementConnected
    signalConnected = parsed.signalConnected
    peersConnected = parsed.peersConnected
    peersTotal = parsed.peersTotal
    peers = parsed.running ? parsed.peers : []

    if (needsLogin) {
      statusText = "Needs login"
    } else if (running) {
      statusText = "Connected"
      _loginInProgress = false
      _loginUrlOpened = false
    } else if (/disconnected/i.test(daemonStatus)) {
      statusText = "Disconnected"
    } else {
      statusText = daemonStatus
    }
    lastError = ""
  }

  function toggleNetbird() {
    if (!installed) return
    if (active) down()
    else up()
  }

  function down() {
    // No progress status here — the greyed icon and hero line already convey
    // the optimistic off; only surface a message if the command fails.
    _desired = 0
    runAction(["netbird", "down"])
  }

  function up() {
    if (!installed || upProcess.running) return
    _upOutput = ""
    _upError = ""
    _desired = 1
    _loginInProgress = true
    _loginUrlOpened = false
    upProcess.command = ["netbird", "up"]
    upProcess.running = true
  }

  function selectProfile(name) {
    var profile = String(name || "")
    if (!installed || profile === "" || profile === activeProfile || profileSwitchProcess.running) return
    switchingProfile = profile
    profileSwitchProcess.command = ["netbird", "profile", "select", profile]
    profileSwitchProcess.running = true
  }

  function toggleNetwork(network) {
    if (!installed || !running || !network || networkProcess.running) return
    var id = String(network.id || "")
    if (id === "") return
    settingNetworkId = id
    networkProcess.command = ["netbird", "networks", network.selected ? "deselect" : "select", id]
    networkProcess.running = true
  }

  function runAction(command, label) {
    if (actionProcess.running) return
    _actionOutput = ""
    _actionError = ""
    actionStatus = label || ""
    actionProcess.command = command
    actionProcess.running = true
  }

  function openAuthUrlFrom(text) {
    if (_loginUrlOpened) return true
    var url = Model.extractAuthUrl(text)
    if (url !== "") {
      // Turning on ended up needing browser auth — stop pretending we're up.
      _desired = -1
      _loginUrlOpened = true
      _loginInProgress = false
      Quickshell.execDetached(["omarchy-launch-browser", url])
      return true
    }
    return false
  }

  function handleUpOutput(data, isError) {
    var text = String(data || "")
    if (isError) _upError += text + "\n"
    else _upOutput += text + "\n"
    if (_loginInProgress && !_loginUrlOpened) openAuthUrlFrom(text)
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    // After a fresh boot the startup poll usually lands before the netbird
    // daemon has connected, which left the icon stale until the next periodic
    // refresh. Poll quickly until it shows up, or give up after ~30 seconds.
    id: startupRamp
    property int ticks: 0
    interval: 2000
    repeat: true
    running: true
    onTriggered: {
      ticks += 1
      if (root.running || ticks >= 15) startupRamp.running = false
      else root.refresh()
    }
  }

  Timer {
    id: delayedRefresh
    interval: 600
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    // Every poll is skipped while its own process is still running, so one that
    // never exits — netbird can hang on a network that is coming and going —
    // silently stops the panel refreshing at all, and it stays stopped. Reap
    // anything still running well inside the refresh interval so the next tick
    // starts clean.
    id: pollWatchdog
    interval: 15000
    repeat: false
    onTriggered: {
      if (statusProcess.running) statusProcess.running = false
      if (networksProcess.running) networksProcess.running = false
      if (profilesProcess.running) profilesProcess.running = false
    }
  }

  Timer {
    id: actionStatusTimer
    interval: 2200
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  Process {
    id: whichProcess
    running: false
    command: []
    onExited: function (exitCode) {
      root.installed = exitCode === 0
      if (root.installed) root.refreshAll()
      else {
        root.refreshing = false
        root.resetUnavailable("Not installed")
      }
    }
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusStdout; waitForEnd: true; onStreamFinished: root._statusOutput = text }
    stderr: StdioCollector { id: statusStderr; waitForEnd: true; onStreamFinished: root._statusError = text }
    onExited: function (exitCode) {
      root.refreshing = false
      var stdout = String(statusStdout.text || root._statusOutput || "")
      var stderr = String(statusStderr.text || root._statusError || "")
      // `netbird status --json` still prints usable JSON in some non-zero
      // cases, so try the payload before declaring the daemon unreachable.
      if (exitCode === 0 || stdout.trim().charAt(0) === "{") root.parseStatus(stdout)
      else {
        root.resetUnavailable("Disconnected")
        root.lastError = stderr.trim()
      }
    }
  }

  Process {
    id: networksProcess
    running: false
    command: []
    stdout: StdioCollector { id: networksStdout; waitForEnd: true; onStreamFinished: root._networksOutput = text }
    onExited: function (exitCode) {
      var stdout = String(networksStdout.text || root._networksOutput || "")
      root.networks = exitCode === 0 ? Model.parseNetworks(stdout) : []
    }
  }

  Process {
    id: profilesProcess
    running: false
    command: []
    stdout: StdioCollector { id: profilesStdout; waitForEnd: true; onStreamFinished: root._profilesOutput = text }
    onExited: function (exitCode) {
      var stdout = String(profilesStdout.text || root._profilesOutput || "")
      var parsed = Model.parseProfiles(exitCode === 0 ? stdout : "")
      root.profiles = parsed.profiles
      root.activeProfile = parsed.activeProfile
    }
  }

  Process {
    id: actionProcess
    running: false
    command: []
    stdout: StdioCollector { id: actionStdout; waitForEnd: true; onStreamFinished: root._actionOutput = text }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true; onStreamFinished: root._actionError = text }
    onExited: function (exitCode) {
      var stdout = String(actionStdout.text || root._actionOutput || "")
      var stderr = String(actionStderr.text || root._actionError || "")
      if (exitCode !== 0) {
        root._desired = -1
        root.lastError = elideStatus(stderr || stdout || "NetBird command failed")
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      } else {
        root.lastError = ""
        root.actionStatus = ""
      }
      delayedRefresh.restart()
    }
  }

  Process {
    id: upProcess
    running: false
    command: []
    stdout: SplitParser { onRead: function (data) { root.handleUpOutput(data, false) } }
    stderr: SplitParser { onRead: function (data) { root.handleUpOutput(data, true) } }
    onExited: function (exitCode) {
      var combined = String(root._upOutput || "") + "\n" + String(root._upError || "")
      var opened = root.openAuthUrlFrom(combined)
      if (exitCode !== 0 && !opened) {
        root._desired = -1
        root._loginInProgress = false
        root.lastError = elideStatus(combined || "netbird up failed")
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      } else if (!opened) {
        root._loginInProgress = false
        root.lastError = ""
        root.actionStatus = ""
      }
      delayedRefresh.restart()
    }
  }

  Process {
    id: profileSwitchProcess
    running: false
    command: []
    stdout: StdioCollector { id: profileSwitchStdout; waitForEnd: true }
    stderr: StdioCollector { id: profileSwitchStderr; waitForEnd: true }
    onExited: function (exitCode) {
      var stdout = String(profileSwitchStdout.text || "")
      var stderr = String(profileSwitchStderr.text || "")
      if (exitCode !== 0) {
        root.lastError = elideStatus(stderr || stdout || "Profile switch failed")
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      } else {
        root.lastError = ""
        root.actionStatus = ""
        root._lastProfilesRefreshMs = 0
      }
      root.switchingProfile = ""
      delayedRefresh.restart()
    }
  }

  Process {
    id: networkProcess
    running: false
    command: []
    stdout: StdioCollector { id: networkStdout; waitForEnd: true }
    stderr: StdioCollector { id: networkStderr; waitForEnd: true }
    onExited: function (exitCode) {
      var stdout = String(networkStdout.text || "")
      var stderr = String(networkStderr.text || "")
      if (exitCode !== 0) {
        root.lastError = elideStatus(stderr || stdout || "Exit node selection failed")
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      } else {
        root.lastError = ""
        root.actionStatus = ""
      }
      root.settingNetworkId = ""
      delayedRefresh.restart()
    }
  }
}
