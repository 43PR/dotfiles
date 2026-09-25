pragma Singleton
import QtQuick

QtObject {
    readonly property color bg: Qt.rgba(0, 0, 0, 0.7)
    readonly property color text: '#ffffff'
    readonly property color textDim: '#c2c2c2'
    readonly property int radius: 3

    readonly property color danger: "#ff003c" //red
    readonly property color accent: '#ffffff'   
    readonly property color accent2: "#ffffff"  
    readonly property color border: '#151515' 
    
    readonly property color bgPanel: "#050505"
    readonly property color bgCard: "#0d0d0d"
    readonly property color borderAccent: "#2a2a2a"
    readonly property color textFaint: "#4a4a4a"
    readonly property color ok: "#00ff9c"
    readonly property color trackBg: "#161616"
    readonly property string fontFamily: "JetBrains Mono"
    property string iconFont: "JetBrainsMono Nerd Font"

    readonly property int animFast: 120
    readonly property int animMed: 220
    readonly property int animSlow: 380

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
}
