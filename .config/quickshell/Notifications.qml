import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import QtQuick

PanelWindow {
    id: root

    property int topGap: 50
    property int sideGap: 16
    property int baseWidth: 300
    property int maxHistory: 100

    property bool dnd: false
    property bool panelOpen: false
    property bool stateReady: false
    property bool historyReady: false
    property int menuSize: 100
    readonly property real ui: menuSize / 100
    readonly property int cardWidth: Math.round(baseWidth * ui)

    anchors { top: true; bottom: true; right: true; left: true }
    implicitWidth: cardWidth + sideGap + 24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notifications"
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region { item: root.panelOpen ? backdrop : stack }

    component Lbl: Text {
        property real ui: 1
        property real sz: 10
        font.pixelSize: Math.round(sz * ui)
        color: Theme.text
        elide: Text.ElideRight
    }

    component Thumb: Rectangle {
        property real ui: 1
        property real size: 40
        property string src: ""
        width: Math.round(size * ui)
        height: width
        radius: Math.round(8 * ui)
        clip: true
        Image {
            id: im
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: parent.src
        }
        Text {
            anchors.centerIn: parent
            visible: im.status !== Image.Ready
            text: "󰂚"
            font.family: Theme.iconFont
            font.pixelSize: Math.round(parent.size * 0.45 * parent.ui)
            color: Theme.text
        }
    }

    component IconBtn: Rectangle {
        id: b
        property real ui: 1
        property string icon: ""
        property string tip: ""
        property color tint: Theme.text
        property real rest: 0.08
        property real hot: 0.2
        property bool tipReady: false
        signal clicked()
        width: Math.round(24 * ui)
        height: width
        radius: Math.round(8 * ui)
        color: Theme.alpha(tint, area.containsMouse ? hot : rest)

        Text {
            anchors.centerIn: parent
            text: b.icon
            font.family: Theme.iconFont
            font.pixelSize: Math.round(13 * b.ui)
            color: b.tint
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: b.clicked()
            onContainsMouseChanged: {
                b.tipReady = false;
                if (containsMouse) tipTimer.restart();
                else tipTimer.stop();
            }
        }
        Timer { id: tipTimer; interval: 400; onTriggered: b.tipReady = true }

        Rectangle {
            visible: b.tipReady && b.tip !== ""
            anchors.top: parent.bottom
            anchors.topMargin: 6
            anchors.right: parent.right
            width: tipText.implicitWidth + Math.round(14 * b.ui)
            height: tipText.implicitHeight + Math.round(8 * b.ui)
            radius: Math.round(7 * b.ui)
            color: Theme.bg
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.15)
            Lbl { id: tipText; anchors.centerIn: parent; ui: b.ui; sz: 9; text: b.tip }
        }
    }

    component SizeBtn: Text {
        signal clicked()
        height: 16
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        color: Theme.text
        MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
    }

    function px(n) { return Math.round(n * ui); }
    function imgSrc(p) { return !p ? "" : (p.startsWith("/") ? "file://" + p : p); }
    function thumbSrc(image, icon) {
        if (image && image !== "") return imgSrc(image);
        if (icon && icon !== "") return Quickshell.iconPath(icon, true);
        return "";
    }
    function fmtTime(ms) {
        const d = new Date(ms);
        return d.toDateString() === new Date().toDateString()
            ? Qt.formatDateTime(d, "HH:mm")
            : Qt.formatDateTime(d, "dd MMM HH:mm");
    }
    function copyText(s, b) { Quickshell.execDetached(["wl-copy", b !== "" ? s + "\n" + b : s]); }
    function removeHistory(i) { history.remove(i); saveTimer.restart(); }
    function clearHistory() { history.clear(); saveTimer.restart(); }
    function setSize(v) { menuSize = Math.max(60, Math.min(200, v)); stateTimer.restart(); }
    function toggleDnd() { dnd = !dnd; stateTimer.restart(); }

    IpcHandler {
        target: "notifications"
        function toggle(): void { root.panelOpen = !root.panelOpen; }
        function open(): void { root.panelOpen = true; }
        function close(): void { root.panelOpen = false; }
        function clear(): void { root.clearHistory(); }
        function dnd(): void { root.toggleDnd(); }
    }

    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.config/quickshell/state/notifications-state.json"
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                if (typeof s.dnd === "boolean") root.dnd = s.dnd;
                if (typeof s.menuSize === "number") root.menuSize = Math.max(60, Math.min(200, Math.round(s.menuSize)));
            } catch (e) { console.warn("Notifications: bad state file: " + e); }
            root.stateReady = true;
        }
        onLoadFailed: root.stateReady = true
    }
    Timer {
        id: stateTimer
        interval: 300
        onTriggered: if (root.stateReady) stateFile.setText(JSON.stringify({ dnd: root.dnd, menuSize: root.menuSize }))
    }

    ListModel { id: history }

    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.cache/43pr/notifications.json"
        printErrors: false
        onLoaded: {
            try {
                const arr = JSON.parse(text());
                for (let i = 0; i < arr.length; i++) history.append(arr[i]);
            } catch (e) { console.warn("Notifications: bad history file: " + e); }
            root.historyReady = true;
        }
        onLoadFailed: root.historyReady = true
    }
    Timer {
        id: saveTimer
        interval: 400
        onTriggered: {
            if (!root.historyReady) return;
            const out = [];
            for (let i = 0; i < history.count; i++) {
                const e = history.get(i);
                out.push({ summary: e.summary, body: e.body, appName: e.appName, appIcon: e.appIcon, image: e.image, time: e.time });
            }
            store.setText(JSON.stringify(out));
        }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = !(root.dnd && n.urgency !== NotificationUrgency.Critical);
            if (n.transient) return;

            const img = (n.image && !String(n.image).startsWith("image://")) ? String(n.image) : "";
            history.insert(0, {
                summary: n.summary || "",
                body: n.body || "",
                appName: n.appName || "",
                appIcon: n.appIcon || "",
                image: img,
                time: Date.now()
            });
            if (history.count > root.maxHistory) history.remove(root.maxHistory, history.count - root.maxHistory);
            saveTimer.restart();
        }
    }

    property real lastBat: -1
    property bool bat20: false
    property bool bat15: false

    function notifyBat(urgency, icon, title, pct) {
        Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", urgency, "-i", icon, title, "Battery is at " + Math.round(pct) + "%"]);
    }

    function checkBattery() {
        if (!UPower.displayDevice.ready) return;
        const p = UPower.displayDevice.percentage;

        if (!UPower.onBattery) {
            bat20 = false;
            bat15 = false;
            lastBat = p;
            return;
        }
        if (lastBat < 0) { lastBat = p; return; }

        if (p > 20) bat20 = false;
        if (p > 15) bat15 = false;

        if (!bat20 && lastBat > 20 && p <= 20) { bat20 = true; notifyBat("normal", "battery-caution", "Battery Low", p); }
        if (!bat15 && lastBat > 15 && p <= 15) { bat15 = true; notifyBat("critical", "battery-empty", "Battery Critical", p); }
        lastBat = p;
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.config/quickshell/state"]);
        checkBattery();
    }
    Connections {
        target: UPower.displayDevice
        function onPercentageChanged() { root.checkBattery(); }
        function onStateChanged() { root.checkBattery(); }
    }
    Connections {
        target: UPower
        function onOnBatteryChanged() { root.checkBattery(); }
    }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.checkBattery() }

    Item { anchors.fill: parent; focus: root.panelOpen; Keys.onEscapePressed: root.panelOpen = false }

    Item {
        id: backdrop
        anchors.fill: parent
        visible: root.panelOpen
        MouseArea {
            anchors.fill: parent
            enabled: root.panelOpen
            onClicked: root.panelOpen = false
        }
    }

    Column {
        id: stack
        visible: !root.panelOpen
        anchors { top: parent.top; topMargin: root.topGap; right: parent.right; rightMargin: root.sideGap }
        spacing: root.px(8)

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
                    if (leaving) return;
                    wasExpired = expired;
                    leaving = true;
                    shown = false;
                    gone.start();
                }
                Component.onCompleted: shown = true

                Timer {
                    id: gone
                    interval: 220
                    onTriggered: wrapper.wasExpired ? wrapper.modelData.expire() : wrapper.modelData.dismiss()
                }

                Timer {
                    interval: wrapper.modelData.expireTimeout > 0 ? wrapper.modelData.expireTimeout * 1000 : 6000
                    running: !wrapper.critical && !hover.containsMouse && !wrapper.leaving
                    onTriggered: wrapper.close(true)
                }

                Rectangle {
                    id: card
                    width: parent.width
                    height: Math.max(root.px(64), content.implicitHeight + root.px(20))
                    radius: root.px(16)
                    color: Theme.bg
                    border.width: wrapper.critical ? 1 : 0
                    border.color: Theme.danger
                    x: wrapper.shown ? 0 : root.cardWidth + 40
                    opacity: wrapper.shown ? 1 : 0

                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) root.copyText(wrapper.modelData.summary, wrapper.modelData.body);
                            wrapper.close(false);
                        }
                    }

                    Row {
                        id: content
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: root.px(10) }
                        spacing: root.px(10)

                        Thumb {
                            id: thumb
                            ui: root.ui
                            color: Theme.bg
                            src: root.thumbSrc(wrapper.modelData.image, wrapper.modelData.appIcon)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.px(3)
                            width: parent.width - thumb.width - parent.spacing

                            Lbl { ui: root.ui; sz: 12; font.bold: true; width: parent.width; text: wrapper.modelData.summary }
                            Lbl {
                                ui: root.ui
                                width: parent.width
                                visible: text !== ""
                                text: wrapper.modelData.body
                                color: Theme.textDim
                                textFormat: Text.PlainText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                            }
                            Lbl { ui: root.ui; sz: 9; width: parent.width; text: wrapper.modelData.appName; color: Theme.textDim; opacity: 0.7 }

                            Row {
                                visible: wrapper.modelData.actions.length > 0
                                spacing: root.px(6)

                                Repeater {
                                    model: wrapper.modelData.actions
                                    delegate: Rectangle {
                                        required property var modelData
                                        height: root.px(20)
                                        width: label.implicitWidth + root.px(14)
                                        radius: root.px(7)
                                        color: Theme.alpha(Theme.text, btn.containsMouse ? 0.22 : 0.1)

                                        Lbl { id: label; anchors.centerIn: parent; ui: root.ui; sz: 9; text: parent.modelData.text }
                                        MouseArea {
                                            id: btn
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: { parent.modelData.invoke(); wrapper.close(false); }
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

    Rectangle {
        id: panel
        width: root.cardWidth
        height: panelCol.height + root.px(28)
        radius: root.px(20)
        color: Theme.bg
        anchors { top: parent.top; topMargin: root.topGap; right: parent.right; rightMargin: root.panelOpen ? root.sideGap : -(root.cardWidth + 40) }
        opacity: root.panelOpen ? 1 : 0
        visible: opacity > 0

        Behavior on anchors.rightMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        MouseArea { anchors.fill: parent }

        Column {
            id: panelCol
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.px(14) }
            spacing: root.px(10)

            Item {
                width: parent.width
                height: root.px(24)
                z: 10

                Lbl {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    ui: root.ui
                    sz: 13
                    font.bold: true
                    text: "Notifications" + (history.count > 0 ? "  " + history.count : "")
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: root.px(4)

                    IconBtn {
                        ui: root.ui
                        icon: root.dnd ? "󰂛" : "󰂚"
                        tip: "Do Not Disturb: " + (root.dnd ? "ON" : "OFF")
                        rest: root.dnd ? 0.3 : 0.08
                        onClicked: root.toggleDnd()
                    }
                    IconBtn {
                        ui: root.ui
                        icon: "󰆴"
                        tip: "Clear all"
                        tint: Theme.danger
                        rest: 0.1
                        hot: 0.25
                        visible: history.count > 0
                        onClicked: root.clearHistory()
                    }
                    IconBtn { ui: root.ui; icon: "󰅖"; tip: "Close"; onClicked: root.panelOpen = false }
                }
            }

            Lbl {
                visible: history.count === 0
                ui: root.ui
                sz: 11
                width: parent.width
                height: root.px(40)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "No notifications"
                color: Theme.textDim
            }

            ListView {
                id: list
                visible: history.count > 0
                width: parent.width
                height: Math.min(contentHeight, root.height - root.topGap - root.px(120))
                clip: true
                spacing: root.px(8)
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

                    property bool copied: false

                    width: list.width
                    height: Math.max(root.px(56), textCol.implicitHeight + root.px(20))
                    radius: root.px(12)
                    color: Theme.alpha(Theme.text, entry.copied ? 0.2 : 0.06)

                    Timer { id: copiedTimer; interval: 600; onTriggered: entry.copied = false }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.copyText(entry.summary, entry.body);
                            entry.copied = true;
                            copiedTimer.restart();
                        }
                    }

                    Thumb {
                        id: eThumb
                        ui: root.ui
                        size: 32
                        color: Theme.alpha(Theme.text, 0.1)
                        src: root.thumbSrc(entry.image, entry.appIcon)
                        anchors { left: parent.left; leftMargin: root.px(10); verticalCenter: parent.verticalCenter }
                    }

                    Column {
                        id: textCol
                        anchors { left: eThumb.right; leftMargin: root.px(10); right: delBtn.left; rightMargin: root.px(8); verticalCenter: parent.verticalCenter }
                        spacing: root.px(2)

                        Lbl { ui: root.ui; sz: 11; font.bold: true; width: parent.width; text: entry.summary }
                        Lbl {
                            ui: root.ui
                            width: parent.width
                            visible: text !== ""
                            text: entry.body
                            color: Theme.textDim
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                        }
                        Lbl {
                            ui: root.ui
                            sz: 9
                            width: parent.width
                            color: Theme.textDim
                            opacity: 0.7
                            text: (entry.appName !== "" ? entry.appName + " · " : "") + root.fmtTime(entry.time)
                        }
                    }

                    Item {
                        id: delBtn
                        width: root.px(24)
                        height: width
                        anchors { right: parent.right; rightMargin: root.px(8); verticalCenter: parent.verticalCenter }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: Theme.iconFont
                            font.pixelSize: root.px(13)
                            color: delArea.containsMouse ? Theme.danger : Theme.textDim
                        }
                        MouseArea { id: delArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.removeHistory(entry.index) }
                    }
                }
            }
        }
    }

    Row {
        id: sizeRow
        anchors { top: panel.bottom; topMargin: 6; left: panel.left }
        spacing: 2
        width: root.panelOpen ? implicitWidth : 0
        height: root.panelOpen ? implicitHeight : 0
        visible: root.panelOpen
        opacity: sizeHover.hovered ? 0.9 : 0.18

        Behavior on opacity { NumberAnimation { duration: 150 } }
        HoverHandler { id: sizeHover }

        SizeBtn { text: "−"; width: 16; font.pixelSize: 12; onClicked: root.setSize(root.menuSize - 10) }
        SizeBtn { text: "+"; width: 16; font.pixelSize: 12; onClicked: root.setSize(root.menuSize + 10) }
    }
}