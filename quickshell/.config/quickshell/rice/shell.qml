import QtQml
import Quickshell

Scope {
    id: root

    // Wallpaper selection and timing belong to Quickshell; hyprpaper only renders.
    property string wallpaperCommand: "$HOME/.local/bin/wallpaper-next"
    property int startupDelay: 5000
    property int rotationInterval: 900000

    function changeWallpaper() {
        Quickshell.execDetached(["sh", "-lc", root.wallpaperCommand])
    }

    Timer {
        interval: root.startupDelay
        running: true
        repeat: false
        onTriggered: root.changeWallpaper()
    }

    Timer {
        interval: root.rotationInterval
        running: true
        repeat: true
        onTriggered: root.changeWallpaper()
    }
}
