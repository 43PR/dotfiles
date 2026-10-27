import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: page

    property real marginLeft: 0
    property real marginRight: 10
    property real marginTop: 0
    property real marginBottom: 0

    // ---- Terminal used for anything that needs sudo / shows output ----
    readonly property string terminal: "kitty"

    // ---- Pending update counts: -2 = checking, -1 = unavailable ----
    property int pacmanCount: -2
    property int aurCount: -2
    property int flatpakCount: -2
    property string aurHelper: ""          // "paru" | "yay" | ""

    // ---- Dotfiles repo status vs upstream ----
    // dotfilesBehind: -2 = checking, -1 = unavailable, otherwise commits upstream has that HEAD lacks.
    // dotfilesAhead: local commits not on upstream (> 0 together with behind means diverged).
    property int dotfilesBehind: -2
    property int dotfilesAhead: 0

    // ---- Desktop updater script: "update.sh" | "update2.sh" ----
    property string updater: "update.sh"

    property string statusText: ""

    readonly property string stateDir: Quickshell.env("HOME") + "/.config/quickshell/state"

    // ---- Tooltip texts ----
    readonly property string tipUpdateSh:
        "update.sh (symlink model)\n"
        + "Links files that are new in the repo, installs new packages.txt entries "
        + "and regenerates the theme. Existing real files in ~/.config are never overwritten."
    readonly property string tipUpdate2Sh:
        "update2.sh (repo is source of truth)\n"
        + "Also repairs wrong links, replaces real files in the way (backed up to ~/.config-backups) "
        + "and removes stale links. Your personal files (fastfetch, cava, rofi config, themes...) are kept."
    readonly property string tipRunButton:
        ""

    function countLabel(n) {
        if (n === -2) return "CHECKING…"
        if (n === -1) return "N/A"
        if (n === 0)  return "UP TO DATE"
        return n + " PENDING"
    }
    function countColor(n) {
        if (n > 0) return Theme.accent2
        return Theme.textDim
    }

    // Dotfiles status text. "NEW UPDATE" with local commits means `git pull --ff-only` would fail.
    readonly property string dotfilesLabel: {
        if (dotfilesBehind === -2) return "CHECKING…"
        if (dotfilesBehind === -1) return "N/A"
        if (dotfilesBehind > 0 && dotfilesAhead > 0) return "NEW UPDATE"
        if (dotfilesBehind > 0) return dotfilesBehind + " PENDING"
        return "UP TO DATE"
    }
    readonly property bool dotfilesAttention: dotfilesBehind > 0

    // Wrap a script so the terminal stays open until Enter is pressed.
    function inTerminal(title, script) {
        const full = script
            + "; printf '\\n\\033[1;32m[DONE]\\033[0m Press Enter to close...'; read -r _"
        return [terminal, "--title", title, "bash", "-c", full]
    }
    function run(title, script) {
        if (runner.running) {
            page.statusText = "ANOTHER UPDATE IS STILL RUNNING"
            return
        }
        page.statusText = title.toUpperCase() + " RUNNING…"
        runner.title = title
        runner.command = inTerminal(title, script)
        runner.running = true
    }

    // ---- Individual update scripts ----
    readonly property string pacmanScript: "sudo pacman -Syu"
    readonly property string flatpakScript: "flatpak update -y"

    function aurScript() {
        if (aurHelper === "") return "echo 'No AUR helper (paru/yay) found.'"
        return aurHelper + " -Sua"
    }
    function allScript() {
        const parts = [pacmanScript]
        if (aurHelper !== "") parts.push(aurScript())
        parts.push("if command -v flatpak >/dev/null 2>&1; then " + flatpakScript + "; fi")
        return parts.join("; ")
    }

    // Resolve the dotfiles repo by following the theme.py symlink back to the repo.
    readonly property string repoPath:
        "REPO=\"$(dirname \"$(dirname \"$(dirname \"$(dirname \"$(readlink -f \"$HOME/.config/43pr/bin/theme.py\")\")\")\")\")\"; "

    function repoResolve(script) {
        return repoPath
            + "if [ ! -f \"$REPO/" + script + "\" ]; then echo \"" + script + " not found (resolved repo: $REPO)\"; exit 1; fi; "
            + "cd \"$REPO\" || exit 1; "
    }

    // Silent check: fetch, then print "<ahead> <behind>" for HEAD vs its upstream, or -1 on any failure.
    // GIT_TERMINAL_PROMPT=0 and timeout keep it from hanging on credentials or a dead network.
    readonly property string dotfilesCheckScript:
        repoPath
        + "[ -e \"$REPO/.git\" ] || { echo -1; exit 0; }; "
        + "cd \"$REPO\" || { echo -1; exit 0; }; "
        + "GIT_TERMINAL_PROMPT=0 timeout 20 git fetch --quiet >/dev/null 2>&1 || { echo -1; exit 0; }; "
        + "git rev-list --left-right --count 'HEAD...@{u}' 2>/dev/null || echo -1"

    // Pull first, then run the selected updater. update2.sh pulls on its own via --pull.
    function desktopScript() {
        let s = repoResolve(updater)
        if (updater === "update2.sh")
            s += "./update2.sh --pull"
        else
            s += "echo '--- git pull ---'; git pull --ff-only; ./update.sh"
        return s
    }

    // ------------------------------------------------------------------
    // Tooltip (drawn inside the page, no Popup/overlay needed)
    // ------------------------------------------------------------------

    property Item tipTarget: null
    property string tipPending: ""
    property string tipText: ""
    property bool tipShown: false
    property real tipAnchorX: 0
    property real tipAnchorTop: 0
    property real tipAnchorBottom: 0

    function showTip(item, text) {
        tipTarget = item
        tipPending = text
        tipTimer.restart()
    }
    function hideTip() {
        tipTimer.stop()
        tipShown = false
    }

    Timer {
        id: tipTimer
        interval: 450
        onTriggered: {
            if (!page.tipTarget || page.tipPending.length === 0) return
            const top = page.tipTarget.mapToItem(page, 0, 0)
            page.tipAnchorX = top.x
            page.tipAnchorTop = top.y
            page.tipAnchorBottom = top.y + page.tipTarget.height
            page.tipText = page.tipPending
            page.tipShown = true
        }
    }

    // ------------------------------------------------------------------
    // Processes
    // ------------------------------------------------------------------

    Process {
        id: runner
        property string title: ""
        onExited: exitCode => {
            page.statusText = runner.title.toUpperCase() + " FINISHED"
            refreshTimer.restart()
        }
    }
    Process {
        id: helperDetect
        command: ["sh", "-c", "command -v paru >/dev/null 2>&1 && echo paru || { command -v yay >/dev/null 2>&1 && echo yay; }"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.aurHelper = text.trim()
                aurCheck.running = true
            }
        }
    }
    Process {
        id: pacmanCheck
        command: ["sh", "-c", "if command -v checkupdates >/dev/null 2>&1; then checkupdates 2>/dev/null | wc -l; else echo -1; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim())
                page.pacmanCount = isNaN(n) ? -1 : n
            }
        }
    }
    Process {
        id: aurCheck
        command: ["sh", "-c", page.aurHelper === "" ? "echo -1" : page.aurHelper + " -Qua 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim())
                page.aurCount = isNaN(n) ? -1 : n
            }
        }
    }
    Process {
        id: flatpakCheck
        command: ["sh", "-c", "if command -v flatpak >/dev/null 2>&1; then flatpak remote-ls --updates 2>/dev/null | wc -l; else echo -1; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim())
                page.flatpakCount = isNaN(n) ? -1 : n
            }
        }
    }
    Process {
        id: dotfilesCheck
        command: ["sh", "-c", page.dotfilesCheckScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/)
                if (parts.length >= 2) {
                    const ahead = parseInt(parts[0])
                    const behind = parseInt(parts[1])
                    if (!isNaN(ahead) && !isNaN(behind)) {
                        page.dotfilesAhead = ahead
                        page.dotfilesBehind = behind
                        return
                    }
                }
                page.dotfilesAhead = 0
                page.dotfilesBehind = -1
            }
        }
    }
    function refresh() {
        pacmanCount = -2
        aurCount = -2
        flatpakCount = -2
        dotfilesBehind = -2
        dotfilesAhead = 0
        pacmanCheck.running = true
        flatpakCheck.running = true
        dotfilesCheck.running = true
        helperDetect.running = true     // chains into aurCheck
    }

    Timer { id: refreshTimer; interval: 500; onTriggered: page.refresh() }

    // ------------------------------------------------------------------
    // Persist selected updater
    // ------------------------------------------------------------------

    FileView {
        id: settingsFile
        path: page.stateDir + "/updates.json"
        blockLoading: true
    }

    Process {
        id: stateDirProcess
        command: ["mkdir", "-p", page.stateDir]
    }

    function loadSettings() {
        try {
            const s = JSON.parse(settingsFile.text())
            if (s.updater === "update.sh" || s.updater === "update2.sh")
                updater = s.updater
        } catch (error) {}
    }

    function setUpdater(name) {
        if (updater === name) return
        updater = name
        saveTimer.restart()
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: {
            try {
                settingsFile.setText(JSON.stringify({ updater: page.updater }, null, 2))
            } catch (error) {}
        }
    }

    // Reusable inline components
    component SectionTitle: Text {
        color: Theme.text
        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSection; font.bold: true; font.letterSpacing: 2
    }

    component GroupLabel: Text {
        color: Theme.text
        font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeGroup; font.bold: true; font.letterSpacing: 1
    }

    component Card: Rectangle {
        id: card
        default property alias contentData: cardColumn.data
        width: parent.width
        height: cardColumn.implicitHeight + 28
        radius: Theme.radius
        color: "#00000000"; border.width: 1; border.color: Theme.border

        Column {
            id: cardColumn
            x: 14; y: 14
            width: parent.width - 28
            spacing: 16
        }
    }

    component SmallButton: Rectangle {
        id: sb
        property string label: ""
        property string tip: ""
        property bool current: false
        property bool buttonEnabled: true
        signal clicked()
        height: 28; radius: Theme.radius
        opacity: buttonEnabled ? 1.0 : 0.35
        color: current ? Theme.alpha(Theme.accent, 0.10) : (sbMouse.containsMouse ? Theme.alpha(Theme.accent, 0.08) : "#00000000")
        border.width: 1
        border.color: current || sbMouse.containsMouse ? Theme.accent : Theme.border

        Text {
            anchors.centerIn: parent
            text: sb.label
            color: sb.current ? Theme.accent : Theme.text
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.bold: true; font.letterSpacing: 1
        }

        MouseArea {
            id: sbMouse
            anchors.fill: parent; hoverEnabled: true
            enabled: sb.buttonEnabled
            cursorShape: Qt.PointingHandCursor
            onEntered: if (sb.tip.length > 0) page.showTip(sb, sb.tip)
            onExited: page.hideTip()
            onClicked: { page.hideTip(); sb.clicked() }
        }
    }

    component UpdateRow: Item {
        id: ur
        property string label: ""
        property string detail: ""
        property int count: -2
        property bool buttonEnabled: true
        property bool showButton: true
        property bool attention: false
        signal run()

        width: parent.width; height: 28

        Row {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ur.label
                color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeBody; font.bold: true; font.letterSpacing: 1
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: ur.detail.length > 0
                text: ur.detail
                color: ur.attention ? Theme.accent2 : Theme.textDim
                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSmall
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                visible: ur.showButton
                anchors.verticalCenter: parent.verticalCenter
                text: page.countLabel(ur.count)
                color: page.countColor(ur.count)
                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSmall
            }

            SmallButton {
                visible: ur.showButton
                width: 90
                label: "UPDATE"
                buttonEnabled: ur.buttonEnabled && !runner.running
                onClicked: ur.run()
            }
        }
    }
    // UI
    Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: page.marginLeft; anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop; anchors.bottomMargin: page.marginBottom
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onMovingChanged: if (moving) page.hideTip()

        ScrollBar.vertical: ScrollBar {
            id: scrollBar

            background: Rectangle {
                color: "transparent"
                radius: width / 2
            }
            contentItem: Rectangle {
                color: "transparent"
                radius: width / 2
            }
        }

        Column {
            id: content
            width: flick.width
            spacing: 14

            Text {
                text: "UPDATES"; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeTitle; font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ---------------- SYSTEM PACKAGES ----------------
            Column {
                width: parent.width; spacing: 10
                topPadding: 6

                Item {
                    width: parent.width; height: 24

                    SectionTitle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "SYSTEM PACKAGES"
                    }

                    SmallButton {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 90; height: 24
                        label: "REFRESH"
                        onClicked: page.refresh()
                    }
                }

                Card {
                    Column {
                        width: parent.width; spacing: 10

                        UpdateRow {
                            label: "PACMAN"; detail: "official repos"
                            count: page.pacmanCount
                            onRun: page.run("Pacman update", page.pacmanScript)
                        }

                        UpdateRow {
                            label: "AUR"
                            detail: page.aurHelper !== "" ? "via " + page.aurHelper : "no helper found"
                            count: page.aurCount
                            buttonEnabled: page.aurHelper !== ""
                            onRun: page.run("AUR update", page.aurScript())
                        }

                        UpdateRow {
                            label: "FLATPAK"; detail: "apps & runtimes"
                            count: page.flatpakCount
                            buttonEnabled: page.flatpakCount !== -1
                            onRun: page.run("Flatpak update", page.flatpakScript)
                        }
                    }

                    Column {
                        width: parent.width; spacing: 8

                        GroupLabel { text: "EVERYTHING" }

                        SmallButton {
                            width: parent.width
                            label: "UPDATE ALL (PACMAN + AUR + FLATPAK)"
                            buttonEnabled: !runner.running
                            onClicked: page.run("Full system update", page.allScript())
                        }
                    }
                }
            }

            // ---------------- DESKTOP ----------------
            Column {
                width: parent.width; spacing: 10
                topPadding: 6
                bottomPadding: 6

                Item {
                    width: parent.width; height: 24

                    SectionTitle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "DESKTOP"
                    }

                    SmallButton {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 90; height: 24
                        label: "REFRESH"
                        onClicked: page.refresh()
                    }
                }

                Card {
                    Column {
                        width: parent.width; spacing: 10

                        UpdateRow {
                            label: "DOTFILES"
                            detail: page.dotfilesLabel
                            attention: page.dotfilesAttention
                            showButton: false
                        }

                        Text {
                            visible: page.dotfilesBehind > 0 && page.dotfilesAhead > 0
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: page.dotfilesBehind + " behind, " + page.dotfilesAhead
                                  + " ahead of upstream. A fast-forward pull will fail; rebase or merge manually."
                            color: Theme.textDim
                            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSmall
                        }
                    }

                    Column {
                        width: parent.width; spacing: 8

                        GroupLabel { text: "UPDATER" }

                        Row {
                            id: updaterRow
                            width: parent.width
                            spacing: 8

                            SmallButton {
                                width: (updaterRow.width - updaterRow.spacing) / 2
                                label: "UPDATE.SH"
                                tip: page.tipUpdateSh
                                current: page.updater === "update.sh"
                                onClicked: page.setUpdater("update.sh")
                            }

                            SmallButton {
                                width: (updaterRow.width - updaterRow.spacing) / 2
                                label: "UPDATE2.SH"
                                tip: page.tipUpdate2Sh
                                current: page.updater === "update2.sh"
                                onClicked: page.setUpdater("update2.sh")
                            }
                        }
                    }

                    SmallButton {
                        width: parent.width
                        tip: page.tipRunButton
                        current: page.dotfilesAttention
                        label: page.dotfilesBehind > 0 ? "UPDATE DESKTOP (" + page.dotfilesBehind + ")" : "UPDATE DESKTOP"
                        buttonEnabled: !runner.running
                        onClicked: page.run("Desktop setup update", page.desktopScript())
                    }
                }

                Text {
                    visible: page.statusText.length > 0
                    text: page.statusText
                    color: Theme.accent2
                    font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSmall; font.letterSpacing: 1
                }
            }
        }
    }

    // Shared tooltip, above everything else
    Rectangle {
        id: tooltip
        z: 100
        visible: page.tipShown
        width: Math.min(300, page.width - 8)
        height: tipLabel.implicitHeight + 16
        x: Math.max(4, Math.min(page.tipAnchorX, page.width - width - 4))
        y: (page.tipAnchorBottom + 6 + height <= page.height)
            ? page.tipAnchorBottom + 6
            : Math.max(4, page.tipAnchorTop - 6 - height)
        radius: Theme.radius
        color: Theme.bg
        border.width: 1
        border.color: Theme.accent

        Text {
            id: tipLabel
            x: 10; y: 8
            width: parent.width - 20
            wrapMode: Text.WordWrap
            text: page.tipText
            color: Theme.text
            font.family: Theme.fontFamily; font.pixelSize: Theme.textSizeSmall
        }
    }

    Component.onCompleted: {
        stateDirProcess.running = true
        loadSettings()
        refresh()
    }
}