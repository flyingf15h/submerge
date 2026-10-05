import QtQuick
import QtQuick.Window
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus

// Decides whether the pond is worth animating right now. Loaded through a Loader so the
// wallpaper still works where the task manager module isn't available.
//  - covered: a maximized or fullscreen window hides the desktop (unless the desktop has focus,
//    which is what clicking it or Show Desktop does)
//  - focused: the desktop itself is the active window
Item {
    id: watcher
    property bool covered: false
    // Show Desktop only hands the desktop focus for a moment, so ask KWin about it directly
    property bool showingDesktop: false
    readonly property bool focused: Window.active || showingDesktop

    onFocusedChanged: check.restart()

    DBus.Properties {
        id: kwinProps
        busType: DBus.BusType.Session
        service: "org.kde.KWin"
        path: "/KWin"
        iface: "org.kde.KWin"
        onRefreshed: watcher.showingDesktop = !!properties.showingDesktop
    }
    DBus.SignalWatcher {
        busType: DBus.BusType.Session
        service: "org.kde.KWin"
        path: "/KWin"
        iface: "org.kde.KWin"
        // the watcher calls "dbus" + the signal name, exactly as KWin spells it
        function dbusshowingDesktopChanged(showing) { watcher.showingDesktop = showing; }
    }

    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        virtualDesktop: desktops.currentDesktop
        activity: activities.currentActivity
        filterByVirtualDesktop: true
        filterByActivity: true
        filterMinimized: true

        onActiveTaskChanged: check.restart()
        onDataChanged: check.restart()
        onCountChanged: check.restart()
        onModelReset: check.restart()
    }

    // window changes come in bursts; look once things settle
    Timer {
        id: check
        interval: 150
        onTriggered: {
            let c = false;
            for (let i = 0; i < tasks.count && !c; i++) {
                const idx = tasks.makeModelIndex(i);
                if (tasks.data(idx, TaskManager.AbstractTasksModel.IsMaximized)
                    || tasks.data(idx, TaskManager.AbstractTasksModel.IsFullScreen))
                    c = true;
            }
            watcher.covered = c && !watcher.focused;
        }
    }

    Component.onCompleted: check.start()
}
