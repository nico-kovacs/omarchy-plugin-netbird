import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "nico.netbird"
  ipcTarget: "nico.netbird"
  manageIpc: false

  property string focusSection: "header"
  property int headerIndex: 0
  property int profileIndex: 0
  property int peerIndex: 0
  property int networkIndex: 0
  property bool cursorActive: false
  property bool copyMenuOpen: false
  property int phraseIndex: 0
  readonly property var activePhrases: [
    "Meshing peers",
    "Encrypting connections",
    "Punching holes",
    "Braiding packets",
    "Polishing tunnels",
    "Trading keys",
    "Sealing ports",
    "Routing quietly",
    "Watching peers",
    "Holding the wire"
  ]
  readonly property string heroPhraseText: activePhrases[phraseIndex % activePhrases.length]

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool showProfiles: netbird.profiles.length > 1
  readonly property bool showPeers: netbird.active && netbird.peers.length > 0
  readonly property bool showNetworks: netbird.active && netbird.networks.length > 0
  // Only claim the header cursor when the switch is actually on screen —
  // "header" stays navigable, but an absent CLI leaves nothing to highlight.
  readonly property bool headerHasCursor: cursorActive && focusSection === "header" && netbird.installed
  readonly property color iconColor: netbird.active ? foreground : dim
  readonly property string toggleHint: netbird.active ? "Disconnect NetBird" : (netbird.needsLogin ? "Log in to NetBird" : "Connect NetBird")
  readonly property color barIconColor: netbird.active ? barForeground : Qt.darker(barForeground, 1.55)
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "transparent"

  readonly property string peerSummary: {
    if (!netbird.active) return ""
    if (netbird.peersTotal === 0) return ""
    return netbird.peersConnected + "/" + netbird.peersTotal + " up"
  }

  function selectedPeer() {
    if (netbird.peers.length === 0) return null
    return netbird.peers[Math.max(0, Math.min(peerIndex, netbird.peers.length - 1))]
  }

  function selectedNetwork() {
    if (netbird.networks.length === 0) return null
    return netbird.networks[Math.max(0, Math.min(networkIndex, netbird.networks.length - 1))]
  }

  function selectedProfile() {
    if (netbird.profiles.length === 0) return null
    return netbird.profiles[Math.max(0, Math.min(profileIndex, netbird.profiles.length - 1))]
  }

  function ensureCursor() {
    if (headerIndex !== 0) headerIndex = 0
    if (profileIndex >= netbird.profiles.length) profileIndex = Math.max(0, netbird.profiles.length - 1)
    if (peerIndex >= netbird.peers.length) peerIndex = Math.max(0, netbird.peers.length - 1)
    if (networkIndex >= netbird.networks.length) networkIndex = Math.max(0, netbird.networks.length - 1)
    if (focusSection === "profiles" && !showProfiles) focusSection = showNetworks ? "networks" : (showPeers ? "peers" : "header")
    if (focusSection === "networks" && !showNetworks) focusSection = showPeers ? "peers" : (showProfiles ? "profiles" : "header")
    if (focusSection === "peers" && !showPeers) focusSection = showNetworks ? "networks" : (showProfiles ? "profiles" : "header")
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    ensureCursor()
    if (dy !== 0) {
      if (focusSection === "header") {
        if (dy > 0) {
          if (showProfiles) focusSection = "profiles"
          else if (showNetworks) focusSection = "networks"
          else if (showPeers) focusSection = "peers"
        }
      } else if (focusSection === "profiles") {
        if (dy < 0) {
          if (profileIndex <= 0) focusSection = "header"
          else profileIndex--
        } else {
          if (profileIndex < netbird.profiles.length - 1) profileIndex++
          else if (showNetworks) focusSection = "networks"
          else if (showPeers) focusSection = "peers"
        }
      } else if (focusSection === "networks") {
        if (dy < 0) {
          if (networkIndex <= 0) focusSection = showProfiles ? "profiles" : "header"
          else networkIndex--
        } else {
          if (networkIndex < netbird.networks.length - 1) networkIndex++
          else if (showPeers) focusSection = "peers"
        }
      } else if (focusSection === "peers") {
        if (dy < 0) {
          if (peerIndex <= 0) focusSection = showNetworks ? "networks" : (showProfiles ? "profiles" : "header")
          else peerIndex--
        } else if (peerIndex < netbird.peers.length - 1) {
          peerIndex++
        }
      }
    }
    ensureCursor()
    scrollCursorIntoView()
  }

  function activateCursor() {
    ensureCursor()
    if (focusSection === "header") {
      netbird.toggleNetbird()
    } else if (focusSection === "profiles") {
      var profile = selectedProfile()
      if (profile) netbird.selectProfile(profile.name)
    } else if (focusSection === "networks") {
      netbird.toggleNetwork(selectedNetwork())
    } else if (focusSection === "peers") {
      openSelectedPeerCopyMenu()
    }
  }

  function scrollItemIntoView(item) {
    if (!panelFlick || !item) return
    Qt.callLater(function () {
      if (!item) return
      var margin = Style.space(6)
      var point = item.mapToItem(panelFlick.contentItem, 0, 0)
      var top = point.y
      var bottom = top + item.height
      var viewTop = panelFlick.contentY
      var viewBottom = viewTop + panelFlick.height
      var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      if (top < viewTop + margin) panelFlick.contentY = Math.max(0, top - margin)
      else if (bottom > viewBottom - margin) panelFlick.contentY = Math.min(maxY, bottom + margin - panelFlick.height)
    })
  }

  function scrollCursorIntoView() {
    if (focusSection === "peers" && peerColumn && peerIndex >= 0 && peerIndex < peerColumn.children.length) scrollItemIntoView(peerColumn.children[peerIndex])
    else if (focusSection === "networks" && networkColumn && networkIndex >= 0 && networkIndex < networkColumn.children.length) scrollItemIntoView(networkColumn.children[networkIndex])
  }

  function setPeerCursor(index) {
    cursorActive = true
    focusSection = "peers"
    peerIndex = index
    scrollCursorIntoView()
  }

  function setNetworkCursor(index) {
    cursorActive = true
    focusSection = "networks"
    networkIndex = index
    scrollCursorIntoView()
  }

  function setProfileCursor(index) {
    cursorActive = true
    focusSection = "profiles"
    profileIndex = index
  }

  function setHeaderCursor() {
    cursorActive = true
    focusSection = "header"
    headerIndex = 0
  }

  function openSelectedPeerCopyMenu() {
    if (!peerColumn || peerIndex < 0 || peerIndex >= peerColumn.children.length) return
    var item = peerColumn.children[peerIndex]
    if (item && item.openCopyMenu) item.openCopyMenu()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    if (panelFlick) panelFlick.contentY = 0
    netbird.refresh(true)
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }
  onPeerIndexChanged: scrollCursorIntoView()
  onNetworkIndexChanged: scrollCursorIntoView()
  onShowProfilesChanged: ensureCursor()
  onShowPeersChanged: ensureCursor()
  onShowNetworksChanged: ensureCursor()

  Service {
    id: netbird
    settings: root.settings
  }

  Connections {
    target: netbird
    function onPeersChanged() { root.ensureCursor() }
    function onNetworksChanged() { root.ensureCursor() }
    function onProfilesChanged() { root.ensureCursor() }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { netbird.refresh(true); return "ok" }
    function up(): string { netbird.up(); return "ok" }
    function down(): string { netbird.down(); return "ok" }
    function toggleNetbird(): string { netbird.toggleNetbird(); return "ok" }
    function status(): string { return netbird.statusText }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        NetbirdIcon {
          anchors.centerIn: parent
          iconSize: Style.space(11)
          color: root.barIconColor
          badgeColor: root.urgent
          crossed: !netbird.active && !netbird.needsLogin
          warning: netbird.needsLogin
        }
      }
    }
    onPressed: function (buttonCode) {
      if (buttonCode === Qt.RightButton) netbird.toggleNetbird()
      else if (buttonCode === Qt.MiddleButton) netbird.refresh(true)
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.copyMenuOpen
      onMoveRequested: function (dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (t) {
        if (t === "t" || t === "T") netbird.toggleNetbird()
        else if (t === "c" || t === "C") netbird.copyPeerIp(root.selectedPeer())
        else if (t === "n" || t === "N") netbird.copyPeerName(root.selectedPeer())
        else if (t === "d" || t === "D") netbird.copyPeerFqdn(root.selectedPeer())
        else if (t === "r" || t === "R") netbird.refresh(true)
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          Item {
            id: header
            width: parent.width
            implicitHeight: hero.implicitHeight
            // Exposed for the hero's trailingControl, whose `root` resolves to
            // PanelHero (not this Panel) — reach panel state via `header`.
            readonly property bool ringVisible: root.headerHasCursor
            function focusHero() { root.setHeaderCursor() }

            PanelHero {
              id: hero
              width: parent.width
              title: netbird.installed ? (netbird.selfName || "NetBird") : "NetBird"
              meta: netbird.active ? root.heroPhraseText : "NetBird is disconnected"
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconOpacity: netbird.active ? 1.0 : 0.5
              // Status only — the switch owns toggling, mouse and keyboard alike.
              iconComponent: Component {
                NetbirdIcon {
                  iconSize: Style.font.display
                  color: root.iconColor
                  badgeColor: root.urgent
                  crossed: !netbird.active && !netbird.needsLogin
                  warning: netbird.needsLogin
                }
              }

              // Compact on/off switch on the trailing edge of the hero, and the
              // header's only cursor target. The service already flips `active`
              // optimistically, so the knob throws the instant you click it.
              trailingControl: Component {
                ToggleSwitch {
                  id: powerSwitch
                  visible: netbird.installed
                  checked: netbird.active
                  busy: netbird.busy
                  hasCursor: header.ringVisible
                  foreground: hero.foreground
                  onHovered: function (on) { if (on) header.focusHero() }
                  onToggled: netbird.toggleNetbird()

                  PanelToolTip {
                    visible: powerSwitch.containsMouse
                    text: root.toggleHint
                    fontFamily: hero.fontFamily
                  }
                }
              }
            }
          }

          Text {
            visible: netbird.active && (netbird.selfIp !== "" || netbird.selfFqdn !== "")
            width: parent.width
            text: {
              var parts = []
              if (netbird.selfFqdn !== "") parts.push(netbird.selfFqdn)
              if (netbird.selfIp !== "") parts.push(netbird.selfIp)
              return parts.join(" · ")
            }
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          Text {
            visible: netbird.actionStatus !== "" || netbird.lastError !== ""
            width: parent.width
            text: netbird.actionStatus !== "" ? netbird.actionStatus : netbird.lastError
            color: netbird.lastError !== "" && netbird.actionStatus === "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          CursorSurface {
            visible: !netbird.installed
            width: parent.width
            implicitHeight: missingText.implicitHeight + Style.spacing.rowPaddingX
            foreground: root.foreground

            Text {
              id: missingText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(12)
              text: "NetBird CLI is not installed or not on PATH."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }
          }

          PanelSeparator {
            visible: root.showProfiles
            foreground: root.foreground
          }

          Column {
            visible: root.showProfiles
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "PROFILES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: netbird.profiles
              ProfileRow {
                required property var modelData
                required property int index
                width: parent.width
                profile: modelData
                rowIndex: index
              }
            }
          }

          PanelSeparator {
            visible: root.showNetworks
            foreground: root.foreground
          }

          Column {
            visible: root.showNetworks
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "EXIT NODES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              id: networkColumn
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: netbird.networks
                NetworkRow {
                  required property var modelData
                  required property int index
                  width: networkColumn.width
                  network: modelData
                  rowIndex: index
                }
              }
            }
          }

          PanelSeparator {
            visible: netbird.installed && netbird.active
            foreground: root.foreground
          }

          Column {
            visible: netbird.installed && netbird.active
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: root.peerSummary !== "" ? "PEERS · " + root.peerSummary : "PEERS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: netbird.installed && netbird.active && netbird.peers.length === 0
              width: parent.width
              text: "No peers found on this network."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
            }

            Column {
              id: peerColumn
              visible: root.showPeers
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: netbird.peers
                PeerRow {
                  required property var modelData
                  required property int index
                  width: peerColumn.width
                  peer: modelData
                  rowIndex: index
                }
              }
            }
          }
        }
      }
    }
  }

  Timer {
    id: phraseTimer
    interval: 2800
    running: root.opened && netbird.active
    repeat: true
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: hero; property: "metaOpacity"
      to: 0.0; duration: 180; easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length
    }
    PropertyAnimation {
      target: hero; property: "metaOpacity"
      to: 1.0; duration: 260; easing.type: Easing.InQuad
    }
  }

  component ProfileRow: CursorSurface {
    id: profileRow
    property var profile: null
    property int rowIndex: 0
    readonly property bool activeProfile: profile && profile.active === true
    readonly property bool switchingProfile: profile && netbird.switchingProfile === String(profile.name || "")
    readonly property string profileText: profile ? String(profile.name || "Profile") : "Profile"

    hasCursor: root.cursorActive && root.focusSection === "profiles" && root.profileIndex === rowIndex
    current: activeProfile
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill

    implicitHeight: profileInner.implicitHeight + Style.spacing.xl

    Row {
      id: profileInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        text: ""
        color: profileRow.activeProfile || profileRow.switchingProfile ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
        opacity: profileRow.switchingProfile ? 0.45 : 1.0

        SequentialAnimation on opacity {
          running: profileRow.switchingProfile
          NumberAnimation { to: 1.0; duration: 420; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 0.45; duration: 420; easing.type: Easing.InOutQuad }
          loops: Animation.Infinite
        }
      }

      Text {
        text: profileRow.profileText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: profileRow.activeProfile
        elide: Text.ElideRight
        width: parent.width - Style.space(22) - Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setProfileCursor(profileRow.rowIndex)
      onClicked: if (profileRow.profile) netbird.selectProfile(profileRow.profile.name)
    }
  }

  component NetworkRow: CursorSurface {
    id: networkRow
    property var network: null
    property int rowIndex: 0
    readonly property bool selectedNetwork: network && network.selected === true
    readonly property bool settingNetwork: network && netbird.settingNetworkId === String(network.id || "")
    readonly property string networkName: network ? String(network.id || "Unknown") : "Unknown"
    readonly property string networkRange: network ? String(network.network || "") : ""
    readonly property string actionTooltip: selectedNetwork ? "Disconnect" : "Connect"

    hasCursor: root.cursorActive && root.focusSection === "networks" && root.networkIndex === rowIndex
    current: selectedNetwork || settingNetwork
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill

    implicitHeight: networkInner.implicitHeight + Style.spacing.lg

    Row {
      id: networkInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        text: "󱇢"
        color: networkRow.selectedNetwork || networkRow.settingNetwork ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter

        NumberAnimation on rotation {
          running: networkRow.settingNetwork
          from: 0
          to: 360
          duration: 900
          loops: Animation.Infinite
        }

        onRotationChanged: if (!networkRow.settingNetwork && rotation !== 0) rotation = 0
      }

      Column {
        width: parent.width - Style.space(30)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          width: parent.width
          text: networkRow.networkName
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: networkRow.selectedNetwork
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: networkRow.networkRange
          visible: text !== ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }

    MouseArea {
      id: networkMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setNetworkCursor(networkRow.rowIndex)
      onClicked: netbird.toggleNetwork(networkRow.network)
    }

    PanelToolTip {
      visible: networkMouse.containsMouse
      text: networkRow.actionTooltip
      fontFamily: root.fontFamily
    }
  }

  component PeerRow: CursorSurface {
    id: peerRow
    property var peer: null
    property int rowIndex: 0
    readonly property string peerName: peer ? String(peer.name || "Unknown") : "Unknown"
    readonly property string peerIp: peer ? String(peer.ip || "") : ""
    readonly property string peerFqdn: peer ? String(peer.fqdn || "") : ""
    readonly property bool peerConnected: peer ? peer.connected === true : false
    readonly property string peerDetail: {
      if (!peer) return ""
      var parts = []
      if (peerIp !== "") parts.push(peerIp)
      if (String(peer.connectionType || "") !== "") parts.push(String(peer.connectionType))
      if (String(peer.latency || "") !== "") parts.push(String(peer.latency))
      if (!peerConnected && String(peer.status || "") !== "") parts.push(String(peer.status).toLowerCase())
      return parts.join(" · ")
    }
    readonly property var copyOptions: {
      var options = []
      if (peerName !== "") options.push({ kind: "name", label: peerName })
      if (peerFqdn !== "") options.push({ kind: "fqdn", label: peerFqdn })
      if (peerIp !== "") options.push({ kind: "ip", label: peerIp })
      return options
    }
    property int copyIndex: 0

    hasCursor: root.cursorActive && root.focusSection === "peers" && root.peerIndex === rowIndex
    foreground: root.foreground

    implicitHeight: Math.max(peerContent.implicitHeight, copyButton.implicitHeight) + Style.spacing.rowPaddingX

    function clampCopyIndex() {
      copyIndex = Math.max(0, Math.min(copyIndex, copyOptions.length - 1))
    }

    function openCopyMenu() {
      if (copyOptions.length === 0) return
      clampCopyIndex()
      copyPopup.open()
    }

    function moveCopyCursor(delta) {
      if (copyOptions.length === 0) return
      copyIndex = Math.max(0, Math.min(copyOptions.length - 1, copyIndex + delta))
    }

    function copyOption(kind) {
      if (kind === "name") netbird.copyPeerName(peer)
      else if (kind === "fqdn") netbird.copyPeerFqdn(peer)
      else if (kind === "ip") netbird.copyPeerIp(peer)
      copyPopup.close()
    }

    function copyCurrentOption() {
      clampCopyIndex()
      if (copyOptions.length === 0) return
      copyOption(copyOptions[copyIndex].kind)
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      hoverEnabled: true
      cursorShape: Qt.ArrowCursor
      onContainsMouseChanged: if (containsMouse) root.setPeerCursor(peerRow.rowIndex)
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: "󰟀"
        color: peerRow.peerConnected ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        id: peerContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: peerRow.peerName
          color: peerRow.peerConnected ? root.foreground : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: peerRow.peerDetail
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      PanelActionButton {
        id: copyButton
        iconText: "󰆏"
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: peerRow.copyOptions.length > 0
        Layout.alignment: Qt.AlignVCenter
        onClicked: peerRow.openCopyMenu()
      }

      Popup {
        id: copyPopup
        x: copyButton.x + copyButton.width - width
        y: copyButton.y + copyButton.height + Style.space(4)
        width: Style.space(280)
        padding: 0
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        function handleKey(event) {
          if (event.key === Qt.Key_Escape) {
            close()
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Down || event.text === "j") {
            peerRow.moveCopyCursor(1)
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Up || event.text === "k") {
            peerRow.moveCopyCursor(-1)
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            peerRow.copyCurrentOption()
            event.accepted = true
          }
        }
        onOpenedChanged: {
          root.copyMenuOpen = opened
          if (opened) {
            peerRow.clampCopyIndex()
            Qt.callLater(function () { copyPopupContent.forceActiveFocus() })
          } else if (root.opened) {
            Qt.callLater(function () { keyCatcher.forceActiveFocus() })
          }
        }
        background: BorderSurface {
          color: Color.background
          borderSpec: Border.flat(root.dim, 1)
          radius: Style.cornerRadius
        }

        contentItem: Column {
          id: copyPopupContent
          width: parent.width
          focus: true
          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function (event) { copyPopup.handleKey(event) }

          Repeater {
            model: peerRow.copyOptions
            CopyChoice {
              required property var modelData
              required property int index
              width: parent.width
              label: String(modelData.label || "")
              selected: peerRow.copyIndex === index
              onHovered: peerRow.copyIndex = index
              onChosen: peerRow.copyOption(String(modelData.kind || ""))
            }
          }
        }
      }
    }
  }

  component CopyChoice: CursorSurface {
    id: copyChoice
    signal chosen()
    signal hovered()
    property string label: ""
    property bool selected: false

    visible: enabled
    foreground: root.foreground
    hasCursor: selected
    implicitHeight: Style.space(48)
    radius: 0

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: copyChoice.hovered()
      onClicked: copyChoice.chosen()
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      spacing: Style.space(10)

      Text {
        Layout.fillWidth: true
        text: copyChoice.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        text: "󰆏"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }
}
