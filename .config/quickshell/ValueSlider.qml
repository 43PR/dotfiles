import QtQuick

// Reusable slider extracted from BarPage's BarSlider.
//
// Two layouts:
//   stacked (default)         inline: true  (for use inside a Row, e.g. volume rows)
//   LABEL ........ value      ───────●───────  value
//   ───────●──────────────
//
// Input:
//   - drag the track with the mouse
//   - click the value to type a number (Enter = apply, Esc = cancel)
//   - when focused (click the slider / Tab): Left/Right = one step,
//     PageUp/PageDown = 10 steps, Home/End = min/max, Enter = edit value,
//     Ctrl+Z = undo, Ctrl+Y or Ctrl+Shift+Z = redo, Esc = escapePressed()
//
// The component does NOT write `value` itself: bind it and handle `moved`
//   ValueSlider {
//       label: "SCALE"; from: 0.5; to: 2; step: 0.05; unit: "×"; decimals: 2
//       value: myThing.scale
//       onMoved: v => myThing.scale = v
//   }
//
// Undo history is per slider: one drag = one entry, each key press / typed value = one entry.
Item {
    id: sl

    // ---- data ----
    property string label: ""
    property real from: 0
    property real to: 1
    property real step: 1
    property real value: 0

    // ---- display ----
    property string unit: ""
    property real displayScale: 1
    property int decimals: 0
    property string zeroText: ""       // shown instead of the number when value is 0 (e.g. "AUTO")
    property string displayText: ""    // if set, shown instead of the number (e.g. "MUTED"); typing still edits the real value

    // ---- layout ----
    property bool inline: false        // single row: [track] [value]; the label is not shown
    property real valueWidth: 52       // width of the value box in inline mode
    property int valueFontSize: Theme.textSizeSmall

    // ---- behaviour ----
    property bool keyboardAdjust: true // arrow keys etc. while focused
    property bool undoKeys: true       // Ctrl+Z / Ctrl+Y while focused
    property int undoLimit: 100
    property bool editing: false

    // ---- look (tweak per use) ----
    property color accentColor: Theme.accent
    property color valueColor: Theme.accent2

    signal moved(real v)       // fired on every change (drag, keys, typed value, undo/redo)
    signal committed(real v)   // fired when a drag ends, or after a typed/key/undo change
    signal editFinished()      // typing ended (Enter/Esc/focus lost): give focus back to your window here
    signal escapePressed()     // Esc while the slider itself has focus (e.g. close the window)

    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    readonly property bool canUndo: _undo.length > 0
    readonly property bool canRedo: _redo.length > 0
    readonly property bool dragging: _dragging   // true while the mouse is held on the track

    // internal undo state
    property var _undo: []
    property var _redo: []
    property bool _applying: false
    property bool _dragging: false
    property bool _dragPushed: false

    // inside a Cols/Grid take one cell, anywhere else the full width
    width: parent.cellWidth ?? parent.width
    height: inline ? 28 : 34
    opacity: enabled ? 1.0 : 0.4
    activeFocusOnTab: keyboardAdjust || undoKeys

    // ------------------------------------------------------------------
    // Logic
    // ------------------------------------------------------------------

    function clampSnap(v) {
        v = Math.max(from, Math.min(to, v))
        if (step > 0) v = +(Math.round(v / step) * step).toFixed(3)
        return Math.max(from, Math.min(to, v))
    }

    // remember the current value before it changes (a whole drag counts as one entry)
    function record() {
        if (_applying) return
        if (_dragging) {
            if (_dragPushed) return
            _dragPushed = true
        }
        _undo.push(value)
        if (_undo.length > undoLimit) _undo.shift()
        _redo = []
        _undo = _undo   // re-assign so canUndo / canRedo update
    }

    // live change (drag)
    function emitIfChanged(v) {
        v = clampSnap(v)
        if (v === value) return
        record()
        moved(v)
    }

    // moved + committed in one go (typed values, key presses, undo/redo have no "release")
    function emitCommitted(v) {
        v = clampSnap(v)
        if (v === value) return
        record()
        moved(v)
        committed(v)
    }

    function undo() {
        if (_undo.length === 0) return
        const prev = _undo.pop()
        _redo.push(value)
        _undo = _undo; _redo = _redo
        _applying = true
        moved(prev); committed(prev)
        _applying = false
    }

    function redo() {
        if (_redo.length === 0) return
        const next = _redo.pop()
        _undo.push(value)
        _undo = _undo; _redo = _redo
        _applying = true
        moved(next); committed(next)
        _applying = false
    }

    function startEdit() {
        if (!enabled) return
        valueEdit.text = (value * displayScale).toFixed(decimals)
        editing = true
        valueEdit.forceActiveFocus()
        valueEdit.selectAll()
    }

    function commitEdit() {
        if (!editing) return
        editing = false
        const raw = parseFloat(valueEdit.text.replace(",", "."))
        if (isNaN(raw)) return
        emitCommitted(raw / (displayScale !== 0 ? displayScale : 1))
    }

    function cancelEdit() {
        editing = false
    }

    Keys.onPressed: event => {
        if (editing || !enabled) return     // the TextInput handles its own keys (incl. its own Ctrl+Z)

        if (event.key === Qt.Key_Escape) {
            escapePressed()
            event.accepted = true
            return
        }

        // undo / redo
        if (undoKeys && (event.modifiers & Qt.ControlModifier)) {
            if (event.key === Qt.Key_Z && (event.modifiers & Qt.ShiftModifier)) {
                redo(); event.accepted = true; return
            }
            if (event.key === Qt.Key_Z) { undo(); event.accepted = true; return }
            if (event.key === Qt.Key_Y) { redo(); event.accepted = true; return }
        }

        if (!keyboardAdjust) return
        const s = step > 0 ? step : (to - from) / 100
        switch (event.key) {
        case Qt.Key_Left:     emitCommitted(value - s);      break
        case Qt.Key_Right:    emitCommitted(value + s);      break
        case Qt.Key_PageDown: emitCommitted(value - s * 10); break
        case Qt.Key_PageUp:   emitCommitted(value + s * 10); break
        case Qt.Key_Home:     emitCommitted(from);           break
        case Qt.Key_End:      emitCommitted(to);             break
        case Qt.Key_Return:
        case Qt.Key_Enter:    startEdit();                   break
        default: return
        }
        event.accepted = true
    }

    // ------------------------------------------------------------------
    // Label + value
    // ------------------------------------------------------------------

    Text {
        visible: !sl.inline
        anchors.left: parent.left
        anchors.right: valueBox.left; anchors.rightMargin: 6
        y: 0
        elide: Text.ElideRight
        text: sl.label
        color: Theme.textDim
        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.letterSpacing: 1
    }

    Item {
        id: valueBox
        anchors.right: parent.right
        y: sl.inline ? Math.round((sl.height - height) / 2) : 0
        width: sl.inline ? sl.valueWidth
                         : (sl.editing ? Math.max(48, valueText.implicitWidth) : valueText.implicitWidth)
        height: valueText.implicitHeight

        Text {
            id: valueText
            anchors.right: parent.right
            visible: !sl.editing
            text: sl.displayText !== "" ? sl.displayText
                  : (sl.zeroText !== "" && sl.value === 0)
                  ? sl.zeroText
                  : (sl.value * sl.displayScale).toFixed(sl.decimals) + sl.unit
            color: valueMouse.containsMouse ? sl.accentColor : sl.valueColor
            font.family: Theme.fontFamily; font.pixelSize: sl.valueFontSize
        }

        TextInput {
            id: valueEdit
            anchors.right: parent.right
            width: parent.width
            visible: sl.editing
            horizontalAlignment: TextInput.AlignRight
            selectByMouse: true
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            color: sl.accentColor
            selectionColor: sl.accentColor
            selectedTextColor: Theme.text
            font.family: Theme.fontFamily; font.pixelSize: sl.valueFontSize

            Keys.onReturnPressed: { sl.commitEdit(); sl.editFinished() }
            Keys.onEnterPressed:  { sl.commitEdit(); sl.editFinished() }
            Keys.onEscapePressed: { sl.cancelEdit(); sl.editFinished() }
            onActiveFocusChanged: if (!activeFocus) sl.commitEdit()
        }

        MouseArea {
            id: valueMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            enabled: sl.enabled && !sl.editing
            cursorShape: Qt.IBeamCursor
            onClicked: sl.startEdit()
        }
    }

    // ------------------------------------------------------------------
    // Track
    // ------------------------------------------------------------------

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: sl.inline ? valueBox.left : parent.right
        anchors.rightMargin: sl.inline ? 8 : 0
        y: sl.inline ? Math.round((sl.height - height) / 2) : 24
        height: 4; radius: 2
        color: Theme.border

        Rectangle {
            width: knob.x + knob.width / 2
            height: parent.height; radius: 2
            color: sl.accentColor
        }

        Rectangle {
            id: knob
            width: 12; height: 12; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            x: sl.ratio * (track.width - width)
            color: sl.accentColor
            // focus ring for keyboard navigation
            border.width: sl.activeFocus && !sl.editing ? 2 : 0
            border.color: Theme.text
        }
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: sl.inline ? valueBox.left : parent.right
        anchors.rightMargin: sl.inline ? 8 : 0
        y: sl.inline ? Math.round((sl.height - 20) / 2) : 14
        height: 20
        hoverEnabled: true
        preventStealing: true      // keep the page from scrolling while dragging
        enabled: sl.enabled
        cursorShape: Qt.PointingHandCursor

        function apply(mx) {
            const usable = track.width - knob.width
            if (usable <= 0) return
            const r = Math.max(0, Math.min(1, (mx - knob.width / 2) / usable))
            sl.emitIfChanged(sl.from + r * (sl.to - sl.from))
        }

        onPressed: m => {
            if (sl.keyboardAdjust || sl.undoKeys) sl.forceActiveFocus()
            sl._dragging = true
            sl._dragPushed = false
            apply(m.x)
        }
        onPositionChanged: m => { if (pressed) apply(m.x) }
        onReleased: { sl.committed(sl.value); sl._dragging = false }
        onCanceled: sl._dragging = false
    }
}