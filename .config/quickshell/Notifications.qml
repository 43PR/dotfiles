import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import QtQuick

// Notification daemon:
//  - popups in the top-right corner
//  - persistent history panel (toggle: qs ipc call notifications toggle)
//  - history saved to ~/.cache/43pr/notifications.json
//  - battery low / critical alerts
PanelWindow {
    id: root

    // ---- tweakables ----
    property int topGap: 50          // distance from the top (clear your bar)
    property int sideGap: 16         // distance from the right edge
    property int cardWidth: 300
    property int maxHistory: 100

    property bool panelOpen: false

    anchors {
        top: true
        bottom: true
        right: true
    }

    implicitWidth: cardWidth + sideGap + 24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notifications"
    WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only the visible thing catches input; the rest of the edge clicks through.
    mask: Region {
        item: root.panelOpen ? panel : stack
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    function imgSrc(p) {
        if (!p)
            return "";
        return p.startsWith("/") ? "file://" + p : p;
    }

    function fmtTime(ms) {
        const d = new Date(ms);
        const now = new Date();
        return d.toDateString() === now.toDateString()
            ? Qt.formatDateTime(d, "HH:mm")
            : Qt.formatDateTime(d, "dd MMM HH:mm");
    }

    function removeHistory(i) {
        history.remove(i);
        saveTimer.restart();
    }

    function clearHistory() {
        history.clear();
        saveTimer.restart();
    }

    // ------------------------------------------------------------------
    // IPC:  qs ipc call notifications toggle | open | close | clear
    // ------------------------------------------------------------------
    IpcHandler {
        target: "notifications"

        function toggle(): void {
            root.panelOpen = !root.panelOpen;
        }
        function open(): void {
            root.panelOpen = true;
        }
        function close(): void {
            root.panelOpen = false;
        }
        function clear(): void {
            root.clearHistory();
        }
    }

    // ------------------------------------------------------------------
    // History (persisted)
    // ------------------------------------------------------------------
    ListModel {
        id: history
    }

    property bool historyReady: false

    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.cache/43pr/notifications.json"
        printErrors: false

        onLoaded: {
            try {
                const arr = JSON.parse(text());
                // Append (not replace): anything that arrived before the
                // file finished loading is newer and stays on top.
                for (let i = 0; i < arr.length; i++)
                    history.append(arr[i]);
            } catch (e) {
                console.warn("Notifications: bad history file: " + e);
            }
            root.historyReady = true;
        }
        onLoadFailed: root.historyReady = true
    }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: {
            if (!root.historyReady)
                return;
            const out = [];
            for (let i = 0; i < history.count; i++) {
                const e = history.get(i);
                out.push({
                    summary: e.summary,
                    body: e.body,
                    appName: e.appName,
                    appIcon: e.appIcon,
                    image: e.image,
                    time: e.time
                });
            }
            store.setText(JSON.stringify(out));
        }
    }

    // ------------------------------------------------------------------
    // Notification server
    // ------------------------------------------------------------------
    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true;

            if (n.transient)
                return;

            // image:// providers only live as long as the notification,
            // so only real file paths are kept in history.
            const img = (n.image && !String(n.image).startsWith("image://")) ? String(n.image) : "";

            history.insert(0, {
                summary: n.summary || "",
                body: n.body || "",
                appName: n.appName || "",
                appIcon: n.appIcon || "",
                image: img,
                time: Date.now()
            });
            if (history.count > root.maxHistory)
                history.remove(root.maxHistory, history.count - root.maxHistory);
            saveTimer.restart();
        }
    }

    // ------------------------------------------------------------------
    // Battery alerts
    // ------------------------------------------------------------------
    property real lastBatteryPercentage: -1
    property bool battery20Triggered: false
    property bool battery15Triggered: false

    function checkBattery() {
        if (!UPower.displayDevice.ready)
            return;

        var percentage = UPower.displayDevice.percentage;
        var discharging = UPower.onBattery;

        if (!discharging) {
            battery20Triggered = false;
            battery15Triggered = false;
            lastBatteryPercentage = percentage;
            return;
        }

        if (lastBatteryPercentage < 0) {
            lastBatteryPercentage = percentage;
            return;
        }

        if (percentage > 20)
            battery20Triggered = false;
        if (percentage > 15)
            battery15Triggered = false;

        if (!battery20Triggered && lastBatteryPercentage > 20 && percentage <= 20) {
            battery20Triggered = true;
            Quickshell.execDetached([
                "notify-send", "-a", "Battery", "-u", "normal",
                "-i", "battery-caution",
                "Battery Low",
                "Battery is at " + Math.round(percentage) + "%"
            ]);
        }

        if (!battery15Triggered && lastBatteryPercentage > 15 && percentage <= 15) {
            battery15Triggered = true;
            Quickshell.execDetached([
                "notify-send", "-a", "Battery", "-u", "critical",
                "-i", "battery-empty",
                "Battery Critical",
                "Battery is at " + Math.round(percentage) + "%"
            ]);
        }

        lastBatteryPercentage = percentage;
    }

    Component.onCompleted: checkBattery()

    Connections {
        target: UPower.displayDevice
        function onPercentageChanged() {
            root.checkBattery();
        }
        function onStateChanged() {
            root.checkBattery();
        }
    }

    Connections {
        target: UPower
        function onOnBatteryChanged() {
            root.checkBattery();
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.checkBattery()
    }

    // Esc closes the panel
    Item {
        anchors.fill: parent
        focus: root.panelOpen
        Keys.onEscapePressed: root.panelOpen = false
    }

    // ------------------------------------------------------------------
    // Popups (top-right)
    // ------------------------------------------------------------------
    Column {
        id: stack
        visible: !root.panelOpen
        anchors.top: parent.top
        anchors.topMargin: root.topGap
        anchors.right: parent.right
        anchors.rightMargin: root.sideGap
        spacing: 8

        Repeater {
            model: server.trackedNotifications

            delegate: Item {
                id: wrapper

                required property var modelData

                property bool shown: false
                property bool leaving: false
                property bool wasExpired: false
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical

                width: root.cardWidth
                height: card.height

                function close(expired) {
                    if (leaving)
                        return;
                    wasExpired = expired;
                    leaving = true;
                    shown = false;
                    gone.start();
                }

                Component.onCompleted: shown = true

                // Let the slide-out finish before destroying.
                Timer {
                    id: gone
                    interval: 220
                    onTriggered: {
                        if (wrapper.wasExpired)
                            wrapper.modelData.expire();
                        else
                            wrapper.modelData.dismiss();
                    }
                }

                // Auto-expire (paused on hover, never for critical).
                Timer {
                    interval: wrapper.modelData.expireTimeout > 0
                        ? wrapper.modelData.expireTimeout * 1000
                        : 6000
                    running: !wrapper.critical && !hover.containsMouse && !wrapper.leaving
                    onTriggered: wrapper.close(true)
                }

                Rectangle {
                    id: card
                    width: parent.width
                    height: Math.max(64, content.implicitHeight + 20)
                    radius: 16
                    color: Theme.bg
                    border.width: wrapper.critical ? 1 : 0
                    border.color: Theme.danger

                    x: wrapper.shown ? 0 : root.cardWidth + 40
                    opacity: wrapper.shown ? 1 : 0

                    Behavior on x {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                        }
                    }

                    // Click = dismiss
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: wrapper.close(false)
                    }

                    Row {
                        id: content
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 10
                        spacing: 10

                        Rectangle {
                            id: thumb
                            width: 40
                            height: 40
                            radius: 8
                            color: Theme.bg
                            clip: true
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                id: img
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                source: {
                                    if (wrapper.modelData.image !== "")
                                        return root.imgSrc(wrapper.modelData.image);
                                    if (wrapper.modelData.appIcon !== "")
                                        return Quickshell.iconPath(wrapper.modelData.appIcon, true);
                                    return "";
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: img.status !== Image.Ready
                                text: "󰂚"
                                font.family: Theme.iconFont
                                font.pixelSize: 18
                                color: Theme.text
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            width: parent.width - thumb.width - parent.spacing

                            Text {
                                text: wrapper.modelData.summary
                                font.pixelSize: 12
                                font.bold: true
                                color: Theme.text
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                visible: text !== ""
                                text: wrapper.modelData.body
                                font.pixelSize: 10
                                color: Theme.textDim
                                textFormat: Text.PlainText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: wrapper.modelData.appName
                                font.pixelSize: 9
                                color: Theme.textDim
                                opacity: 0.7
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            // Action buttons (if the app provided any)
                            Row {
                                visible: wrapper.modelData.actions.length > 0
                                spacing: 6

                                Repeater {
                                    model: wrapper.modelData.actions

                                    delegate: Rectangle {
                                        required property var modelData
                                        height: 20
                                        width: label.implicitWidth + 14
                                        radius: 7
                                        color: Theme.alpha(Theme.text, btn.containsMouse ? 0.22 : 0.1)

                                        Text {
                                            id: label
                                            anchors.centerIn: parent
                                            text: parent.modelData.text
                                            font.pixelSize: 9
                                            color: Theme.text
                                        }
                                        MouseArea {
                                            id: btn
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                parent.modelData.invoke();
                                                wrapper.close(false);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // History panel (top-right, slides in)
    // ------------------------------------------------------------------
    Rectangle {
        id: panel
        width: root.cardWidth
        height: panelCol.height + 28
        radius: 20
        color: Theme.bg

        anchors.top: parent.top
        anchors.topMargin: root.topGap
        anchors.right: parent.right
        anchors.rightMargin: root.panelOpen ? root.sideGap : -(root.cardWidth + 40)

        opacity: root.panelOpen ? 1 : 0
        visible: opacity > 0

        Behavior on anchors.rightMargin {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }

        Column {
            id: panelCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            spacing: 10

            // Header
            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications" + (history.count > 0 ? "  " + history.count : "")
                    font.pixelSize: 13
                    font.bold: true
                    color: Theme.text
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Clear all
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 8
                        visible: history.count > 0
                        color: Theme.alpha(Theme.danger, clearArea.containsMouse ? 0.25 : 0.1)

                        Text {
                            anchors.centerIn: parent
                            text: "󰆴"
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                            color: Theme.danger
                        }
                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.clearHistory()
                        }
                    }

                    // Close panel
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 8
                        color: Theme.alpha(Theme.text, closeArea.containsMouse ? 0.2 : 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                            color: Theme.text
                        }
                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.panelOpen = false
                        }
                    }
                }
            }

            // Empty state
            Text {
                visible: history.count === 0
                width: parent.width
                height: 40
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "No notifications"
                font.pixelSize: 11
                color: Theme.textDim
            }

            // History list
            ListView {
                id: list
                visible: history.count > 0
                width: parent.width
                height: Math.min(contentHeight, root.height - root.topGap - 120)
                clip: true
                spacing: 8
                model: history
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: entry

                    required property int index
                    required property string summary
                    required property string body
                    required property string appName
                    required property string appIcon
                    required property string image
                    required property real time

                    width: list.width
                    height: Math.max(56, textCol.implicitHeight + 20)
                    radius: 12
                    color: Theme.alpha(Theme.text, 0.06)

                    Rectangle {
                        id: eThumb
                        width: 32
                        height: 32
                        radius: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.alpha(Theme.text, 0.1)
                        clip: true

                        Image {
                            id: eImg
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            source: entry.image !== ""
                                ? root.imgSrc(entry.image)
                                : (entry.appIcon !== "" ? Quickshell.iconPath(entry.appIcon, true) : "")
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: eImg.status !== Image.Ready
                            text: "󰂚"
                            font.family: Theme.iconFont
                            font.pixelSize: 15
                            color: Theme.text
                        }
                    }

                    Column {
                        id: textCol
                        anchors.left: eThumb.right
                        anchors.leftMargin: 10
                        anchors.right: delBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: entry.summary
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.text
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            visible: text !== ""
                            text: entry.body
                            font.pixelSize: 10
                            color: Theme.textDim
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: (entry.appName !== "" ? entry.appName + " · " : "") + root.fmtTime(entry.time)
                            font.pixelSize: 9
                            color: Theme.textDim
                            opacity: 0.7
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    // Delete this entry
                    Item {
                        id: delBtn
                        width: 24
                        height: 24
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                            color: delArea.containsMouse ? Theme.danger : Theme.textDim
                        }
                        MouseArea {
                            id: delArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.removeHistory(entry.index)
                        }
                    }
                }
            }
        }
    }
}