
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: root
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 140
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Unmap the surface when idle; stay mapped during the fade-out
    visible: showing || flyout.opacity > 0

    mask: Region {
        item: root.showing ? flyout : null
    }

    property bool showing: false
    property bool cancelled: false
    property string imagePath: ""

    property string kind: "screenshot"   // "screenshot" | "ocr"
    property string ocrState: ""         // "working" | "done" | "empty" | "cancelled"
    property string ocrText: ""

    readonly property bool isOcr: kind === "ocr"
    readonly property string titleText: {
        if (isOcr) {
            switch (ocrState) {
            case "working":   return "Reading text…"
            case "done":      return "Text copied"
            case "empty":     return "No text found"
            default:          return "OCR cancelled"
            }
        }
        return cancelled ? "Screenshot cancelled" : "Screenshot saved"
    }
    readonly property string subText: {
        if (isOcr) {
            switch (ocrState) {
            case "working":   return "Please wait"
            case "done":      return "Copied to clipboard"
            case "empty":     return "Try a larger area"
            default:          return "No area selected"
            }
        }
        return cancelled ? "No area selected" : "Copied to clipboard"
    }

    // Release the decoded pixmap only after the fade-out has finished
    onVisibleChanged: if (!visible) imagePath = ""

    function showOsd(path) {
        kind = "screenshot"
        cancelled = false
        ocrState = ""
        ocrText = ""
        imagePath = path
        showing = true
        hideTimer.interval = 2200
        hideTimer.restart()
    }

    function showCancelled() {
        kind = "screenshot"
        cancelled = true
        ocrState = ""
        ocrText = ""
        imagePath = ""
        showing = true
        hideTimer.interval = 2200
        hideTimer.restart()
    }

    function showOcr(state, text) {
        kind = "ocr"
        ocrState = state
        ocrText = text
        cancelled = false
        imagePath = ""
        showing = true
        // "working" gets a long fallback so the OSD can't get stuck if the script dies
        hideTimer.interval = state === "working" ? 15000 : 2200
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 2200
        repeat: false
        onTriggered: root.showing = false
    }

    IpcHandler {
        target: "screenshot"
        function notify(path: string): void {
            root.showOsd(path)
        }
        function cancelled(): void {
            root.showCancelled()
        }
    }

    IpcHandler {
        target: "ocr"
        function working(): void { root.showOcr("working", "") }
        function done(preview: string): void { root.showOcr("done", preview) }
        function empty(): void { root.showOcr("empty", "") }
        function cancelled(): void { root.showOcr("cancelled", "") }
    }

    Rectangle {
        id: flyout
        width: 320
        height: 84
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 30
        radius: 20
        color: Theme.alpha(Theme.bg, 0.8)
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.9

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 14

            Rectangle {
                id: thumb
                width: 60
                height: 60
                radius: 10
                color: "#33ffffff"
                clip: true
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    source: root.imagePath ? "file://" + root.imagePath : ""
                    sourceSize: Qt.size(120, 120)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
                Text {
                    anchors.centerIn: parent
                    visible: !root.imagePath
                    text: root.isOcr
                          ? (root.ocrState === "done" || root.ocrState === "working" ? "Aa" : "󰜺")
                          : (root.cancelled ? "󰜺" : "󰄀")
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 22
                    color: Theme.text
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                width: parent.width - thumb.width - parent.spacing

                // title
                Text {
                    text: root.titleText
                    font.pixelSize: 13
                    font.bold: true
                    color: Theme.text
                }
                // middle line: filename for screenshots, text preview for OCR
                Text {
                    visible: root.isOcr ? root.ocrState === "done" : !root.cancelled
                    text: root.isOcr ? root.ocrText : root.imagePath.split("/").pop()
                    font.pixelSize: 11
                    color: Theme.textDim
                    elide: root.isOcr ? Text.ElideRight : Text.ElideMiddle
                    width: parent.width
                }
                // bottom line
                Text {
                    text: root.subText
                    font.pixelSize: 10
                    color: Theme.textDim
                }
            }
        }
    }
}
