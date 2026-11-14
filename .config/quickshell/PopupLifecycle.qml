import Quickshell
import QtQuick

// Open/close/toggle animation logic for a lazily created popup window.
//
//   showing  : what you want (toggle this)
//   mounted  : bind a LazyLoader's `active` to it. Becomes true on show and stays true for
//              keepAliveMs after hide, so reopening is instant.
//   reveal   : bind your panel's `open` to it. Only turns true once the window is sized and
//              its content is ready (so the open animation never plays on a half-built window),
//              then just follows `showing`.
//   opened   : true once the first reveal has happened (use for `prewarm: sized && !opened`)
//
// Usage:
//   PopupLifecycle {
//       id: life
//       sized: win.sized                         // window has a real size
//       contentReady: pageLoader.status === Loader.Ready
//       assetsReady: bgPic.ready                 // optional
//       frameWindow: card.Window.window          // set from inside the window
//       onUnmounted: { root.winW = 0; root.winH = 0 }
//   }
//   function toggle() { life.toggle() }
//   LazyLoader { active: life.mounted; PanelWindow { ... PerspectivePanel { open: life.reveal } } }
Scope {
    id: life

    // ---- state -----------------------------------------------------------
    property bool showing: false
    readonly property bool mounted: _mounted
    readonly property bool reveal: opened && showing
    property bool opened: false

    function show()   { showing = true }
    function hide()   { showing = false }
    function toggle() { showing = !showing }

    signal unmounted()

    // ---- inputs from the window ------------------------------------------
    property bool sized: false
    property bool contentReady: false
    property bool assetsReady: true
    property var frameWindow: null

    // ---- tuning ----------------------------------------------------------
    property int keepAliveMs: 20000
    property int minKeepAliveMs: 600
    property int warmTimeoutMs: 600     // fallback so a broken page/asset can't block forever
    property int settleMs: 250          // wait after everything is ready
    property int settleFrames: 3        // or this many rendered frames, whichever comes first

    // ---- internals -------------------------------------------------------
    property bool _mounted: false
    property bool _warm: false
    property int _frames: 0
    readonly property bool _canOpen: sized && (contentReady || _warm) && (assetsReady || _warm)

    onShowingChanged: {
        if (showing) {
            keepAliveTimer.stop()
            _mounted = true
        } else {
            keepAliveTimer.restart()
        }
    }

    on_MountedChanged: {
        if (!_mounted) {            // fresh start for the next mount
            opened = false
            _warm = false
            _frames = 0
        }
    }

    Timer {
        id: keepAliveTimer
        interval: Math.max(life.minKeepAliveMs, life.keepAliveMs)
        onTriggered: {
            if (life.showing) return        // reopened in the meantime
            life._mounted = false
            life.unmounted()
        }
    }

    Timer {
        running: life._mounted && !life._warm
        interval: life.warmTimeoutMs
        onTriggered: life._warm = true
    }

    Timer {
        running: life._canOpen && !life.opened
        interval: life.settleMs
        onTriggered: life.opened = true
    }

    Connections {
        target: life.frameWindow
        enabled: !life.opened               // stop listening to every frame once opened
        ignoreUnknownSignals: true
        function onFrameSwapped() {
            if (life.sized && life.contentReady && ++life._frames >= life.settleFrames)
                life.opened = true
        }
    }
}
