import QtQuick 2.15

// Stand-in for Qt 6's FrameAnimation: fires triggered() once per rendered frame with
// frameTime set to the seconds since the previous one. A looping animation is driven by the
// render loop, so it ticks in step with the screen.
Item {
    id: ticker
    property bool running: true
    property real frameTime: 0
    signal triggered()

    property real tick: 0
    property double last: 0
    NumberAnimation on tick { from: 0; to: 1; duration: 1000; loops: Animation.Infinite; running: ticker.running }
    onTickChanged: {
        const now = Date.now();
        if (last > 0 && now > last) {
            frameTime = (now - last) / 1000;
            triggered();
        }
        last = now;
    }
    onRunningChanged: last = 0
}
