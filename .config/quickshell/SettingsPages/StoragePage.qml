import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../"

Item {
    id: page
    property var drives: []
    property var filesystems: []
    property var cleanupInfo: ({yay:0, pacman:0, journal:0, trash:0, flatpak:0, cliphist:0})
    property var sdaUsageData: null
    property int contentMargin: 0
    property int contentRightMargin: 46
    property int contentTopMargin: 0
    property int contentBottomMargin: 0
    property string pendingAction: ""
    property string pendingTitle: ""
    property string pendingMessage: ""

    readonly property var cleanupDefaults: ({yay:0, pacman:0, journal:0, trash:0, flatpak:0, cliphist:0})
    readonly property var sizeUnits: ({
        B:1, K:1024, KB:1024, KIB:1024,
        M:1048576, MB:1048576, MIB:1048576,
        G:1073741824, GB:1073741824, GIB:1073741824,
        T:1099511627776, TB:1099511627776, TIB:1099511627776
    })

    function formatBytes(b) {
        if (!isFinite(b) || b < 0) return "0 B"
        var u = ["B", "KB", "MB", "GB", "TB"]
        var i = 0
        var v = b
        while (v >= 1024 && i < u.length - 1) { v /= 1024; ++i }
        return (i ? v.toFixed(1) : Math.round(v)) + " " + u[i]
    }

    function formatCount(n) {
        var v = Math.round(n) || 0
        return v + (v === 1 ? " ITEM" : " ITEMS")
    }

    function parseSize(v) {
        if (!v) return 0
        var p = v.trim().split(/\s+/)
        var n = parseFloat(p[0])
        return isNaN(n) ? 0 : n * (p.length > 1 ? (sizeUnits[p[1].toUpperCase()] || 1) : 1)
    }

    function usageColor(p) { return p >= 90 ? Theme.danger : p >= 75 ? Theme.accent2 : Theme.accent }
    function usageWidth(p) { return Math.min(1, Math.max(0, p / 100)) }
    function ignoredMount(m) { return ["/proc", "/sys", "/run", "/dev"].some(function(x) { return m.indexOf(x) === 0 }) }
    function ignoredFilesystem(f) { return ["tmpfs", "devtmpfs", "overlay"].some(function(x) { return f.indexOf(x) === 0 }) }

    function parseDfLine(line) {
        var f = line.trim().split(/\s+/)
        if (f.length < 6) return null
        var d = {
            filesystem: f[0], total: parseInt(f[1]), used: parseInt(f[2]),
            available: parseInt(f[3]), percent: parseInt(f[4]), mount: f.slice(5).join(" ")
        }
        if ([d.total, d.used, d.available, d.percent].some(isNaN) || ignoredMount(d.mount) || ignoredFilesystem(d.filesystem)) return null
        return d
    }

    function parseDriveData(data) {
        var disks = []
        try {
            var obj = JSON.parse(data)
            if (!obj.blockdevices) return disks
            for (var i = 0; i < obj.blockdevices.length; ++i) {
                var d = obj.blockdevices[i]
                if (d.type === "disk" && d.name === "sda")
                    disks.push({ name: d.name || "", model: d.model || "", size: parseInt(d.size) || 0, type: d.type || "", tran: d.tran || "" })
            }
        } catch (e) { console.log("lsblk JSON error:", e) }
        return disks
    }

    function findSdaUsage() {
        var used = 0
        for (var i = 0; i < filesystems.length; ++i) {
            var fs = filesystems[i]
            if (fs.filesystem.indexOf("/dev/sda") === 0) used += fs.used
        }
        return used > 0 ? {used: used} : null
    }

    function runCommand(c) { commandProcess.command = ["sh", "-c", c]; commandProcess.running = true }
    function refreshAll() { pDrives.running = pStorage.running = pCleanup.running = true }
    function confirmAction(t, m, c) { pendingTitle = t; pendingMessage = m; pendingAction = c; confirmPopup.visible = true }

    Process {
        id: pDrives
        command: ["sh", "-c", "lsblk -J -b -d -o NAME,MODEL,SIZE,TYPE,TRAN 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: page.drives = page.parseDriveData(text) }
        stderr: StdioCollector {}
    }

    Process {
        id: pStorage
        command: ["sh", "-c", "df -P -B1 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var fs = []
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; ++i) {
                    var item = page.parseDfLine(lines[i])
                    if (item) fs.push(item)
                }
                page.filesystems = fs
                page.sdaUsageData = page.findSdaUsage()
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: pCleanup
        command: [
            "sh", "-c",
            "printf 'YAY '; du -sb \"$HOME/.cache/yay\" 2>/dev/null | awk '{print $1}'; " +
            "printf 'PACMAN '; du -sb /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}'; " +
            "printf 'JOURNAL '; journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+ (B|K|M|G|T)' | tail -1; " +
            "printf 'TRASH '; du -sb \"$HOME/.local/share/Trash\" 2>/dev/null | awk '{print $1}'; " +
            "printf 'FLATPAK '; flatpak uninstall --unused --assumeno 2>/dev/null | grep -oE '[0-9.]+ (kB|MB|GB|TB)' | tail -1; " +
            "printf 'CLIPHIST '; cliphist list 2>/dev/null | wc -l"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var info = {yay: 0, pacman: 0, journal: 0, trash: 0, flatpak: 0, cliphist: 0}
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; ++i) {
                    var p = lines[i].trim().split(/\s+/)
                    var k = p[0] ? p[0].toLowerCase() : ""
                    if (p.length > 1 && info[k] !== undefined) info[k] = page.parseSize(p.slice(1).join(" "))
                }
                page.cleanupInfo = info
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: commandProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onRunningChanged: { if (!running) page.refreshAll() }
    }

    Rectangle {
        id: confirmPopup
        visible: false; anchors.centerIn: parent; z: 100
        width: Math.min(parent.width - 30, 420); height: 190; radius: Theme.radius
        color: "#000000"; border.width: 1; border.color: Theme.border

        Column {
            anchors.fill: parent; anchors.margins: 18; spacing: 12
            Text {
                text: page.pendingTitle; color: "#fff"
                font.family: Theme.fontFamily; font.pixelSize: 17; font.bold: true
            }
            Text {
                width: parent.width; text: page.pendingMessage; color: "#fff"
                font.family: Theme.fontFamily; font.pixelSize: 13; wrapMode: Text.WordWrap
            }
            Item { width: 1; height: 1 }
            Row {
                width: parent.width; spacing: 10
                ToolButton {
                    width: (parent.width - 8) / 2; label: "CANCEL"
                    onClicked: confirmPopup.visible = false
                }
                ToolButton {
                    width: (parent.width - 8) / 2; label: "CONFIRM"; accent: true
                    onClicked: { confirmPopup.visible = false; page.runCommand(page.pendingAction) }
                }
            }
        }
    }

    Timer { interval: 10000; running: true; repeat: true; onTriggered: page.refreshAll() }
    Component.onCompleted: page.refreshAll()

    Column {
        anchors.fill: parent
        anchors.leftMargin: page.contentMargin; anchors.rightMargin: page.contentRightMargin
        anchors.topMargin: page.contentTopMargin; anchors.bottomMargin: page.contentBottomMargin
        spacing: 10

        Row {
            id: header
            width: parent.width; height: 36
            Text {
                text: "STORAGE"; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 19; font.letterSpacing: 3
                anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -6
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Item {
            width: parent.width; height: parent.height - header.height - 10

            Flickable {
                id: flick
                anchors.fill: parent; clip: true
                contentWidth: width; contentHeight: list.height
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    id: scrollBar
                    background: Rectangle {
                    color: Theme.alpha(Theme.border, 0.3)
                    radius: width / 2
                    }
                    contentItem: Rectangle {
                        color: Theme.accent
                        radius: width / 2
                    }
                }

                Column {
                    id: list
                    width: parent.width; spacing: 10

                    Text {
                        text: "DRIVES"; color: Theme.text
                        font.family: Theme.fontFamily; font.pixelSize: 15; font.bold: true; font.letterSpacing: 2
                    }

                    Repeater {
                        model: page.drives
                        delegate: Item {
                            required property var modelData
                            property bool hasUsage: page.sdaUsageData !== null && modelData.size > 0
                            property real usedPct: hasUsage ? (page.sdaUsageData.used / modelData.size) * 100 : 0
                            width: list.width; height: 64

                            Column {
                                anchors.fill: parent; spacing: 9

                                Row {
                                    width: parent.width; height: 17
                                    Text {
                                        width: parent.width - 70; text: modelData.model || modelData.name || "SSD/HDD"
                                        color: Theme.text; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                        font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true
                                    }
                                    Text {
                                        width: 70; text: hasUsage ? Math.round(usedPct) + "%" : "--%"
                                        color: hasUsage ? page.usageColor(usedPct) : Theme.textDim
                                        horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                                        font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true
                                    }
                                }

                                Rectangle {
                                    width: parent.width; height: 4; radius: 2
                                    color: Theme.alpha(Theme.textDim, .15)
                                    Rectangle {
                                        width: hasUsage ? parent.width * page.usageWidth(usedPct) : 0
                                        height: parent.height; radius: 2
                                        color: hasUsage ? page.usageColor(usedPct) : Theme.accent
                                        Behavior on width { NumberAnimation { duration: Theme.animMed } }
                                    }
                                }

                                Row {
                                    width: parent.width; height: 13; spacing: 14
                                    Text {
                                        text: page.sdaUsageData ? page.formatBytes(page.sdaUsageData.used) + " USED" : "-- USED"
                                        color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11
                                    }
                                    Text {
                                        text: page.sdaUsageData && modelData.size > page.sdaUsageData.used
                                            ? page.formatBytes(modelData.size - page.sdaUsageData.used) + " FREE" : "-- FREE"
                                        color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11
                                    }
                                    Text {
                                        text: page.formatBytes(modelData.size) + " TOTAL"
                                        color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: "FILESYSTEMS"; color: Theme.text; topPadding: 4
                        font.family: Theme.fontFamily; font.pixelSize: 15; font.bold: true; font.letterSpacing: 2
                    }

                    Repeater {
                        model: page.filesystems
                        delegate: Item {
                            required property var modelData
                            width: list.width; height: 64

                            Column {
                                anchors.fill: parent; spacing: 9

                                Row {
                                    width: parent.width; height: 17
                                    Text {
                                        width: parent.width - 55; text: modelData.mount
                                        color: Theme.text; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                        font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true
                                    }
                                    Text {
                                        width: 55; text: modelData.percent + "%"; color: page.usageColor(modelData.percent)
                                        horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                                        font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true
                                    }
                                }

                                Rectangle {
                                    width: parent.width; height: 4; radius: 2
                                    color: Theme.alpha(Theme.textDim, .15)
                                    Rectangle {
                                        width: parent.width * page.usageWidth(modelData.percent)
                                        height: parent.height; radius: 2; color: page.usageColor(modelData.percent)
                                        Behavior on width { NumberAnimation { duration: Theme.animMed } }
                                    }
                                }

                                Row {
                                    width: parent.width; height: 13; spacing: 14
                                    Text {
                                        text: page.formatBytes(modelData.used) + " USED"
                                        color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11
                                    }
                                    Text {
                                        text: page.formatBytes(modelData.available) + " FREE"
                                        color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11
                                    }
                                    Text {
                                        text: page.formatBytes(modelData.total) + " TOTAL"
                                        color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: "CLEANUP"; color: Theme.text; topPadding: 4
                        font.family: Theme.fontFamily; font.pixelSize: 15; font.bold: true; font.letterSpacing: 2
                    }

                    Repeater {
                        model: [
                            {
                                key: "trash", label: "TRASH", action: "EMPTY", title: "EMPTY TRASH?",
                                message: "This permanently deletes everything in ~/.local/share/Trash.",
                                command: "rm -rf -- \"$HOME/.local/share/Trash/files/\"* \"$HOME/.local/share/Trash/info/\"*"
                            },
                            {
                                key: "cliphist", label: "CLIPHIST", action: "WIPE", title: "WIPE CLIPBOARD HISTORY?",
                                message: "This permanently clears your entire clipboard history (cliphist).",
                                command: "cliphist wipe"
                            },
                            {
                                key: "yay", label: "YAY CACHE", action: "CLEAN", title: "CLEAR YAY CACHE?",
                                message: "CACHE_PLACEHOLDER",
                                command: "rm -rf -- \"$HOME/.cache/yay/\"*"
                            },
                            {
                                key: "pacman", label: "PACMAN CACHE", action: "CLEAN", title: "CLEAN PACMAN CACHE?",
                                message: "paccache will remove old package versions while keeping the currently installed packages.",
                                command: "sudo paccache -r"
                            },
                            {
                                key: "journal", label: "JOURNAL", action: "7 DAYS", title: "VACUUM JOURNAL?",
                                message: "Keep only the last 7 days of system logs.",
                                command: "sudo journalctl --vacuum-time=7d"
                            },
                            {
                                key: "flatpak", label: "FLATPAK UNUSED", action: "CLEAN", title: "REMOVE UNUSED FLATPAKS?",
                                message: "This removes unused Flatpak runtimes and packages.",
                                command: "flatpak uninstall --unused"
                            }
                        ]

                        delegate: CleanupButton {
                            required property var modelData
                            width: list.width
                            label: modelData.label
                            value: modelData.key === "cliphist" ? page.formatCount(page.cleanupInfo.cliphist) : page.formatBytes(page.cleanupInfo[modelData.key])
                            actionText: modelData.action
                            onClicked: page.confirmAction(
                                modelData.title,
                                modelData.message === "CACHE_PLACEHOLDER"
                                    ? page.formatBytes(page.cleanupInfo.yay) + " currently in ~/.cache/yay"
                                    : modelData.message,
                                modelData.command
                            )
                        }
                    }
                }
            }
        }
    }

    component ToolButton: Rectangle {
        property string label: ""
        property bool accent: false
        signal clicked()
        height: 38; radius: Theme.radius; color: "transparent"
        border.width: 1; border.color: "transparent"

        Text {
            anchors.centerIn: parent; text: parent.label
            color: parent.accent ? Theme.accent : Theme.text
            font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; font.letterSpacing: .5
        }

        MouseArea {
            anchors.fill: parent; hoverEnabled: true
            onEntered: parent.border.color = "#ffffff"
            onExited: parent.border.color = "transparent"
            onClicked: parent.clicked()
        }
    }

    component CleanupButton: Item {
        id: cleanupRoot
        property string label: ""
        property string value: ""
        property string actionText: ""
        signal clicked()
        height: 38

        Rectangle {
            id: cleanupHoverBorder
            anchors.fill: parent; radius: Theme.radius; color: "transparent"
            border.width: 1; border.color: "transparent"

            Text {
                anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: cleanupRoot.label; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; font.letterSpacing: .5
            }

            Text {
                id: cleanupValue
                anchors.right: actionTextItem.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: cleanupRoot.value; color: Theme.text; horizontalAlignment: Text.AlignRight
                font.family: Theme.fontFamily; font.pixelSize: 11
            }

            Text {
                id: actionTextItem
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                text: cleanupRoot.actionText; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; font.letterSpacing: .5

                MouseArea {
                    anchors.fill: parent; anchors.margins: -8; hoverEnabled: true
                    onEntered: { cleanupHoverBorder.border.color = "#ffffff"; actionTextItem.color = Theme.accent }
                    onExited: { cleanupHoverBorder.border.color = "transparent"; actionTextItem.color = Theme.text }
                    onClicked: cleanupRoot.clicked()
                }
            }
        }

        MouseArea {
            anchors.fill: parent; z: -1; hoverEnabled: true
            onEntered: cleanupHoverBorder.border.color = "#ffffff"
            onExited: cleanupHoverBorder.border.color = "transparent"
            onClicked: cleanupRoot.clicked()
        }
    }
}