import QtQuick
import QtQuick.Effects
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.plasma5support as P5Support

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
    property bool pauseWhenCovered: true
    property bool slowWhenUnfocused: true
    // on the lock screen every window is hidden, so the window checks don't apply there
    property bool lockScreen: false
    property bool slowOnBattery: true
    property int fps: 20
    property int lowFps: 10
    // room taken by a panel along the bottom of the screen, so the HUD sits above the taskbar
    property real bottomInset: 0
    Loader { id: coverLoader; source: "CoverWatcher.qml" }
    readonly property bool watcherReady: coverLoader.item !== null
    readonly property bool covered: pauseWhenCovered && !lockScreen && watcherReady && coverLoader.item.covered
    readonly property bool unfocused: watcherReady && !coverLoader.item.focused

    P5Support.DataSource {
        id: power
        engine: "powermanagement"
        connectedSources: pond.slowOnBattery ? ["AC Adapter", "Battery"] : []
    }
    readonly property bool onBattery: !!power.data["Battery"] && !!power.data["Battery"]["Has Battery"]
                                      && !!power.data["AC Adapter"] && power.data["AC Adapter"]["Plugged in"] === false

    // Only stop completely when the pond can't be seen at all (a maximized or fullscreen window
    // covers it). While you're working in a window, or on battery, it keeps swimming at a lower
    // frame rate instead of freezing.
    readonly property bool active: running && visible && !covered
    readonly property bool lowPower: (slowWhenUnfocused && unfocused && !lockScreen) || (slowOnBattery && onBattery)
    readonly property real liveFps: lowPower ? Math.min(fps, lowFps) : fps

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
    readonly property int simW: 512
    readonly property int simH: Math.max(64, Math.round(512 * height / Math.max(1, width)))
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
        // per step at 40 steps a second (fades like 0.975 per step did at 30)
        property real damping: 0.981
        property real steps: 1
        property real simAspect: pond.width / Math.max(1, pond.height)
        property vector4d drop0: Qt.vector4d(0, 0, 0, 0)
        property vector4d drop1: Qt.vector4d(0, 0, 0, 0)
        property vector4d drop2: Qt.vector4d(0, 0, 0, 0)
        property vector4d drop3: Qt.vector4d(0, 0, 0, 0)
        fragmentShader: pond.shaders + "sim.frag.qsb"
    }
    ShaderEffectSource {
        id: simSrc
        sourceItem: simStep
        hideSource: true
        recursive: true
        live: false
        smooth: true
        format: ShaderEffectSource.RGBA16F
        textureSize: Qt.size(pond.simW, pond.simH)
    }
    // the ripples advance on the main frame timer, doing several steps per frame when the frame
    // rate is low so they always move at about 40 steps a second
    readonly property int simRate: 40
    function stepSim() {
        const z = Qt.vector4d(0, 0, 0, 0);
        const due = [];
        pond.pendingDrops = pond.pendingDrops.filter(p => {
            if (p.at <= pond.t && due.length < 4) { due.push(p.v); return false; }
            return true;
        });
        simStep.drop0 = due[0] ?? z;
        simStep.drop1 = due[1] ?? z;
        simStep.drop2 = due[2] ?? z;
        simStep.drop3 = due[3] ?? z;
        simStep.steps = Math.max(1, Math.min(3, Math.round(simRate / liveFps)));
        simSrc.scheduleUpdate();
    }
    // the odd drip landing somewhere on the water
    Timer {
        running: pond.ripples && pond.active
        repeat: true
        interval: 3000
        onTriggered: {
            interval = 2500 + Math.random() * 5500;
            pond.dripAt(pond.width * (0.3 + Math.random() * 0.65), pond.height * Math.random(), 0.15, 2);
        }
    }
    // and a steady drip from the filter in the top-right corner, always sending out fine rings
    Timer {
        running: pond.ripples && pond.active
        repeat: true
        interval: 650
        onTriggered: pond.drop(pond.width * 0.82 + Math.random() * 6, pond.height * 0.2 + Math.random() * 6, 0.006, 0.07)
    }

    // A steady, capped frame rate: on a 120 Hz screen per-vsync animation would redraw the
    // whole 5-megapixel scene 120 times a second for fish that barely move between frames.
    Timer {
        interval: Math.round(1000 / pond.liveFps)
        repeat: true
        running: pond.active
        property real last: 0
        property real fgAccum: 0
        onRunningChanged: last = 0
        onTriggered: {
            const now = Date.now();
            const dt = last ? Math.min((now - last) / 1000, 0.1) : interval / 1000;
            last = now;
            cyberLayer.tick(dt);
            hudLayer.step(dt);
            if (pond.ripples) pond.stepSim();
            pond.t += dt;
            pond.mouseSpeed *= Math.pow(0.02, dt);
            for (let i = 0; i < fishRep.count; i++) fishRep.itemAt(i)?.step(dt);
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
            // the big blurry fish are slow and soft, so they only need 15 updates a second
            fgAccum += dt;
            if (fgAccum >= 1 / 15) {
                for (let i = 0; i < fgRep.count; i++) fgRep.itemAt(i)?.step(fgAccum);
                fgAccum = 0;
            }
            // the big blurry fish keep their distance from each other instead of piling up
            for (let i = 0; i < fgRep.count; i++) {
                const a = fgRep.itemAt(i)?.fish;
                if (!a) continue;
                for (let j = 0; j < fgRep.count; j++) {
                    const b = fgRep.itemAt(j)?.fish;
                    if (!b || i === j) continue;
                    const dx = a.fx - b.fx, dy = a.fy - b.fy;
                    if (dx * dx + dy * dy < (pond.width * 0.38) ** 2) {
                        const away = Math.atan2(dy, dx);
                        a.baseAngle += Math.atan2(Math.sin(away - a.baseAngle), Math.cos(away - a.baseAngle)) * Math.min(1, dt * 2.5);
                    }
                }
            }
            if (pond.motes)
                for (let j = 0; j < moteRep.count; j++) moteRep.itemAt(j)?.step(dt);
        }
    }

    component Koi: Item {
        id: fish
        required property int index
        property bool big: false
        property bool gold: Math.random() < pond.cond.gold
        // mostly full-size koi with a few babies; no in-between sizes
        readonly property bool baby: !big && Math.random() < pond.cond.baby
        readonly property int type: baby ? 5 + Math.floor(Math.random() * 2) : 1 + Math.floor(Math.random() * 2)
        property real sizeBoost: 1
        readonly property real baseLen: big ? (420 + Math.random() * 160) * sizeBoost
                                       : baby ? 55 + Math.random() * 12
                                       : 140 + Math.random() * 35
        property int forcePal: -1
        readonly property var pals: gold ? pond.goldPalettes : Math.random() < pond.cond.tint ? pond.cond.tintPals : pond.whitePalettes
        readonly property int pal: forcePal >= 0 ? forcePal : pals[Math.floor(Math.random() * pals.length)]
        readonly property string variety: pond.varietyNames[pal]
        // extra blurry fish hang around the edges of the screen, half out of view
        property bool edge: false
        property real homeY: 0.3 + Math.random() * 0.4
        property real homeTimer: 20 + Math.random() * 20
        property bool surfaced: false
        readonly property var def: pond.fishDefs[type]
        readonly property var sdef: pond.shadowDefs[Math.min(type, 5)]
        readonly property real wrap: (big ? 700 : 120) * pond.unit

        property real fx: Math.random() * pond.width
        property real fy: Math.random() * pond.height
        property real angle: Math.random() * Math.PI * 2
        property real baseAngle: angle
        property real cruise: ((big ? 0.6 : 0.5) + Math.random() * 0.8) * pond.cond.speed
        property real speed: cruise
        property real wanderT: Math.random() * 1000
        property real seedA: Math.random() * 100
        property real seedB: Math.random() * 100
        property real swimPhase: Math.random() * Math.PI * 2
        property real turn: 0          // smoothed turning speed, rad/s
        // koi swim in bursts: a few strong tail beats, then a glide with the tail almost still
        property real beat: 0.5
        property real beatTarget: 0.8
        property real beatTimer: Math.random() * 2
        property real depthPhase: Math.random() * Math.PI * 2
        property real depthRate: 0.03 + Math.random() * 0.05
        property real depth: 0

        readonly property real len: baseLen * pond.unit * (1 - depth * 0.12)
        readonly property real s: len / def.len
        readonly property real deg: angle * 180 / Math.PI + 90
        readonly property real drive: Math.max(beat, Math.min(1, Math.abs(turn) * 0.8))
        readonly property real yaw: Math.sin(swimPhase + 0.6) * 2.8 * drive
        // fold angle for the back half; negative so the tail trails to the outside of the turn
        readonly property real bendAng: -Math.max(-0.7, Math.min(0.7, turn * 0.9))
        readonly property real swimAmp: len * (0.02 + 0.07 * drive)
        readonly property real shadowRoll: Math.random()
        readonly property bool glitchShadow: shadowRoll > 0.82
        readonly property vector4d shadowTint: glitchShadow ? Qt.vector4d(0, 0, 0, 0)
                                             : shadowRoll > 0.7 ? Qt.vector4d(0.18, 0.04, 0.32, 1)
                                             : shadowRoll > 0.55 ? Qt.vector4d(0.0, 0.2, 0.26, 1)
                                             : Qt.vector4d(0, 0, 0, 0)

        function step(dt) {
            const k = dt * 60;
            if (big && edge) {
                // drift around a spot just past the left or right edge, so only part of it shows
                homeTimer -= dt;
                if (homeTimer <= 0) { homeY = 0.2 + Math.random() * 0.6; homeTimer = 20 + Math.random() * 25; }
                const hx = index % 2 ? -0.02 * pond.width : 1.02 * pond.width, hy = homeY * pond.height;
                const bx = fx - Math.cos(angle) * len * 0.4, by = fy - Math.sin(angle) * len * 0.4;
                if ((bx - hx) ** 2 + (by - hy) ** 2 > (pond.width * 0.16) ** 2) {
                    const home = Math.atan2(hy - by, hx - bx);
                    baseAngle += Math.atan2(Math.sin(home - baseAngle), Math.cos(home - baseAngle)) * Math.min(1, 0.03 * k);
                }
            } else if (!big) {
                // small fish turn back before leaving the screen, so it never looks empty
                const mx = pond.width * 0.04, my = pond.height * 0.06;
                if (fx < mx || fx > pond.width - mx || fy < my || fy > pond.height - my) {
                    const home = Math.atan2(pond.height / 2 - fy, pond.width / 2 - fx);
                    baseAngle += Math.atan2(Math.sin(home - baseAngle), Math.cos(home - baseAngle)) * Math.min(1, 0.04 * k);
                }
            } else {
                // keep the middle of the body (not the head) well inside the screen; these fish are huge
                const bx = fx - Math.cos(angle) * len * 0.4, by = fy - Math.sin(angle) * len * 0.4;
                const mx = pond.width * 0.15, my = pond.height * 0.18;
                if (bx < mx || bx > pond.width - mx || by < my || by > pond.height - my) {
                    const home = Math.atan2(pond.height / 2 - by, pond.width / 2 - bx);
                    baseAngle += Math.atan2(Math.sin(home - baseAngle), Math.cos(home - baseAngle)) * Math.min(1, 0.03 * k);
                }
            }
            wanderT += 0.012 * k;
            depthPhase += depthRate * dt;
            depth = big ? 0 : 0.5 + 0.5 * Math.sin(depthPhase);
            if (!big) {
                if (depth < 0.03 && !surfaced) {
                    surfaced = true;
                    pond.drop(fx, fy, 0.008, 0.1);
                } else if (depth > 0.3) {
                    surfaced = false;
                }
            }

            // where it wants to head drifts smoothly (no per-frame randomness), and the turning
            // speed eases toward what's needed, so turns build up and settle like a real fish
            baseAngle += (0.16 * Math.sin(pond.t * 0.07 + seedA) + 0.09 * Math.sin(pond.t * 0.19 + seedB)) * dt;
            const target = baseAngle + Math.sin(wanderT) * 0.8;
            const diff = Math.atan2(Math.sin(target - angle), Math.cos(target - angle));
            const want = Math.max(-1.1, Math.min(1.1, diff * 1.1));
            turn += (want - turn) * (1 - Math.exp(-dt / 0.55));
            angle += turn * dt;

            // burst and glide
            beatTimer -= dt;
            if (beatTimer <= 0) {
                const gliding = beatTarget > 0.5;
                beatTarget = gliding ? 0.08 + Math.random() * 0.1 : 0.65 + Math.random() * 0.35;
                beatTimer = gliding ? 1.2 + Math.random() * 2.2 : 1.4 + Math.random() * 2.4;
            }
            beat += (beatTarget - beat) * (1 - Math.exp(-dt / 0.6));
            const targetSpeed = cruise * (0.4 + 0.9 * drive);
            speed += (targetSpeed - speed) * (1 - Math.exp(-dt / (targetSpeed > speed ? 0.8 : 1.6)));

            // the tail beats while driving and almost stops while gliding
            swimPhase += dt * (1.4 + 4.6 * drive) * Math.sqrt(pond.fishSpeed) * (big ? 0.6 : 1);
            const v = speed * pond.fishSpeed * pond.unit / pond.fishSize * (big ? 0.85 : 1) * k;
            fx += Math.cos(angle) * v;
            fy += Math.sin(angle) * v;
            if (fx < -wrap) fx = pond.width + wrap; else if (fx > pond.width + wrap) fx = -wrap;
            if (fy < -wrap) fy = pond.height + wrap; else if (fy > pond.height + wrap) fy = -wrap;
        }

        // about a third swim deeper and show up fainter, so the pond reads less busy
        readonly property bool faint: !big && index % 3 === 2
        x: fx; y: fy
        opacity: (1 - depth * 0.35) * (faint ? 0.55 : 1)

        Item {
            rotation: fish.deg + fish.yaw
            // soft blue light around the body, oriented with the fish
            Image {
                visible: !fish.big
                source: pond.img + "fx/glow.png"
                x: -fish.len * 0.34; y: -fish.len * 0.18
                width: fish.len * 0.68; height: fish.len * 1.3
                opacity: 0.5
            }
            Image {
                id: bodyTex
                source: pond.img + "fish/f" + fish.type + "_" + fish.pal + ".png"
                mipmap: true
                visible: false
            }
            ShaderEffect {
                width: 240 * fish.s; height: 340 * fish.s
                x: -fish.def.a[0] * fish.s
                y: -fish.def.a[1] * fish.s
                property variant source: bodyTex
                property real phase: fish.swimPhase
                property real amp: fish.swimAmp
                property real bend: fish.bendAng
                property real headV: fish.def.a[1] / 340
                property real tailV: Math.min(1, (fish.def.a[1] + fish.def.len) / 340)
                property real fog: 0
                property real pivotX: fish.def.a[0] * fish.s
                property real itemH: height
                property vector4d tint: Qt.vector4d(0, 0, 0, 0)
                property real glitchy: 0
                mesh: GridMesh { resolution: Qt.size(2, 28) }
                vertexShader: pond.shaders + "fish.vert.qsb"
                fragmentShader: pond.shaders + "fish.frag.qsb"
            }
        }

        // shadow on the floor, bent the same way; deeper fish sit closer to their shadow
        Item {
            parent: fish.big ? fish : shadowLayer
            visible: !fish.big
            readonly property real lx: fish.fx - pond.lightX
            readonly property real ly: fish.fy - pond.lightY
            readonly property real ln: Math.max(1, Math.sqrt(lx * lx + ly * ly))
            readonly property real off: fish.len * (0.42 - fish.depth * 0.26)
            x: fish.fx + lx / ln * off
            y: fish.fy + ly / ln * off
            rotation: fish.deg + fish.yaw
            opacity: 0.6 + fish.depth * 0.25
            Image {
                id: shadowTex
                source: pond.img + "fish/s" + (fish.type >= 5 ? 6 : fish.type) + ".png"
                mipmap: true
                visible: false
            }
            ShaderEffect {
                width: 240 * fish.s; height: 340 * fish.s
                x: -fish.sdef[0] * fish.s
                y: -fish.sdef[1] * fish.s
                property variant source: shadowTex
                property real phase: fish.swimPhase - 0.3
                property real amp: fish.swimAmp
                property real bend: fish.bendAng
                property real headV: fish.sdef[1] / 340
                property real tailV: Math.min(1, (fish.sdef[1] + fish.def.len) / 340)
                property real fog: 0
                property real pivotX: fish.sdef[0] * fish.s
                property real itemH: height
                property vector4d tint: fish.shadowTint
                property real glitchy: fish.glitchShadow ? 1 : 0
                mesh: GridMesh { resolution: Qt.size(2, 20) }
                vertexShader: pond.shaders + "fish.vert.qsb"
                fragmentShader: pond.shaders + "fish.frag.qsb"
            }
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
            fragmentShader: pond.shaders + "post.frag.qsb"
        }

        // the pond floor as seen through the surface: everything in here is bent and lit by the ripples
        Item {
            id: floorView
            anchors.fill: parent
            layer.enabled: true
            layer.textureSize: Qt.size(Math.round(width * 0.6), Math.round(height * 0.6))
            layer.smooth: true
            layer.effect: ShaderEffect {
                property variant sim: simSrc
                property vector2d simTexel: Qt.vector2d(1 / pond.simW, 1 / pond.simH)
                property real refraction: pond.ripples ? 0.08 : 0
                property real glow: pond.ripples ? 1 : 0
                fragmentShader: pond.shaders + "ripple.frag.qsb"
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

        ShaderEffect {
            // only the top of the screen ever gets this light, so don't run the shader below it
            width: parent.width
            height: parent.height * yScale
            readonly property real yScale: 0.3
            visible: pond.lights
            property real time: pond.t
            property real aspect: pond.width / Math.max(1, pond.height)
            property real strength: 1.1
            fragmentShader: pond.shaders + "surface.frag.qsb"
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

        // ---- koi ----
        Item {
            id: fishLayer
            anchors.fill: parent
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
                model: 30
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
            id: cyberLayer
            anchors.fill: parent
            anchors.bottomMargin: pond.bottomInset
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
            id: hudLayer
            anchors.fill: parent
            anchors.bottomMargin: pond.bottomInset
            visible: pond.hud
            title: pond.title
            player: pond.player
            textScale: pond.textScale
            paused: !pond.active
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
                // only the first one swims in full view; the others stay faint at the edges
                opacity: index === 0 ? 0.88 : 0.5
                layer.enabled: true
                layer.textureSize: Qt.size(Math.round(width / 4), Math.round(height / 4))
                layer.smooth: true
                layer.effect: ShaderEffect {
                    property real time: pond.t
                    property real seed: fgHolder.index * 7.3 + 1.1
                    property real strength: 1.0
                    fragmentShader: pond.shaders + "glitch.frag.qsb"
                }
                readonly property Item fish: fgFish
                function step(dt) { fgFish.step(dt); }
                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    // so soft it can be blurred at an eighth of the screen's resolution
                    layer.textureSize: Qt.size(Math.round(width / 8), Math.round(height / 8))
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 12
                        saturation: 0.2
                    }
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
        onPositionChanged: (e) => {
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
