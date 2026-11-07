import QtQuick

// Declares which SystemStats readings a piece of UI needs.
// Polling for a key runs only while at least one active subscription asks for it.
//
//   StatsSubscription { active: root.barVisible && root.isOn("cpu"); keys: ["cpu"] }
//   StatsSubscription { active: page.visible; fast: true; keys: ["cpu", "mem", "gpu", "temp", "net", "info"] }
//
// keys: "cpu" | "mem" | "gpu" | "temp" | "net" | "info"   (see SystemStats.qml)
// fast: set it for live graphs; CPU / network then update every second instead of every two.
QtObject {
    id: sub

    property bool active: true
    property bool fast: false
    property var keys: []

    // what this subscription currently holds (so it can be released exactly)
    property string _sig: ""
    property var _held: []
    property bool _heldFast: false

    function _apply() {
        const want = active ? keys.slice().sort().join(",") + (fast ? "|fast" : "") : "";
        if (want === _sig) return;            // nothing really changed (e.g. a binding re-evaluated)
        SystemStats.release(_held, _heldFast);
        _held = [];
        _heldFast = false;
        _sig = want;
        if (active) {
            _held = keys.slice();
            _heldFast = fast;
            SystemStats.acquire(_held, _heldFast);
        }
    }

    onActiveChanged: _apply()
    onKeysChanged: _apply()
    onFastChanged: _apply()
    Component.onCompleted: _apply()
    Component.onDestruction: SystemStats.release(_held, _heldFast)
}
