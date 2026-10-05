import QtQuick 2.15
import org.kde.ksysguard.sensors 1.0 as Sensors

// The whole scene. Kept separate from main.qml so it can be run on its own for testing.
Item {
    id: pond
    clip: true

    property int fishCount: 9
    // keep the pond from feeling crowded: fewer fish on smaller screens
    readonly property int liveFish: Math.max(4, Math.min(fishCount, Math.round(fishCount * width * height / (1920 * 1080))))
    // koi variety for each colour variant, used on the specimen labels
    readonly property var varietyNames: ["HAKU", "PLATINUM OGON", "MIDORIGOI", "ASAGI", "MATSUBA",
                                         "MURASAKI", "AI GOROMO", "ORENJI OGON", "KOHAKU", "BENIGOI"]
    property real fishSize: 1.0
    property real fishSpeed: 1.0
    property bool lights: true
    property bool motes: true
    property bool ripples: true
    property bool foreground: true
    property bool filmLook: true
    property bool hud: true
    property string title: "SUBMERGE"
    property string player: "GUEST"
    property real textScale: 1.0
    property bool running: true
    property real maxFps: 10            // 0 = redraw every screen refresh
    property bool lowPower: false       // on battery: no live sensors, clock updated once a minute
    readonly property bool pointerInside: mouseX > -9000

    readonly property url img: Qt.resolvedUrl("../images/")
    readonly property url shaders: Qt.resolvedUrl("../shaders/")
    // fish lengths were tuned for a ~900px tall pond on the original site
    readonly property real unit: Math.min(width, height) / 900 * fishSize
    property real t: 0
    property real mouseX: -9999
    property real mouseY: -9999
    property real mouseSpeed: 0

    // head anchor of the straight pose (frame 3) and body length, from the original render-koi.js.
    // Fish5 has no shadow art, so both baby fish use the Fish6 shadow with the type 5 anchors.
    readonly property var fishDefs: ({
        1: { len: 226, a: [118, 61] },
        2: { len: 203, a: [115, 63] },
        3: { len: 197, a: [118, 66] },
        4: { len: 156, a: [116, 82] },
        5: { len: 83,  a: [112, 105] },
        6: { len: 74,  a: [112, 110] }
    })
    readonly property var shadowDefs: ({
        1: [123, 56], 2: [115, 64], 3: [116, 78], 4: [112, 102], 5: [113, 134]
    })
    // a consistent school: pale koi in the artist's base colours plus orange goldfish
    // ---- tank conditions ----
    // Rolled from the boot time, so they change every time the computer restarts but stay put
    // when Plasma reloads. They decide the mix of fish: warm water brings out goldfish, acidic
    // water the teal/green koi, alkaline water the violet ones, low oxygen more babies, and
    // strong flow makes everyone swim a little faster.
    Sensors.Sensor { id: uptimeSensor; sensorId: "os/system/uptime" }
    property var cond: null
    readonly property bool ready: cond !== null
    function rollConditions(seed) {
        let a = seed >>> 0;
        const rand = () => {   // mulberry32
            a = (a + 0x6D2B79F5) >>> 0;
            let t = a;
            t = Math.imul(t ^ (t >>> 15), t | 1);
            t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
        const temp = 18 + rand() * 10, ph = 6.2 + rand() * 2.0, o2 = 85 + rand() * 14, flow = 0.2 + rand() * 0.5;
        const warm = (temp - 18) / 10, acid = Math.max(-1, Math.min(1, (7.2 - ph) / 1.0));
        const gold = 0.1 + 0.45 * warm;
        const tint = 0.2 + 0.35 * Math.abs(acid);
        const tintPals = acid > 0 ? [2, 3, 4, 4, 2] : [5, 6, 5, 6, 3];
        const dominant = gold > 0.38 ? "ORENJI OGON" : tint > 0.42 ? (acid > 0 ? "ASAGI" : "MURASAKI") : "PLATINUM OGON";
        cond = { seed: seed, temp: temp, ph: ph, o2: o2, flow: flow, gold: gold, tint: tint, tintPals: tintPals,
                 baby: 0.08 + 0.3 * (1 - (o2 - 85) / 14), speed: 0.8 + 0.5 * (flow - 0.2) / 0.5, dominant: dominant };
    }
    Timer {
        // wait for the uptime sensor; fall back to the date if it never answers
        interval: 200; repeat: true; running: !pond.ready
        property int tries: 0
        onTriggered: {
            const up = Number(uptimeSensor.value);
            if (up > 0) pond.rollConditions(Math.floor((Date.now() / 1000 - up) / 60));
            else if (++tries > 20) pond.rollConditions(Math.floor(Date.now() / 86400000));
        }
    }

    // mostly white koi, with the artist's tinted variants and orange goldfish mixed in
    readonly property var whitePalettes: [0, 1]
    readonly property var tintPalettes: [2, 3, 4, 5, 6]
    readonly property var goldPalettes: [7, 8, 9]

    // light comes from the surface near the top-left; shadows fall away from it
    readonly property real lightX: width * 0.3
    readonly property real lightY: -height * 0.4

    // ---- real ripples: a damped wave equation on a height field covering the screen ----
    // below 20 fps a half-resolution field keeps the ripples at full speed: each step moves a wave
    // twice as far, so 30 steps a second (three per frame at 10 fps) are enough
    readonly property bool coarseSim: maxFps > 0 && maxFps < 20
    readonly property int simW: coarseSim ? 256 : 512
    readonly property real simRate: coarseSim ? 30 : 60
    readonly property int simH: Math.max(32, Math.round(simW * height / Math.max(1, width)))
    property var pendingDrops: []
    function drop(px, py, radius, strength, delay) {
        if (!ripples || pendingDrops.length > 24) return;
        pendingDrops.push({ at: t + (delay || 0), v: Qt.vector4d(px / width, py / height, radius, strength) });
    }
    // a real drop bounces a few times, sending out a train of fine rings rather than one big wave
    function dripAt(px, py, strength, rings) {
        for (let i = 0; i < rings; i++)
            drop(px, py, 0.007, strength * Math.pow(0.7, i) * (i % 2 ? -1 : 1), i * 0.11);
    }
    ShaderEffect {
        id: simStep
        width: pond.simW; height: pond.simH
        blending: false
        property variant prev: simSrc
        property vector2d texel: Qt.vector2d(1 / pond.simW, 1 / pond.simH)
        property real damping: pond.coarseSim ? 0.95 : 0.975   // the same fade per second
        property real steps: 1
        property real simAspect: pond.width / Math.max(1, pond.height)
        property vector4d drop0: Qt.vector4d(0, 0, 0, 0)
        property vector4d drop1: Qt.vector4d(0, 0, 0, 0)
        property vector4d drop2: Qt.vector4d(0, 0, 0, 0)
        property vector4d drop3: Qt.vector4d(0, 0, 0, 0)
        fragmentShader: pond.shaders + "sim.frag"
    }
    ShaderEffectSource {
        id: simSrc
        sourceItem: simStep
        hideSource: true
        recursive: true
        live: false
        smooth: true
        // Qt 5 has no float enum value, but the GL internal format is passed straight through:
        // 0x881A is GL_RGBA16F, needed because the height field goes negative
        Component.onCompleted: format = 0x881A
        textureSize: Qt.size(pond.simW, pond.simH)
    }
    // step the simulation at a steady rate whatever the frame rate is: up to three steps per frame
    property real simAcc: 0
    function simTick(dt) {
        simAcc = Math.min(simAcc + dt, 4 / simRate);
        if (simAcc < 0.5 / simRate) return;
        const steps = Math.min(3, Math.round(simAcc * simRate));
        simAcc = Math.max(0, simAcc - steps / simRate);
        const z = Qt.vector4d(0, 0, 0, 0);
        const due = [];
        pendingDrops = pendingDrops.filter(p => {
            if (p.at <= t && due.length < 4) { due.push(p.v); return false; }
            return true;
        });
        simStep.drop0 = due[0] || z;
        simStep.drop1 = due[1] || z;
        simStep.drop2 = due[2] || z;
        simStep.drop3 = due[3] || z;
        simStep.steps = steps;
        simSrc.scheduleUpdate();
    }
    // the odd drip landing somewhere on the water
    Timer {
        running: pond.ripples && pond.running
        repeat: true
        interval: 3000
        onTriggered: {
            interval = 2500 + Math.random() * 5500;
            pond.dripAt(pond.width * (0.3 + Math.random() * 0.65), pond.height * Math.random(), 0.15, 2);
        }
    }
    // and a steady drip from the filter in the top-right corner, always sending out fine rings
    Timer {
        running: pond.ripples && pond.running
        repeat: true
        interval: 650
        onTriggered: pond.drop(pond.width * 0.82 + Math.random() * 6, pond.height * 0.2 + Math.random() * 6, 0.006, 0.07)
    }

    FrameTicker {
        running: pond.running && pond.visible
        maxFps: pond.maxFps
        onTriggered: {
            const dt = Math.min(frameTime, 0.05);
            pond.t += dt;
            if (pond.ripples) pond.simTick(dt);
            pond.mouseSpeed *= Math.pow(0.02, dt);
            for (let i = 0; i < fishRep.count; i++) { const it = fishRep.itemAt(i); if (it) it.step(dt); }
            // small fish give each other room so the pond never looks crowded in one spot
            for (let i = 0; i < fishRep.count; i++) {
                const a = fishRep.itemAt(i);
                if (!a) continue;
                for (let j = i + 1; j < fishRep.count; j++) {
                    const b = fishRep.itemAt(j);
                    if (!b) continue;
                    const dx = a.fx - b.fx, dy = a.fy - b.fy, r = (a.len + b.len) * 0.9;
                    if (dx * dx + dy * dy < r * r) {
                        const away = Math.atan2(dy, dx), push = Math.min(1, dt * 1.2);
                        a.baseAngle += Math.atan2(Math.sin(away - a.baseAngle), Math.cos(away - a.baseAngle)) * push;
                        b.baseAngle += Math.atan2(Math.sin(away + Math.PI - b.baseAngle), Math.cos(away + Math.PI - b.baseAngle)) * push;
                    }
                }
            }
            for (let i = 0; i < fgRep.count; i++) { const it = fgRep.itemAt(i); if (it) it.step(dt); }
            // the big blurry fish keep their distance from each other instead of piling up
            for (let i = 0; i < fgRep.count; i++) {
                const a = (fgRep.itemAt(i) || {}).fish;
                if (!a) continue;
                for (let j = 0; j < fgRep.count; j++) {
                    const b = (fgRep.itemAt(j) || {}).fish;
                    if (!b || i === j) continue;
                    const dx = a.fx - b.fx, dy = a.fy - b.fy;
                    if (dx * dx + dy * dy < (pond.width * 0.38) ** 2) {
                        const away = Math.atan2(dy, dx);
                        a.baseAngle += Math.atan2(Math.sin(away - a.baseAngle), Math.cos(away - a.baseAngle)) * Math.min(1, dt * 2.5);
                    }
                }
            }
            if (pond.motes)
                for (let j = 0; j < moteRep.count; j++) { const it = moteRep.itemAt(j); if (it) it.step(dt); }
            if (pond.hud) { cyber.step(dt); hud.step(dt); }
        }
    }

    Item {
        id: scene
        anchors.fill: parent
        layer.enabled: pond.filmLook
        layer.effect: ShaderEffect {
            property real time: pond.t
            property real grain: 0.085
            property real aberration: 0.009
            property real scanlines: 0.06
            property size res: Qt.size(scene.width, scene.height)
            fragmentShader: pond.shaders + "post.frag"
        }

        // the pond floor as seen through the surface: everything in here is bent and lit by the ripples
        Item {
            id: floorView
            anchors.fill: parent
            layer.enabled: true
            layer.effect: ShaderEffect {
                property variant sim: simSrc
                property vector2d simTexel: Qt.vector2d(1 / pond.simW, 1 / pond.simH)
                property real refraction: pond.ripples ? 0.08 : 0
                property real glow: pond.ripples ? 1 : 0
                fragmentShader: pond.shaders + "ripple.frag"
            }

        // ---- water ----
        Repeater {
            model: 5
            Image {
                required property int index
                anchors.fill: parent
                source: pond.img + "water/w" + (index + 1) + ".jpg"
                fillMode: Image.PreserveAspectCrop
                // slow crossfade through the painted water frames
                readonly property real ph: (pond.t * 0.12) % 5
                readonly property real d: Math.abs(((ph - index + 7.5) % 5) - 2.5)
                opacity: index === 0 ? 1 : Math.max(0, 1 - d)
            }
        }

        // two drifting caustic layers, like the original site
        Repeater {
            model: 7
            Image {
                required property int index
                anchors.fill: parent
                source: pond.img + "water/c" + (index + 1) + ".png"
                fillMode: Image.PreserveAspectCrop
                readonly property real ph: (pond.t * 0.9) % 7
                readonly property real d: Math.abs(((ph - index + 10.5) % 7) - 3.5)
                opacity: Math.max(0, 1 - d) * 0.7
            }
        }
        Item {
            anchors.fill: parent
            scale: 1.4
            rotation: 12
            opacity: 0.45
            Repeater {
                model: 7
                Image {
                    required property int index
                    anchors.fill: parent
                    source: pond.img + "water/c" + (index + 1) + ".png"
                    fillMode: Image.PreserveAspectCrop
                    readonly property real ph: (pond.t * 1.26 + 3.5) % 7
                    readonly property real d: Math.abs(((ph - index + 10.5) % 7) - 3.5)
                    opacity: Math.max(0, 1 - d)
                }
            }
        }

        // tank lights: a bright surface glow up top and coloured pools drifting around
        Item {
            anchors.fill: parent
            visible: pond.lights
            Image {
                source: pond.img + "fx/light_surface.png"
                width: pond.width * 1.1; height: width * 0.5
                x: pond.width * 0.35 - width / 2 + Math.sin(pond.t * 0.05) * 40
                y: -height * 0.45
                opacity: 0.7
            }
            Repeater {
                model: [
                    { c: "light_blue",   s: 0.9,  ax: 0.55, ay: 0.55, fx: 0.021, fy: 0.017, p: 0.0, o: 0.7 },
                    { c: "light_cyan",   s: 0.6,  ax: 0.25, ay: 0.35, fx: 0.031, fy: 0.023, p: 2.0, o: 0.45 },
                    { c: "light_violet", s: 0.7,  ax: 0.85, ay: 0.75, fx: 0.019, fy: 0.027, p: 4.0, o: 0.45 },
                    { c: "light_warm",   s: 0.45, ax: 0.80, ay: 0.25, fx: 0.015, fy: 0.021, p: 1.0, o: 0.5 },
                    { c: "light_blue",   s: 0.6,  ax: 0.10, ay: 0.85, fx: 0.022, fy: 0.020, p: 3.0, o: 0.55 }
                ]
                Image {
                    required property var modelData
                    source: pond.img + "fx/" + modelData.c + ".png"
                    width: pond.width * modelData.s; height: width * 0.75
                    x: pond.width * (modelData.ax + 0.18 * Math.sin(pond.t * modelData.fx * 6.28 + modelData.p)) - width / 2
                    y: pond.height * (modelData.ay + 0.16 * Math.cos(pond.t * modelData.fy * 6.28 + modelData.p)) - height / 2
                    opacity: modelData.o * (0.75 + 0.25 * Math.sin(pond.t * 0.4 + modelData.p * 1.7))
                }
            }
        }

        // the caustics and lamp glow fade to nothing a third of the way down, so only the top
        // band is drawn; the rest of the screen skips this expensive shader entirely
        ShaderEffect {
            width: parent.width
            height: parent.height * span
            visible: pond.lights
            property real span: 0.34
            property real time: pond.t
            property real aspect: pond.width / Math.max(1, pond.height)
            property real strength: 1.1
            fragmentShader: pond.shaders + "surface.frag"
        }
        // the water falls off into darkness toward the bottom of the screen
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.45; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0.0, 0.01, 0.05, 0.62) }
            }
        }
        Item {
            anchors.fill: parent
            visible: pond.hud
            readonly property real cell: 120 * pond.height / 1080
            Repeater {
                model: parent.cell > 0 ? Math.ceil(pond.width / parent.cell) + 1 : 0
                Rectangle {
                    required property int index
                    x: index * parent.cell; width: 1; height: pond.height
                    color: "#8fb0ff"; opacity: index % 4 === 0 ? 0.07 : 0.035
                }
            }
            Repeater {
                model: parent.cell > 0 ? Math.ceil(pond.height / parent.cell) + 1 : 0
                Rectangle {
                    required property int index
                    y: index * parent.cell; height: 1; width: pond.width
                    color: "#8fb0ff"; opacity: index % 4 === 0 ? 0.07 : 0.035
                }
            }
        }
        Item { id: shadowLayer; anchors.fill: parent }
        }

        // ---- koi, with a blue rim-light bloom ----
        Item {
            id: fishLayer
            anchors.fill: parent
            layer.enabled: true
            layer.effect: ShadowFx {
                shadowColor: "#5d8dff"
                shadowBlur: 0.7
                shadowOpacity: 0.85
                shadowScale: 1.04
            }
            Repeater {
                id: fishRep
                model: pond.ready ? pond.liveFish : 0
                Koi {}
            }
        }

        // ---- glowing particles drifting up through the water ----
        Item {
            anchors.fill: parent
            visible: pond.motes
            Repeater {
                id: moteRep
                model: 45
                Image {
                    source: pond.img + "fx/mote.png"
                    property real px: Math.random() * pond.width
                    property real py: Math.random() * pond.height
                    property real vy: 4 + Math.random() * 10
                    property real ph: Math.random() * 6.28
                    property real tw: 0.5 + Math.random() * 1.5
                    property real sz: (3 + Math.random() * 9) * Math.max(0.6, pond.unit / pond.fishSize)
                    width: sz; height: sz
                    x: px + Math.sin(ph) * 14 - sz / 2
                    y: py - sz / 2
                    opacity: (0.25 + 0.35 * (0.5 + 0.5 * Math.sin(ph * tw * 2))) * (sz > 8 ? 0.6 : 1)
                    function step(dt) {
                        ph += dt * 0.5;
                        py -= vy * dt;
                        if (py < -20) { py = pond.height + 20; px = Math.random() * pond.width; }
                    }
                }
            }
        }

        Cyber {
            id: cyber
            anchors.fill: parent
            visible: pond.hud
            fishItems: fishRep
            fgItems: fgRep
            textScale: pond.textScale
            cond: pond.cond
            t: pond.t
            mouseX: pond.mouseX
            mouseY: pond.mouseY
        }

        Hud {
            id: hud
            anchors.fill: parent
            visible: pond.hud
            title: pond.title
            player: pond.player
            textScale: pond.textScale
            running: pond.running
            // a paused pond (battery, covered, or the screen not in use) only updates once a minute
            lowPower: pond.lowPower || !pond.running
            t: pond.t
            mouseX: pond.mouseX
            mouseY: pond.mouseY
        }

        // two or three big out-of-focus fish close to the glass, each a different colour,
        // blurred and then run through a glitch effect
        readonly property var fgLooks: {
            // always clearly different: solid orange, a pale tinted koi, and orange-and-white
            const looks = [Math.random() < 0.5 ? 7 : 9, Math.random() < 0.5 ? 3 : 5, 8];
            for (let i = looks.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [looks[i], looks[j]] = [looks[j], looks[i]];
            }
            return looks;
        }
        Repeater {
            id: fgRep
            model: pond.foreground && pond.ready ? (Math.random() < 0.5 ? 2 : 3) : 0
            Item {
                id: fgHolder
                required property int index
                anchors.fill: parent
                readonly property Item fish: fgFish
                function step(dt) { fgFish.step(dt); }
                // it ends up heavily blurred anyway, so draw it at 1/8 size, blur it there, and
                // let the glitch pass stretch it back up to full screen
                Item {
                    id: fgSrc
                    anchors.fill: parent
                    Koi {
                        id: fgFish
                        index: fgHolder.index
                        big: true
                        gold: true
                        sizeBoost: 1.17
                        edge: fgHolder.index > 0
                        forcePal: scene.fgLooks[fgHolder.index]
                        fx: fgHolder.index === 0 ? pond.width * (0.4 + Math.random() * 0.2) : fgHolder.index % 2 ? -pond.width * 0.02 : pond.width * 1.02
                        fy: pond.height * (0.3 + Math.random() * 0.4)
                    }
                }
                ShaderEffectSource {
                    id: fgTex
                    sourceItem: fgSrc
                    hideSource: true
                    visible: false
                    smooth: true
                    textureSize: Qt.size(fgBlur.width, fgBlur.height)
                }
                SoftBlur {
                    id: fgBlur
                    width: Math.max(1, Math.ceil(pond.width / 8)); height: Math.max(1, Math.ceil(pond.height / 8))
                    source: fgTex
                    deviation: 3.2
                }
                ShaderEffect {
                    anchors.fill: parent
                    // only the first one swims in full view; the others stay faint at the edges
                    opacity: fgHolder.index === 0 ? 0.88 : 0.5
                    property variant source: fgBlur.output
                    property real time: pond.t
                    property real seed: fgHolder.index * 7.3 + 1.1
                    property real strength: 1.0
                    property real saturation: 0.2
                    fragmentShader: pond.shaders + "glitch.frag"
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        property real lx: 0
        property real ly: 0
        property real lt: 0
        onPositionChanged: {
            const e = mouse;
            const now = Date.now();
            const dt = Math.max(1, now - lt) / 1000;
            const v = Math.sqrt((e.x - lx) ** 2 + (e.y - ly) ** 2) / dt;
            if (now - lt < 200) pond.mouseSpeed = Math.max(pond.mouseSpeed, v);
            if (v > 700 && now - lt < 200 && Math.random() < 0.12) pond.drop(e.x, e.y, 0.008, 0.07);
            lx = e.x; ly = e.y; lt = now;
            pond.mouseX = e.x; pond.mouseY = e.y;
        }
        onExited: { pond.mouseX = -9999; pond.mouseY = -9999; }
    }
}
