import QtQuick
import Quickshell.Io
import "../"

Item {
    id: page

    property var filesystems: []
    property var cleanupInfo: ({yay:0,pacman:0,journal:0,trash:0,flatpak:0})
    property int contentMargin: 0
    property int contentRightMargin: 48
    property int contentTopMargin: 0
    property int contentBottomMargin: 0
    property string pendingAction: ""
    property string pendingTitle: ""
    property string pendingMessage: ""

    function formatBytes(b) {
        if (!isFinite(b) || b < 0) return "0 B"
        var u=["B","KB","MB","GB","TB"],i=0,v=b
        while(v>=1024&&i<u.length-1){v/=1024;++i}
        return (i?v.toFixed(1):Math.round(v))+" "+u[i]
    }

    function parseSize(v) {
        if (!v) return 0
        var p=v.trim().split(/\s+/),n=parseFloat(p[0])
        if(isNaN(n)) return 0
        var u={B:1,K:1024,KB:1024,KIB:1024,M:1048576,MB:1048576,MIB:1048576,
               G:1073741824,GB:1073741824,GIB:1073741824,T:1099511627776,
               TB:1099511627776,TIB:1099511627776}
        return n*(p.length>1?(u[p[1].toUpperCase()]||1):1)
    }

    function usageColor(p){return p>=90?Theme.danger:p>=75?Theme.accent2:Theme.accent}
    function usageWidth(p){return Math.min(1,Math.max(0,p/100))}
    function ignoredMount(m){return ["/proc","/sys","/run","/dev"].some(x=>m.indexOf(x)===0)}
    function ignoredFilesystem(f){return ["tmpfs","devtmpfs","overlay"].some(x=>f.indexOf(x)===0)}

    function parseDfLine(line) {
        var f=line.trim().split(/\s+/)
        if(f.length<6)return null
        var d={filesystem:f[0],total:parseInt(f[1]),used:parseInt(f[2]),available:parseInt(f[3]),
               percent:parseInt(f[4].replace("%","")),mount:f.slice(5).join(" ")}
        return isNaN(d.total)||isNaN(d.used)||isNaN(d.available)||isNaN(d.percent)||
               ignoredMount(d.mount)||ignoredFilesystem(d.filesystem)?null:d
    }

    function runCommand(c){commandProcess.command=["sh","-c",c];commandProcess.running=true}
    function refreshAll(){pStorage.running=true;pCleanup.running=true}
    function confirmAction(t,m,c){pendingTitle=t;pendingMessage=m;pendingAction=c;confirmPopup.visible=true}

    Process {
        id:pStorage
        command:["sh","-c","df -P -B1 2>/dev/null"]

        stdout:StdioCollector {
            onStreamFinished:{
                var fs=[]
                var a=text.trim().split("\n")
                for(var i=0;i<a.length;++i){var x=parseDfLine(a[i]);if(x)fs.push(x)}
                page.filesystems=fs
            }
        }

        stderr:StdioCollector{}
    }

    Process {
        id:pCleanup
        command:["sh","-c",
            "printf 'YAY '; du -sb \"$HOME/.cache/yay\" 2>/dev/null | awk '{print $1}'; "+
            "printf 'PACMAN '; du -sb /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}'; "+
            "printf 'JOURNAL '; journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+ (B|K|M|G|T)' | tail -1; "+
            "printf 'TRASH '; du -sb \"$HOME/.local/share/Trash\" 2>/dev/null | awk '{print $1}'; "+
            "printf 'FLATPAK '; flatpak uninstall --unused --assumeno 2>/dev/null | grep -oE '[0-9.]+ (kB|MB|GB|TB)' | tail -1"]

        stdout:StdioCollector {
            onStreamFinished:{
                var info={yay:0,pacman:0,journal:0,trash:0,flatpak:0}
                var lines=text.trim().split("\n")
                for(var i=0;i<lines.length;++i){
                    var p=lines[i].trim().split(/\s+/)
                    if(p.length<2)continue
                    var k=p[0].toLowerCase()
                    if(info[k]!==undefined)info[k]=parseSize(p.slice(1).join(" "))
                }
                page.cleanupInfo=info
            }
        }

        stderr:StdioCollector{}
    }

    Process {
        id:commandProcess
        stdout:StdioCollector{}
        stderr:StdioCollector{}
        onRunningChanged:if(!running)page.refreshAll()
    }

    Rectangle {
        id:confirmPopup
        visible:false
        anchors.centerIn:parent
        width:Math.min(parent.width-30,420)
        height:190
        radius:Theme.radius
        color:"#000000"
        border.width:1
        border.color:Theme.border
        z:100

        Column {
            anchors.fill:parent
            anchors.margins:18
            spacing:12

            Text {
                text:page.pendingTitle
                color:"#ffffff"
                font.family:Theme.fontFamily
                font.pixelSize:15
                font.bold:true
            }

            Text {
                width:parent.width
                text:page.pendingMessage
                color:"#ffffff"
                font.family:Theme.fontFamily
                font.pixelSize:11
                wrapMode:Text.WordWrap
            }

            Item{width:1;height:1}

            Row {
                width:parent.width
                spacing:8

                ToolButton {
                    width:(parent.width-8)/2
                    label:"CANCEL"
                    onClicked:confirmPopup.visible=false
                }

                ToolButton {
                    width:(parent.width-8)/2
                    label:"CONFIRM"
                    onClicked:{
                        confirmPopup.visible=false
                        page.runCommand(page.pendingAction)
                    }
                }
            }
        }
    }

    Timer {
        interval:10000
        running:true
        repeat:true
        onTriggered:page.refreshAll()
    }

    Component.onCompleted:page.refreshAll()

    Column {
        anchors.fill:parent
        anchors.leftMargin:page.contentMargin
        anchors.rightMargin:page.contentRightMargin
        anchors.topMargin:page.contentTopMargin
        anchors.bottomMargin:page.contentBottomMargin
        spacing:9

        Row {
            id:header
            width:parent.width
            height:36

            Text {
                text:"STORAGE"
                color:Theme.text
                font.family:Theme.fontFamily
                font.pixelSize:19
                font.letterSpacing:3
                anchors.verticalCenter:parent.verticalCenter
                anchors.verticalCenterOffset:-6
            }
        }

        Rectangle{width:parent.width;height:1;color:Theme.border}

        Item {
            width:parent.width
            height:parent.height-header.height-10

            Flickable {
                anchors.fill:parent
                clip:true
                contentWidth:width
                contentHeight:list.height

                Column {
                    id:list
                    width:parent.width
                    spacing:8

                    Text {
                        text:"FILESYSTEMS"
                        color:Theme.textDim
                        font.family:Theme.fontFamily
                        font.pixelSize:12
                        font.bold:true
                        font.letterSpacing:2
                    }

                    Repeater {
                        model:page.filesystems

                        delegate:Rectangle {
                            required property var modelData
                            width:list.width
                            height:64
                            radius:Theme.radius
                            color:"#00000000"
                            border.width:1
                            border.color:Theme.border

                            Column {
                                anchors.fill:parent
                                anchors.margins:9
                                spacing:5

                                Row {
                                    width:parent.width
                                    height:17

                                    Text {
                                        width:parent.width-55
                                        text:modelData.mount
                                        color:Theme.text
                                        font.family:Theme.fontFamily
                                        font.pixelSize:11
                                        font.bold:true
                                        elide:Text.ElideRight
                                        verticalAlignment:Text.AlignVCenter
                                    }

                                    Text {
                                        width:55
                                        text:modelData.percent+"%"
                                        color:page.usageColor(modelData.percent)
                                        font.family:Theme.fontFamily
                                        font.pixelSize:10
                                        font.bold:true
                                        horizontalAlignment:Text.AlignRight
                                        verticalAlignment:Text.AlignVCenter
                                    }
                                }

                                Rectangle {
                                    width:parent.width
                                    height:4
                                    radius:2
                                    color:Theme.alpha(Theme.textDim,.15)

                                    Rectangle {
                                        width:parent.width*page.usageWidth(modelData.percent)
                                        height:parent.height
                                        radius:2
                                        color:page.usageColor(modelData.percent)

                                        Behavior on width{NumberAnimation{duration:Theme.animMed}}
                                    }
                                }

                                Row {
                                    width:parent.width
                                    height:13
                                    spacing:14

                                    Text{text:page.formatBytes(modelData.used)+" USED";color:Theme.textDim;font.family:Theme.fontFamily;font.pixelSize:8}
                                    Text{text:page.formatBytes(modelData.available)+" FREE";color:Theme.textDim;font.family:Theme.fontFamily;font.pixelSize:8}
                                    Text{text:page.formatBytes(modelData.total)+" TOTAL";color:Theme.textDim;font.family:Theme.fontFamily;font.pixelSize:8}
                                }
                            }
                        }
                    }

                    Text {
                        text:"TOOLS"
                        color:Theme.textDim
                        font.family:Theme.fontFamily
                        font.pixelSize:12
                        font.bold:true
                        font.letterSpacing:2
                        topPadding:4
                    }

                    Row {
                        width:parent.width
                        spacing:6

                        ToolButton {
                            width:(parent.width-6)/2
                            label:"NCDU HOME"
                            onClicked:page.runCommand("kitty --title 'ncdu ~' ncdu \"$HOME\"")
                        }

                        ToolButton {
                            width:(parent.width-6)/2
                            label:"NCDU /"
                            onClicked:page.runCommand("kitty --title 'ncdu /' sudo ncdu /")
                        }
                    }

                    Row {
                        width:parent.width
                        spacing:6

                        ToolButton {
                            width:(parent.width-6)/2
                            label:"LARGE FILES"
                            onClicked:page.runCommand(
                                "kitty --hold --title 'Large Files' bash -lc "+
                                "'echo \"Scanning $HOME for files larger than 0.2 GiB...\"; "+
                                "echo; find \"$HOME\" -type f -size +200M "+
                                "-printf \"%s %p\\\\n\" 2>/dev/null | sort -nr | head -30 | "+
                                "numfmt --field=1 --to=iec; echo; "+
                                "echo \"Scan complete. Press Enter to close.\"; read'"
                            )
                        }

                        ToolButton {
                            width:(parent.width-6)/2
                            label:"REFRESH"
                            onClicked:page.refreshAll()
                        }
                    }

                    Text {
                        text:"CLEANUP"
                        color:Theme.textDim
                        font.family:Theme.fontFamily
                        font.pixelSize:12
                        font.bold:true
                        font.letterSpacing:2
                        topPadding:4
                    }

                    CleanupButton {
                        width:parent.width
                        label:"TRASH"
                        value:page.formatBytes(page.cleanupInfo.trash)
                        actionText:"EMPTY"
                        onClicked:page.confirmAction(
                            "EMPTY TRASH?",
                            "This permanently deletes everything in ~/.local/share/Trash.",
                            "rm -rf -- \"$HOME/.local/share/Trash/files/\"* \"$HOME/.local/share/Trash/info/\"*"
                        )
                    }

                    CleanupButton {
                        width:parent.width
                        label:"YAY CACHE"
                        value:page.formatBytes(page.cleanupInfo.yay)
                        actionText:"CLEAN"
                        onClicked:page.confirmAction(
                            "CLEAR YAY CACHE?",
                            page.formatBytes(page.cleanupInfo.yay)+" currently in ~/.cache/yay",
                            "rm -rf -- \"$HOME/.cache/yay/\"*"
                        )
                    }

                    CleanupButton {
                        width:parent.width
                        label:"PACMAN CACHE"
                        value:page.formatBytes(page.cleanupInfo.pacman)
                        actionText:"CLEAN"
                        onClicked:page.confirmAction(
                            "CLEAN PACMAN CACHE?",
                            "paccache will remove old package versions while keeping the currently installed packages.",
                            "sudo paccache -r"
                        )
                    }

                    CleanupButton {
                        width:parent.width
                        label:"JOURNAL"
                        value:page.formatBytes(page.cleanupInfo.journal)
                        actionText:"7 DAYS"
                        onClicked:page.confirmAction(
                            "VACUUM JOURNAL?",
                            "Keep only the last 7 days of system logs.",
                            "sudo journalctl --vacuum-time=7d"
                        )
                    }

                    CleanupButton {
                        width:parent.width
                        label:"FLATPAK UNUSED"
                        value:page.formatBytes(page.cleanupInfo.flatpak)
                        actionText:"CLEAN"
                        onClicked:page.confirmAction(
                            "REMOVE UNUSED FLATPAKS?",
                            "This removes unused Flatpak runtimes and packages.",
                            "flatpak uninstall --unused"
                        )
                    }
                }
            }
        }
    }

    component ToolButton: Rectangle {
        property string label:""
        property bool accent:false
        signal clicked()

        height:38
        radius:Theme.radius
        color:accent?Theme.alpha(Theme.accent,.10):Theme.alpha(Theme.textDim,.06)
        border.width:1
        border.color:Theme.border

        Text {
            anchors.centerIn:parent
            text:label
            color:accent?Theme.accent:Theme.text
            font.family:Theme.fontFamily
            font.pixelSize:9
            font.bold:true
            font.letterSpacing:.5
        }

        MouseArea {
            anchors.fill:parent
            hoverEnabled:true

            onEntered:{
                parent.border.color=Theme.border
                parent.color=accent?Theme.alpha(Theme.accent,.18):Theme.alpha(Theme.textDim,.12)
            }

            onExited:{
                parent.border.color=Theme.border
                parent.color=accent?Theme.alpha(Theme.accent,.10):Theme.alpha(Theme.textDim,.06)
            }

            onClicked:parent.clicked()
        }
    }

    component CleanupButton: Rectangle {
        property string label:""
        property string value:""
        property string actionText:""
        signal clicked()

        height:38
        radius:Theme.radius
        color:Theme.alpha(Theme.textDim,.06)
        border.width:1
        border.color:Theme.border

        Text {
            anchors.left:parent.left
            anchors.leftMargin:12
            anchors.verticalCenter:parent.verticalCenter
            text:label
            color:Theme.text
            font.family:Theme.fontFamily
            font.pixelSize:9
            font.bold:true
            font.letterSpacing:.5
        }

        Text {
            anchors.right:actionButton.left
            anchors.rightMargin:10
            anchors.verticalCenter:parent.verticalCenter
            text:value
            color:Theme.textDim
            font.family:Theme.fontFamily
            font.pixelSize:9
            horizontalAlignment:Text.AlignRight
        }

        Rectangle {
            id:actionButton
            width:70
            height:28
            anchors.right:parent.right
            anchors.rightMargin:5
            anchors.verticalCenter:parent.verticalCenter
            radius:Theme.radius
            color:Theme.alpha(Theme.textDim,.08)
            border.width:1
            border.color:Theme.border

            Text {
                anchors.centerIn:parent
                text:actionText
                color:Theme.text
                font.family:Theme.fontFamily
                font.pixelSize:8
                font.bold:true
                font.letterSpacing:.5
            }

            MouseArea {
                anchors.fill:parent
                hoverEnabled:true
                onEntered:actionButton.color=Theme.alpha(Theme.textDim,.14)
                onExited:actionButton.color=Theme.alpha(Theme.textDim,.08)
                onClicked:parent.parent.clicked()
            }
        }

        MouseArea {
            anchors.fill:parent
            z:-1
            hoverEnabled:true

            onEntered:{
                parent.border.color=Theme.border
                parent.color=Theme.alpha(Theme.textDim,.12)
            }

            onExited:{
                parent.border.color=Theme.border
                parent.color=Theme.alpha(Theme.textDim,.06)
            }

            onClicked:parent.clicked()
        }
    }
}
