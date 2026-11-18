import QtQuick

// Reusable building blocks for the Quickshell settings windows
// (powermenu, mediaosd, wallpaper picker, ...).
//
// Put this file next to the files that use it. Quickshell makes every
// Uppercase.qml in the same directory available as a type, and the inline
// components below are used with the file name as prefix:
//
//     CustomizationSettings.SectionHeader { host: root; text: "General" }
//     CustomizationSettings.ToggleRow     { host: root; key: "showTips"; label: "Tooltips"; checked: root.showTips }
//     CustomizationSettings.SliderRow     { host: root; key: "menuSize"; label: "Scale" }
//     CustomizationSettings.ActionButton  { host: root; label: "Done"; primary: true; onClicked: ... }
//
// Every component takes a `host` (the Scope that owns the settings). The host
// must provide:
//
//   properties : menuUi (real), th (QtObject: radius, fontFamily, animFast,
//                animMed, textSizeGroup, textSizeBody, textSizeSmall),
//                cAccent (color), numSpec (per-key { min, max, step, unit })
//   functions  : cellW(parent), focusStep(item, forward),
//                ensureVisible(item, margin), fmtValue(key, value),
//                setNumber(key, value), toggleSetting(key), saveState(),
//                cycleColor(key, dir), themeColor(id), colorLabel(id)
//                (the last three are only needed for ToggleRow with colorKey)
//
// `Theme` is the shared singleton from the same directory.
//
// ActionButton, ToggleRow and SliderRow are Tab-focusable and draw a
// highlight ring while focused. Disabled controls are skipped by Tab.

QtObject {

    // ---------------------------------------------------------------------
    // Button (primary = filled with the highlight colour)
    // ---------------------------------------------------------------------
    component ActionButton: Rectangle {
        id: ab
        property var host
        property string label: ""
        property bool primary: false
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th
        readonly property color cAccent: host.cAccent
        signal clicked()

        activeFocusOnTab: true

        implicitWidth: abText.implicitWidth + 28 * u
        width: implicitWidth
        height: 28 * u
        radius: Math.min(height / 2, ab.th.radius * u)
        opacity: enabled ? 1 : 0.4
        color: primary
            ? ab.cAccent
            : Theme.alpha(Theme.text, abArea.containsMouse && enabled ? 0.18 : 0.1)
        border.width: ab.activeFocus ? Math.max(1, Math.round(2 * u)) : 0
        border.color: ab.primary ? Theme.text : ab.cAccent
        Behavior on color { ColorAnimation { duration: ab.th.animFast } }

        onActiveFocusChanged: if (activeFocus) ab.host.ensureVisible(ab, 32 * u)

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Space
                    || event.key === Qt.Key_Return
                    || event.key === Qt.Key_Enter) {
                if (ab.enabled)
                    ab.clicked()
                event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                ab.host.focusStep(ab, false)
                event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                ab.host.focusStep(ab, true)
                event.accepted = true
            }
        }

        Text {
            id: abText
            anchors.centerIn: parent
            text: ab.label
            font.family: ab.th.fontFamily
            font.pixelSize: ab.th.textSizeBody * ab.u
            font.bold: true
            color: ab.primary ? Theme.bg : Theme.text
        }

        MouseArea {
            id: abArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: ab.enabled
            onClicked: {
                ab.forceActiveFocus()
                ab.clicked()
            }
        }
    }

    // ---------------------------------------------------------------------
    // Section title (small, uppercase, dimmed)
    // ---------------------------------------------------------------------
    component SectionHeader: Item {
        id: sh
        property var host
        property string text: ""
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th
        width: parent?.width ?? 0
        height: 26 * u

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3 * sh.u
            text: sh.text
            font.family: sh.th.fontFamily
            font.pixelSize: sh.th.textSizeSmall * sh.u
            font.bold: true
            font.letterSpacing: 1.2
            font.capitalization: Font.AllUppercase
            color: Theme.textDim
        }
    }

    // ---------------------------------------------------------------------
    // One line of a keybind cheat-sheet: description left, key chip right.
    // ---------------------------------------------------------------------
    component KeyRow: Item {
        id: kr
        property var host
        property string keys: ""
        property string desc: ""
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th

        width: host.cellW(parent)
        height: 22 * u

        Text {
            anchors.left: parent.left
            anchors.right: krChip.left
            anchors.rightMargin: 8 * kr.u
            anchors.verticalCenter: parent.verticalCenter
            text: kr.desc
            elide: Text.ElideRight
            font.family: kr.th.fontFamily
            font.pixelSize: kr.th.textSizeBody * kr.u
            color: Theme.text
        }

        Rectangle {
            id: krChip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: chipText.implicitWidth + 14 * kr.u
            height: 18 * kr.u
            radius: 5 * kr.u
            color: Theme.alpha(Theme.text, 0.08)

            Text {
                id: chipText
                anchors.centerIn: parent
                text: kr.keys
                font.family: kr.th.fontFamily
                font.pixelSize: kr.th.textSizeSmall * kr.u
                font.bold: true
                color: Theme.textDim
            }
        }
    }

    // ---------------------------------------------------------------------
    // Toggle row.
    //   key       : flips that boolean setting on the host
    //   colorKey  : row becomes a colour picker for that host property
    //   neither   : just emits toggled() (used for lists of actions)
    // Keyboard: Space / Enter toggles, Left / Right cycle colour (colour
    // rows), Up / Down move focus.
    // ---------------------------------------------------------------------
    component ToggleRow: Item {
        id: tr
        property var host
        property string key: ""
        property string label: ""
        // follows host[key] by default; pass `checked:` to override it
        property bool checked: key !== "" && host ? !!host[key] : false
        property string colorKey: ""
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th
        readonly property color cAccent: host.cAccent
        signal toggled()

        activeFocusOnTab: true

        width: host.cellW(parent)
        height: (colorKey !== "" ? 38 : 28) * u
        opacity: enabled ? 1 : 0.4

        function activate() {
            if (tr.colorKey !== "")
                tr.host.cycleColor(tr.colorKey, 1)
            else if (tr.key !== "")
                tr.host.toggleSetting(tr.key)
            else
                tr.toggled()
        }

        onActiveFocusChanged: if (activeFocus) tr.host.ensureVisible(tr, 32 * u)

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Space
                    || event.key === Qt.Key_Return
                    || event.key === Qt.Key_Enter) {
                tr.activate()
                event.accepted = true
            } else if (tr.colorKey !== "" && event.key === Qt.Key_Left) {
                tr.host.cycleColor(tr.colorKey, -1)
                event.accepted = true
            } else if (tr.colorKey !== "" && event.key === Qt.Key_Right) {
                tr.activate()
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                tr.host.focusStep(tr, true)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                tr.host.focusStep(tr, false)
                event.accepted = true
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -6 * tr.u
            anchors.rightMargin: -6 * tr.u
            radius: Math.min(8 * tr.u, tr.th.radius * tr.u)
            color: (trArea.containsMouse || tr.activeFocus) && tr.enabled
                ? Theme.alpha(Theme.text, 0.06) : "transparent"
            border.width: tr.activeFocus ? Math.max(1, Math.round(tr.u)) : 0
            border.color: tr.cAccent
        }

        Text {
            anchors.left: parent.left
            anchors.right: tr.colorKey !== "" ? chip.left : sw.left
            anchors.rightMargin: 8 * tr.u
            anchors.verticalCenter: parent.verticalCenter
            text: tr.label
            elide: Text.ElideRight
            font.family: tr.th.fontFamily
            font.pixelSize: tr.th.textSizeGroup * tr.u
            font.bold: true
            color: Theme.text
        }

        // switch (only when colorKey is not set)
        Rectangle {
            id: sw
            visible: tr.colorKey === ""
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32 * tr.u; height: 18 * tr.u; radius: height / 2
            color: tr.checked ? tr.cAccent : "transparent"
            border.width: 1
            border.color: tr.checked ? tr.cAccent : Theme.alpha(Theme.text, 0.3)
            Behavior on color { ColorAnimation { duration: tr.th.animMed } }

            Rectangle {
                width: 12 * tr.u; height: 12 * tr.u; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: tr.checked ? parent.width - width - 3 * tr.u : 3 * tr.u
                color: tr.checked ? Theme.bg : Theme.text
                Behavior on x { NumberAnimation { duration: tr.th.animMed; easing.type: Easing.OutCubic } }
            }
        }

        // colour chip (only when colorKey is set): swatch + colour name
        Rectangle {
            id: chip
            visible: tr.colorKey !== ""
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 96 * tr.u
            height: 24 * tr.u
            radius: Math.min(8 * tr.u, tr.th.radius * tr.u)
            color: "transparent"
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.2)

            Rectangle {
                id: chipDot
                anchors.left: parent.left
                anchors.leftMargin: 8 * tr.u
                anchors.verticalCenter: parent.verticalCenter
                width: 10 * tr.u
                height: 10 * tr.u
                radius: width / 2
                color: tr.colorKey !== "" ? tr.host.themeColor(tr.host[tr.colorKey]) : "transparent"
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.3)
            }

            Text {
                anchors.left: chipDot.right
                anchors.leftMargin: 6 * tr.u
                anchors.right: parent.right
                anchors.rightMargin: 4 * tr.u
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: tr.colorKey !== "" ? tr.host.colorLabel(tr.host[tr.colorKey]) : ""
                font.family: tr.th.fontFamily
                font.pixelSize: tr.th.textSizeBody * tr.u
                color: Theme.text
            }
        }

        MouseArea {
            id: trArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: tr.enabled
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                tr.forceActiveFocus()
                if (tr.colorKey !== "" && mouse.button === Qt.RightButton)
                    tr.host.cycleColor(tr.colorKey, -1)
                else
                    tr.activate()
            }
        }
    }

    // ---------------------------------------------------------------------
    // Minimal slider bound to a numSpec entry on the host; saves on release.
    // Keyboard: Left / Right = one step, PgUp / PgDn = five steps,
    // Home / End = min / max, Up / Down move focus.
    // ---------------------------------------------------------------------
    component SliderRow: Item {
        id: sr
        property var host
        property string key: ""
        property string label: ""
        readonly property real u: host.menuUi
        readonly property QtObject th: host.th
        readonly property color cAccent: host.cAccent

        readonly property var spec: host.numSpec[key]
        readonly property real ratio: Math.max(0, Math.min(1,
            (host[key] - spec.min) / (spec.max - spec.min)))

        activeFocusOnTab: true

        width: host.cellW(parent)
        height: 38 * u
        opacity: enabled ? 1 : 0.4

        onActiveFocusChanged: if (activeFocus) sr.host.ensureVisible(sr, 32 * u)

        function nudge(delta) {
            sr.host.setNumber(sr.key, sr.host[sr.key] + delta)
            sr.host.saveState()
        }

        Keys.onPressed: function (event) {
            var st = sr.spec.step
            switch (event.key) {
            case Qt.Key_Left:     sr.nudge(-st);     break
            case Qt.Key_Right:    sr.nudge(st);      break
            case Qt.Key_PageDown: sr.nudge(-st * 5); break
            case Qt.Key_PageUp:   sr.nudge(st * 5);  break
            case Qt.Key_Home:
                sr.host.setNumber(sr.key, sr.spec.min); sr.host.saveState(); break
            case Qt.Key_End:
                sr.host.setNumber(sr.key, sr.spec.max); sr.host.saveState(); break
            case Qt.Key_Down:     sr.host.focusStep(sr, true);  break
            case Qt.Key_Up:       sr.host.focusStep(sr, false); break
            default: return
            }
            event.accepted = true
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3 * sr.u
            radius: Math.min(8 * sr.u, sr.th.radius * sr.u)
            color: "transparent"
            visible: sr.activeFocus
            border.width: Math.max(1, Math.round(sr.u))
            border.color: sr.cAccent
        }

        Text {
            anchors.left: parent.left
            anchors.right: srValue.left
            anchors.rightMargin: 6 * sr.u
            y: 4 * sr.u
            text: sr.label
            elide: Text.ElideRight
            font.family: sr.th.fontFamily
            font.pixelSize: sr.th.textSizeGroup * sr.u
            font.bold: true
            color: Theme.text
        }

        Text {
            id: srValue
            anchors.right: parent.right
            y: 5 * sr.u
            text: sr.host.fmtValue(sr.key, sr.host[sr.key])
            font.family: sr.th.fontFamily
            font.pixelSize: sr.th.textSizeBody * sr.u
            color: Theme.textDim
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            y: 27 * sr.u
            height: 4 * sr.u
            radius: height / 2
            color: Theme.alpha(Theme.text, 0.15)

            Rectangle {
                width: knob.x + knob.width / 2
                height: parent.height
                radius: parent.radius
                color: sr.cAccent
            }

            Rectangle {
                id: knob
                width: 14 * sr.u
                height: 14 * sr.u
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: sr.ratio * (track.width - width)
                color: Theme.text
            }
        }

        MouseArea {
            id: sliderArea
            anchors.fill: parent
            anchors.topMargin: 18 * sr.u
            hoverEnabled: true
            preventStealing: true
            enabled: sr.enabled

            function apply(mx) {
                var usable = track.width - knob.width
                if (usable <= 0)
                    return
                var r = Math.max(0, Math.min(1, (mx - knob.width / 2) / usable))
                var s = sr.spec
                sr.host.setNumber(sr.key,
                    s.min + Math.round(r * (s.max - s.min) / s.step) * s.step)
            }

            onPressed: mouse => {
                sr.forceActiveFocus()
                apply(mouse.x)
            }
            onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
            onReleased: sr.host.saveState()
        }
    }
}