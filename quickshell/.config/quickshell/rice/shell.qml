import QtQml
import Quickshell

Scope {
    id: root

    // Wallpaper selection and timing belong to Quickshell; hyprpaper only renders.
    property string wallpaperCommand: "$HOME/.config/quickshell/scripts/wallpaper/wallpaper-next"
    property int rotationInterval: 900000

    function changeWallpaper() {
        Quickshell.execDetached(["sh", "-lc", root.wallpaperCommand])
    }

    Timer {
        interval: root.rotationInterval
        running: true
        repeat: true
        onTriggered: root.changeWallpaper()
    }
}
