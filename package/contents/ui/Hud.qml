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
    // the lock screen draws its own unlock prompt in the middle, so the HUD moves to a centred
    // layout above and below it instead of the left column
    property bool lockScreen: false
    readonly property int slow: lowPower ? 60000 : 1

    readonly property real u: height / 1080 * textScale
    readonly property color ink: "#eef4ff"
    readonly property color line: "#a9c2ff"
    readonly property color hot: "#ff9a4d"
    readonly property string mono: "IBM Plex Mono"
    readonly property string cond: "IBM Plex Sans Condensed"
    property date now: new Date()
    // things that only change every few seconds, worked out once here instead of in every row
    readonly property int litIndex: rows.count ? Math.floor(t / 6) % rows.count : -1
    readonly property bool blink: Math.sin(t * 3) > 0

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
    // No GPU load sensor: on this kind of laptop it runs `nvidia-smi dmon`, which keeps the dGPU
    // awake (~3 W) just to report on it. The dGPU's power state is read from sysfs instead.
    // The lock screen layout only shows CPU, memory, network and power, so it skips the rest.
    Sensors.Sensor { id: cpu; sensorId: "cpu/all/usage"; updateRateLimit: Math.max(1500, hud.slow) }
    Sensors.Sensor { id: mem; sensorId: "memory/physical/usedPercent"; updateRateLimit: Math.max(2000, hud.slow) }
    Sensors.Sensor { id: down; sensorId: "network/all/download"; updateRateLimit: Math.max(1500, hud.slow) }
    Sensors.Sensor { id: temp; enabled: !hud.lockScreen; sensorId: "cpu/all/averageTemperature"; updateRateLimit: Math.max(3000, hud.slow) }
    Sensors.Sensor { id: uptime; enabled: !hud.lockScreen; sensorId: "os/system/uptime"; updateRateLimit: Math.max(30000, hud.slow) }
    Sensors.Sensor { id: host; sensorId: "os/system/hostname" }
    Sensors.Sensor { id: plasma; enabled: !hud.lockScreen; sensorId: "os/plasma/plasmaVersion" }
    Sensors.Sensor { id: kernel; enabled: !hud.lockScreen; sensorId: "os/kernel/prettyName" }

    // battery: pushed by the power management engine when it changes, no polling
    PlasmaCore.DataSource {
        id: power
        engine: "powermanagement"
        connectedSources: ["Battery"]
        // a binding on power.data["Battery"] that first ran before the key existed never
        // re-runs, so copy the values over as they arrive
        onNewData: hud.battery = data
    }
    property var battery: ({})
    readonly property bool hasBattery: !!battery["Has Battery"]
    readonly property real batteryPct: battery["Percent"] || 0
    // Plasma 5.27's "AC Adapter" source can say plugged in while the battery drains, so the
    // battery's own state decides
    readonly property bool discharging: battery["State"] === "Discharging"
    readonly property bool charging: battery["State"] === "Charging"
    readonly property string batteryState: charging ? (batteryLeft ? "CHARGING  ·  FULL " + batteryLeft : "CHARGING")
                                         : battery["State"] === "FullyCharged" ? "FULLY CHARGED"
                                         : discharging ? (batteryLeft ? batteryLeft + " LEFT" : "ON BATTERY") : "ON AC POWER"
    // time to empty (or to full while charging) from the battery's energy and a smoothed power
    // reading; the engine doesn't provide one here. Whole minutes, so it rarely redraws.
    readonly property string batteryLeft: {
        const w = smoothWatts, e = energyWh, f = energyFullWh;
        if (w < 0.5 || e <= 0 || !(discharging || charging)) return "";
        const m = Math.round((discharging ? e : Math.max(0, f - e)) / w * 60), h = Math.floor(m / 60);
        return h > 0 ? h + "H " + String(m % 60).padStart(2, "0") + "M" : m + "M";
    }
    readonly property color good: "#5fe08f"
    readonly property color low: "#ff4d5e"
    // green when there's plenty left, orange getting low, red nearly empty
    readonly property color batteryColor: batteryPct > 50 ? good : batteryPct > 20 ? hot : low

    // ---- power draw and the GPUs ----
    // All from sysfs, which never wakes the dGPU. The paths are looked up once; after that each
    // poll is a single shell reading a few files with builtins (no cat).
    property string gpuStatusFile: ""   // power/runtime_status of the discrete GPU, if any
    property string dgpuVendor: ""
    // the integrated GPU's load: Intel counts the ms it spends idle (RC6), AMD reports a percentage
    property string igpuFile: ""
    property bool igpuIsRc6: false
    property string igpuVendor: ""
    property bool hasNvidiaSmi: false
    property string batteryDir: ""
    property bool probed: false
    readonly property string probeCmd: "for d in /sys/bus/pci/devices/*; do read c < $d/class; case $c in 0x03*) read v < $d/vendor; b=1; { read b < $d/boot_vga; } 2>/dev/null; "
        + "if [ \"$b\" = 0 ]; then echo gpu $d/power/runtime_status $v; else for f in $d/drm/card*/gt/gt0/rc6_residency_ms; do [ -r \"$f\" ] && echo igpu rc6 $f $v; done; [ -r $d/gpu_busy_percent ] && echo igpu busy $d/gpu_busy_percent $v; fi;; esac; done; "
        + "for b in /sys/class/power_supply/*; do read t < $b/type; [ \"$t\" = Battery ] && echo bat $b && break; done; command -v nvidia-smi >/dev/null && echo nvsmi; true"
    // prints "<dGPU runtime status or -> <power uW> <energy uWh> <full uWh> <iGPU counter or ->";
    // some batteries only report current and charge, so it falls back to multiplying those by
    // the voltage
    readonly property string powerCmd: !probed || (!gpuStatusFile && !batteryDir && !igpuFile) ? ""
        : "g=-; p=0; e=0; f=0; i=-; " + (gpuStatusFile ? "read g < " + gpuStatusFile + "; " : "")
          + (igpuFile ? "read i < " + igpuFile + "; " : "")
          + (batteryDir ? "B=" + batteryDir + "; { read p < $B/power_now; } 2>/dev/null || { read c < $B/current_now && read v < $B/voltage_now && p=$((c * v / 1000000)); } 2>/dev/null; "
                        + "{ read e < $B/energy_now && read f < $B/energy_full; } 2>/dev/null || { read v < $B/voltage_now && read c < $B/charge_now && read cf < $B/charge_full && e=$((c * v / 1000000)) && f=$((cf * v / 1000000)); } 2>/dev/null; " : "")
          + "echo $g $p $e $f $i"
    property bool dgpuAwake: false
    property real igpuPct: 0
    property real dgpuPct: 0
    property real lastRc6: -1
    property double lastRc6At: 0
    function vendorName(v) { return v === "0x8086" ? "INTEL" : v === "0x10de" ? "NVIDIA" : v === "0x1002" ? "AMD" : ""; }
    readonly property bool hasGpu: igpuFile !== "" || (gpuStatusFile !== "" && hasNvidiaSmi)
    // the busier of the two; the dGPU only counts while it's awake
    readonly property bool dgpuBusier: dgpuAwake && dgpuPct > igpuPct
    property real watts: 0
    property real smoothWatts: 0
    property real energyWh: 0
    property real energyFullWh: 0
    // charging rate on AC, system draw on battery; the battery can't see the draw when it's full
    // draw on battery, charge rate while charging; nothing to show on AC once it's full
    readonly property string powerText: watts > 0.05 ? watts.toFixed(1) + " W" : ""
    PlasmaCore.DataSource {
        engine: "executable"
        connectedSources: hud.probed ? [] : [hud.probeCmd]
        onNewData: {
            for (const l of (data.stdout || "").split("\n")) {
                const w = l.split(" ");
                if (w[0] === "gpu" && !hud.gpuStatusFile) { hud.gpuStatusFile = w[1]; hud.dgpuVendor = w[2]; }
                else if (w[0] === "igpu" && !hud.igpuFile) { hud.igpuIsRc6 = w[1] === "rc6"; hud.igpuFile = w[2]; hud.igpuVendor = w[3]; }
                else if (w[0] === "bat") hud.batteryDir = w[1];
                else if (w[0] === "nvsmi") hud.hasNvidiaSmi = true;
            }
            hud.probed = true;
        }
    }
    PlasmaCore.DataSource {
        engine: "executable"
        connectedSources: hud.visible && hud.powerCmd ? [hud.powerCmd] : []
        // while paused the HUD only needs to be roughly current
        interval: hud.lowPower ? 15000 : 2000
        onNewData: {
            const w = (data.stdout || "").trim().split(" ");
            hud.dgpuAwake = w[0] === "active";
            if (!hud.dgpuAwake) hud.dgpuPct = 0;
            if (w[4] !== undefined && w[4] !== "-") {
                if (!hud.igpuIsRc6) hud.igpuPct = hud.pct(Number(w[4]));
                else {
                    // busy = the part of the time since the last poll it wasn't idle
                    const rc6 = Number(w[4]), now = Date.now();
                    if (hud.lastRc6 >= 0 && now > hud.lastRc6At)
                        hud.igpuPct = Math.round(hud.pct(100 * (1 - (rc6 - hud.lastRc6) / (now - hud.lastRc6At))));
                    hud.lastRc6 = rc6;
                    hud.lastRc6At = now;
                }
            }
            const uw = Math.abs(Number(w[1]) || 0);
            // rounded so a jitter in the last digit doesn't redraw the HUD
            hud.watts = Math.round(uw / 100000) / 10;
            // the time-left estimate follows a ~10 s average, so it doesn't jump with every spike
            hud.smoothWatts = hud.smoothWatts > 0 && uw > 0 ? hud.smoothWatts * 0.8 + uw / 1e6 * 0.2 : uw / 1e6;
            hud.energyWh = (Number(w[2]) || 0) / 1e6;
            hud.energyFullWh = (Number(w[3]) || 0) / 1e6;
        }
    }

    // The dGPU's load needs nvidia-smi, and one query keeps the card awake for ~20 s. So only ask
    // while it's already awake, re-check that right before asking, and wait 30 s between asks, so
    // an otherwise idle card can always power down before the next one.
    PlasmaCore.DataSource {
        engine: "executable"
        connectedSources: hud.visible && !hud.lockScreen && !hud.lowPower && hud.dgpuAwake && hud.hasNvidiaSmi
                          && hud.dgpuVendor === "0x10de" ? [hud.nvidiaCmd] : []
        interval: 30000
        onNewData: hud.dgpuPct = hud.dgpuAwake ? hud.pct(Number((data.stdout || "").trim())) : 0
    }
    readonly property string nvidiaCmd: "read s < " + gpuStatusFile + "; [ \"$s\" = active ] && nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1 || echo 0"

    // which app is using the most CPU and memory (processes with the same name added together)
    property string topCpu: ""
    property string topMem: ""
    readonly property string cpuCmd: "top -b -n2 -d0.5 -w 200 | awk '/^top -/{n++} n==2 && $1 ~ /^[0-9]+$/ {a[$12]+=$9} END{for(k in a) printf \"%.1f %s\\n\", a[k], k}' | sort -rn | head -1"
    readonly property string memCmd: "ps -eo comm,rss --no-headers | awk '{a[$1]+=$2} END{for(k in a) print a[k], k}' | sort -rn | head -1"
    PlasmaCore.DataSource {
        engine: "executable"
        // the lock screen layout doesn't show the top apps, so don't look them up there
        connectedSources: hud.visible && hud.running && !hud.lockScreen ? [hud.cpuCmd, hud.memCmd] : []
        // top and ps walk every process, so don't run them often
        interval: 10000
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
    // a binding only re-runs for the properties it actually read, so each row only wakes up for
    // its own sensor
    function readout(en) {
        switch (en) {
        case "CPU":     return { sub: hud.topCpu ? "TOP: " + hud.topCpu : "TOTAL LOAD", v: Math.round(pct(cpu.value)) + "%", f: pct(cpu.value) / 100 };
        case "GPU": {
            const g = hud.dgpuBusier ? hud.dgpuPct : hud.igpuPct;
            const name = hud.vendorName(hud.dgpuBusier ? hud.dgpuVendor : hud.igpuVendor);
            return { sub: (hud.dgpuBusier ? "DGPU" : "IGPU") + (name ? "  ·  " + name : "") + " LOAD", v: Math.round(g) + "%", f: g / 100 };
        }
        case "MEMORY":  return { sub: hud.topMem ? "TOP: " + hud.topMem : "PHYSICAL RAM", v: Math.round(pct(mem.value)) + "%", f: pct(mem.value) / 100 };
        case "NETWORK": return { sub: "DOWNLINK", v: "↓ " + rate(down.value), f: Math.min(1, (down.value || 0) / 5242880) };
        default:        return { sub: hud.batteryState + (hud.powerText ? "  ·  " + hud.powerText : ""), v: Math.round(hud.batteryPct) + "%", f: hud.batteryPct / 100 };
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
        visible: !hud.lockScreen
        x: 0; y: 0
        width: 560 * hud.u; height: hud.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(0.0, 0.02, 0.08, 0.55) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Column {
        visible: !hud.lockScreen
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
            // (no rows at all on the lock screen, which has its own layout)
            model: hud.lockScreen ? [] : ["CPU"].concat(hud.hasGpu ? ["GPU"] : [], ["MEMORY", "NETWORK"],
                                                       hud.hasBattery ? ["BATTERY"] : [])
            Item {
                id: row
                required property var modelData
                required property int index
                width: 360 * hud.u
                height: 58 * hud.u
                readonly property var r: hud.readout(modelData)
                readonly property real level: r.f
                readonly property bool isBattery: modelData === "BATTERY"
                readonly property bool high: !isBattery && level > 0.85
                // colour of the value and level bar: battery goes green / orange / red
                readonly property color accent: isBattery ? hud.batteryColor : high ? hud.hot : hud.line
                // the highlight drifts down the list slowly, like an idle menu cursor
                readonly property bool lit: hud.litIndex === index
                // eased by step() on the pond's frames; set straight away while paused
                property real shownLevel: level
                property real shownLit: lit ? 0.4 : 0
                // snap once close, or the easing never quite finishes and the HUD's glow layer
                // gets redrawn on every frame for nothing
                function step(dt) {
                    const lv = level - shownLevel, li = (lit ? 0.4 : 0) - shownLit;
                    if (lv !== 0) shownLevel = Math.abs(lv) < 0.002 ? level : shownLevel + lv * (1 - Math.exp(-dt / 0.25));
                    if (li !== 0) shownLit = Math.abs(li) < 0.004 ? (lit ? 0.4 : 0) : shownLit + li * (1 - Math.exp(-dt / 0.2));
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
                    Mono { anchors.centerIn: parent; text: String(row.index + 1).padStart(2, "0"); font.pixelSize: 8 * hud.u; font.letterSpacing: 0.5 * hud.u }
                }
                Column {
                    x: 44 * hud.u
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -3 * hud.u
                    spacing: 3 * hud.u
                    Row {
                        spacing: 10 * hud.u
                        Mono { text: row.modelData; font.pixelSize: 15 * hud.u; font.letterSpacing: 3.5 * hud.u }
                        // red tag while the dGPU is awake and adding to the power draw below
                        Mono {
                            visible: row.isBattery && hud.dgpuAwake
                            anchors.verticalCenter: parent.verticalCenter
                            text: "● DGPU ON"
                            color: hud.low
                            font.pixelSize: 10 * hud.u
                        }
                    }
                    Mono { text: row.r.sub; font.pixelSize: 10 * hud.u; font.letterSpacing: 1.6 * hud.u; opacity: 0.9 }
                }
                Mono {
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * hud.u
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -3 * hud.u
                    text: row.r.v
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
        visible: !hud.lockScreen
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
        visible: !hud.lockScreen
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
                opacity: hud.blink ? 0.95 : 0.2
            }
        }
    }

    // ---- lock screen: centred title and clock up top, a strip of readouts along the bottom ----
    function lockReadout(k) {
        switch (k) {
        case "CPU":   return { v: Math.round(pct(cpu.value)) + "%", f: pct(cpu.value) / 100 };
        case "MEM":   return { v: Math.round(pct(mem.value)) + "%", f: pct(mem.value) / 100 };
        case "NET":   return { v: "↓ " + rate(down.value), f: Math.min(1, (down.value || 0) / 5242880) };
        default:      return { v: Math.round(hud.batteryPct) + "%" + (hud.discharging && hud.batteryLeft ? "  ·  " + hud.batteryLeft : "")
                                  + (hud.powerText ? "  ·  " + hud.powerText : ""), f: hud.batteryPct / 100 };
        }
    }
    Loader {
        // only built on the lock screen
        active: hud.lockScreen
        anchors.fill: parent
        sourceComponent: Item {
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.08
                spacing: 0

                Mono {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "// " + (host.value || "localhost").toString().toUpperCase() + "   ·   SESSION LOCKED"
                    font.pixelSize: 11 * hud.u
                    font.letterSpacing: 4 * hud.u
                    leftPadding: font.letterSpacing
                    opacity: 0.9
                }
                Item { width: 1; height: 16 * hud.u }
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: lockTitle.width
                    height: lockTitle.height * 1.45
                    Text {
                        id: lockTitle
                        text: hud.title
                        color: hud.ink
                        font.family: hud.cond
                        font.weight: Font.Light
                        font.pixelSize: 40 * hud.u
                        font.letterSpacing: 22 * hud.u
                        leftPadding: font.letterSpacing
                        transform: Scale { yScale: 1.45 }
                    }
                }
                Item { width: 1; height: 4 * hud.u }
                // the clock sits between two thin rules, like a readout on a gauge
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 26 * hud.u
                    Rectangle { width: 110 * hud.u; height: Math.max(1, hud.u); color: hud.line; opacity: 0.6; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: Qt.formatDateTime(hud.now, "HH:mm")
                        color: hud.ink
                        font.family: hud.cond
                        font.weight: Font.ExtraLight
                        font.pixelSize: 128 * hud.u
                        font.letterSpacing: 8 * hud.u
                        leftPadding: font.letterSpacing
                    }
                    Rectangle { width: 110 * hud.u; height: Math.max(1, hud.u); color: hud.line; opacity: 0.6; anchors.verticalCenter: parent.verticalCenter }
                }
                Mono {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(hud.now, "dddd dd MMMM").toUpperCase() + (hud.lowPower ? "" : "   ·   :" + Qt.formatDateTime(hud.now, "ss"))
                    font.pixelSize: 12 * hud.u
                    font.letterSpacing: 6 * hud.u
                    leftPadding: font.letterSpacing
                    opacity: 0.95
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 150 * hud.u
                spacing: 40 * hud.u
                Repeater {
                    model: ["CPU", "MEM", "NET"].concat(hud.hasBattery ? ["BATTERY"] : [])
                    Column {
                        id: cell
                        required property var modelData
                        readonly property var r: hud.lockReadout(modelData)
                        readonly property color accent: modelData === "BATTERY" ? hud.batteryColor : hud.line
                        spacing: 5 * hud.u
                        width: Math.max(120 * hud.u, cellValue.implicitWidth)
                        Mono { text: "// " + cell.modelData; font.pixelSize: 9 * hud.u; opacity: 0.8 }
                        Row {
                            id: cellValue
                            spacing: 12 * hud.u
                            Mono {
                                text: cell.r.v
                                font.pixelSize: 14 * hud.u
                                color: cell.accent === hud.line ? hud.ink : cell.accent
                            }
                            // red tag while the dGPU is awake and costing power
                            Mono {
                                visible: cell.modelData === "BATTERY" && hud.dgpuAwake
                                anchors.verticalCenter: parent.verticalCenter
                                text: "● DGPU ON"
                                color: hud.low
                                font.pixelSize: 10 * hud.u
                            }
                        }
                        Item {
                            width: parent.width; height: Math.max(2, 2 * hud.u)
                            Rectangle { anchors.fill: parent; color: hud.line; opacity: 0.3 }
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, cell.r.f))
                                height: parent.height
                                color: cell.accent
                            }
                        }
                    }
                }
            }
        }
    }
}
