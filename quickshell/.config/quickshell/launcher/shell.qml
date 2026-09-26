import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    visible: true
    implicitWidth: 1920
    implicitHeight: 1080
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var allResults: []
    property var clipboardResults: []
    property var wallpaperResults: []
    property string activeMode: "search" // "search", "apps", "files", "wallpaper", "clipboard", "commands"
    property string calculation: ""
    property bool isClipboardMode: activeMode === "clipboard"
    property bool isWallpaperMode: activeMode === "wallpaper"
    property bool isDualPane: isClipboardMode || isWallpaperMode
    property bool resultsVisible: searchInput.text.trim().length > 0 || calculation.length > 0 || isDualPane || activeMode === "apps" || activeMode === "files"
    property var currentItem: (resultList.currentIndex >= 0 && resultList.currentIndex < resultModel.count) ? resultModel.get(resultList.currentIndex) : null
    property bool iconsSeparated: false

    Colors { id: colors }

    // Tahoe 1-second separation timer
    Timer {
        id: separationTimer
        interval: 1000
        running: true
        repeat: false
        onTriggered: root.separateIcons()
    }

    function separateIcons() {
        if (!iconsSeparated) {
            iconsSeparated = true
            separationTimer.stop()
            glowAnim.start()
            fluidSeparationAnim.start()
        }
    }

    function getPlaceholderText() {
        if (root.activeMode === "clipboard") return "Search clipboard history..."
        if (root.activeMode === "wallpaper") return "Search wallpapers..."
        if (root.activeMode === "apps") return "Search applications..."
        if (root.activeMode === "files") return "Search files..."
        if (root.activeMode === "commands") return "Search commands & controls..."
        return "Search"
    }

    function toggleMode(targetMode) {
        separateIcons()
        if (activeMode === targetMode) {
            activeMode = "search"
            if (searchInput.text.startsWith("@") || searchInput.text.startsWith(":")) {
                searchInput.text = ""
            }
        } else {
            activeMode = targetMode
            if (targetMode === "wallpaper") {
                searchInput.text = "@"
                searchInput.cursorPosition = 1
                if (!wallpaperLoader.running) wallpaperLoader.running = true
            } else if (targetMode === "clipboard") {
                searchInput.text = ":"
                searchInput.cursorPosition = 1
                if (!clipboardLoader.running) clipboardLoader.running = true
            } else {
                if (searchInput.text.startsWith("@") || searchInput.text.startsWith(":")) {
                    searchInput.text = ""
                }
            }
        }
        rebuild(searchInput.text)
        searchInput.forceActiveFocus()
    }

    function loadResults(raw) {
        try {
            allResults = JSON.parse(raw)
            rebuild(searchInput.text)
        } catch (error) {
            console.log("spotlight data parse failed", error)
        }
    }

    function loadClipboard(raw) {
        try {
            clipboardResults = JSON.parse(raw)
            rebuild(searchInput.text)
        } catch (error) {
            console.log("spotlight clipboard parse failed", error)
        }
    }

    function loadWallpapers(raw) {
        try {
            wallpaperResults = JSON.parse(raw)
            rebuild(searchInput.text)
        } catch (error) {
            console.log("spotlight wallpaper parse failed", error)
        }
    }

    function rebuild(query) {
        const trimmed = query.trim()
        const prefix = trimmed.length > 0 ? trimmed.charAt(0) : ""

        if (prefix === ":") {
            activeMode = "clipboard"
        } else if (prefix === "@") {
            activeMode = "wallpaper"
        } else if (prefix === ">") {
            activeMode = "commands"
        } else if (activeMode === "clipboard" || activeMode === "wallpaper" || activeMode === "commands") {
            if (prefix !== ":" && prefix !== "@" && prefix !== ">") {
                activeMode = "search"
            }
        }

        const normalized = (prefix === ":" || prefix === ">" || prefix === "@" ? trimmed.slice(1) : trimmed).toLowerCase()
        let source = allResults
        if (activeMode === "clipboard") source = clipboardResults
        else if (activeMode === "wallpaper") source = wallpaperResults

        resultModel.clear()

        if (prefix !== ":" && prefix !== "@" && trimmed.length > 0 && activeMode !== "wallpaper" && activeMode !== "clipboard") {
            resultModel.append({ id: "__run__", name: trimmed, subtitle: "Run shell command", kind: "run", isImage: false, preview: "", icon: "" })
        }

        for (let index = 0; index < source.length; index++) {
            const item = source[index]
            const kind = String(item.kind || (activeMode === "wallpaper" ? "wallpaper" : "app"))

            if (activeMode === "apps" && kind !== "app") continue
            if (activeMode === "files" && kind !== "file") continue
            if (activeMode === "commands" && kind !== "command") continue

            const haystack = ((item.name || "") + " " + (item.subtitle || "") + " " + (item.label || "")).toLowerCase()
            if (normalized === "" || haystack.indexOf(normalized) !== -1) {
                resultModel.append({
                    id: String(item.id || item.path || ""),
                    name: String(item.name || ""),
                    subtitle: String(item.subtitle || item.label || (activeMode === "wallpaper" ? ("Wallpaper • " + (item.filename || "")) : "")),
                    kind: kind,
                    mime: String(item.mime || (activeMode === "wallpaper" ? "image/jpeg" : "")),
                    label: String(item.label || item.name || ""),
                    isImage: Boolean(item.isImage || activeMode === "wallpaper"),
                    preview: String(item.preview || item.path || ""),
                    icon: String(item.icon || "")
                })
            }
            if (resultModel.count >= 60) break
        }
        resultList.currentIndex = resultModel.count > 0 ? 0 : -1
        updateCalculation(trimmed)
    }

    function updateCalculation(query) {
        const expression = query.replace(/^[:>@]/, "").trim()
        if (/^[0-9+*/%().,\- ]+$/.test(expression) && /[0-9]/.test(expression)) {
            calculator.command = ["qalc", "-t", expression]
            calculator.running = true
        } else {
            calculation = ""
        }
    }

    function closeAndQuit() {
        root.visible = false
        Qt.quit()
    }

    function runCurrent() {
        if (root.calculation.length > 0 && (resultList.currentIndex < 0 || searchInput.text.trim() === root.calculation)) {
            try {
                Quickshell.execDetached(["sh", "-lc", "printf '%s' '" + root.calculation.replace(/'/g, "'\\''") + "' | wl-copy"])
            } catch (e) {
                console.log("copy failed", e)
            }
            closeAndQuit()
            return
        }

        if (resultList.currentIndex < 0 || resultList.currentIndex >= resultModel.count) {
            closeAndQuit()
            return
        }
        const item = resultModel.get(resultList.currentIndex)
        if (!item) {
            closeAndQuit()
            return
        }

        if (item.id === "@" || item.kind === "wallpaper-picker" || item.name === "Wallpaper Picker") {
            toggleMode("wallpaper")
            return
        }

        try {
            if (item.kind === "run") Quickshell.execDetached(["sh", "-lc", item.name])
            else if (item.kind === "app") Quickshell.execDetached(["gtk-launch", item.id])
            else if (item.kind === "file") Quickshell.execDetached(["xdg-open", item.id])
            else if (item.kind === "command") Quickshell.execDetached(["sh", "-lc", item.id])
            else if (item.kind === "clipboard") Quickshell.execDetached(["sh", "-lc", "$HOME/.config/quickshell/scripts/clipboard/clipboard-restore " + item.id])
            else if (item.kind === "wallpaper") Quickshell.execDetached(["sh", "-lc", "$HOME/.config/quickshell/scripts/wallpaper/apply-wallpaper '" + item.id + "'"])
        } catch (e) {
            console.log("execDetached failed", e)
        }
        closeAndQuit()
    }

    Process {
        id: loader
        command: ["sh", "-lc", "$HOME/.config/quickshell/scripts/launcher/spotlight-items"]
        running: true
        stdout: StdioCollector { id: output }
        onExited: root.loadResults(output.text)
    }

    Process {
        id: clipboardLoader
        command: ["sh", "-lc", "$HOME/.config/quickshell/scripts/clipboard/clipboard-items"]
        stdout: StdioCollector { id: clipboardOutput }
        onExited: root.loadClipboard(clipboardOutput.text)
    }

    Process {
        id: wallpaperLoader
        command: ["sh", "-lc", "$HOME/.config/quickshell/scripts/wallpaper/wallpaper-items"]
        stdout: StdioCollector { id: wallpaperOutput }
        onExited: root.loadWallpapers(wallpaperOutput.text)
    }

    Process {
        id: calculator
        stdout: StdioCollector { id: calculatorOutput }
        onExited: root.calculation = calculatorOutput.text.trim()
    }

    ListModel { id: resultModel }

    // Fullscreen scrim: click outside to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeAndQuit()
    }

    // Main Floating Container
    Item {
        id: spotlightContainer
        width: 780
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(parent.height * 0.16)
        scale: 0.92
        opacity: 0
        y: -16

        Component.onCompleted: entrance.start()

        ParallelAnimation {
            id: entrance
            NumberAnimation { target: spotlightContainer; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: spotlightContainer; property: "scale"; to: 1; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            NumberAnimation { target: spotlightContainer; property: "y"; to: 0; duration: 280; easing.type: Easing.OutCubic }
        }

        // Top Area: Contains Search Pill + 4 Circular Mode Buttons
        Item {
            id: topBarArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 52

            // Search Capsule Pill (starts centered at x: 121, slides fluidly to x: 0 on separation)
            Rectangle {
                id: searchPill
                x: 121
                width: 538
                height: 52
                radius: 26
                clip: true
                color: Qt.rgba(colors.surface.r, colors.surface.g, colors.surface.b, 0.90)
                border.width: 1
                border.color: searchInput.activeFocus
                    ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.55)
                    : Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.25)

                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: searchInput.forceActiveFocus()
                }

                // Magnifying glass icon
                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: searchInput.activeFocus ? colors.primary : colors.muted

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                // Search Text Input
                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 12
                    anchors.right: clearButton.visible ? clearButton.left : parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: colors.foreground
                    selectionColor: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.50)
                    selectedTextColor: colors.on_primary
                    font.pixelSize: 18
                    font.weight: Font.Normal
                    focus: true
                    clip: true

                    onTextChanged: {
                        root.separateIcons()
                        if (text.startsWith(":") && root.activeMode !== "clipboard" && !clipboardLoader.running) {
                            clipboardLoader.running = true
                        }
                        if (text.startsWith("@") && root.activeMode !== "wallpaper" && !wallpaperLoader.running) {
                            wallpaperLoader.running = true
                        }
                        root.rebuild(text)
                    }

                    Keys.onEscapePressed: root.closeAndQuit()
                    Keys.onReturnPressed: root.runCurrent()
                    Keys.onEnterPressed: root.runCurrent()
                    Keys.onDownPressed: resultList.incrementCurrentIndex()
                    Keys.onUpPressed: resultList.decrementCurrentIndex()
                }

                // Placeholder Text
                Text {
                    visible: searchInput.text.length === 0
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.getPlaceholderText()
                    color: colors.muted
                    font.pixelSize: 18
                    font.weight: Font.Light
                }

                // Clear Button (✕)
                Rectangle {
                    id: clearButton
                    visible: searchInput.text.length > 0
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    radius: 11
                    color: clearMouse.containsMouse
                        ? Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.90)
                        : Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.50)

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: colors.muted
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = ""
                            searchInput.forceActiveFocus()
                        }
                    }
                }
            }

            // Fluid Separation Glow Pulse (Tahoe VFX)
            Rectangle {
                id: separationGlow
                x: searchPill.x + searchPill.width - 26
                y: 0
                width: 52
                height: 52
                radius: 26
                color: colors.primary
                opacity: 0

                ParallelAnimation {
                    id: glowAnim
                    SequentialAnimation {
                        NumberAnimation { target: separationGlow; property: "opacity"; to: 0.35; duration: 80 }
                        NumberAnimation { target: separationGlow; property: "opacity"; to: 0; duration: 320; easing.type: Easing.OutCubic }
                    }
                    NumberAnimation { target: separationGlow; property: "scale"; from: 0.6; to: 1.4; duration: 400; easing.type: Easing.OutCubic }
                }
            }

            // Redesigned macOS Tahoe Fluid Droplet Spring Animation
            ParallelAnimation {
                id: fluidSeparationAnim

                // 1. Search Capsule fluid glide with organic easing
                NumberAnimation {
                    target: searchPill
                    property: "x"
                    from: 121
                    to: 0
                    duration: 440
                    easing.type: Easing.OutCubic
                }

                // 2. Apps Droplet (starts 0ms)
                SequentialAnimation {
                    PropertyAction { target: btnApps; property: "visible"; value: true }
                    ParallelAnimation {
                        NumberAnimation { target: btnApps; property: "x"; from: 510; to: 548; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.28 }
                        NumberAnimation { target: btnApps; property: "scale"; from: 0.2; to: 1.0; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.30 }
                        NumberAnimation { target: btnApps; property: "opacity"; from: 0.0; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
                    }
                }

                // 3. Files Droplet (50ms stagger)
                SequentialAnimation {
                    PauseAnimation { duration: 50 }
                    PropertyAction { target: btnFiles; property: "visible"; value: true }
                    ParallelAnimation {
                        NumberAnimation { target: btnFiles; property: "x"; from: 530; to: 608; duration: 440; easing.type: Easing.OutBack; easing.overshoot: 1.28 }
                        NumberAnimation { target: btnFiles; property: "scale"; from: 0.2; to: 1.0; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.30 }
                        NumberAnimation { target: btnFiles; property: "opacity"; from: 0.0; to: 1.0; duration: 240; easing.type: Easing.OutCubic }
                    }
                }

                // 4. Wallpapers Droplet (100ms stagger)
                SequentialAnimation {
                    PauseAnimation { duration: 100 }
                    PropertyAction { target: btnWallpapers; property: "visible"; value: true }
                    ParallelAnimation {
                        NumberAnimation { target: btnWallpapers; property: "x"; from: 550; to: 668; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.28 }
                        NumberAnimation { target: btnWallpapers; property: "scale"; from: 0.2; to: 1.0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.30 }
                        NumberAnimation { target: btnWallpapers; property: "opacity"; from: 0.0; to: 1.0; duration: 260; easing.type: Easing.OutCubic }
                    }
                }

                // 5. Clipboard Droplet (150ms stagger)
                SequentialAnimation {
                    PauseAnimation { duration: 150 }
                    PropertyAction { target: btnClipboard; property: "visible"; value: true }
                    ParallelAnimation {
                        NumberAnimation { target: btnClipboard; property: "x"; from: 570; to: 728; duration: 480; easing.type: Easing.OutBack; easing.overshoot: 1.28 }
                        NumberAnimation { target: btnClipboard; property: "scale"; from: 0.2; to: 1.0; duration: 440; easing.type: Easing.OutBack; easing.overshoot: 1.30 }
                        NumberAnimation { target: btnClipboard; property: "opacity"; from: 0.0; to: 1.0; duration: 280; easing.type: Easing.OutCubic }
                    }
                }
            }

            // 1. Applications Button (Tahoe separated circle 0 - Vector App Store "A" Icon)
            Rectangle {
                id: btnApps
                x: 548
                y: 0
                width: 52
                height: 52
                radius: 26
                visible: false
                opacity: 0.0
                scale: 0.0
                color: root.activeMode === "apps"
                    ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.35)
                    : (appsMouse.containsMouse
                        ? Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.90)
                        : Qt.rgba(colors.surface.r, colors.surface.g, colors.surface.b, 0.90))
                border.width: 1
                border.color: root.activeMode === "apps"
                    ? colors.primary
                    : (appsMouse.containsMouse
                        ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.40)
                        : Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.25))

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Shape {
                    id: appsIconShape
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    preferredRendererType: Shape.CurveRenderer
                    layer.enabled: true
                    layer.samples: 4

                    ShapePath {
                        fillColor: root.activeMode === "apps"
                            ? colors.primary
                            : (appsMouse.containsMouse ? colors.foreground : colors.muted)
                        strokeColor: "transparent"
                        strokeWidth: 0

                        Behavior on fillColor { ColorAnimation { duration: 150 } }

                        PathSvg {
                            path: "M 10.97 4.14 L 11.49 3.21 C 11.84 2.63 12.54 2.46 13.12 2.81 C 13.7 3.1 13.88 3.85 13.53 4.43 L 8.47 13.21 L 12.13 13.21 C 13.35 13.21 13.99 14.6 13.47 15.59 L 2.72 15.59 C 2.08 15.59 1.5 15.07 1.5 14.43 C 1.5 13.73 2.08 13.21 2.72 13.21 L 5.74 13.21 L 9.58 6.53 L 8.41 4.43 C 8.07 3.85 8.24 3.1 8.82 2.81 C 9.4 2.46 10.1 2.63 10.45 3.21 L 10.97 4.14 Z M 6.38 16.81 L 5.28 18.79 C 4.93 19.37 4.23 19.54 3.65 19.19 C 3.07 18.9 2.89 18.15 3.19 17.62 L 4.06 16.11 C 4.99 15.82 5.8 16.06 6.38 16.81 Z M 16.2 13.21 L 19.28 13.21 C 19.98 13.21 20.5 13.73 20.5 14.43 C 20.5 15.07 19.98 15.59 19.28 15.59 L 17.59 15.59 L 18.76 17.62 C 19.05 18.15 18.87 18.9 18.29 19.19 C 17.71 19.54 17.01 19.37 16.67 18.79 C 14.75 15.42 13.3 12.86 12.31 11.17 C 11.32 9.49 12.02 7.75 12.71 7.17 C 13.47 8.5 14.63 10.54 16.2 13.21 Z"
                        }
                    }
                }

                MouseArea {
                    id: appsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMode("apps")
                }
            }

            // 2. Files Button (Tahoe separated circle 1)
            Rectangle {
                id: btnFiles
                x: 608
                y: 0
                width: 52
                height: 52
                radius: 26
                visible: false
                opacity: 0.0
                scale: 0.0
                color: root.activeMode === "files"
                    ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.35)
                    : (filesMouse.containsMouse
                        ? Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.90)
                        : Qt.rgba(colors.surface.r, colors.surface.g, colors.surface.b, 0.90))
                border.width: 1
                border.color: root.activeMode === "files"
                    ? colors.primary
                    : (filesMouse.containsMouse
                        ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.40)
                        : Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.25))

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰉋" // Folder icon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22
                    color: root.activeMode === "files"
                        ? colors.primary
                        : (filesMouse.containsMouse ? colors.foreground : colors.muted)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: filesMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMode("files")
                }
            }

            // 3. Wallpapers Button (Tahoe separated circle 2 - Stacked Layer Diamonds)
            Rectangle {
                id: btnWallpapers
                x: 668
                y: 0
                width: 52
                height: 52
                radius: 26
                visible: false
                opacity: 0.0
                scale: 0.0
                color: root.activeMode === "wallpaper"
                    ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.35)
                    : (wpMouse.containsMouse
                        ? Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.90)
                        : Qt.rgba(colors.surface.r, colors.surface.g, colors.surface.b, 0.90))
                border.width: 1
                border.color: root.activeMode === "wallpaper"
                    ? colors.primary
                    : (wpMouse.containsMouse
                        ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.40)
                        : Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.25))

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰧾" // md-layers_outline (Two stacked layer diamonds)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22
                    color: root.activeMode === "wallpaper"
                        ? colors.primary
                        : (wpMouse.containsMouse ? colors.foreground : colors.muted)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: wpMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMode("wallpaper")
                }
            }

            // 4. Clipboard Button (Tahoe separated circle 3 - Overlapping Documents Outline)
            Rectangle {
                id: btnClipboard
                x: 728
                y: 0
                width: 52
                height: 52
                radius: 26
                visible: false
                opacity: 0.0
                scale: 0.0
                color: root.activeMode === "clipboard"
                    ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.35)
                    : (cbMouse.containsMouse
                        ? Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.90)
                        : Qt.rgba(colors.surface.r, colors.surface.g, colors.surface.b, 0.90))
                border.width: 1
                border.color: root.activeMode === "clipboard"
                    ? colors.primary
                    : (cbMouse.containsMouse
                        ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.40)
                        : Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.25))

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰆏" // md-content_copy (Overlapping documents with folded corner)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22
                    color: root.activeMode === "clipboard"
                        ? colors.primary
                        : (cbMouse.containsMouse ? colors.foreground : colors.muted)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: cbMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMode("clipboard")
                }
            }
        }

        // Results Card (Smoothly extends underneath the search pill & action circles)
        Rectangle {
            id: resultsCard
            visible: root.resultsVisible
            opacity: root.resultsVisible ? 1.0 : 0.0
            anchors.top: topBarArea.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            height: {
                if (!root.resultsVisible) return 0
                if (root.isDualPane) return 490
                if (resultModel.count > 0) return Math.min(480, 16 + resultModel.count * 52)
                if (root.calculation.length > 0) return 120
                return 70
            }
            radius: 18
            color: Qt.rgba(colors.surface.r, colors.surface.g, colors.surface.b, 0.94)
            border.width: 1
            border.color: Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.25)
            clip: true

            Behavior on height {
                NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
            }
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            // MouseArea to prevent dismiss when clicking inside results card
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            // Calculation View
            Item {
                id: calculationPane
                visible: root.calculation.length > 0 && resultModel.count === 0
                anchors.fill: parent

                Row {
                    anchors.centerIn: parent
                    spacing: 16

                    Text {
                        text: "="
                        color: colors.primary
                        font.pixelSize: 34
                        font.weight: Font.Light
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.calculation
                        color: colors.foreground
                        font.pixelSize: 36
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Empty state placeholder
            Item {
                visible: root.resultsVisible && resultModel.count === 0 && root.calculation.length === 0
                anchors.fill: parent

                Text {
                    anchors.centerIn: parent
                    text: root.activeMode === "wallpaper"
                        ? (wallpaperLoader.running ? "Loading wallpapers..." : "No wallpapers found")
                        : (root.activeMode === "clipboard"
                            ? (clipboardLoader.running ? "Loading clipboard history..." : "Clipboard history is empty")
                            : "No results found")
                    color: colors.muted
                    font.pixelSize: 14
                }
            }

            // Main Content Area
            Item {
                id: contentArea
                visible: root.resultsVisible && resultModel.count > 0
                anchors.fill: parent
                anchors.margins: 8

                // Results List
                ListView {
                    id: resultList
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: root.isDualPane ? 320 : parent.width
                    spacing: 3
                    clip: true
                    model: resultModel
                    currentIndex: 0
                    boundsBehavior: Flickable.StopAtBounds

                    Behavior on width {
                        NumberAnimation { duration: 220; easing.type: Easing.OutQuint }
                    }

                    delegate: Rectangle {
                        id: itemDelegate
                        width: resultList.width - 6
                        height: 48
                        radius: 10
                        color: ListView.isCurrentItem
                            ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.28)
                            : (itemMouse.containsMouse ? Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.40) : "transparent")

                        border.width: ListView.isCurrentItem ? 1 : 0
                        border.color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.50)

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }

                        // Leading Icon Badge
                        Rectangle {
                            id: itemBadge
                            width: 32
                            height: 32
                            radius: 8
                            clip: true
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: ListView.isCurrentItem
                                ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.40)
                                : Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.55)

                            Image {
                                id: appIcon
                                anchors.fill: parent
                                anchors.margins: (model.kind === "wallpaper" || model.isImage) ? 0 : 4
                                fillMode: (model.kind === "wallpaper" || model.isImage) ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                asynchronous: true
                                cache: true
                                sourceSize.width: 64
                                sourceSize.height: 64
                                visible: status === Image.Ready && source.toString().length > 0
                                source: {
                                    if ((model.kind === "wallpaper" || model.isImage) && model.preview) {
                                        return model.preview.startsWith("file://") ? model.preview : ("file://" + model.preview)
                                    }
                                    const iconName = model.icon || ""
                                    if (!iconName) return ""
                                    if (iconName.startsWith("/") || iconName.startsWith("file://")) {
                                        return iconName.startsWith("file://") ? iconName : ("file://" + iconName)
                                    }
                                    const cleanName = iconName.replace(/\.(png|svg|xpm)$/i, "")
                                    return "image://icon/" + cleanName
                                }
                            }

                            Text {
                                visible: !appIcon.visible
                                anchors.centerIn: parent
                                text: model.kind === "run" ? "⚡" : (model.kind === "app" ? "󰀻" : (model.kind === "file" ? "󰉋" : (model.kind === "command" ? ">_" : (model.kind === "wallpaper" ? "󰧾" : (model.isImage ? "🖼" : "󰆏")))))
                                font.family: "JetBrainsMono Nerd Font"
                                color: colors.foreground
                                font.pixelSize: 15
                            }
                        }

                        // Title & Subtitle Column
                        Column {
                            anchors.left: itemBadge.right
                            anchors.leftMargin: 12
                            anchors.right: trailingHint.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                text: model.kind === "wallpaper" ? model.name : (model.isImage ? "Image Screenshot" : model.name)
                                color: colors.foreground
                                font.pixelSize: 13
                                font.weight: ListView.isCurrentItem ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: model.isImage ? model.subtitle : (model.subtitle || model.kind)
                                color: ListView.isCurrentItem ? colors.foreground : colors.muted
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        // Trailing Action Pill or Chevron
                        Item {
                            id: trailingHint
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.isDualPane ? 16 : actionPill.implicitWidth
                            height: 24

                            Text {
                                visible: root.isDualPane && ListView.isCurrentItem
                                anchors.centerIn: parent
                                text: "›"
                                color: colors.primary
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }

                            Rectangle {
                                id: actionPill
                                visible: !root.isDualPane && ListView.isCurrentItem
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 22
                                width: actionPillText.implicitWidth + 14
                                radius: 6
                                color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.35)
                                border.width: 1
                                border.color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.55)

                                Text {
                                    id: actionPillText
                                    anchors.centerIn: parent
                                    text: model.kind === "run" ? "↩ Run" : (model.kind === "app" ? "↩ Open" : (model.kind === "file" ? "↩ Open" : (model.kind === "command" ? "↩ Run" : (model.kind === "wallpaper" ? "↩ Apply" : "↩ Select"))))
                                    color: colors.foreground
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                resultList.currentIndex = index
                                root.runCurrent()
                            }
                        }
                    }
                }

                // Vertical Divider in dual-pane mode
                Rectangle {
                    id: verticalDivider
                    visible: root.isDualPane
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: resultList.right
                    anchors.leftMargin: 6
                    width: 1
                    color: Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.20)
                }

                // Right Column Preview Pane (Dual Pane)
                Item {
                    id: previewPane
                    visible: root.isDualPane
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: verticalDivider.right
                    anchors.right: parent.right
                    anchors.margins: 12

                    // Empty state
                    Text {
                        visible: root.currentItem === null
                        anchors.centerIn: parent
                        text: root.isWallpaperMode
                            ? (wallpaperLoader.running ? "Loading wallpapers..." : "No wallpapers found")
                            : (clipboardLoader.running ? "Loading clipboard..." : "No clipboard items")
                        color: colors.muted
                        font.pixelSize: 13
                    }

                    // Wallpaper Preview
                    Item {
                        id: wallpaperPreviewSection
                        visible: root.isWallpaperMode && root.currentItem !== null
                        anchors.fill: parent

                        Column {
                            anchors.fill: parent
                            spacing: 12

                            Rectangle {
                                width: parent.width
                                height: parent.height - 70
                                radius: 12
                                color: Qt.rgba(colors.background.r, colors.background.g, colors.background.b, 0.60)
                                border.width: 1
                                border.color: Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.25)
                                clip: true

                                Image {
                                    id: wallpaperFullImg
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: (root.currentItem && root.currentItem.preview) ? root.currentItem.preview : ""
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    asynchronous: true
                                    cache: true
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: 8

                                Rectangle {
                                    height: 22
                                    width: wpPillText.implicitWidth + 12
                                    radius: 5
                                    color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.25)
                                    border.width: 1
                                    border.color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.45)

                                    Text {
                                        id: wpPillText
                                        anchors.centerIn: parent
                                        text: "Wallpaper"
                                        color: colors.primary
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Text {
                                    text: (root.currentItem && root.currentItem.name) ? root.currentItem.name : ""
                                    color: colors.foreground
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                text: "Press ↩ Return to apply wallpaper & theme"
                                color: colors.muted
                                font.pixelSize: 11
                            }
                        }
                    }

                    // Clipboard Image Preview
                    Item {
                        id: imagePreviewSection
                        visible: root.isClipboardMode && root.currentItem !== null && root.currentItem.isImage
                        anchors.fill: parent

                        Column {
                            anchors.fill: parent
                            spacing: 10

                            Rectangle {
                                width: parent.width
                                height: parent.height - 70
                                radius: 10
                                color: Qt.rgba(colors.background.r, colors.background.g, colors.background.b, 0.55)
                                border.width: 1
                                border.color: Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.25)
                                clip: true

                                Image {
                                    id: fullImagePreview
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    source: (root.currentItem && root.currentItem.preview) ? root.currentItem.preview : ""
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                    cache: false
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: 8

                                Rectangle {
                                    height: 22
                                    width: mimeText.implicitWidth + 12
                                    radius: 5
                                    color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.25)
                                    border.width: 1
                                    border.color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.45)

                                    Text {
                                        id: mimeText
                                        anchors.centerIn: parent
                                        text: (root.currentItem && root.currentItem.mime) ? root.currentItem.mime : "image/png"
                                        color: colors.primary
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Text {
                                    text: (root.currentItem && root.currentItem.label) ? root.currentItem.label.replace(/^\[\[\s*binary data\s*/i, "").replace(/\s*\]\]$/, "") : ""
                                    color: colors.muted
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                text: "Press ↩ Return to paste image"
                                color: colors.muted
                                font.pixelSize: 11
                            }
                        }
                    }

                    // Clipboard Text Preview
                    Item {
                        id: textPreviewSection
                        visible: root.isClipboardMode && root.currentItem !== null && !root.currentItem.isImage
                        anchors.fill: parent

                        Column {
                            anchors.fill: parent
                            spacing: 12

                            Text {
                                text: "Clipboard Text Entry"
                                color: colors.muted
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            Rectangle {
                                width: parent.width
                                height: parent.height - 60
                                radius: 10
                                color: Qt.rgba(colors.background.r, colors.background.g, colors.background.b, 0.55)
                                border.width: 1
                                border.color: Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.25)
                                clip: true

                                Flickable {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    contentWidth: width
                                    contentHeight: textContent.implicitHeight
                                    clip: true

                                    Text {
                                        id: textContent
                                        width: parent.width
                                        text: root.currentItem ? root.currentItem.name : ""
                                        color: colors.foreground
                                        font.pixelSize: 13
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                    }
                                }
                            }

                            Text {
                                text: "Press ↩ Return to restore to clipboard"
                                color: colors.muted
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        const initialQuery = Quickshell.env("LAUNCHER_INITIAL_QUERY")
        if (initialQuery && initialQuery.length > 0) {
            root.iconsSeparated = true
            searchPill.x = 0
            btnApps.visible = true; btnApps.x = 548; btnApps.opacity = 1.0; btnApps.scale = 1.0
            btnFiles.visible = true; btnFiles.x = 608; btnFiles.opacity = 1.0; btnFiles.scale = 1.0
            btnWallpapers.visible = true; btnWallpapers.x = 668; btnWallpapers.opacity = 1.0; btnWallpapers.scale = 1.0
            btnClipboard.visible = true; btnClipboard.x = 728; btnClipboard.opacity = 1.0; btnClipboard.scale = 1.0
            searchInput.text = initialQuery
            searchInput.cursorPosition = initialQuery.length
            if (initialQuery.startsWith(":")) {
                activeMode = "clipboard"
                clipboardLoader.running = true
            } else if (initialQuery.startsWith("@")) {
                activeMode = "wallpaper"
                wallpaperLoader.running = true
            }
        }
        searchInput.forceActiveFocus()
    }
}
