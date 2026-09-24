import QtQuick
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
    property string activeMode: "search"
    property string calculation: ""
    property bool isClipboardMode: activeMode === "clipboard"
    property bool isWallpaperMode: activeMode === "wallpaper"
    property bool isDualPane: isClipboardMode || isWallpaperMode
    property bool resultsVisible: searchInput.text.trim().length > 0 || calculation.length > 0 || isDualPane
    property var currentItem: (resultList.currentIndex >= 0 && resultList.currentIndex < resultModel.count) ? resultModel.get(resultList.currentIndex) : null

    Colors { id: colors }

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
        const normalized = (prefix === ":" || prefix === ">" || prefix === "@" ? trimmed.slice(1) : trimmed).toLowerCase()
        const source = prefix === ":" ? clipboardResults : (prefix === "@" ? wallpaperResults : allResults)
        activeMode = prefix === ":" ? "clipboard" : (prefix === "@" ? "wallpaper" : (prefix === ">" ? "commands" : "search"))
        resultModel.clear()

        if (prefix !== ":" && prefix !== ">" && prefix !== "@" && trimmed.length > 0) {
            resultModel.append({ id: "__run__", name: trimmed, subtitle: "Run shell command", kind: "run", isImage: false, preview: "" })
        }

        for (let index = 0; index < source.length; index++) {
            const item = source[index]
            const haystack = ((item.name || "") + " " + (item.subtitle || "") + " " + (item.label || "")).toLowerCase()
            if (normalized === "" || haystack.indexOf(normalized) !== -1) {
                if (prefix !== ">" || item.kind === "command") {
                    resultModel.append({
                        id: String(item.id || item.path || ""),
                        name: String(item.name || ""),
                        subtitle: String(item.subtitle || item.label || (prefix === "@" ? ("Wallpaper • " + (item.filename || "")) : "")),
                        kind: String(item.kind || (prefix === "@" ? "wallpaper" : "app")),
                        mime: String(item.mime || (prefix === "@" ? "image/jpeg" : "")),
                        label: String(item.label || item.name || ""),
                        isImage: Boolean(item.isImage || prefix === "@"),
                        preview: String(item.preview || item.path || "")
                    })
                }
            }
            if (resultModel.count >= 50) break
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

    function runCurrent() {
        if (root.calculation.length > 0 && (resultList.currentIndex < 0 || searchInput.text.trim() === root.calculation)) {
            Quickshell.execDetached(["sh", "-lc", "printf '%s' '" + root.calculation.replace(/'/g, "'\\''") + "' | wl-copy"])
            Qt.quit()
            return
        }

        if (resultList.currentIndex < 0 || resultList.currentIndex >= resultModel.count) return
        const item = resultModel.get(resultList.currentIndex)

        if (item.id === "@" || item.kind === "wallpaper-picker" || item.name === "Wallpaper Picker") {
            searchInput.text = "@"
            searchInput.cursorPosition = 1
            if (!wallpaperLoader.running) wallpaperLoader.running = true
            return
        }

        if (item.kind === "run") Quickshell.execDetached(["sh", "-lc", item.name])
        else if (item.kind === "app") Quickshell.execDetached(["gtk-launch", item.id])
        else if (item.kind === "file") Quickshell.execDetached(["xdg-open", item.id])
        else if (item.kind === "command") Quickshell.execDetached(["sh", "-lc", item.id])
        else if (item.kind === "clipboard") Quickshell.execDetached(["sh", "-lc", "$HOME/.config/quickshell/scripts/clipboard/clipboard-restore " + item.id])
        else if (item.kind === "wallpaper") Quickshell.execDetached(["sh", "-lc", "$HOME/.config/quickshell/scripts/wallpaper/apply-wallpaper '" + item.id + "'"])
        Qt.quit()
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
        onClicked: Qt.quit()
    }

    // Spotlight Floating Card
    Rectangle {
        id: spotlight
        width: root.isDualPane ? 780 : 660
        height: {
            if (!root.resultsVisible) return 66
            if (root.isDualPane) return 490
            if (resultModel.count > 0) return Math.min(480, 74 + resultModel.count * 50)
            if (root.calculation.length > 0) return 140
            return 66
        }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(parent.height * 0.18)
        radius: 20
        color: Qt.rgba(colors.surface.r, colors.surface.g, colors.surface.b, 0.92)
        border.width: 1
        border.color: searchInput.activeFocus
            ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.45)
            : Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.28)
        clip: true
        scale: 0.96
        opacity: 0

        // Prevent clicks on spotlight container from closing the window
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // Inner top subtle glass reflection
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(colors.foreground.r, colors.foreground.g, colors.foreground.b, 0.10)
        }

        Behavior on width {
            NumberAnimation { duration: 220; easing.type: Easing.OutQuint }
        }

        Behavior on height {
            NumberAnimation { duration: 240; easing.type: Easing.OutQuint }
        }

        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }

        Component.onCompleted: entrance.start()

        ParallelAnimation {
            id: entrance
            NumberAnimation { target: spotlight; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: spotlight; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutCubic }
        }

        // Top Search Bar
        Item {
            id: searchBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 64

            // Apple Spotlight magnifying glass
            Text {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: "⌕"
                color: searchInput.activeFocus ? colors.primary : colors.muted
                font.pixelSize: 26

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            // Mode indicator pill
            Rectangle {
                id: modeBadge
                visible: root.activeMode !== "search"
                anchors.left: searchIcon.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                width: modeText.implicitWidth + 16
                radius: 6
                color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.22)
                border.width: 1
                border.color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.45)

                Text {
                    id: modeText
                    anchors.centerIn: parent
                    text: root.activeMode === "clipboard" ? "Clipboard" : (root.activeMode === "wallpaper" ? "Wallpaper" : "Controls")
                    color: colors.primary
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            // Search Text Input
            TextInput {
                id: searchInput
                anchors.left: modeBadge.visible ? modeBadge.right : searchIcon.right
                anchors.leftMargin: 12
                anchors.right: clearButton.visible ? clearButton.left : parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: colors.foreground
                selectionColor: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.50)
                selectedTextColor: colors.on_primary
                font.pixelSize: 20
                font.weight: Font.Normal
                focus: true
                clip: true

                onTextChanged: {
                    if (text.startsWith(":") && root.activeMode !== "clipboard" && !clipboardLoader.running) {
                        clipboardLoader.running = true
                    }
                    if (text.startsWith("@") && root.activeMode !== "wallpaper" && !wallpaperLoader.running) {
                        wallpaperLoader.running = true
                    }
                    root.rebuild(text)
                }

                Keys.onEscapePressed: Qt.quit()
                Keys.onReturnPressed: root.runCurrent()
                Keys.onEnterPressed: root.runCurrent()
                Keys.onDownPressed: resultList.incrementCurrentIndex()
                Keys.onUpPressed: resultList.decrementCurrentIndex()
            }

            // Placeholder Text
            Text {
                visible: searchInput.text.length === 0
                anchors.left: modeBadge.visible ? modeBadge.right : searchIcon.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.activeMode === "clipboard"
                    ? "Search clipboard history..."
                    : (root.activeMode === "wallpaper"
                        ? "Search wallpapers..."
                        : (root.activeMode === "commands"
                            ? "Search controls & commands..."
                            : "Spotlight Search"))
                color: colors.muted
                font.pixelSize: 20
                font.weight: Font.Normal
            }

            // Clear Button
            Rectangle {
                id: clearButton
                visible: searchInput.text.length > 0
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 10
                color: clearMouse.containsMouse
                    ? Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.80)
                    : Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.40)

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: colors.muted
                    font.pixelSize: 10
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        searchInput.text = ""
                        searchInput.forceActiveFocus()
                    }
                }
            }
        }

        // Horizontal Divider below Search Bar
        Rectangle {
            id: horizontalDivider
            visible: root.resultsVisible
            anchors.top: searchBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.20)
        }

        // Calculation Bar (if calculation exists and no results)
        Item {
            id: calculationPane
            visible: root.calculation.length > 0 && resultModel.count === 0
            anchors.top: horizontalDivider.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

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

        // Main Content Area
        Item {
            id: contentArea
            visible: root.resultsVisible && resultModel.count > 0
            anchors.top: horizontalDivider.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            // Results List (Takes 310px in clipboard mode; takes full width in search mode)
            ListView {
                id: resultList
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                anchors.leftMargin: 8
                width: root.isDualPane ? 310 : (parent.width - 16)
                spacing: 2
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
                    radius: 8
                    color: ListView.isCurrentItem
                        ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.30)
                        : (itemMouse.containsMouse ? Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.35) : "transparent")

                    border.width: ListView.isCurrentItem ? 1 : 0
                    border.color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.50)

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }

                    // Leading Category Icon Badge
                    Rectangle {
                        id: itemBadge
                        width: 30
                        height: 30
                        radius: 7
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: ListView.isCurrentItem
                            ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.40)
                            : Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.55)

                        Text {
                            anchors.centerIn: parent
                            text: model.kind === "run" ? "⚡" : (model.kind === "app" ? "◻" : (model.kind === "file" ? "📄" : (model.kind === "command" ? ">_" : (model.kind === "wallpaper" ? "🖼" : (model.isImage ? "🖼" : "📋")))))
                            color: colors.foreground
                            font.pixelSize: 13
                        }
                    }

                    // Title & Subtitle Column
                    Column {
                        anchors.left: itemBadge.right
                        anchors.leftMargin: 10
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

                        // In dual-pane mode: show subtle chevron
                        Text {
                            visible: root.isDualPane && ListView.isCurrentItem
                            anchors.centerIn: parent
                            text: "›"
                            color: colors.primary
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }

                        // In search mode: show sleek action pill when selected
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

            // Vertical Divider (ONLY in dual-pane mode)
            Rectangle {
                id: verticalDivider
                visible: root.isDualPane
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: resultList.right
                anchors.leftMargin: 4
                width: 1
                color: Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.20)
            }

            // Right Column: Preview Pane (in dual-pane mode: clipboard or wallpaper)
            Item {
                id: previewPane
                visible: root.isDualPane
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: verticalDivider.right
                anchors.right: parent.right
                anchors.margins: 14

                // Empty state or loading placeholder
                Text {
                    visible: root.currentItem === null
                    anchors.centerIn: parent
                    text: root.isWallpaperMode
                        ? (wallpaperLoader.running ? "Loading wallpapers..." : "No wallpapers found")
                        : (clipboardLoader.running ? "Loading clipboard..." : "No clipboard items")
                    color: colors.muted
                    font.pixelSize: 13
                }

                // Wallpaper Full Preview Section
                Item {
                    id: wallpaperPreviewSection
                    visible: root.isWallpaperMode && root.currentItem !== null
                    anchors.fill: parent

                    Column {
                        anchors.fill: parent
                        spacing: 12

                        // Wallpaper preview image frame
                        Rectangle {
                            width: parent.width
                            height: parent.height - 72
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

                        // Wallpaper info row & Action hint
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

                // Clipboard Image Preview (Full, unclipped viewport)
                Item {
                    id: imagePreviewSection
                    visible: root.isClipboardMode && root.currentItem !== null && root.currentItem.isImage
                    anchors.fill: parent

                    Column {
                        anchors.fill: parent
                        spacing: 10

                        // Image viewport frame
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

                        // Image metadata & Action Prompt
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

                        // Return Action hint
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

    Component.onCompleted: {
        const initialQuery = Quickshell.env("LAUNCHER_INITIAL_QUERY")
        if (initialQuery && initialQuery.length > 0) {
            searchInput.text = initialQuery
            searchInput.cursorPosition = initialQuery.length
            if (initialQuery.startsWith(":")) {
                clipboardLoader.running = true
            } else if (initialQuery.startsWith("@")) {
                wallpaperLoader.running = true
            }
        }
        searchInput.forceActiveFocus()
    }
}
