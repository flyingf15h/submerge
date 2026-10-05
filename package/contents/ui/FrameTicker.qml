import QtQuick 2.15

// Stand-in for Qt 6's FrameAnimation: fires triggered() in step with the render loop, with
// frameTime set to the seconds since the previous trigger. A looping animation is driven by the
// render loop, so it ticks in step with the screen.
// maxFps caps how often it fires: on a 144 or 165 Hz screen, firing every frame would redraw the
// whole pond 150 times a second. Ticks in between change nothing, so Qt skips rendering them.
Item {
    id: ticker
    property bool running: true
    property real maxFps: 0             // 0 = every frame
    property real frameTime: 0
    signal triggered()

    property real tick: 0
    property double last: 0
    property double acc: 0
    NumberAnimation on tick { from: 0; to: 1; duration: 1000; loops: Animation.Infinite; running: ticker.running }
    onTickChanged: {
        const now = Date.now();
        if (last > 0 && now > last) {
            acc += (now - last) / 1000;
            // allow a few ms early so the cap lands on a vsync instead of skipping a whole extra one
            if (maxFps <= 0 || acc >= 1 / maxFps - 0.004) {
                frameTime = acc;
                acc = 0;
                triggered();
            }
        }
        last = now;
    }
    onRunningChanged: { last = 0; acc = 0; }
}
