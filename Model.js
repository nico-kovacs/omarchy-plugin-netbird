// Pure parsing helpers for the NetBird widget. No QML imports live here on
// purpose, so this file can be exercised directly under node.

var PEER_DOMAIN_SUFFIX = ".netbird.cloud"

function stripCidr(address) {
  var value = String(address || "").trim()
  var slash = value.indexOf("/")
  return slash === -1 ? value : value.substring(0, slash)
}

// Peers are reported as FQDNs. The bar has no room for the domain, and every
// peer in a tenant shares it, so it carries no information.
function shortName(fqdn) {
  var value = String(fqdn || "").trim()
  if (value === "") return ""
  var lower = value.toLowerCase()
  if (lower.length > PEER_DOMAIN_SUFFIX.length &&
      lower.indexOf(PEER_DOMAIN_SUFFIX) === lower.length - PEER_DOMAIN_SUFFIX.length) {
    return value.substring(0, value.length - PEER_DOMAIN_SUFFIX.length)
  }
  return value.split(".")[0] || value
}

// NetBird reports latency in nanoseconds; zero means "not measured yet"
// rather than "instant", so it must not render as 0ms.
function latencyMs(nanos) {
  var n = Number(nanos)
  if (!isFinite(n) || n <= 0) return -1
  return Math.round(n / 1000000)
}

function formatLatency(nanos) {
  var ms = latencyMs(nanos)
  if (ms < 0) return ""
  if (ms < 1000) return ms + "ms"
  return (ms / 1000).toFixed(1) + "s"
}

function connectionLabel(peer) {
  var type = String((peer && peer.connectionType) || "").trim()
  if (type === "" || type === "-") return ""
  return type
}

function peerFromStatus(raw) {
  var peer = raw || {}
  var status = String(peer.status || "")
  var fqdn = String(peer.fqdn || "")
  return {
    id: String(peer.publicKey || fqdn),
    fqdn: fqdn,
    name: shortName(fqdn),
    ip: stripCidr(peer.netbirdIp),
    status: status,
    connected: status.toLowerCase() === "connected",
    connectionType: connectionLabel(peer),
    latency: formatLatency(peer.latency),
    // A peer advertising routes is what NetBird calls an exit node / network
    // resource; the widget only needs to know it advertises something.
    routes: Array.isArray(peer.networks) ? peer.networks : []
  }
}

function parseStatus(raw) {
  var text = String(raw || "").trim()
  if (text === "") return { ok: true, unavailable: true, message: "Disconnected" }

  try {
    var data = JSON.parse(text)
    var daemon = String(data.daemonStatus || "Unknown")
    var lowered = daemon.toLowerCase()
    var peers = []
    var details = (data.peers && data.peers.details) || []

    for (var i = 0; i < details.length; i++) {
      peers.push(peerFromStatus(details[i]))
    }

    peers.sort(function (a, b) {
      // Connected peers first, then alphabetical, so the useful rows are on top.
      if (a.connected !== b.connected) return a.connected ? -1 : 1
      return String(a.name).localeCompare(String(b.name))
    })

    var management = data.management || {}
    var signal = data.signal || {}

    return {
      ok: true,
      unavailable: false,
      daemonStatus: daemon,
      running: lowered === "connected",
      needsLogin: lowered === "needslogin" || lowered === "needs login",
      selfName: shortName(data.fqdn),
      selfFqdn: String(data.fqdn || ""),
      selfIp: stripCidr(data.netbirdIp),
      profileName: String(data.profileName || ""),
      managementConnected: management.connected === true,
      managementError: String(management.error || ""),
      signalConnected: signal.connected === true,
      signalError: String(signal.error || ""),
      peersConnected: Number((data.peers && data.peers.connected) || 0),
      peersTotal: Number((data.peers && data.peers.total) || 0),
      peers: peers
    }
  } catch (e) {
    return { ok: false, unavailable: true, message: "Status error", error: "Failed to parse netbird status" }
  }
}

// `netbird networks list` has no --json, so parse its block format:
//   Available Networks:
//
//     - ID: Exit Node (Tower)
//       Network: 0.0.0.0/0
//       Status: Selected
function parseNetworks(raw) {
  var lines = String(raw || "").split(/\r?\n/)
  var networks = []
  var current = null

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    // IDs can contain spaces and parentheses, so take the rest of the line.
    var idMatch = line.match(/^\s*-\s*ID:\s*(.+?)\s*$/)
    if (idMatch) {
      if (current) networks.push(current)
      current = { id: idMatch[1], network: "", status: "", selected: false }
      continue
    }
    if (!current) continue

    var networkMatch = line.match(/^\s*Network:\s*(.+?)\s*$/)
    if (networkMatch) {
      current.network = networkMatch[1]
      continue
    }
    var statusMatch = line.match(/^\s*Status:\s*(.+?)\s*$/)
    if (statusMatch) {
      current.status = statusMatch[1]
      current.selected = /^selected$/i.test(statusMatch[1])
    }
  }
  if (current) networks.push(current)

  networks.sort(function (a, b) {
    return String(a.id).localeCompare(String(b.id))
  })
  return networks
}

// `netbird profile list` prints a two-column table; the active row is marked
// with a check mark.
function parseProfiles(raw) {
  var lines = String(raw || "").split(/\r?\n/)
  var profiles = []
  var active = ""

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (/^\s*$/.test(line)) continue
    if (/^\s*NAME\s+ACTIVE\s*$/i.test(line)) continue

    var match = line.match(/^\s*(\S+)\s*(.*)$/)
    if (!match) continue

    var name = match[1]
    var isActive = /[✓✔]/.test(match[2]) || /^(true|yes|active)$/i.test(match[2].trim())
    profiles.push({ name: name, active: isActive })
    if (isActive) active = name
  }

  return { profiles: profiles, activeProfile: active }
}

// Per-peer SSH usernames live in a small JSON object keyed by peer FQDN,
// because `netbird ssh` defaults to the local username and peers routinely
// run a different account (an Alpine box whose only user is root, say).
// A malformed or missing file must not break the widget, so anything that
// isn't a string-to-string map degrades to "no overrides".
function parseSshUsers(raw) {
  var text = String(raw || "").trim()
  if (text === "") return {}
  try {
    var data = JSON.parse(text)
    if (!data || typeof data !== "object" || Array.isArray(data)) return {}
    var users = {}
    for (var key in data) {
      if (!Object.prototype.hasOwnProperty.call(data, key)) continue
      var value = String(data[key] || "").trim()
      if (key !== "" && value !== "") users[key] = value
    }
    return users
  } catch (e) {
    return {}
  }
}

function serializeSshUsers(users) {
  return JSON.stringify(users || {}, null, 2) + "\n"
}

// Empty string means "pass no -u and let netbird use the local username".
function resolveSshUser(users, fqdn, defaultUser) {
  var map = users || {}
  var key = String(fqdn || "")
  if (key !== "" && Object.prototype.hasOwnProperty.call(map, key)) {
    var override = String(map[key] || "").trim()
    if (override !== "") return override
  }
  return String(defaultUser || "").trim()
}

function withSshUser(users, fqdn, user) {
  var next = {}
  var map = users || {}
  for (var key in map) {
    if (Object.prototype.hasOwnProperty.call(map, key)) next[key] = map[key]
  }
  var host = String(fqdn || "")
  var value = String(user || "").trim()
  if (host === "") return next
  // Clearing the field removes the override rather than storing an empty
  // string, so resolution falls back to the configured default.
  if (value === "") delete next[host]
  else next[host] = value
  return next
}

// `netbird up` prints a browser URL when the peer still has to authenticate.
function extractAuthUrl(text) {
  var match = String(text || "").match(/https?:\/\/\S+/)
  return match && match[0] ? match[0] : ""
}

if (typeof module !== "undefined") {
  module.exports = {
    stripCidr: stripCidr,
    shortName: shortName,
    latencyMs: latencyMs,
    formatLatency: formatLatency,
    connectionLabel: connectionLabel,
    peerFromStatus: peerFromStatus,
    parseStatus: parseStatus,
    parseNetworks: parseNetworks,
    parseProfiles: parseProfiles,
    extractAuthUrl: extractAuthUrl,
    parseSshUsers: parseSshUsers,
    serializeSshUsers: serializeSshUsers,
    resolveSshUser: resolveSshUser,
    withSshUser: withSshUser
  }
}
