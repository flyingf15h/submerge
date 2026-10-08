import QtQuick 2.15

// One koi or goldfish with its shadow. Looks up `pond` and `shadowLayer` from Pond.qml.
Item {
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
            vertexShader: pond.shaders + "fish.vert"
            fragmentShader: pond.shaders + "fish.frag"
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
            vertexShader: pond.shaders + "fish.vert"
            fragmentShader: pond.shaders + "fish.frag"
        }
    }
}
