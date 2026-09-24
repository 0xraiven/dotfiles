import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    visible: true
    implicitWidth: 560
    implicitHeight: 720
    color: "transparent"

    anchors {
        top: true
        right: true
    }

    margins {
        top: 64
        right: 24
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var entries: []

    Colors { id: colors }

    function loadEntries(raw) {
        try {
            entries = JSON.parse(raw)
            entryModel.clear()
            for (let index = 0; index < entries.length; index++) {
                entryModel.append(entries[index])
            }
        } catch (error) {
            console.log("clipboard history parse failed", error)
        }
    }

    function restore(entryId) {
        Quickshell.execDetached(["sh", "-lc", "$HOME/.config/quickshell/r41n/scripts/.local/bin/clipboard-restore " + entryId])
        Qt.quit()
    }

    Process {
        id: loader
        command: ["sh", "-lc", "$HOME/.config/quickshell/r41n/scripts/.local/bin/clipboard-items"]
        running: true
        stdout: StdioCollector {
            id: output
        }
        onExited: root.loadEntries(output.text)
    }

    ListModel {
        id: entryModel
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(colors.surface.r, colors.surface.g, colors.surface.b, 0.94)
        radius: 12
        border.width: 1
        border.color: colors.outline

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            Row {
                width: parent.width
                spacing: 12

                Column {
                    width: parent.width - 52
                    spacing: 3

                    Text {
                        text: "Clipboard"
                        color: "#e5e7eb"
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Select an item to copy it back"
                        color: "#9aa1ad"
                        font.pixelSize: 12
                    }
                }

                Text {
                    text: "ESC"
                    color: "#9aa1ad"
                    font.pixelSize: 11
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#2b2f38"
            }

            ListView {
                id: historyList
                width: parent.width
                height: parent.height - 82
                clip: true
                spacing: 8
                model: entryModel
                focus: true
                Keys.onEscapePressed: Qt.quit()

                delegate: Rectangle {
                    width: historyList.width
                    height: model.isImage ? 234 : 68
                    radius: 8
                    color: delegateMouse.containsMouse ? "#252a34" : "#1d2027"
                    border.width: 1
                    border.color: delegateMouse.containsMouse ? "#8ab4f8" : "#2c313b"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Row {
                            width: parent.width
                            spacing: 10

                            Text {
                                text: model.isImage ? "BINARY DATA" : "TEXT"
                                color: model.isImage ? "#b8c9ff" : "#aeb6c3"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: model.mime
                                color: "#777f8d"
                                font.pixelSize: 10
                            }
                        }

                        Text {
                            width: parent.width
                            text: model.isImage ? model.label : model.label
                            color: "#d8dce4"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            maximumLineCount: 2
                        }

                        Image {
                            visible: model.isImage && model.preview !== ""
                            width: parent.width
                            height: 156
                            source: model.preview
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            cache: false
                        }
                    }

                    MouseArea {
                        id: delegateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.restore(model.id)
                    }
                }
            }
        }
    }

    Component.onCompleted: historyList.forceActiveFocus()
}
