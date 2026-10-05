import QtQuick
import QtQuick.Effects

// Tank-monitoring overlay: one specimen box that locks onto a fish (the one nearest the cursor
// when the cursor is on the desktop, otherwise a random one every so often), a depth ruler
// and the tank readout. Sits above the fish and under the HUD text.
Item {
    id: cyber

    property Repeater fishItems
    property Repeater fgItems
    property real t: 0
    property var cond: null
    property real mouseX: -9999
    property real mouseY: -9999
    property real textScale: 1
    readonly property bool pointing: mouseX > -9000
    readonly property int slowT: Math.floor(t)

    readonly property real u: height / 1080 * textScale
    readonly property color ink: "#e6efff"
    readonly property color line: "#9fbaff"
    readonly property string mono: "IBM Plex Mono"

    component Glow: MultiEffect {
        shadowEnabled: true
        shadowColor: "#3f73ff"
        shadowBlur: 0.7
        shadowOpacity: 0.95
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

    component Mono: Text {
        color: cyber.ink
        font.family: cyber.mono
        font.pixelSize: 11 * cyber.u
        font.letterSpacing: 1.6 * cyber.u
        renderType: Text.QtRendering
    }

    // every fish that can be scanned: the small ones, plus the big blurry ones (flagged "blur")
    function candidates() {
        const out = [];
        const n = fishItems ? fishItems.count : 0;
        for (let i = 0; i < n; i++) {
            const f = fishItems.itemAt(i);
            if (f) out.push({ fish: f, id: i + 1, blur: false });
        }
        const m = fgItems ? fgItems.count : 0;
        for (let j = 0; j < m; j++) {
            const f = fgItems.itemAt(j)?.fish;
            if (f) out.push({ fish: f, id: 0, blur: true });
        }
        return out;
    }
    function centreOf(f) {
        return [f.fx - Math.cos(f.angle) * f.len * 0.4, f.fy - Math.sin(f.angle) * f.len * 0.4];
    }
    function onScreen(p, margin) {
        return p[0] > width * margin && p[0] < width * (1 - margin) && p[1] > height * margin && p[1] < height * (1 - margin);
    }

    // scrambled text for the blurry fish the scanner can't read properly
    readonly property string glyphs: "#%&?!@$/\\<>=+*▓▒░█"
    function scramble(text) {
        let out = "";
        for (let i = 0; i < text.length; i++)
            out += text[i] === " " || Math.random() < 0.45 ? text[i] : glyphs[Math.floor(Math.random() * glyphs.length)];
        return out;
    }

    // ---- the single specimen box ----
    Item {
        id: box
        property var target: null      // { fish, id, blur }
        property real fade: 0
        property real cx: 0
        property real cy: 0
        property real size: 100
        property real hold: 0
        property string hdgText: ""
        property string depthText: ""
        property int tick: -1

        function retarget(next) {
            if (target && next && target.fish === next.fish) return;
            target = next;
            if (next) { const p = cyber.centreOf(next.fish); if (fade === 0) { cx = p[0]; cy = p[1]; } }
        }

        function step(dt) {
            const list = cyber.candidates();
            if (cyber.pointing) {
                // follow whichever fish is closest to the cursor; never more than one box
                let best = null, bestD = Infinity;
                for (const c of list) {
                    const p = cyber.centreOf(c.fish);
                    const d = (p[0] - cyber.mouseX) ** 2 + (p[1] - cyber.mouseY) ** 2;
                    if (d < bestD) { bestD = d; best = c; }
                }
                retarget(best);
                hold = 4;
            } else {
                hold -= dt;
                const visible = target && cyber.onScreen(cyber.centreOf(target.fish), 0.05);
                if (hold <= 0 || !visible) {
                    fade = Math.max(0, fade - dt * 2.5);
                    if (fade > 0) return;
                    // the blurry fish come up now and then, the small ones most of the time
                    const pool = list.filter(c => {
                        const p = cyber.centreOf(c.fish);
                        return p[0] > cyber.width * 0.28 && p[0] < cyber.width * 0.78 && cyber.onScreen(p, 0.1)
                               && (!c.blur || Math.random() < 0.25) && !(c.fish.baby);
                    });
                    retarget(pool.length ? pool[Math.floor(Math.random() * pool.length)] : null);
                    hold = 9 + Math.random() * 7;
                    if (!target) return;
                }
            }
            if (!target) return;
            fade = Math.min(1, fade + dt * (cyber.pointing ? 4 : 1.6));
            const f = target.fish, p = cyber.centreOf(f);
            const k = Math.min(1, dt * (cyber.pointing ? 14 : 6));
            cx += (p[0] - cx) * k;
            cy += (p[1] - cy) * k;
            size += (f.len * (target.blur ? 0.9 : 1.25) - size) * k;
            const hdg = "HDG " + String(Math.round(((f.angle * 180 / Math.PI) % 360 + 360) % 360)).padStart(3, "0") + "°";
            const dep = "DEPTH " + (0.3 + f.depth * 1.2).toFixed(2) + "m";
            if (!target.blur) { hdgText = hdg; depthText = dep; }
            else if (Math.floor(cyber.t * 6) !== tick) {   // re-scramble a few times a second
                tick = Math.floor(cyber.t * 6);
                hdgText = cyber.scramble(hdg);
                depthText = cyber.scramble(dep);
            }
        }

        x: cx - size / 2
        y: cy - size / 2
        width: size; height: size
        opacity: fade * 0.92

        Repeater {
            model: 4
            Item {
                id: corner
                required property int index
                readonly property bool isRight: index % 2 === 1
                readonly property bool isBottom: index > 1
                readonly property real arm: box.size * 0.18
                x: isRight ? box.width - arm : 0
                y: isBottom ? box.height - arm : 0
                width: arm; height: arm
                Rectangle { y: corner.isBottom ? corner.height - height : 0; width: corner.width; height: Math.max(1, cyber.u * 1.2); color: cyber.line }
                Rectangle { x: corner.isRight ? corner.width - width : 0; width: Math.max(1, cyber.u * 1.2); height: corner.height; color: cyber.line }
            }
        }
        Rectangle {
            x: box.width; y: -1
            width: 34 * cyber.u; height: Math.max(1, cyber.u)
            color: cyber.line; opacity: 0.7
        }
        Column {
            x: box.width + 40 * cyber.u
            y: -8 * cyber.u
            layer.enabled: true
            layer.effect: Glow {}
            spacing: 2 * cyber.u
            Mono {
                text: !box.target ? "" : box.target.blur ? "SPECIMEN K-???" : "SPECIMEN K-" + String(box.target.id).padStart(2, "0")
                font.pixelSize: 12 * cyber.u
                font.weight: Font.Medium
            }
            Mono {
                text: !box.target ? "" : box.target.blur ? "???  ·  ???"
                      : box.target.fish.variety + "  ·  " + (box.target.fish.baby ? "JUVENILE" : "ADULT")
                opacity: 0.92
            }
            Mono {
                text: box.target ? box.hdgText + "   " + box.depthText : ""
                opacity: 0.92
            }
        }
    }

    // driven by the pond's frame timer
    function tick(dt) { if (visible) box.step(dt); }

    // ---- depth ruler down the right edge ----
    Item {
        x: cyber.width - 46 * cyber.u
        y: 90 * cyber.u
        width: 20 * cyber.u
        height: cyber.height - 180 * cyber.u
        opacity: 0.75
        Rectangle { x: parent.width - 1; width: Math.max(1, cyber.u); height: parent.height; color: cyber.line; opacity: 0.5 }
        Repeater {
            model: Math.max(0, Math.floor(parent.height / (24 * cyber.u)) + 1)
            Rectangle {
                required property int index
                readonly property bool major: index % 5 === 0
                x: parent.width - width
                y: index * 24 * cyber.u
                width: (major ? 14 : 6) * cyber.u
                height: Math.max(1, cyber.u)
                color: cyber.line
                Mono {
                    visible: parent.major
                    anchors.right: parent.left
                    anchors.rightMargin: 6 * cyber.u
                    anchors.verticalCenter: parent.verticalCenter
                    text: (parent.index / 10).toFixed(1)
                    font.pixelSize: 9 * cyber.u
                    opacity: 0.85
                }
            }
        }
    }

    // ---- tank telemetry ----
    Column {
        x: cyber.width - 290 * cyber.u
        layer.enabled: true
        layer.effect: Glow {}
        y: cyber.height * 0.42
        spacing: 5 * cyber.u
        opacity: 0.92

        Mono { text: "// TANK 03  —  BOOT " + (cyber.cond ? (cyber.cond.seed % 65536).toString(16).toUpperCase().padStart(4, "0") : "----"); font.pixelSize: 10 * cyber.u; opacity: 0.92 }
        Rectangle { width: 210 * cyber.u; height: Math.max(1, cyber.u); color: cyber.line; opacity: 0.45 }
        Repeater {
            model: [
                { k: "TEMP", v: () => cyber.cond ? (cyber.cond.temp + 0.1 * Math.sin(cyber.slowT * 0.05)).toFixed(1) + " °C" : "--", f: () => cyber.cond ? (cyber.cond.temp - 18) / 10 : 0 },
                { k: "PH", v: () => cyber.cond ? (cyber.cond.ph + 0.02 * Math.sin(cyber.slowT * 0.03 + 1)).toFixed(2) : "--", f: () => cyber.cond ? (cyber.cond.ph - 6.2) / 2 : 0 },
                { k: "O₂", v: () => cyber.cond ? Math.round(cyber.cond.o2) + " %" : "--", f: () => cyber.cond ? (cyber.cond.o2 - 80) / 20 : 0 },
                { k: "FLOW", v: () => cyber.cond ? (cyber.cond.flow + 0.01 * Math.sin(cyber.slowT * 0.11)).toFixed(2) + " L/s" : "--", f: () => cyber.cond ? cyber.cond.flow / 0.7 : 0 },
                { k: "SPECIMENS", v: () => String((cyber.fishItems ? cyber.fishItems.count : 0) + (cyber.fgItems ? cyber.fgItems.count : 0)), f: () => 1 },
                { k: "THRIVING", v: () => cyber.cond ? cyber.cond.dominant : "--", f: () => 1 }
            ]
            Item {
                required property var modelData
                width: 210 * cyber.u
                height: 16 * cyber.u
                Mono { text: modelData.k; opacity: 0.92 }
                Mono { anchors.right: parent.right; text: { cyber.slowT; cyber.cond; return modelData.v(); } }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: Math.max(1, cyber.u); color: cyber.line; opacity: 0.18
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.max(0, Math.min(1, modelData.f())); height: Math.max(1, cyber.u); color: cyber.line; opacity: 0.6
                }
            }
        }
    }
}
