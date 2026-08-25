# NetBird for Omarchy

A NetBird bar widget for the [Omarchy](https://omarchy.org/) shell. It mirrors
the built-in Tailscale widget: connection state at a glance, one-click toggling,
peer browsing, exit node selection, and quick copy actions.

## Features

- **Status at a glance** — daemon state, your own peer name and NetBird IP,
  and a connected/total peer count in the bar.
- **Toggle the connection** — bring NetBird up or down from the panel, with an
  optimistic UI so the icon reacts immediately instead of waiting for the next
  status poll.
- **Login handling** — when the daemon reports `NeedsLogin`, the panel surfaces
  the authentication URL that `netbird up` prints.
- **Peer browsing** — every peer with its status, connection type (P2P or
  relayed), and latency. Connected peers sort to the top.
- **Exit nodes and networks** — list advertised networks and select or deselect
  one without leaving the bar.
- **Profile switching** — see available NetBird profiles and switch the active one.
- **Copy actions** — copy a peer's NetBird IP or its short name.

## Requirements

- Omarchy with the Omarchy shell (Quickshell) bar.
- The **`netbird`** CLI on `PATH`, plus a running `netbird` daemon.
  On Arch: `omarchy pkg aur add netbird` (or `yay -S netbird`), then
  `sudo systemctl enable --now netbird`.

The widget shells out to the `netbird` binary only. It makes no network
requests of its own, bundles no binaries, and never invokes `sudo` or `pkexec`.
If `netbird` is not installed, the widget reports it and stays inert.

## Installation

```bash
omarchy plugin add https://github.com/kovacsni76574/omarchy-plugin-netbird --enable
```

That clones the plugin into `~/.config/omarchy/plugins/` and adds the widget to
your bar. To install without enabling it immediately, drop `--enable` and then:

```bash
omarchy plugin enable io.github.kovacsni76574.netbird right
```

## Configuration

Configurable from the bar widget settings UI, or in
`~/.config/omarchy/shell.json`:

| Setting | Type | Default | Range | Description |
|---|---|---|---|---|
| `refreshIntervalSec` | integer | `30` | 5–3600 | How often to poll `netbird status` |

## Updating

```bash
omarchy plugin update io.github.kovacsni76574.netbird
```

## Removal

```bash
omarchy plugin remove io.github.kovacsni76574.netbird --yes
```

That disables the widget, removes it from your bar layout, and deletes the
plugin directory. To only hide it while keeping it installed:

```bash
omarchy plugin disable io.github.kovacsni76574.netbird
```

## Development

```bash
omarchy plugin validate .
```

`Model.js` holds the parsing logic with no QML imports, so it can be exercised
directly under Node:

```js
const M = require("./Model.js");
M.parseStatus(rawJsonFromNetbirdStatusJson);
```

## License

MIT — see [LICENSE](LICENSE).
