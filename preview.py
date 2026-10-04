#!/usr/bin/env python3
"""Live preview of the wallpaper in a normal window.

Restarts the window whenever anything in package/ changes. A full restart (instead of reloading
QML in place) is needed because Qt caches compiled shaders by path, so edited shaders would
otherwise keep showing the old version.
"""
import os, subprocess, sys, time, urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.join(HERE, "package")
UI = os.path.join(PKG, "contents", "ui")


WRAPPER = b"""
import QtQuick 2.15
import QtQuick.Window 2.15
Window {
    width: 1600; height: 900; visible: true; color: "black"
    title: "Submerge preview (restarts on save)"
    Loader { anchors.fill: parent; source: "Pond.qml" }
}
"""


def viewer():
    try:
        from PyQt5.QtCore import QUrl
        from PyQt5.QtGui import QGuiApplication
        from PyQt5.QtQml import QQmlApplicationEngine
    except ImportError:
        # no PyQt5 QML bindings: run the same wrapper with Qt 5's qmlscene instead. It goes in a
        # temp file (outside package/, which is watched) pointing at Pond.qml by full URL.
        import tempfile
        pond = "file://" + urllib.parse.quote(os.path.join(UI, "Pond.qml"))
        path = os.path.join(tempfile.gettempdir(), "submerge-preview.qml")
        with open(path, "wb") as f:
            f.write(WRAPPER.replace(b'"Pond.qml"', b'"' + pond.encode() + b'"'))
        os.execvp("qmlscene", ["qmlscene", path])
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.warnings.connect(lambda ws: [print("QML:", w.toString(), flush=True) for w in ws])
    engine.loadData(WRAPPER, QUrl.fromLocalFile(os.path.join(UI, "preview-wrapper.qml")))
    sys.exit(app.exec_())


def snapshot():
    out = {}
    for root, _, files in os.walk(PKG):
        for f in files:
            p = os.path.join(root, f)
            try:
                out[p] = os.stat(p).st_mtime_ns
            except FileNotFoundError:
                pass
    return out


def supervise():
    child = None
    last = None
    while True:
        now = snapshot()
        if now != last:
            time.sleep(0.4)   # let a burst of writes (e.g. install.sh compiling shaders) finish
            now = snapshot()
            if child and child.poll() is None:
                child.terminate()
                child.wait()
            child = subprocess.Popen([sys.executable, __file__, "--viewer"])
            print("started preview", flush=True)
            last = now
        elif child.poll() is not None:
            print("preview window closed", flush=True)
            return
        time.sleep(0.5)


if __name__ == "__main__":
    viewer() if "--viewer" in sys.argv else supervise()
