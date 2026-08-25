import Quickshell.Io

// A size-bounded replacement for StdioCollector.
//
// StdioCollector has no limit: parseBytes() is a bare `buffer.append(incoming)`
// that keeps growing for the whole life of the process, so CLI-controlled
// output can make the shared Omarchy shell process allocate without bound long
// before we get to parse or elide it.
//
// SplitParser with an empty splitMarker is the one parser Quickshell offers
// that never buffers internally — it flushes each chunk straight to onRead —
// so the budget can be enforced here instead. Past the budget we stop
// appending and terminate the producer.
SplitParser {
  id: root

  // netbird's largest payload by far is `status --json`, a couple of KB per
  // peer, so this sits orders of magnitude above anything legitimate while
  // staying trivial to hold.
  property int maxBytes: 256 * 1024

  // Terminated once the budget is blown. Optional.
  property var process: null

  // Collected output. Never exceeds maxBytes.
  property string text: ""
  // Set once output was dropped, so callers can tell "gave us nothing" apart
  // from "gave us too much".
  property bool truncated: false
  property int byteCount: 0

  // Emitted per chunk for callers that need to react as output streams in.
  // A plain `onRead` at the usage site would override the handler below, so
  // consumers get their own signal.
  signal chunk(string data)

  splitMarker: ""

  // Quickshell resets StdioCollector between runs; this has to be told.
  function reset() {
    root.text = ""
    root.truncated = false
    root.byteCount = 0
  }

  // The budget is in bytes but QML strings are UTF-16, so measure what the
  // chunk actually costs rather than its length in code units.
  function utf8Length(value) {
    var bytes = 0
    for (var i = 0; i < value.length; i++) {
      var code = value.charCodeAt(i)
      if (code < 0x80) bytes += 1
      else if (code < 0x800) bytes += 2
      else if (code >= 0xd800 && code <= 0xdbff) {
        bytes += 4 // surrogate pair, consumed as one code point
        i++
      } else bytes += 3
    }
    return bytes
  }

  onRead: function (data) {
    if (root.truncated) return

    var value = String(data)
    var size = root.utf8Length(value)

    if (root.byteCount + size > root.maxBytes) {
      // Drop the whole overflowing chunk rather than a prefix of it: that
      // keeps text provably <= maxBytes, and a truncated payload is useless
      // to the parsers anyway. Pipe reads are far smaller than the budget, so
      // an error message worth elideStatus()'s 140 chars survives regardless.
      root.truncated = true
      if (root.process) root.process.running = false
      return
    }

    root.byteCount += size
    root.text += value
    root.chunk(value)
  }
}
