import QtQuick 2.15
import org.kde.ksysguard.sensors 1.0 as Sensors
import org.kde.plasma.core 2.0 as PlasmaCore

// Desktop HUD in the style of a game loading screen: title, a big clock, live system readouts
// in place of a menu, and status lines in the corners.
Item {
    id: hud

    property string title: "SUBMERGE"
    property string player: "GUEST"
    property real t: 0
    property real mouseX: -9999
    property real mouseY: -9999
    property real textScale: 1
    property bool running: true
    property bool lowPower: false   // sensors and clock update once a minute (set while paused)

    readonly property real u: height / 1080 * textScale
    readonly property color ink: "#eef4ff"
    readonly property color line: "#a9c2ff"
    readonly property color hot: "#ff9a4d"
    readonly property string mono: "IBM Plex Mono"
    readonly property string cond: "IBM Plex Sans Condensed"
    property date now: new Date()

    // every second normally; on battery only on the minute, so a still desktop stays still
    Timer {
        id: clock
        interval: 1000; running: hud.visible; repeat: true; triggeredOnStart: true
        onTriggered: {
            hud.now = new Date();
            interval = hud.lowPower ? (60 - hud.now.getSeconds()) * 1000 + 50 : 1000;
        }
    }
    onLowPowerChanged: clock.restart()

    // ---- live system sensors ----
    Sensors.Sensor { id: cpu; sensorId: "cpu/all/usage"; updateRateLimit: hud.lowPower ? 60000 : 1500 }
    Sensors.Sensor { id: gpu; sensorId: "gpu/all/usage"; updateRateLimit: hud.lowPower ? 60000 : 1500 }
    Sensors.Sensor { id: mem; sensorId: "memory/physical/usedPercent"; updateRateLimit: hud.lowPower ? 60000 : 2000 }
    Sensors.Sensor { id: down; sensorId: "network/all/download"; updateRateLimit: hud.lowPower ? 60000 : 1500 }
    Sensors.Sensor { id: disk; sensorId: "disk/all/usedPercent"; updateRateLimit: hud.lowPower ? 60000 : 10000 }
    Sensors.Sensor { id: temp; sensorId: "cpu/all/averageTemperature"; updateRateLimit: hud.lowPower ? 60000 : 3000 }
    Sensors.Sensor { id: uptime; sensorId: "os/system/uptime"; updateRateLimit: hud.lowPower ? 60000 : 30000 }
    Sensors.Sensor { id: host; sensorId: "os/system/hostname" }
    Sensors.Sensor { id: plasma; sensorId: "os/plasma/plasmaVersion" }
    Sensors.Sensor { id: kernel; sensorId: "os/kernel/prettyName" }

    // battery: pushed by the power management engine when it changes, no polling
    PlasmaCore.DataSource {
        id: power
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter"]
    }
    readonly property var battery: power.data["Battery"] || ({})
    readonly property bool hasBattery: !!battery["Has Battery"]
    readonly property real batteryPct: battery["Percent"] || 0
    readonly property string batteryState: {
        const st = battery["State"], ac = (power.data["AC Adapter"] || {})["Plugged in"];
        return st === "Charging" ? "CHARGING" : st === "FullyCharged" ? "FULLY CHARGED"
             : ac ? "ON AC POWER" : "ON BATTERY";
    }
    readonly property color good: "#5fe08f"
    readonly property color low: "#ff4d5e"
    // green when there's plenty left, orange getting low, red nearly empty
    readonly property color batteryColor: batteryPct > 50 ? good : batteryPct > 20 ? hot : low

    // which app is using the most CPU and memory (processes with the same name added together)
    property string topCpu: ""
    property string topMem: ""
    readonly property string cpuCmd: "top -b -n2 -d0.5 -w 200 | awk '/^top -/{n++} n==2 && $1 ~ /^[0-9]+$/ {a[$12]+=$9} END{for(k in a) printf \"%.1f %s\\n\", a[k], k}' | sort -rn | head -1"
    readonly property string memCmd: "ps -eo comm,rss --no-headers | awk '{a[$1]+=$2} END{for(k in a) print a[k], k}' | sort -rn | head -1"
    PlasmaCore.DataSource {
        engine: "executable"
        connectedSources: hud.visible && hud.running ? [hud.cpuCmd, hud.memCmd] : []
        interval: 4000
        onNewData: {
            const source = sourceName;
            const name = (data.stdout || "").trim().split(/\s+/).slice(1).join(" ").toUpperCase().slice(0, 16);
            if (source === hud.cpuCmd) hud.topCpu = name;
            else hud.topMem = name;
        }
    }

    function pct(v) { return isNaN(v) || v === undefined ? 0 : Math.max(0, Math.min(100, v)); }
    function rate(bytes) {
        if (!bytes || isNaN(bytes)) return "0 KB/s";
        return bytes > 1048576 ? (bytes / 1048576).toFixed(1) + " MB/s" : Math.round(bytes / 1024) + " KB/s";
    }
    function span(seconds) {
        const s = Math.floor(seconds || 0);
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d ? d + "D " : "") + String(h).padStart(2, "0") + "H " + String(m).padStart(2, "0") + "M";
    }
    function readout(en) {
        switch (en) {
        case "CPU":     return { sub: hud.topCpu ? "TOP: " + hud.topCpu : "TOTAL LOAD", v: Math.round(pct(cpu.value)) + "%", f: pct(cpu.value) / 100 };
        case "GPU":     return { sub: "RENDER LOAD", v: Math.round(pct(gpu.value)) + "%", f: pct(gpu.value) / 100 };
        case "MEMORY":  return { sub: hud.topMem ? "TOP: " + hud.topMem : "PHYSICAL RAM", v: Math.round(pct(mem.value)) + "%", f: pct(mem.value) / 100 };
        case "NETWORK": return { sub: "DOWNLINK", v: "↓ " + rate(down.value), f: Math.min(1, (down.value || 0) / 5242880) };
        case "BATTERY": return { sub: hud.batteryState, v: Math.round(hud.batteryPct) + "%", f: hud.batteryPct / 100 };
        default:        return { sub: "DISK USED", v: Math.round(pct(disk.value)) + "%", f: pct(disk.value) / 100 };
        }
    }
    // called by the pond's frame ticker
    function step(dt) {
        for (let i = 0; i < rows.count; i++) { const r = rows.itemAt(i); if (r) r.step(dt); }
    }
    readonly property bool busy: pct(cpu.value) > 85 || pct(mem.value) > 90

    component Mono: Text {
        color: hud.ink
        font.family: hud.mono
        font.pixelSize: 12 * hud.u
        font.letterSpacing: 2.2 * hud.u
        renderType: Text.QtRendering
    }

    component Bracket: Item {
        property bool flipX: false
        property bool flipY: false
        width: 26 * hud.u; height: 26 * hud.u
        transform: Scale { origin.x: 13 * hud.u; origin.y: 13 * hud.u; xScale: flipX ? -1 : 1; yScale: flipY ? -1 : 1 }
        Rectangle { width: parent.width; height: Math.max(1, hud.u); color: hud.line; opacity: 0.8 }
        Rectangle { width: Math.max(1, hud.u); height: parent.height; color: hud.line; opacity: 0.8 }
    }

    // a dark halo behind the thin text so it reads on bright water, then a blue bloom on top
    layer.enabled: true
    layer.effect: ShadowFx {
        shadowColor: "#3f73ff"
        shadowBlur: 0.85
        shadowOpacity: 1.0
        brightness: 0.08
    }

    Bracket { x: 28 * hud.u; y: 28 * hud.u }
    Bracket { x: hud.width - width - 28 * hud.u; y: 28 * hud.u; flipX: true }
    Bracket { x: 28 * hud.u; y: hud.height - height - 28 * hud.u; flipY: true }
    Bracket { x: hud.width - width - 28 * hud.u; y: hud.height - height - 28 * hud.u; flipX: true; flipY: true }

    // soft dark backing for the left column, like the gradient behind a game menu
    Rectangle {
        x: 0; y: 0
        width: 560 * hud.u; height: hud.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(0.0, 0.02, 0.08, 0.55) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Column {
        x: 72 * hud.u
        y: 64 * hud.u
        spacing: 0

        Mono {
            text: "// " + (host.value || "localhost").toString().toUpperCase() + "   ·   PLASMA " + (plasma.value || "")
            font.pixelSize: 11 * hud.u
            opacity: 0.95
        }
        Item { width: 1; height: 18 * hud.u }

        // tall, thin, widely spaced title
        Item {
            width: titleText.width
            height: titleText.height * 1.45
            Text {
                id: titleText
                text: hud.title
                color: hud.ink
                font.family: hud.cond
                font.weight: Font.Light
                font.pixelSize: 66 * hud.u
                font.letterSpacing: 9 * hud.u
                transform: Scale { yScale: 1.45 }
            }
        }
        Item { width: 1; height: 14 * hud.u }

        // big clock
        Row {
            spacing: 14 * hud.u
            Text {
                text: Qt.formatDateTime(hud.now, "HH:mm")
                color: hud.ink
                font.family: hud.cond
                font.weight: Font.ExtraLight
                font.pixelSize: 44 * hud.u
                font.letterSpacing: 4 * hud.u
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3 * hud.u
                Mono { text: Qt.formatDateTime(hud.now, "ddd dd MMM yyyy").toUpperCase(); font.pixelSize: 11 * hud.u }
                Mono { text: (hud.lowPower ? "" : ":" + Qt.formatDateTime(hud.now, "ss") + "   ") + "UP " + hud.span(uptime.value); font.pixelSize: 10 * hud.u; opacity: 0.9 }
            }
        }
        Item { width: 1; height: 40 * hud.u }

        // live readouts, laid out like the menu in the video
        Repeater {
            id: rows
            // Qt 5 drops functions from array models, so each row looks its values up by name
            model: [
                { n: "01", en: "CPU" },
                { n: "02", en: "GPU" },
                { n: "03", en: "MEMORY" },
                { n: "04", en: "NETWORK" },
                { n: "05", en: "STORAGE" }
            ].concat(hud.hasBattery ? [{ n: "06", en: "BATTERY" }] : [])
            Item {
                id: row
                required property var modelData
                required property int index
                width: 360 * hud.u
                height: 58 * hud.u
                readonly property real level: { cpu.value; gpu.value; mem.value; down.value; disk.value; hud.batteryPct; return hud.readout(modelData.en).f; }
                readonly property bool isBattery: modelData.en === "BATTERY"
                readonly property bool high: !isBattery && level > 0.85
                // colour of the value and level bar: battery goes green / orange / red
                readonly property color accent: isBattery ? hud.batteryColor : high ? hud.hot : hud.line
                // the highlight drifts down the list slowly, like an idle menu cursor
                readonly property bool lit: Math.floor(hud.t / 6) % rows.count === index
                // eased by step() on the pond's frames; set straight away while paused
                property real shownLevel: level
                property real shownLit: lit ? 0.4 : 0
                function step(dt) {
                    shownLevel += (level - shownLevel) * (1 - Math.exp(-dt / 0.25));
                    shownLit += ((lit ? 0.4 : 0) - shownLit) * (1 - Math.exp(-dt / 0.2));
                }
                onLevelChanged: if (!hud.running) shownLevel = level
                onLitChanged: if (!hud.running) shownLit = lit ? 0.4 : 0

                Rectangle {
                    anchors.fill: parent
                    anchors.bottomMargin: 6 * hud.u
                    opacity: row.shownLit
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: row.high ? hud.hot : "#3d6dff" }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
                Rectangle {
                    width: 24 * hud.u; height: 20 * hud.u
                    x: 4 * hud.u
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -3 * hud.u
                    color: "transparent"
                    border.color: hud.line; border.width: Math.max(1, hud.u)
                    Mono { anchors.centerIn: parent; text: row.modelData.n; font.pixelSize: 8 * hud.u; font.letterSpacing: 0.5 * hud.u }
                }
                Column {
                    x: 44 * hud.u
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -3 * hud.u
                    spacing: 3 * hud.u
                    Mono { text: row.modelData.en; font.pixelSize: 15 * hud.u; font.letterSpacing: 3.5 * hud.u }
                    Mono { text: { hud.topCpu; hud.topMem; hud.batteryState; return hud.readout(row.modelData.en).sub; } font.pixelSize: 10 * hud.u; font.letterSpacing: 1.6 * hud.u; opacity: 0.9 }
                }
                Mono {
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * hud.u
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -3 * hud.u
                    text: { cpu.value; gpu.value; mem.value; down.value; disk.value; hud.batteryPct; return hud.readout(row.modelData.en).v; }
                    color: row.isBattery ? hud.batteryColor : row.high ? hud.hot : hud.ink
                    font.pixelSize: 14 * hud.u
                }
                // baseline doubles as a level meter
                Rectangle {
                    width: parent.width; height: Math.max(1, hud.u)
                    anchors.bottom: parent.bottom
                    color: hud.line; opacity: 0.3
                }
                Rectangle {
                    width: parent.width * row.shownLevel; height: Math.max(2, 2 * hud.u)
                    anchors.bottom: parent.bottom
                    color: row.accent
                }
            }
        }
    }

    // bottom left: overall status, barcode and a core temperature gauge
    Column {
        x: 72 * hud.u
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 64 * hud.u
        spacing: 4 * hud.u
        Mono { text: "// SYSTEM STATUS"; font.pixelSize: 10 * hud.u; opacity: 0.95 }
        Mono {
            text: hud.busy ? "HIGH LOAD" : "ALL SYSTEMS NOMINAL"
            color: hud.busy ? hud.hot : hud.ink
            font.pixelSize: 10 * hud.u
        }
        Item { width: 1; height: 6 * hud.u }
        Row {
            spacing: 14 * hud.u
            Row {
                spacing: 0
                Repeater {
                    model: [2,1,1,3,1,2,1,1,2,3,1,1,2,1,3,1,2,1,1,1,2,3,1,2,1,1,3,1,2,1,1,2,1,3,1,1,2,1,2,1]
                    Rectangle {
                        required property int modelData
                        required property int index
                        width: modelData * hud.u * 1.6
                        height: 18 * hud.u
                        color: index % 2 === 0 ? hud.ink : "transparent"
                        opacity: 0.95
                    }
                }
            }
            Column {
                spacing: 4 * hud.u
                Mono { text: "CORE " + (temp.value ? Math.round(temp.value) + "°C" : "--"); font.pixelSize: 10 * hud.u; opacity: 0.95 }
                Item {
                    width: 160 * hud.u; height: 6 * hud.u
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"; border.color: hud.line; border.width: Math.max(1, hud.u); opacity: 0.9
                    }
                    Rectangle {
                        x: 2 * hud.u; y: 2 * hud.u
                        height: Math.max(1, parent.height - 4 * hud.u)
                        width: (parent.width - 4 * hud.u) * Math.max(0.03, Math.min(1, ((temp.value || 30) - 30) / 70))
                        color: (temp.value || 0) > 85 ? hud.hot : hud.ink
                    }
                }
            }
        }
    }

    // bottom right: who's logged in and what's running
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 72 * hud.u
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 64 * hud.u
        spacing: 4 * hud.u
        Mono { anchors.right: parent.right; text: (kernel.value || "").toString().toUpperCase(); font.pixelSize: 10 * hud.u; opacity: 0.9 }
        Mono { anchors.right: parent.right; text: "USER: " + hud.player.toUpperCase() }
        Row {
            anchors.right: parent.right
            spacing: 8 * hud.u
            Mono { text: "SESSION: 01" }
            Rectangle {
                width: 7 * hud.u; height: width
                anchors.verticalCenter: parent.verticalCenter
                color: hud.ink
                opacity: Math.sin(hud.t * 3) > 0 ? 0.95 : 0.2
            }
        }
    }
}
