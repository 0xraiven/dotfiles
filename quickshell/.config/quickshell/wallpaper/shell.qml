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

    Colors { id: colors }

    ListModel { id: wallpaperModel }

    function loadWallpapers(raw) {
        if (!raw || raw.trim().length === 0) return
        try {
            wallpaperModel.clear()
            const items = JSON.parse(raw)
            for (let i = 0; i < items.length; i++) {
                wallpaperModel.append(items[i])
            }
            if (wallpaperModel.count > 0) {
                wallpaperGrid.currentIndex = 0
            }
        } catch (e) {
            console.log("failed to parse wallpapers", e)
        }
    }

    function selectCurrent() {
        if (wallpaperGrid.currentIndex >= 0 && wallpaperGrid.currentIndex < wallpaperModel.count) {
            const item = wallpaperModel.get(wallpaperGrid.currentIndex)
            Quickshell.execDetached(["sh", "-lc", "$HOME/.config/quickshell/scripts/wallpaper/apply-wallpaper '" + item.path + "'"])
            Qt.quit()
        }
    }

    Process {
        id: wpLoader
        command: ["sh", "-lc", "$HOME/.config/quickshell/scripts/wallpaper/wallpaper-items"]
        running: true
        stdout: StdioCollector { id: wpOutput }
        onExited: root.loadWallpapers(wpOutput.text)
    }

    // Fullscreen scrim: click outside to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }

    // Center Wallpaper Picker Card
    Rectangle {
        id: pickerCard
        width: 860
        height: 560
        anchors.centerIn: parent
        radius: 20
        color: Qt.rgba(colors.surface.r, colors.surface.g, colors.surface.b, 0.94)
        border.width: 1
        border.color: Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.35)
        clip: true
        scale: 0.96
        opacity: 0

        // Prevent clicks on card from closing
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // Inner subtle reflection
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(colors.foreground.r, colors.foreground.g, colors.foreground.b, 0.12)
        }

        Component.onCompleted: cardEntrance.start()

        ParallelAnimation {
            id: cardEntrance
            NumberAnimation { target: pickerCard; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: pickerCard; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutCubic }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 16

            // Header Row
            Row {
                width: parent.width
                spacing: 14

                Rectangle {
                    width: 38
                    height: 38
                    radius: 10
                    color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.18)
                    border.width: 1
                    border.color: Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.35)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "🖼"
                        font.pixelSize: 18
                    }
                }

                Column {
                    width: parent.width - 150
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        text: "Wallpaper Gallery"
                        color: colors.foreground
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Select a wallpaper to update desktop theme & colors"
                        color: colors.muted
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 24
                    width: escText.implicitWidth + 14
                    radius: 6
                    color: Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.50)
                    border.width: 1
                    border.color: Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.25)

                    Text {
                        id: escText
                        anchors.centerIn: parent
                        text: "ESC to close"
                        color: colors.muted
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }
            }

            // Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.18)
            }

            // Wallpaper Grid
            GridView {
                id: wallpaperGrid
                width: parent.width
                height: parent.height - 80
                cellWidth: Math.floor(width / 3)
                cellHeight: 200
                clip: true
                model: wallpaperModel
                focus: true

                Keys.onEscapePressed: Qt.quit()
                Keys.onReturnPressed: root.selectCurrent()
                Keys.onEnterPressed: root.selectCurrent()

                Keys.onLeftPressed: {
                    if (currentIndex > 0) currentIndex--
                }
                Keys.onRightPressed: {
                    if (currentIndex < count - 1) currentIndex++
                }
                Keys.onUpPressed: {
                    if (currentIndex >= 3) currentIndex -= 3
                }
                Keys.onDownPressed: {
                    if (currentIndex + 3 < count) currentIndex += 3
                }

                delegate: Item {
                    width: wallpaperGrid.cellWidth
                    height: wallpaperGrid.cellHeight

                    Rectangle {
                        id: cardInner
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: 12
                        color: Qt.rgba(colors.background.r, colors.background.g, colors.background.b, 0.60)
                        clip: true
                        border.width: GridView.isCurrentItem ? 2 : 1
                        border.color: GridView.isCurrentItem
                            ? colors.primary
                            : (cardMouse.containsMouse ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.40) : Qt.rgba(colors.outline.r, colors.outline.g, colors.outline.b, 0.22))

                        Behavior on border.color {
                            ColorAnimation { duration: 120 }
                        }

                        // Thumbnail image
                        Image {
                            anchors.fill: parent
                            source: model.path
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            cache: true
                        }

                        // Bottom gradient scrim for title
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 44
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.85) }
                            }
                        }

                        // Label
                        Row {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 10
                            spacing: 6

                            Text {
                                text: model.name
                                color: "#ffffff"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                width: parent.width - 24
                            }

                            Text {
                                visible: GridView.isCurrentItem
                                text: "✓"
                                color: colors.primary
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                wallpaperGrid.currentIndex = index
                                root.selectCurrent()
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: wallpaperGrid.forceActiveFocus()
}
