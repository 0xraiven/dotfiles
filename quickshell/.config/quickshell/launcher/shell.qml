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

    margins.top: 46

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var allResults: []
    property var clipboardResults: []
    property string activeMode: "search"
    property string calculation: ""
    property bool resultsVisible: searchInput.text.trim().length > 0

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

    function rebuild(query) {
        const trimmed = query.trim()
        const prefix = trimmed.length > 0 ? trimmed.charAt(0) : ""
        const normalized = (prefix === ":" || prefix === ">" ? trimmed.slice(1) : trimmed).toLowerCase()
        const source = prefix === ":" ? clipboardResults : allResults
        activeMode = prefix === ":" ? "clipboard" : (prefix === ">" ? "commands" : "search")
        resultModel.clear()

        if (prefix !== ":" && prefix !== ">" && trimmed.length > 0) {
            resultModel.append({ id: "__run__", name: trimmed, subtitle: "Run command", kind: "run" })
        }

        for (let index = 0; index < source.length; index++) {
            const item = source[index]
            const haystack = (item.name + " " + (item.subtitle || "") + " " + (item.label || "")).toLowerCase()
            if (normalized === "" || haystack.indexOf(normalized) !== -1) {
                if (prefix !== ">" || item.kind === "command") resultModel.append(item)
            }
            if (resultModel.count >= 60) break
        }
        resultList.currentIndex = resultModel.count > 0 ? 0 : -1
        updateCalculation(trimmed)
    }

    function updateCalculation(query) {
        const expression = query.replace(/^[:>]/, "").trim()
        if (/^[0-9+*/%().,\- ]+$/.test(expression) && /[0-9]/.test(expression)) {
            calculator.command = ["qalc", "-t", expression]
            calculator.running = true
        } else {
            calculation = ""
        }
    }

    function runCurrent() {
        if (resultList.currentIndex < 0 || resultList.currentIndex >= resultModel.count) return
        const item = resultModel.get(resultList.currentIndex)
        if (item.kind === "run") Quickshell.execDetached(["sh", "-lc", item.name])
        else if (item.kind === "app") Quickshell.execDetached(["gtk-launch", item.id])
        else if (item.kind === "file") Quickshell.execDetached(["xdg-open", item.id])
        else if (item.kind === "command") Quickshell.execDetached(["sh", "-lc", item.id])
        else if (item.kind === "clipboard") Quickshell.execDetached(["sh", "-lc", "$HOME/.config/quickshell/r41n/scripts/.local/bin/clipboard-restore " + item.id])
        Qt.quit()
    }

    Process {
        id: loader
        command: ["sh", "-lc", "$HOME/.config/quickshell/r41n/scripts/.local/bin/spotlight-items"]
        running: true
        stdout: StdioCollector { id: output }
        onExited: root.loadResults(output.text)
    }

    Process {
        id: clipboardLoader
        command: ["sh", "-lc", "$HOME/.config/quickshell/r41n/scripts/.local/bin/clipboard-items"]
        stdout: StdioCollector { id: clipboardOutput }
        onExited: root.loadClipboard(clipboardOutput.text)
    }

    Process {
        id: calculator
        stdout: StdioCollector { id: calculatorOutput }
        onExited: root.calculation = calculatorOutput.text.trim()
    }

    ListModel { id: resultModel }

    Rectangle {
        anchors.fill: parent
        color: "#3d050609"
    }

    Rectangle {
        id: spotlight
        width: 720
        height: root.resultsVisible ? Math.min(520, 88 + Math.max(1, resultModel.count) * 51 + (root.calculation.length > 0 ? 40 : 0)) : 72
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        radius: 19
        color: Qt.rgba(colors.surface.r, colors.surface.g, colors.surface.b, 0.94)
        border.width: 1
        border.color: searchInput.activeFocus ? colors.primary : colors.outline
        scale: 0.97
        opacity: 0

        Behavior on height {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Component.onCompleted: entrance.start()

        ParallelAnimation {
            id: entrance
            NumberAnimation { target: spotlight; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { target: spotlight; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: searchBar
            x: 7
            y: 7
            width: parent.width - 14
            height: 58
            radius: 14
            color: Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.42)
            border.width: 1
            border.color: searchInput.activeFocus ? "#9aa9bccc" : "#43526070"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "⌕"
                color: colors.foreground
                font.pixelSize: 26
            }

            TextInput {
                id: searchInput
                anchors.left: parent.left
                anchors.leftMargin: 56
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: "#f4f6f8"
                selectionColor: "#668da5c0"
                selectedTextColor: "#11151b"
                font.pixelSize: 17
                focus: true
                clip: true
                onTextChanged: {
                    if (text.startsWith(":") && root.activeMode !== "clipboard") clipboardLoader.running = true
                    root.rebuild(text)
                }
                Keys.onEscapePressed: Qt.quit()
                Keys.onReturnPressed: root.runCurrent()
                Keys.onEnterPressed: root.runCurrent()
                Keys.onDownPressed: resultList.incrementCurrentIndex()
                Keys.onUpPressed: resultList.decrementCurrentIndex()
            }

            Text {
                visible: searchInput.text.length === 0
                anchors.left: parent.left
                anchors.leftMargin: 56
                anchors.verticalCenter: parent.verticalCenter
                text: "Search"
                color: colors.muted
                font.pixelSize: 17
            }
        }

        Text {
            id: calculationResult
            visible: root.calculation.length > 0
            x: 25
            y: 78
            width: parent.width - 50
            height: 34
            text: root.calculation
            color: "#f0f3f7"
            font.pixelSize: 22
            verticalAlignment: Text.AlignVCenter
        }

        ListView {
            id: resultList
            visible: root.resultsVisible
            x: 12
            y: root.calculation.length > 0 ? 116 : 78
            width: parent.width - 24
            height: Math.max(0, spotlight.height - y - 12)
            spacing: 3
            clip: true
            focus: true
            model: resultModel
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: resultDelegate
                width: resultList.width
                height: model.kind === "clipboard" && model.isImage ? 174 : 48
                radius: 11
                color: ListView.isCurrentItem ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.28) : (resultMouse.containsMouse ? Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.32) : Qt.rgba(colors.surface.r, colors.surface.g, colors.surface.b, 0.28))
                border.width: 0
                opacity: 0

                Component.onCompleted: rowAnimation.start()

                SequentialAnimation {
                    id: rowAnimation
                    PauseAnimation { duration: Math.max(0, Math.min(index * 12, 100)) }
                    NumberAnimation { target: resultDelegate; property: "opacity"; to: 1; duration: 130; easing.type: Easing.OutCubic }
                }

                Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: 70
                    height: 22
                    radius: 7
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.top: parent.top
                    anchors.topMargin: 9
                    color: ListView.isCurrentItem ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.42) : Qt.rgba(colors.surfaceVariant.r, colors.surfaceVariant.g, colors.surfaceVariant.b, 0.35)

                    Text {
                        anchors.centerIn: parent
                        text: model.kind === "run" ? "RUN" : (model.kind === "app" ? "APP" : (model.kind === "file" ? "FILE" : (model.kind === "command" ? "CMD" : "CLIPBOARD")))
                        color: colors.foreground
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 96
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.top: parent.top
                    anchors.topMargin: 7
                    spacing: 2

                    Text {
                        width: parent.width
                        text: model.kind === "clipboard" && model.isImage ? "BINARY DATA  ·  " + model.mime : model.name
                        color: colors.foreground
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: model.kind === "clipboard" ? model.label : model.subtitle
                        color: colors.muted
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Image {
                        visible: model.kind === "clipboard" && model.isImage && model.preview !== ""
                        width: parent.width
                        height: 112
                        source: model.preview || ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        cache: false
                    }
                }

                MouseArea {
                    id: resultMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { resultList.currentIndex = index; root.runCurrent() }
                }
            }
        }
    }

    Component.onCompleted: searchInput.forceActiveFocus()
}
