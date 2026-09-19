import QtQuick
import Quickshell.Io
import "../"

Item {
    id: page

    property string homeDir: ""

    property string hostname: "..."
    property string uptime: "..."
    property string os: "..."

    property string cpu: "Loading..."
    property string gpu: "Loading..."
    property string memory: "Loading..."
    property string storage: "Loading..."

    // ------------------------------------------------------------
    // GLOBAL TEXT SIZES
    // ------------------------------------------------------------

    // Hardware section labels: CPU, GPU, MEMORY, STORAGE
    property int hardwareLabelSize: 12

    // Hardware values: CPU/GPU names, memory usage, storage usage
    property int hardwareTextSize: 12

    // ------------------------------------------------------------
    // HOME DIRECTORY
    // ------------------------------------------------------------

    Process {
        id: pHome

        command: [
            "sh",
            "-c",
            "printf '%s' \"$HOME\""
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                page.homeDir = text.trim()
            }
        }
    }

    // ------------------------------------------------------------
    // SYSTEM INFO
    // ------------------------------------------------------------

    Process {
        id: pHost

        command: [
            "sh",
            "-c",
            "hostnamectl --static 2>/dev/null || cat /etc/hostname"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.hostname = text.trim()
        }
    }

    Process {
        id: pUptime

        command: [
            "uptime",
            "-p"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.uptime = text.trim()
        }
    }

    Process {
        id: pOs

        command: [
            "sh",
            "-c",
            "grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"'"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.os = text.trim()
        }
    }

    // ------------------------------------------------------------
    // HARDWARE INFO
    // ------------------------------------------------------------

    Process {
        id: pCpu

        command: [
            "sh",
            "-c",
            "awk -F: '/model name/ {gsub(/^ +/, \"\", $2); print $2; exit}' /proc/cpuinfo"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.cpu = text.trim()
        }
    }

    Process {
        id: pGpu

        command: [
            "sh",
            "-c",
            "lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' | sed -E 's/.*: //; s/ \\(rev.*\\)//' | head -1"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                page.gpu = text.trim()

                if (page.gpu === "")
                    page.gpu = "Unknown"
            }
        }
    }

    Process {
        id: pMemory

        command: [
            "sh",
            "-c",
            "free -h | awk '/^Mem:/ {print $3 \" / \" $2}'"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.memory = text.trim()
        }
    }

    Process {
        id: pStorage

        command: [
            "sh",
            "-c",
            "df -h / | awk 'NR==2 {print $3 \" / \" $2 \" (\" $5 \")\"}'"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: page.storage = text.trim()
        }
    }

    // ------------------------------------------------------------
    // REFRESH
    // ------------------------------------------------------------

    Timer {
        interval: 5000
        running: true
        repeat: true

        onTriggered: {
            pUptime.running = true
            pMemory.running = true
            pStorage.running = true
        }
    }

    // ------------------------------------------------------------
    // MAIN CONTENT
    // ------------------------------------------------------------

    Column {
        anchors.fill: parent
        spacing: 20

        // --------------------------------------------------------
        // TITLE
        // --------------------------------------------------------

        Text {
            text: "SYSTEM"

            color: Theme.text

            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            font.bold: false
            font.letterSpacing: 3
        }

        // --------------------------------------------------------
        // DIVIDER
        // --------------------------------------------------------

        Rectangle {
            width: parent.width
            height: 1

            color: Theme.border
        }

        // --------------------------------------------------------
        // PROFILE + SYSTEM INFORMATION
        // --------------------------------------------------------

        Row {
            width: parent.width
            height: 150

            spacing: 24

            Item {
                width: 150
                height: 150

                Image {
                    anchors.centerIn: parent

                    source: page.homeDir !== ""
                        ? "file://" + page.homeDir + "/.config/fastfetch/pfp3.png"
                        : ""

                    width: 140
                    height: 140

                    fillMode: Image.PreserveAspectFit

                    smooth: true
                    mipmap: true
                    asynchronous: true
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                spacing: 14

                Column {
                    spacing: 3

                    Text {
                        text: "󰒋  HOSTNAME"

                        color: Theme.accent

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.letterSpacing: 2
                    }

                    Text {
                        text: page.hostname

                        color: Theme.text

                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                }

                Column {
                    spacing: 3

                    Text {
                        text: "󰣇  OS"

                        color: Theme.accent

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.letterSpacing: 2
                    }

                    Text {
                        text: page.os

                        color: Theme.text

                        font.family: Theme.fontFamily
                        font.pixelSize: 13

                        elide: Text.ElideRight
                        width: 500
                    }
                }

                Column {
                    spacing: 3

                    Text {
                        text: "󰔛  UPTIME"

                        color: Theme.accent

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.letterSpacing: 2
                    }

                    Text {
                        text: page.uptime

                        color: Theme.text

                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                }
            }
        }

        // --------------------------------------------------------
        // HARDWARE INFORMATION — SINGLE COLUMN
        // --------------------------------------------------------

        Column {
            width: parent.width
            spacing: 40

            // ----------------------------------------------------
            // CPU
            // ----------------------------------------------------

            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "󰍛  CPU"

                    color: Theme.accent

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: page.hardwareLabelSize
                    font.letterSpacing: 2
                }

                Text {
                    text: page.cpu

                    color: Theme.text

                    font.family: Theme.fontFamily
                    font.pixelSize: page.hardwareTextSize

                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            // ----------------------------------------------------
            // GPU
            // ----------------------------------------------------

            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "󰢮  GPU"

                    color: Theme.accent

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: page.hardwareLabelSize
                    font.letterSpacing: 2
                }

                Text {
                    text: page.gpu

                    color: Theme.text

                    font.family: Theme.fontFamily
                    font.pixelSize: page.hardwareTextSize

                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            // ----------------------------------------------------
            // MEMORY
            // ----------------------------------------------------

            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "󰘚  MEMORY"

                    color: Theme.accent

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: page.hardwareLabelSize
                    font.letterSpacing: 2
                }

                Text {
                    text: page.memory

                    color: Theme.text

                    font.family: Theme.fontFamily
                    font.pixelSize: page.hardwareTextSize
                }
            }

            // ----------------------------------------------------
            // STORAGE
            // ----------------------------------------------------

            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "󰋊  STORAGE"

                    color: Theme.accent

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: page.hardwareLabelSize
                    font.letterSpacing: 2
                }

                Text {
                    text: page.storage

                    color: Theme.text

                    font.family: Theme.fontFamily
                    font.pixelSize: page.hardwareTextSize
                }
            }
        }
    }
}
