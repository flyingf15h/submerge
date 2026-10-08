import QtQuick 2.15
import QtQuick.Window 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.taskmanager 0.1 as TaskManager
import org.kde.plasma.private.showdesktop 0.1 as ShowDesktop

Item {
    id: root

    readonly property var cfg: wallpaper.configuration
    readonly property rect screenRect: Qt.rect(root.Screen.virtualX, root.Screen.virtualY, root.Screen.width, root.Screen.height)

    // ---- on battery: hold a still frame ----
    PlasmaCore.DataSource {
        id: power
        engine: "powermanagement"
        connectedSources: ["AC Adapter", "Battery"]
        // a binding on power.data["Battery"] that first ran before the key existed never
        // re-runs, so copy the values over as they arrive
        onNewData: {
            if (sourceName === "Battery") root.battery = data;
            else root.acPlugged = data["Plugged in"];
        }
    }
    // Plasma 5.27's "AC Adapter" source can report plugged in while the battery drains (seen on
    // a laptop with a USB-C power source next to the barrel jack), so trust the battery's state
    property var battery: ({})
    property var acPlugged
    readonly property bool usingBattery: !!battery["Has Battery"] && (battery["State"] === "Discharging" || acPlugged === false)
    // on battery the pond either holds a still frame or keeps swimming at 15 fps
    readonly property bool lowPower: usingBattery && cfg.PauseOnBattery

    // ---- which screens are worth animating ----
    // A maximized or fullscreen window covers the whole pond on its screen, so that screen holds a
    // still frame. With several screens only one animates: the one you're using (focused window,
    // or its desktop clicked / shown), unless that one is covered, in which case the uncovered
    // screens animate instead. Plasma 5 gives every screen its own window and GL context, so one
    // rendered pond can't simply be mirrored to both. Every screen's pond works this out from the
    // same window list, so they agree without talking to each other.
    property bool covered: false
    property bool chosen: true
    readonly property bool desktopFocused: root.Window.active
    onDesktopFocusedChanged: windowCheck.restart()
    // Show Desktop hides every window without minimizing it (or giving the desktop focus)
    ShowDesktop.ShowDesktop {
        id: showDesktop
        onShowingDesktopChanged: windowCheck.restart()
    }

    TaskManager.VirtualDesktopInfo { id: desktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        virtualDesktop: desktopInfo.currentDesktop
        activity: activityInfo.currentActivity
        filterByVirtualDesktop: true
        filterByActivity: true
        filterMinimized: true
        onActiveTaskChanged: windowCheck.restart()
        onDataChanged: windowCheck.restart()
        onCountChanged: windowCheck.restart()
        onModelReset: windowCheck.restart()
    }
    function screenIndexAt(x, y) {
        const ss = Qt.application.screens;
        for (let i = 0; i < ss.length; i++) {
            const s = ss[i];
            if (x >= s.virtualX && x < s.virtualX + s.width && y >= s.virtualY && y < s.virtualY + s.height) return i;
        }
        return -1;
    }
    Timer {
        id: windowCheck
        interval: 150
        onTriggered: {
            if (showDesktop.showingDesktop) {
                root.covered = false;
                root.chosen = true;
                return;
            }
            const ss = Qt.application.screens;
            const me = root.screenIndexAt(root.screenRect.x + root.screenRect.width / 2, root.screenRect.y + root.screenRect.height / 2);
            const coveredBy = [];   // Qt 5 screen lists have no map()
            for (let i = 0; i < ss.length; i++) coveredBy.push(false);
            for (let i = 0; i < tasks.count; i++) {
                const idx = tasks.makeModelIndex(i);
                if (!tasks.data(idx, TaskManager.AbstractTasksModel.IsMaximized)
                        && !tasks.data(idx, TaskManager.AbstractTasksModel.IsFullScreen)) continue;
                const g = tasks.data(idx, TaskManager.AbstractTasksModel.Geometry);
                const k = root.screenIndexAt(g.x + g.width / 2, g.y + g.height / 2);
                if (k >= 0) coveredBy[k] = true;
            }
            // a focused desktop is on show (clicked, or Show Desktop), whatever is maximized
            if (root.desktopFocused && me >= 0) coveredBy[me] = false;
            root.covered = me >= 0 && coveredBy[me];

            // the screen in use: the focused window's, or this one if its desktop has focus
            let inUse = -1;
            const active = tasks.activeTask;
            if (root.desktopFocused) inUse = me;
            else if (active && active.valid) {
                const g = tasks.data(active, TaskManager.AbstractTasksModel.Geometry);
                inUse = root.screenIndexAt(g.x + g.width / 2, g.y + g.height / 2);
            }
            // if that's unknown (another screen's desktop or the panel has focus) or covered,
            // every uncovered screen animates
            root.chosen = inUse < 0 || coveredBy[inUse] || inUse === me;
        }
    }
    Component.onCompleted: windowCheck.start()

    readonly property bool multiScreen: Qt.application.screens.length > 1
    readonly property bool inUse: !multiScreen || !cfg.ActiveScreenOnly || chosen || pond.pointerInside

    Pond {
        id: pond
        anchors.fill: parent
        fishCount: cfg.FishCount
        fishSize: cfg.FishSize / 100
        fishSpeed: cfg.FishSpeed / 100
        lights: cfg.Lights
        motes: cfg.Motes
        ripples: cfg.Ripples
        foreground: cfg.Foreground
        filmLook: cfg.FilmLook
        hud: cfg.Hud
        title: cfg.Title
        player: cfg.Player
        textScale: cfg.TextScale / 100
        // the screen's refresh rate on AC, 15 fps on battery (same visuals)
        maxFps: root.usingBattery ? 15 : 0
        // the HUD's sensors and clock slow down on battery either way
        lowPower: root.usingBattery
        lockScreen: cfg.LockScreen
        trackCursor: !root.usingBattery
        running: root.visible && !root.lowPower
                 && (cfg.LockScreen || (root.inUse && !(root.covered && cfg.PauseWhenCovered)))
    }
}
