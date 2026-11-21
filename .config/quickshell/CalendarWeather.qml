pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

// CalendarWeather.qml  (put it next to SidePanel.qml)
Item {
    id: cw

    // ───────────────────────── inputs (set by SidePanel.qml) ─────────────────────────
    property real ui: 1                       // root.ui
    property real tx: 1                       // root.tx
    property color accent: Theme.accent
    property int animMs: 200
    property bool active: true                // true while the panel is open (weather only refreshes then)
    property string mode: "calendar"          // "calendar" | "weather"
    property date now: new Date()
    property bool weekMonday: true
    property bool clock24: true
    property bool clockSeconds: false
    property var reminders: []                // [{ ts, text, notified }]
    property int monthOffset: 0
    property real selTs: -1                   // local-midnight epoch ms of the selected day, -1 = none
    property bool showDivider: false
    property var tryAddReminder: null         // function (dayTs, clockStr, text) -> bool
    property bool scrollSwitch: true          // scroll over the block switches calendar / weather

    signal modeRequested(string m)
    signal monthOffsetRequested(int v)
    signal selTsRequested(real v)

    // ───────────────────────── helpers ─────────────────────────
    function px(n) { return Math.round(n * ui) }
    function fs(n) { return Math.round(n * ui * tx) }
    function pad2(n) { return String(n).padStart(2, "0") }

    readonly property string icLeft: "\uDB80\uDD41"
    readonly property string icRight: "\uDB80\uDD42"
    readonly property bool showWx: mode === "weather"

    function clockText(d) {
        const h = clock24 ? d.getHours() : (d.getHours() % 12 || 12)
        let t = pad2(h) + ":" + pad2(d.getMinutes())
        if (clockSeconds) t += ":" + pad2(d.getSeconds())
        return clock24 ? t : t + " " + (d.getHours() >= 12 ? "pm" : "am")
    }
    // same as clockText, but the seconds are drawn smaller (needs RichText)
    function clockHtml(d) {
        const h = clock24 ? d.getHours() : (d.getHours() % 12 || 12)
        let t = pad2(h) + ":" + pad2(d.getMinutes())
        if (clockSeconds)
            t += "<span style=\"font-size:" + Math.round(fs(30) * 0.55) + "px\">:" + pad2(d.getSeconds()) + "</span>"
        return clock24 ? t : t + " " + (d.getHours() >= 12 ? "pm" : "am")
    }
    function remindersOn(dayTs) {
        const s = new Date(dayTs)
        const e = new Date(s.getFullYear(), s.getMonth(), s.getDate() + 1).getTime()
        return reminders.filter(r => r.ts >= dayTs && r.ts < e).sort((a, b) => a.ts - b.ts)
    }

    // ───────────────────────── weather state ─────────────────────────
    property string wxState: "loading"        // loading | ok | error
    readonly property bool wxOk: wxState === "ok"
    property real tempC: 0
    property real feelsC: 0
    property int humidity: 0
    property real windKmh: 0
    property int rainPct: 0
    property int code: 0
    property bool isDay: true
    property var hourly: []                   // [{ h, t, code, day }] (8 entries, first = current hour)
    property real lat: 0
    property real lon: 0
    property string loc: ""
    property bool haveGeo: false
    property string geoCity: ""               // the weatherCity the stored lat/lon belong to
    property real fetchedAt: 0
    property bool ready: false

    // from bar-state.json (same settings as the bar's weather module)
    property bool useF: false
    property string city: ""

    readonly property var wxNames: ({
        0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
        45: "Fog", 48: "Fog", 51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle",
        56: "Freezing drizzle", 57: "Freezing drizzle", 61: "Light rain", 63: "Rain", 65: "Heavy rain",
        66: "Freezing rain", 67: "Freezing rain", 71: "Light snow", 73: "Snow", 75: "Heavy snow",
        77: "Snow grains", 80: "Rain showers", 81: "Rain showers", 82: "Heavy showers",
        85: "Snow showers", 86: "Snow showers", 95: "Thunderstorm", 96: "Thunderstorm", 99: "Thunderstorm"
    })
    readonly property string condText: {
    if (code === 0) return isDay ? "Sunny" : "Clear"
    if (code === 1) return isDay ? "Mostly sunny" : "Mostly clear"
    if (code === 3) return "Cloudy"
    return wxNames[code] ?? ""
}
    readonly property string windText: Math.round(useF ? windKmh * 0.621371 : windKmh) + (useF ? " mph" : " km/h")

    function glyphFor(c, day) {
        if (c === 0 || c === 1) return day ? "\uDB81\uDD99" : "\uDB81\uDD94"
        if (c === 2) return day ? "\uDB81\uDD95" : "\uDB83\uDF31"
        if (c === 3) return "\uDB81\uDD90"
        if (c === 45 || c === 48) return "\uDB81\uDD91"
        if (c >= 95) return "\uDB81\uDE7E"
        if (c === 56 || c === 57 || c === 66 || c === 67) return "\uDB81\uDE7F"
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "\uDB81\uDD98"
        if (c === 65 || c === 82) return "\uDB81\uDD96"
        return "\uDB81\uDD97"
    }
    function fmtT(c) { return Math.round(useF ? c * 9 / 5 + 32 : c) + "°" }
    function hourLabel(h) {
        return clock24 ? pad2(h) : ((h % 12 || 12) + (h >= 12 ? "p" : "a"))
    }

    function readBar() {
        try {
            const j = JSON.parse(barFile.text())
            if (typeof j.weatherF === "boolean") useF = j.weatherF
            if (typeof j.weatherCity === "string") city = j.weatherCity
        } catch (e) {}
    }
    function readCache() {
        try {
            const o = JSON.parse(cacheFile.text())
            if (!o || typeof o.at !== "number" || !Array.isArray(o.hourly) || o.hourly.length === 0) return
            if (Date.now() - o.at > 6 * 3600 * 1000) return
            fetchedAt = o.at
            geoCity = String(o.city ?? "")
            haveGeo = typeof o.lat === "number" && typeof o.lon === "number"
            lat = o.lat ?? 0
            lon = o.lon ?? 0
            loc = String(o.loc ?? "")
            tempC = o.tempC
            feelsC = o.feelsC
            humidity = o.humidity
            windKmh = o.windKmh
            rainPct = o.rainPct
            code = o.code
            isDay = o.isDay === true
            hourly = o.hourly
            wxState = "ok"
        } catch (e) {}
    }
    function saveCache() {
        try {
            cacheFile.setText(JSON.stringify({
                at: fetchedAt, city: geoCity, lat: lat, lon: lon, loc: loc,
                tempC: tempC, feelsC: feelsC, humidity: humidity, windKmh: windKmh,
                rainPct: rainPct, code: code, isDay: isDay, hourly: hourly
            }))
        } catch (e) {}
    }
    function applyForecast(j) {
        const c = j.current, h = j.hourly
        const key = String(c.time).slice(0, 13)
        let i0 = 0
        for (let i = 0; i < h.time.length; i++) {
            if (String(h.time[i]).slice(0, 13) >= key) { i0 = i; break }
        }
        const out = []
        for (let i = i0; i < Math.min(h.time.length, i0 + 8); i++)
            out.push({
                h: parseInt(String(h.time[i]).slice(11, 13)),
                t: h.temperature_2m[i],
                code: h.weather_code[i],
                day: h.is_day[i] === 1
            })
        tempC = c.temperature_2m
        feelsC = c.apparent_temperature
        humidity = Math.round(c.relative_humidity_2m)
        windKmh = c.wind_speed_10m
        code = c.weather_code
        isDay = c.is_day === 1
        rainPct = Math.round(h.precipitation_probability[i0] ?? 0)
        hourly = out
        fetchedAt = Date.now()
        wxState = "ok"
    }
    function fetchForecast() { if (!wxProc.running) wxProc.running = true }
    function refresh() {
        if (geoProc.running || wxProc.running) return
        if (haveGeo) fetchForecast()
        else geoProc.running = true
    }
    // refreshes only while the panel is open and the data is older than 10 minutes
    function maybeRefresh() {
        if (!ready || !active) return
        if (geoCity !== city) haveGeo = false
        const fresh = wxOk && geoCity === city && Date.now() - fetchedAt < 600000
        if (!fresh) refresh()
    }

    onActiveChanged: if (active) maybeRefresh()
    Component.onCompleted: { readBar(); readCache(); ready = true; maybeRefresh() }

    FileView {
        id: barFile
        path: Quickshell.env("HOME") + "/.config/quickshell/state/bar-state.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { cw.readBar(); cw.maybeRefresh() }
    }
    FileView {
        id: cacheFile
        path: Quickshell.env("HOME") + "/.cache/43pr/weather-panel.json"
        blockLoading: true
        printErrors: false
    }

    Process {
        id: geoProc
        command: cw.city === ""
            ? ["curl", "-sf", "-m", "10", "http://ip-api.com/json/?fields=status,city,regionName,lat,lon"]
            : ["curl", "-sf", "-m", "10",
               "https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(cw.city)]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    const r = cw.city === "" ? j : j.results[0]
                    cw.lat = r.lat ?? r.latitude
                    cw.lon = r.lon ?? r.longitude
                    cw.loc = cw.city === "" ? (r.city || r.regionName || "") : (r.name || cw.city)
                    cw.geoCity = cw.city
                    cw.haveGeo = true
                    cw.fetchForecast()
                } catch (e) {
                    if (!cw.wxOk) cw.wxState = "error"
                }
            }
        }
    }
    Process {
        id: wxProc
        command: ["curl", "-sf", "-m", "15",
                  "https://api.open-meteo.com/v1/forecast?latitude=" + cw.lat + "&longitude=" + cw.lon
                  + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
                  + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
                  + "&forecast_days=2&timezone=auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    cw.applyForecast(JSON.parse(text))
                    cw.saveCache()
                } catch (e) {
                    if (!cw.wxOk) cw.wxState = "error"
                }
            }
        }
    }
    Timer { interval: 600000; repeat: true; running: cw.active; onTriggered: cw.maybeRefresh() }

    // ───────────────────────── scroll = switch view ─────────────────────────
    property real wheelAcc: 0
    Timer { id: wheelLock; interval: 400; onTriggered: cw.wheelAcc = 0 }

    WheelHandler {
        enabled: cw.scrollSwitch
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        acceptedModifiers: Qt.NoModifier
        onWheel: e => {
            if (wheelLock.running) return
            cw.wheelAcc += e.angleDelta.y
            if (Math.abs(cw.wheelAcc) < 120) return
            const down = cw.wheelAcc < 0
            cw.wheelAcc = 0
            wheelLock.restart()
            // down -> weather, up -> calendar. To let ANY direction toggle instead, replace the next line with:
            //   cw.modeRequested(cw.showWx ? "calendar" : "weather")
            const target = down ? "weather" : "calendar"
            if (target !== cw.mode) cw.modeRequested(target)
        }
    }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        acceptedModifiers: Qt.ControlModifier
        onWheel: e => cw.monthOffsetRequested(cw.monthOffset + (e.angleDelta.y > 0 ? -1 : 1))
    }

    // ───────────────────────── reusable bits ─────────────────────────
    component Lbl: Text {
        property real sz: 10
        property real k: 1
        font.family: Theme.iconFont
        font.pixelSize: Math.round(sz * cw.ui * cw.tx * k)
        color: Theme.text
        elide: Text.ElideRight
    }

    component NavBtn: Rectangle {
        id: b
        property real base: 24
        property string icon: ""
        property string tip: ""
        property color tint: Theme.text
        property real rest: 0.08
        property real hot: 0.2
        property bool tipReady: false
        signal clicked()
        width: cw.px(base)
        height: width
        radius: Math.round(width / 3)
        color: Theme.alpha(tint, area.containsMouse ? hot : rest)

        Text {
            anchors.centerIn: parent
            text: b.icon
            font.family: Theme.iconFont
            font.pixelSize: Math.round(b.width * 0.54)
            color: b.tint
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: b.clicked()
            onContainsMouseChanged: {
                b.tipReady = false
                if (containsMouse) tipTimer.restart(); else tipTimer.stop()
            }
        }
        Timer { id: tipTimer; interval: 400; onTriggered: b.tipReady = true }

        Rectangle {
            visible: b.tipReady && b.tip !== ""
            anchors.top: parent.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            z: 100
            width: tipText.implicitWidth + cw.px(14)
            height: tipText.implicitHeight + cw.px(8)
            radius: cw.px(7)
            color: Theme.bg
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.15)
            Lbl { id: tipText; anchors.centerIn: parent; sz: 9; text: b.tip }
        }
    }

    // icon + value + small caps label (wind, humidity, ...)
    component Stat: Row {
        id: st
        property string glyph: ""
        property string value: ""
        property string label: ""
        spacing: cw.px(6)
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: st.glyph
            font.family: Theme.iconFont
            font.pixelSize: cw.px(19)
            color: Theme.textDim
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: cw.px(1)
            Lbl { sz: 16; font.bold: true; text: st.value }
            Lbl { sz: 10; color: Theme.textDim; font.letterSpacing: 1; text: st.label }
        }
    }

    // ───────────────────────── layout ─────────────────────────
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: cw.px(8)

        Rectangle {
            visible: cw.showDivider
            width: parent.width
            height: 1
            color: Theme.alpha(Theme.text, 0.12)
        }

        // Both views live in the same box. The box is as tall as the calendar,
        // so switching view never changes the panel height.
        Item {
            id: stage
            width: parent.width
            height: calView.implicitHeight
            clip: true

            // ═════════════ calendar view ═════════════
            Column {
                id: calView
                width: parent.width
                spacing: cw.px(8)
                enabled: !cw.showWx
                opacity: cw.showWx ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: cw.animMs; easing.type: Easing.InOutQuad } }
                transform: Translate {
                    x: cw.showWx ? -cw.width : 0
                    Behavior on x { NumberAnimation { duration: cw.animMs; easing.type: Easing.OutCubic } }
                }

                readonly property int firstDay: cw.weekMonday ? 1 : 0
                readonly property int cellW: Math.floor(width / 7)
                readonly property int cellH: cw.px(28)
                readonly property date view: new Date(cw.now.getFullYear(), cw.now.getMonth() + cw.monthOffset, 1)
                readonly property var cells: {
                    const first = (view.getDay() - firstDay + 7) % 7
                    const y = view.getFullYear(), m = view.getMonth()
                    const ty = cw.now.getFullYear(), tm = cw.now.getMonth(), td = cw.now.getDate()
                    const marks = {}
                    cw.reminders.forEach(r => {
                        const rd = new Date(r.ts)
                        marks[new Date(rd.getFullYear(), rd.getMonth(), rd.getDate()).getTime()] = true
                    })
                    return Array.from({ length: 42 }, (_, i) => {
                        const d = new Date(y, m, i - first + 1)
                        return {
                            ts: d.getTime(),
                            hasRem: marks[d.getTime()] === true,
                            n: d.getDate(),
                            inMonth: d.getMonth() === m,
                            today: d.getFullYear() === ty && d.getMonth() === tm && d.getDate() === td
                        }
                    })
                }

                // clock centered, weekday + "Month day" on the right
                Item {
                    width: parent.width
                    height: Math.max(clockLbl.implicitHeight, dateLbl.implicitHeight)

                    Lbl {
                        id: clockLbl
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: cw.px(4)
                        sz: 34
                        color: Theme.textDim
                        font.bold: true
                        font.family: Theme.iconFont
                        textFormat: Text.RichText
                        elide: Text.ElideNone
                        text: cw.clockHtml(cw.now)
                    }
                    Lbl {
                        id: dateLbl
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: cw.px(4)
                        horizontalAlignment: Text.AlignRight
                        sz: 12
                        color: Theme.textDim
                        elide: Text.ElideNone
                        text: Qt.formatDate(cw.now, "dddd") + "\n" + Qt.formatDate(cw.now, "MMMM d")
                    }
                }

                // month navigation
                Item {
                    width: parent.width
                    height: cw.px(26)

                    NavBtn {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        base: 24
                        rest: 0
                        icon: cw.icLeft
                        tip: "Previous month (PgUp)"
                        onClicked: cw.monthOffsetRequested(cw.monthOffset - 1)
                    }
                    Item {
                        anchors.centerIn: parent
                        width: monthTitle.implicitWidth + 16
                        height: parent.height

                        Lbl {
                            id: monthTitle
                            anchors.centerIn: parent
                            sz: 13
                            font.bold: true
                            font.family: Theme.iconFont
                            color: titleMa.containsMouse ? cw.accent : Theme.text
                            text: Qt.formatDate(calView.view, "MMMM yyyy")
                        }
                        MouseArea {
                            id: titleMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cw.monthOffsetRequested(0)
                        }
                    }
                    NavBtn {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        base: 24
                        rest: 0
                        icon: cw.icRight
                        tip: "Next month (PgDn)"
                        onClicked: cw.monthOffsetRequested(cw.monthOffset + 1)
                    }
                }

                // weekday names
                Row {
                    Repeater {
                        model: 7
                        delegate: Lbl {
                            required property int index
                            width: calView.cellW
                            horizontalAlignment: Text.AlignHCenter
                            sz: 11
                            color: Theme.textDim
                            text: Qt.locale().dayName((index + calView.firstDay) % 7, Locale.ShortFormat)
                        }
                    }
                }

                // day grid
                Grid {
                    columns: 7
                    Repeater {
                        model: calView.cells
                        delegate: Item {
                            id: dayCell
                            required property var modelData
                            width: calView.cellW
                            height: calView.cellH

                            Rectangle {
                                visible: dayCell.modelData.today
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: Theme.radius
                                color: Theme.alpha(cw.accent, 0.2)
                                border.width: 1
                                border.color: cw.accent
                            }
                            Rectangle {
                                readonly property bool picked: cw.selTs === dayCell.modelData.ts
                                visible: opacity > 0
                                opacity: picked ? 1 : 0
                                scale: picked ? 1 : 0.7
                                Behavior on opacity { NumberAnimation { duration: cw.animMs * 0.7 } }
                                Behavior on scale { NumberAnimation { duration: cw.animMs; easing.type: Easing.OutBack } }
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: Theme.radius
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.alpha(Theme.text, 0.5)
                            }
                            Lbl {
                                anchors.centerIn: parent
                                sz: 12
                                font.bold: dayCell.modelData.today
                                color: dayCell.modelData.inMonth ? Theme.text : Theme.textFaint
                                text: dayCell.modelData.n
                            }
                            Rectangle {
                                visible: dayCell.modelData.hasRem
                                width: cw.px(4)
                                height: width
                                radius: width / 2
                                color: cw.accent
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: cw.px(3)
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const next = cw.selTs === dayCell.modelData.ts ? -1 : dayCell.modelData.ts
                                    cw.selTsRequested(next)
                                    if (next >= 0) Qt.callLater(function () { textIn.forceActiveFocus() })
                                }
                            }
                        }
                    }
                }

                // reminders for the selected day
                Column {
                    id: remBox
                    visible: cw.selTs >= 0 || height > 0
                    enabled: cw.selTs >= 0
                    clip: true
                    width: parent.width
                    spacing: cw.px(6)
                    height: cw.selTs >= 0 ? implicitHeight : 0
                    opacity: cw.selTs >= 0 ? 1 : 0
                    Behavior on height { enabled: cw.active; NumberAnimation { duration: cw.animMs; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: cw.animMs; easing.type: Easing.InOutQuad } }

                    function submit() {
                        const ok = cw.tryAddReminder ? cw.tryAddReminder(cw.selTs, timeIn.text, textIn.text) : false
                        if (ok) textIn.text = ""
                        else timeBox.bad = true
                    }

                    Lbl {
                        width: parent.width
                        sz: 11
                        font.bold: true
                        text: cw.selTs >= 0 ? Qt.formatDate(new Date(cw.selTs), "dddd, d MMMM") : ""
                    }

                    Repeater {
                        model: cw.selTs >= 0 ? cw.remindersOn(cw.selTs) : []
                        delegate: Lbl {
                            required property var modelData
                            width: remBox.width
                            sz: 10
                            color: modelData.notified ? Theme.textDim : cw.accent
                            text: Qt.formatTime(new Date(modelData.ts), "HH:mm") + "   " + modelData.text.split("\n")[0]
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: cw.px(6)

                        Rectangle {
                            id: timeBox
                            property bool bad: false
                            width: cw.px(70)
                            height: cw.px(28)
                            radius: cw.px(8)
                            color: Theme.alpha(Theme.text, 0.08)
                            border.width: (timeIn.activeFocus || bad) ? 1 : 0
                            border.color: bad ? Theme.danger : cw.accent

                            TextInput {
                                id: timeIn
                                anchors.fill: parent
                                anchors.leftMargin: cw.px(8)
                                anchors.rightMargin: cw.px(8)
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: cw.fs(11)
                                color: Theme.text
                                selectionColor: cw.accent
                                selectedTextColor: Theme.bg
                                clip: true
                                text: "09:00"
                                onTextChanged: timeBox.bad = false
                                Keys.onReturnPressed: textIn.forceActiveFocus()
                                Keys.onEnterPressed: textIn.forceActiveFocus()
                            }
                        }

                        Rectangle {
                            width: parent.width - timeBox.width - parent.spacing
                            height: cw.px(28)
                            radius: cw.px(8)
                            color: Theme.alpha(Theme.text, 0.08)
                            border.width: textIn.activeFocus ? 1 : 0
                            border.color: cw.accent

                            TextInput {
                                id: textIn
                                anchors.fill: parent
                                anchors.leftMargin: cw.px(8)
                                anchors.rightMargin: cw.px(8)
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: cw.fs(11)
                                color: Theme.text
                                selectionColor: cw.accent
                                selectedTextColor: Theme.bg
                                clip: true
                                Keys.onReturnPressed: remBox.submit()
                                Keys.onEnterPressed: remBox.submit()

                                Text {
                                    visible: textIn.text === "" && !textIn.inputMethodComposing
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Remind me to… (Enter)"
                                    font.pixelSize: cw.fs(11)
                                    color: Theme.textDim
                                    opacity: 0.7
                                }
                            }
                        }
                    }
                }
            }

            // ═════════════ weather view ═════════════
            Item {
                id: wxView
                anchors.fill: parent
                opacity: cw.showWx ? 1 : 0
                visible: opacity > 0.01
                enabled: cw.showWx
                Behavior on opacity { NumberAnimation { duration: cw.animMs; easing.type: Easing.InOutQuad } }
                transform: Translate {
                    x: cw.showWx ? 0 : cw.width
                    Behavior on x { NumberAnimation { duration: cw.animMs; easing.type: Easing.OutCubic } }
                }

                Lbl {
                    anchors.centerIn: parent
                    visible: !cw.wxOk
                    sz: 11
                    color: Theme.textDim
                    text: cw.wxState === "error" ? "Weather unavailable" : "Loading weather…"
                }

                Column {
                    id: wxCol
                    visible: cw.wxOk
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: cw.px(16)

                    // ---- current conditions + stats ----
                    Item {
                        id: topRow
                        width: parent.width
                        height: Math.max(leftCol.implicitHeight, statGrid.implicitHeight)

                        Column {
                            id: leftCol
                            x: cw.px(12)                      // space between the border and the icon
                            width: parent.width * 0.44
                            spacing: cw.px(4)

                            Row {
                                spacing: cw.px(14)            // space between the icon and the temperature
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: cw.glyphFor(cw.code, cw.isDay)
                                    font.family: Theme.iconFont
                                    font.pixelSize: cw.px(34)
                                    color: Theme.text
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Lbl { sz: 30; font.bold: true; text: cw.fmtT(cw.tempC) }
                                    Lbl { sz: 10; color: Theme.textDim; text: cw.condText }
                                }
                            }
                            Lbl {
                                width: parent.width
                                sz: 11
                                color: Theme.textDim
                                text: cw.loc !== "" ? cw.loc : cw.city
                            }
                        }

                        Grid {
                            id: statGrid
                            anchors.right: parent.right
                            anchors.rightMargin: cw.px(12)
                            columns: 2
                            columnSpacing: cw.px(14)
                            rowSpacing: cw.px(8)

                            Stat { glyph: "\uDB81\uDD9D"; value: cw.windText; label: "WIND" }
                            Stat { glyph: "\uDB81\uDD8E"; value: cw.humidity + "%"; label: "HUMIDITY" }
                            Stat { glyph: "\uDB81\uDD97"; value: cw.rainPct + "%"; label: "RAIN" }
                            Stat { glyph: "\uDB81\uDD0F"; value: cw.fmtT(cw.feelsC); label: "FEELS" }
                        }
                    }

                    // ---- next 8 hours ----
                    Item {
                        id: chart
                        width: parent.width
                        height: cw.px(128)

                        readonly property real labelH: cw.px(26)
                        readonly property real topPad: cw.px(16)
                        readonly property real plotH: Math.max(cw.px(10), height - topPad - labelH - cw.px(8))
                        readonly property int n: cw.hourly.length
                        readonly property real colW: n > 0 ? width / n : width

                        // point positions; the curve is centred vertically when the range is small
                        readonly property var pts: {
                            const a = cw.hourly
                            if (a.length === 0) return []
                            let lo = a[0].t, hi = a[0].t
                            for (let i = 1; i < a.length; i++) {
                                lo = Math.min(lo, a[i].t)
                                hi = Math.max(hi, a[i].t)
                            }
                            const span = hi - lo
                            const den = Math.max(span, 4)
                            const offset = (plotH - span / den * plotH) / 2
                            return a.map((e, i) => ({
                                x: (i + 0.5) * colW,
                                y: topPad + offset + (hi - e.t) / den * plotH
                            }))
                        }

                        // smooth line: horizontal tangents at every point
                        readonly property string pathStr: {
                            const p = pts
                            if (p.length < 2) return ""
                            let s = "M " + p[0].x + " " + p[0].y
                            for (let i = 1; i < p.length; i++) {
                                const mx = (p[i - 1].x + p[i].x) / 2
                                s += " C " + mx + " " + p[i - 1].y + " " + mx + " " + p[i].y
                                     + " " + p[i].x + " " + p[i].y
                            }
                            return s
                        }

                        Shape {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.samples: 4
                            ShapePath {
                                strokeColor: cw.accent
                                strokeWidth: Math.max(1.5, cw.px(2))
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                PathSvg { path: chart.pathStr }
                            }
                        }

                        // marker on the current hour
                        Rectangle {
                            visible: chart.pts.length > 0
                            width: cw.px(6)
                            height: width
                            radius: width / 2
                            color: cw.accent
                            x: chart.pts.length > 0 ? chart.pts[0].x - width / 2 : 0
                            y: chart.pts.length > 0 ? chart.pts[0].y - height / 2 : 0
                        }

                        Repeater {
                            model: cw.hourly
                            delegate: Item {
                                id: hc
                                required property var modelData
                                required property int index
                                readonly property var pt: chart.pts[index] ?? ({ x: 0, y: 0 })
                                x: index * chart.colW
                                width: chart.colW
                                height: chart.height

                                Lbl {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    y: hc.pt.y - height - cw.px(4)
                                    sz: 9
                                    font.bold: hc.index === 0
                                    color: hc.index === 0 ? Theme.text : Theme.textDim
                                    text: cw.fmtT(hc.modelData.t)
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: chart.height - chart.labelH + cw.px(1)
                                    text: cw.glyphFor(hc.modelData.code, hc.modelData.day)
                                    font.family: Theme.iconFont
                                    font.pixelSize: cw.px(12)
                                    color: Theme.textDim
                                }
                                Lbl {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    y: chart.height - height
                                    sz: 8
                                    color: Theme.textDim
                                    text: cw.hourLabel(hc.modelData.h)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

