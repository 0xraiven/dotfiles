import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

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
        else if (item.kind === "clipboard") Quickshell.execDetached(["sh", "-lc", "$HOME/.local/bin/clipboard-restore " + item.id])
        Qt.quit()
    }

    Process {
        id: loader
        command: ["sh", "-lc", "$HOME/.local/bin/spotlight-items"]
        running: true
        stdout: StdioCollector { id: output }
        onExited: root.loadResults(output.text)
    }

    Process {
        id: clipboardLoader
        command: ["sh", "-lc", "$HOME/.local/bin/clipboard-items"]
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
        color: "#eb1b1e27"
        border.width: 1
        border.color: searchInput.activeFocus ? "#8899a6bc" : "#52697588"
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
            anchors.fill: parent
            anchors.margins: 1
            radius: 18
            color: "transparent"
            border.width: 1
            border.color: "#18ffffff"
        }

        Rectangle {
            id: searchBar
            x: 7
            y: 7
            width: parent.width - 14
            height: 58
            radius: 14
            color: "#b613161e"
            border.width: 1
            border.color: searchInput.activeFocus ? "#9aa9bccc" : "#43526070"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "⌕"
                color: "#e4e9f0"
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
                color: "#929ca8"
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
                color: ListView.isCurrentItem ? "#3c4b5b6d" : (resultMouse.containsMouse ? "#2b343e4b" : "#141c222b")
                border.width: 1
                border.color: ListView.isCurrentItem ? "#71889bb0" : "#182f3a48"
                opacity: 0

                Component.onCompleted: rowAnimation.start()

                SequentialAnimation {
                    id: rowAnimation
                    PauseAnimation { duration: Math.max(0, Math.min(index * 12, 100)) }
                    NumberAnimation { target: resultDelegate; property: "opacity"; to: 1; duration: 130; easing.type: Easing.OutCubic }
                }

                Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 15
                    anchors.top: parent.top
                    anchors.topMargin: 9
                    text: model.kind === "run" ? "Run" : (model.kind === "file" ? "File" : (model.kind === "clipboard" ? "Clipboard" : ""))
                    color: "#9ca9b7"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                IconImage {
                    visible: model.kind === "app" && model.icon !== ""
                    width: 28
                    height: 28
                    anchors.left: parent.left
                    anchors.leftMargin: 43
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    source: model.icon ? (model.icon.charAt(0) === "/" ? "file://" + model.icon : Quickshell.iconPath(model.icon, true)) : ""
                    asynchronous: true
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 82
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.top: parent.top
                    anchors.topMargin: 7
                    spacing: 2

                    Text {
                        width: parent.width
                        text: model.kind === "clipboard" && model.isImage ? "BINARY DATA  ·  " + model.mime : model.name
                        color: "#f1f4f7"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: model.kind === "clipboard" ? model.label : model.subtitle
                        color: "#96a2af"
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
