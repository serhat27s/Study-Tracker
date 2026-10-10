import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
    id: root
    moduleName: "io.github.yourname.study-tracker"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property var rootWidget: null
    property int currentTab: 0 // 0: Timer & Heatmap, 1: App Usage

    property string appScope: "current" // "current" | "today" | "all"
    property string appTagFilter: ""    // "" = all tags
    property var hoveredCell: null

    readonly property color fg: root.barForeground
    readonly property color dim: Qt.darker(fg, 1.55)
    readonly property color faint: Qt.darker(fg, 2.2)
    readonly property color accent: Color.accent
    readonly property color urgent: Color.urgent

    readonly property var heatmapData: root.rootWidget
        ? Model.buildHeatmap(root.rootWidget.history, 14)
        : { weeks: [], totalSeconds: 0, todaySeconds: 0, streakDays: 0, sessionCount: 0 }

    readonly property var appUsageData: root.rootWidget
        ? Model.aggregateAppUsage(root.rootWidget.history, root.rootWidget.currentAppUsage, root.appScope, root.appTagFilter)
        : { apps: [], totalSeconds: 0, totalFormatted: "0m" }

    function open() { root.controller.show() }
    function close() { root.controller.hide() }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction)
        return false
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(450))
        contentHeight: panel.fittedContentHeight(contentCol.implicitHeight, Style.space(680))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }

            Flickable {
                id: panelFlick
                anchors.fill: parent
                contentWidth: width
                contentHeight: contentCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                interactive: contentHeight > height

                Column {
                    id: contentCol
                    width: panelFlick.width
                    spacing: Style.space(12)
                    topPadding: Style.space(12)
                    bottomPadding: Style.space(16)
                    leftPadding: Style.space(14)
                    rightPadding: Style.space(14)

                    // ---------------------------------------------------------
                    // Header & Tab Navigation
                    // ---------------------------------------------------------
                    RowLayout {
                        width: parent.width

                        Text {
                            text: "󰔛 Study Tracker"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.title
                            font.bold: true
                            color: root.fg
                        }

                        Item { Layout.fillWidth: true }

                        Row {
                            spacing: Style.space(4)

                            Button {
                                text: "Timer & Activity"
                                selected: root.currentTab === 0
                                bordered: true
                                fontSize: Style.font.caption
                                onClicked: root.currentTab = 0
                            }

                            Button {
                                text: "App Usage"
                                selected: root.currentTab === 1
                                bordered: true
                                fontSize: Style.font.caption
                                onClicked: root.currentTab = 1
                            }
                        }
                    }

                    PanelSeparator {
                        foreground: root.fg
                    }

                    // =========================================================
                    // VIEW 0: Timer Controls & Heatmap
                    // =========================================================
                    Column {
                        width: parent.width
                        spacing: Style.space(12)
                        visible: root.currentTab === 0

                        // Mode Selector (Pomodoro vs Tracker)
                        RowLayout {
                            width: parent.width

                            Text {
                                text: "MODE"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                color: root.dim
                            }

                            Item { Layout.fillWidth: true }

                            Row {
                                spacing: Style.space(6)

                                Button {
                                    text: "Pomodoro"
                                    iconText: "󰄉 "
                                    selected: root.rootWidget && root.rootWidget.activeMode === "pomodoro"
                                    bordered: true
                                    fontSize: Style.font.bodySmall
                                    onClicked: if (root.rootWidget) root.rootWidget.setMode("pomodoro")
                                }

                                Button {
                                    text: "Stopwatch"
                                    iconText: "󱎫 "
                                    selected: root.rootWidget && root.rootWidget.activeMode === "tracker"
                                    bordered: true
                                    fontSize: Style.font.bodySmall
                                    onClicked: if (root.rootWidget) root.rootWidget.setMode("tracker")
                                }
                            }
                        }

                        // Pomodoro Cycles & Phase Selection (when Pomodoro is active)
                        Column {
                            width: parent.width
                            spacing: Style.space(6)
                            visible: root.rootWidget && root.rootWidget.activeMode === "pomodoro"

                            RowLayout {
                                width: parent.width

                                Text {
                                    text: "PHASE"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                    color: root.dim
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "Cycle " + ((root.rootWidget ? (root.rootWidget.pomodoroCyclesCompleted % 4) : 0) + 1) + " of 4"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    color: root.dim
                                }
                            }

                            Row {
                                spacing: Style.space(6)

                                Button {
                                    text: "Focus (25m)"
                                    selected: root.rootWidget && root.rootWidget.pomodoroPhase === "work"
                                    bordered: true
                                    fontSize: Style.font.bodySmall
                                    onClicked: if (root.rootWidget) root.rootWidget.setPomodoroPhase("work")
                                }

                                Button {
                                    text: "Short Break (5m)"
                                    selected: root.rootWidget && root.rootWidget.pomodoroPhase === "shortBreak"
                                    bordered: true
                                    fontSize: Style.font.bodySmall
                                    onClicked: if (root.rootWidget) root.rootWidget.setPomodoroPhase("shortBreak")
                                }

                                Button {
                                    text: "Long Break (15m)"
                                    selected: root.rootWidget && root.rootWidget.pomodoroPhase === "longBreak"
                                    bordered: true
                                    fontSize: Style.font.bodySmall
                                    onClicked: if (root.rootWidget) root.rootWidget.setPomodoroPhase("longBreak")
                                }
                            }
                        }

                        // Tag Input & Recent Tags Chips
                        Column {
                            width: parent.width
                            spacing: Style.space(6)

                            RowLayout {
                                width: parent.width

                                Text {
                                    text: "ACTIVE TAG: " + (root.rootWidget ? root.rootWidget.activeTag : "General")
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                    color: Color.accent
                                }

                                Item { Layout.fillWidth: true }
                            }

                            // Quick-select chips
                            Flow {
                                width: parent.width
                                spacing: Style.space(4)

                                Repeater {
                                    model: root.rootWidget ? root.rootWidget.recentTags : []

                                    Rectangle {
                                        height: Style.space(22)
                                        width: tagLabel.implicitWidth + Style.space(14)
                                        radius: Style.space(11)
                                        color: (root.rootWidget && root.rootWidget.activeTag === modelData)
                                            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                                            : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                                        border.width: 1
                                        border.color: (root.rootWidget && root.rootWidget.activeTag === modelData)
                                            ? Color.accent
                                            : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)

                                        Text {
                                            id: tagLabel
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption
                                            font.bold: root.rootWidget && root.rootWidget.activeTag === modelData
                                            color: (root.rootWidget && root.rootWidget.activeTag === modelData)
                                                ? Color.accent
                                                : root.fg
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: if (root.rootWidget) root.rootWidget.activeTag = modelData
                                        }
                                    }
                                }
                            }

                            // Custom Tag TextField
                            TextField {
                                id: newTagInput
                                width: parent.width
                                placeholderText: "Enter custom tag and press Enter..."
                                font.pixelSize: Style.font.bodySmall
                                onAccepted: {
                                    if (root.rootWidget && text.trim().length > 0) {
                                        root.rootWidget.addTag(text.trim())
                                        text = ""
                                    }
                                }
                            }
                        }

                        // Big Time Readout & Status
                        Column {
                            width: parent.width
                            spacing: Style.space(4)

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: root.rootWidget ? root.rootWidget.formattedTime() : "00:00"
                                color: root.rootWidget && root.rootWidget.isRunning ? Color.accent : root.fg
                                font.family: Style.font.family
                                font.pixelSize: Style.font.displayLarge * 1.3
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: {
                                    if (!root.rootWidget) return ""
                                    if (!root.rootWidget.isRunning) return "Session Paused"
                                    if (root.rootWidget.activeMode === "pomodoro") {
                                        return (root.rootWidget.pomodoroPhase === "work" ? "Focused on: " : "Resting: ") + root.rootWidget.activeTag
                                    }
                                    return "Stopwatch tracking: " + root.rootWidget.activeTag
                                }
                                color: root.rootWidget && root.rootWidget.isRunning ? root.fg : root.dim
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                            }
                        }

                        // Timer Controls (Start/Pause, Save, Reset)
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Style.space(8)

                            Button {
                                text: root.rootWidget && root.rootWidget.isRunning ? "Pause" : "Start"
                                iconText: root.rootWidget && root.rootWidget.isRunning ? "󰏤 " : "󰐊 "
                                bordered: true
                                selected: root.rootWidget && root.rootWidget.isRunning
                                fontSize: Style.font.body
                                onClicked: if (root.rootWidget) root.rootWidget.toggleRunning()
                            }

                            Button {
                                text: "Save Session"
                                iconText: "󰆓 "
                                bordered: true
                                fontSize: Style.font.body
                                onClicked: if (root.rootWidget) root.rootWidget.finishAndSave()
                            }

                            Button {
                                text: "Reset"
                                iconText: "󰑐 "
                                bordered: true
                                fontSize: Style.font.body
                                onClicked: if (root.rootWidget) root.rootWidget.resetTimer()
                            }
                        }

                        PanelSeparator {
                            foreground: root.fg
                        }

                        // -----------------------------------------------------
                        // 7-Row Activity Heatmap Section
                        // -----------------------------------------------------
                        Column {
                            width: parent.width
                            spacing: Style.space(8)

                            RowLayout {
                                width: parent.width

                                Text {
                                    text: "ACTIVITY HEATMAP (14 WEEKS)"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                    color: root.dim
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: root.heatmapData.streakDays + " Day Streak 🔥"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                    color: Color.accent
                                }
                            }

                            // Heatmap Grid: 7 rows x 14 columns
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Style.space(3)

                                // Day of week labels: Mon, Wed, Fri
                                Column {
                                    spacing: Style.space(3)
                                    Repeater {
                                        model: ["M", "", "W", "", "F", "", "S"]
                                        Text {
                                            width: Style.space(12)
                                            height: Style.space(12)
                                            text: modelData
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption * 0.75
                                            color: root.faint
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }

                                // 14 Week columns
                                Repeater {
                                    model: root.heatmapData.weeks

                                    Column {
                                        spacing: Style.space(3)

                                        Repeater {
                                            model: modelData

                                            Rectangle {
                                                width: Style.space(12)
                                                height: Style.space(12)
                                                radius: Style.space(2)

                                                color: {
                                                    if (modelData.isFuture) return Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.03)
                                                    if (modelData.level === 4) return Color.accent
                                                    if (modelData.level === 3) return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.80)
                                                    if (modelData.level === 2) return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.55)
                                                    if (modelData.level === 1) return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.30)
                                                    return Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07)
                                                }

                                                border.width: modelData.isToday ? 1 : 0
                                                border.color: Color.accent

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: !modelData.isFuture
                                                    onEntered: root.hoveredCell = modelData
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Heatmap Detail Box
                            Rectangle {
                                width: parent.width
                                height: Style.space(32)
                                radius: Style.space(4)
                                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
                                border.width: 1
                                border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - Style.space(16)
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: {
                                        if (root.hoveredCell) {
                                            var base = root.hoveredCell.dateStr + " — " + root.hoveredCell.focusTimeStr
                                            if (root.hoveredCell.dominantTags && root.hoveredCell.dominantTags.length > 0) {
                                                return base + " (" + root.hoveredCell.dominantTags + ")"
                                            }
                                            return base
                                        }
                                        return "Hover over any day square to inspect focus logs"
                                    }
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    color: root.hoveredCell ? root.fg : root.dim
                                }
                            }

                            // Activity Summary Metrics
                            RowLayout {
                                width: parent.width

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Style.space(36)
                                    radius: Style.space(4)
                                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)

                                    Column {
                                        anchors.centerIn: parent
                                        Text {
                                            text: "TODAY"
                                            font.pixelSize: Style.font.caption * 0.8
                                            font.bold: true
                                            color: root.dim
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: Model.formatDurationHuman(root.heatmapData.todaySeconds)
                                            font.pixelSize: Style.font.bodySmall
                                            font.bold: true
                                            color: root.fg
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Style.space(36)
                                    radius: Style.space(4)
                                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)

                                    Column {
                                        anchors.centerIn: parent
                                        Text {
                                            text: "TOTAL"
                                            font.pixelSize: Style.font.caption * 0.8
                                            font.bold: true
                                            color: root.dim
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: Model.formatDurationHuman(root.heatmapData.totalSeconds)
                                            font.pixelSize: Style.font.bodySmall
                                            font.bold: true
                                            color: root.fg
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Style.space(36)
                                    radius: Style.space(4)
                                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)

                                    Column {
                                        anchors.centerIn: parent
                                        Text {
                                            text: "SESSIONS"
                                            font.pixelSize: Style.font.caption * 0.8
                                            font.bold: true
                                            color: root.dim
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: "" + root.heatmapData.sessionCount
                                            font.pixelSize: Style.font.bodySmall
                                            font.bold: true
                                            color: root.fg
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // =========================================================
                    // VIEW 1: Application Usage Slide
                    // =========================================================
                    Column {
                        width: parent.width
                        spacing: Style.space(12)
                        visible: root.currentTab === 1

                        // Slide Header & Scope Filters
                        RowLayout {
                            width: parent.width

                            Text {
                                text: "APP USAGE BREAKDOWN"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                color: root.dim
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "Total: " + root.appUsageData.totalFormatted
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                color: Color.accent
                            }
                        }

                        // Scope Selector (Current Session, Today, All Time)
                        Row {
                            spacing: Style.space(6)

                            Button {
                                text: "Current Session"
                                selected: root.appScope === "current"
                                bordered: true
                                fontSize: Style.font.caption
                                onClicked: root.appScope = "current"
                            }

                            Button {
                                text: "Today"
                                selected: root.appScope === "today"
                                bordered: true
                                fontSize: Style.font.caption
                                onClicked: root.appScope = "today"
                            }

                            Button {
                                text: "All Time"
                                selected: root.appScope === "all"
                                bordered: true
                                fontSize: Style.font.caption
                                onClicked: root.appScope = "all"
                            }
                        }

                        // Filter by Tag
                        Column {
                            width: parent.width
                            spacing: Style.space(4)

                            Text {
                                text: "FILTER BY TAG"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption * 0.85
                                font.bold: true
                                color: root.dim
                            }

                            Flow {
                                width: parent.width
                                spacing: Style.space(4)

                                // "All" chip
                                Rectangle {
                                    height: Style.space(20)
                                    width: allTagLabel.implicitWidth + Style.space(12)
                                    radius: Style.space(10)
                                    color: (root.appTagFilter === "")
                                        ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                                        : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                                    border.width: 1
                                    border.color: (root.appTagFilter === "") ? Color.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)

                                    Text {
                                        id: allTagLabel
                                        anchors.centerIn: parent
                                        text: "All Tags"
                                        font.pixelSize: Style.font.caption * 0.9
                                        color: (root.appTagFilter === "") ? Color.accent : root.fg
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.appTagFilter = ""
                                    }
                                }

                                Repeater {
                                    model: root.rootWidget ? root.rootWidget.recentTags : []

                                    Rectangle {
                                        height: Style.space(20)
                                        width: tLabel.implicitWidth + Style.space(12)
                                        radius: Style.space(10)
                                        color: (root.appTagFilter === modelData)
                                            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                                            : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                                        border.width: 1
                                        border.color: (root.appTagFilter === modelData) ? Color.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)

                                        Text {
                                            id: tLabel
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.pixelSize: Style.font.caption * 0.9
                                            color: (root.appTagFilter === modelData) ? Color.accent : root.fg
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.appTagFilter = modelData
                                        }
                                    }
                                }
                            }
                        }

                        // Ranked List of Applications
                        Column {
                            width: parent.width
                            spacing: Style.space(10)
                            visible: root.appUsageData.apps.length > 0

                            Repeater {
                                model: root.appUsageData.apps

                                Column {
                                    width: parent.width
                                    spacing: Style.space(4)

                                    RowLayout {
                                        width: parent.width

                                        Text {
                                            text: modelData.app
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.bodySmall
                                            font.bold: true
                                            color: root.fg
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: modelData.formatted + "  (" + modelData.percent + "%)"
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption
                                            color: root.dim
                                        }
                                    }

                                    // Usage proportion bar
                                    Rectangle {
                                        width: parent.width
                                        height: Style.space(6)
                                        radius: Style.space(3)
                                        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)

                                        Rectangle {
                                            width: Math.max(Style.space(4), parent.width * (modelData.seconds / Math.max(1, root.appUsageData.totalSeconds)))
                                            height: parent.height
                                            radius: Style.space(3)
                                            color: Color.accent
                                        }
                                    }
                                }
                            }
                        }

                        // Empty State when no usage data for current filter
                        Rectangle {
                            width: parent.width
                            height: Style.space(120)
                            radius: Style.space(6)
                            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
                            visible: root.appUsageData.apps.length === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: Style.space(6)

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰄶"
                                    font.pixelSize: Style.font.display
                                    color: root.faint
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "No window usage logged for this filter"
                                    font.pixelSize: Style.font.bodySmall
                                    color: root.dim
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Start the study timer to track active applications"
                                    font.pixelSize: Style.font.caption
                                    color: root.faint
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
