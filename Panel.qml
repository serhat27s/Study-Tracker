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
    property int currentTab: 0 // 0: Timer & Aktivität, 1: System & Programme

    property bool tagMenuOpen: false
    property string tagStatsScope: "all" // "all" | "today"
    property string appScope: "current"  // "current" | "today" | "all"
    property string appTagFilter: ""     // "" = alle Tags
    property var hoveredCell: null

    readonly property color fg: root.barForeground
    readonly property color dim: Qt.darker(fg, 1.55)
    readonly property color faint: Qt.darker(fg, 2.2)
    readonly property color accent: Color.accent
    readonly property color urgent: Color.urgent

    readonly property var tagStatsData: root.rootWidget
        ? Model.aggregateTagStats(root.rootWidget.history, root.tagStatsScope)
        : { tags: [], grandTotalSeconds: 0, grandTotalFormatted: "0 Min.", grandTotalHours: "0.0 Std." }

    readonly property var heatmapData: root.rootWidget
        ? Model.buildHeatmap(root.rootWidget.history, 14)
        : { weeks: [], totalSeconds: 0, todaySeconds: 0, streakDays: 0, sessionCount: 0 }

    readonly property var appUsageData: root.rootWidget
        ? Model.aggregateAppUsage(root.rootWidget.history, root.rootWidget.currentAppUsage, root.appScope, root.appTagFilter)
        : { apps: [], totalSeconds: 0, totalFormatted: "0 Min.", totalHours: "0.0 Std." }

    function open() {
        if (root.rootWidget) root.rootWidget.refreshUptime()
        root.controller.show()
    }
    function close() {
        root.tagMenuOpen = false
        root.controller.hide()
    }

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
        contentWidth: panel.fittedContentWidth(Style.space(420))
        contentHeight: panel.fittedContentHeight(contentCol.implicitHeight, Style.space(800))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: {
                if (root.tagMenuOpen) {
                    root.tagMenuOpen = false
                } else {
                    root.close()
                }
            }
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
                    topPadding: Style.space(14)
                    bottomPadding: Style.space(18)
                    leftPadding: Style.space(14)
                    rightPadding: Style.space(14)

                    // ---------------------------------------------------------
                    // Header & Tab-Navigation (Slide 1 vs Slide 2)
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
                                text: "Timer & Aktivität"
                                selected: root.currentTab === 0
                                bordered: true
                                fontSize: Style.font.caption
                                onClicked: root.currentTab = 0
                            }

                            Button {
                                text: "System & Apps"
                                selected: root.currentTab === 1
                                bordered: true
                                fontSize: Style.font.caption
                                onClicked: {
                                    if (root.rootWidget) root.rootWidget.refreshUptime()
                                    root.currentTab = 1
                                }
                            }
                        }
                    }

                    PanelSeparator {
                        foreground: root.fg
                    }

                    // =========================================================
                    // SLIDE 1: Timer & Tag GANZ WEIT OBEN, dann Steuerung & Heatmap
                    // =========================================================
                    Column {
                        width: parent.width
                        spacing: Style.space(12)
                        visible: root.currentTab === 0

                        // -----------------------------------------------------
                        // 1. GANZ WEIT OBEN: Timer-Minuten + Tag daneben
                        // -----------------------------------------------------
                        Column {
                            width: parent.width
                            spacing: Style.space(6)

                            // Zentrierte Zeile: [ 25:00 ]   [ 🏷️ Mathe ▾ ]
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Style.space(12)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.rootWidget ? root.rootWidget.formattedTime() : "00:00"
                                    color: root.rootWidget && root.rootWidget.isRunning ? Color.accent : root.fg
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.displayLarge * 1.45
                                    font.bold: true
                                }

                                // Klickbares Tag-Pill
                                Rectangle {
                                    id: tagPill
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: Style.space(32)
                                    width: tagPillRow.implicitWidth + Style.space(20)
                                    radius: Style.space(16)
                                    color: Color.accent
                                    border.width: 1
                                    border.color: Qt.lighter(Color.accent, 1.25)

                                    Row {
                                        id: tagPillRow
                                        anchors.centerIn: parent
                                        spacing: Style.space(6)

                                        Text {
                                            text: "🏷️"
                                            font.pixelSize: Style.font.caption
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: root.rootWidget ? root.rootWidget.activeTag : "Mathe"
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.bodySmall
                                            font.bold: true
                                            color: "#ffffff"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: root.tagMenuOpen ? "󰅃" : "󰅀"
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption * 0.9
                                            font.bold: true
                                            color: "#ffffff"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: tagPillMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.tagMenuOpen = !root.tagMenuOpen
                                            if (root.tagMenuOpen) {
                                                Qt.callLater(function() {
                                                    newTagInput.forceActiveFocus()
                                                })
                                            }
                                        }
                                    }
                                }
                            }

                            // Status-Text
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    if (!root.rootWidget) return ""
                                    if (!root.rootWidget.isRunning) return "Lerneinheit pausiert"
                                    if (root.rootWidget.activeMode === "pomodoro") {
                                        return (root.rootWidget.pomodoroPhase === "work" ? "Fokus auf: " : "Pause: ") + root.rootWidget.activeTag
                                    }
                                    return "Stoppuhr aktiv für: " + root.rootWidget.activeTag
                                }
                                color: root.rootWidget && root.rootWidget.isRunning ? root.fg : root.dim
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                            }

                            // -------------------------------------------------
                            // FOCUS TAGS DROPDOWN CARD (Genau wie im Screenshot)
                            // -------------------------------------------------
                            Rectangle {
                                id: focusTagsCard
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(parent.width - Style.space(16), Style.space(260))
                                visible: root.tagMenuOpen
                                implicitHeight: focusTagsCol.implicitHeight + Style.space(20)
                                radius: Style.space(12)
                                color: Color.popups.background
                                border.width: 1.5
                                border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
                                clip: true

                                Column {
                                    id: focusTagsCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: Style.space(10)
                                    spacing: Style.space(7)

                                    // Header: "FOCUS TAGS"
                                    Text {
                                        text: "FOCUS TAGS"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption * 0.85
                                        font.bold: true
                                        color: Qt.lighter(Color.accent, 1.25)
                                    }

                                    // Tags-Liste untereinander
                                    Column {
                                        width: parent.width
                                        spacing: Style.space(4)

                                        Repeater {
                                            model: root.rootWidget ? root.rootWidget.recentTags : []

                                            Rectangle {
                                                id: tagRow
                                                width: parent.width
                                                height: Style.space(32)
                                                radius: Style.space(8)
                                                color: isSelected
                                                    ? Color.accent
                                                    : (tagRowMouse.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1) : "transparent")

                                                readonly property bool isSelected: root.rootWidget && root.rootWidget.activeTag === modelData

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: Style.space(8)
                                                    anchors.rightMargin: Style.space(8)
                                                    spacing: Style.space(6)

                                                    // Farbiger Punkt
                                                    Rectangle {
                                                        width: Style.space(10)
                                                        height: Style.space(10)
                                                        radius: Style.space(5)
                                                        color: Model.tagColor(modelData, index)
                                                        border.width: 1
                                                        border.color: Qt.lighter(color, 1.2)
                                                    }

                                                    // Tag-Name
                                                    Text {
                                                        text: modelData
                                                        font.family: Style.font.family
                                                        font.pixelSize: Style.font.caption
                                                        font.bold: isSelected
                                                        color: isSelected ? "#ffffff" : root.fg
                                                    }

                                                    // Häkchen bei ausgewähltem Tag
                                                    Text {
                                                        visible: isSelected
                                                        text: "✓"
                                                        font.family: Style.font.family
                                                        font.pixelSize: Style.font.caption
                                                        font.bold: true
                                                        color: "#ffffff"
                                                    }

                                                    Item { Layout.fillWidth: true }

                                                    // Mülleimer-Icon zum Löschen
                                                    Text {
                                                        text: "🗑"
                                                        font.pixelSize: Style.font.caption * 0.9
                                                        color: isSelected ? "#ffffff" : (trashMouse.containsMouse ? Color.urgent : root.dim)
                                                        opacity: trashMouse.containsMouse ? 1.0 : (isSelected ? 0.9 : 0.6)

                                                        MouseArea {
                                                            id: trashMouse
                                                            anchors.fill: parent
                                                            anchors.margins: -Style.space(4)
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (root.rootWidget) {
                                                                    root.rootWidget.removeTag(modelData)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: tagRowMouse
                                                    anchors.fill: parent
                                                    anchors.rightMargin: Style.space(24)
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (root.rootWidget) {
                                                            root.rootWidget.activeTag = modelData
                                                        }
                                                        root.tagMenuOpen = false
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Trennlinie
                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
                                    }

                                    // Unteres Eingabefeld: [ Letters or numbers... ]  [ + ]
                                    RowLayout {
                                        width: parent.width
                                        spacing: Style.space(6)

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: Style.space(32)
                                            radius: Style.space(6)
                                            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)
                                            border.width: 1
                                            border.color: newTagInput.activeFocus ? Color.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)

                                            TextInput {
                                                id: newTagInput
                                                anchors.fill: parent
                                                anchors.leftMargin: Style.space(8)
                                                anchors.rightMargin: Style.space(8)
                                                verticalAlignment: TextInput.AlignVCenter
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption
                                                color: root.fg
                                                clip: true

                                                Text {
                                                    anchors.fill: parent
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: "Letters or numbers..."
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.caption
                                                    color: root.faint
                                                    visible: !newTagInput.text && !newTagInput.activeFocus
                                                }

                                                onAccepted: {
                                                    if (root.rootWidget && text.trim().length > 0) {
                                                        root.rootWidget.addTag(text.trim())
                                                        text = ""
                                                        root.tagMenuOpen = false
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: Style.space(32)
                                            height: Style.space(32)
                                            radius: Style.space(6)
                                            color: Color.accent

                                            Text {
                                                anchors.centerIn: parent
                                                text: "+"
                                                font.pixelSize: Style.font.heading
                                                font.bold: true
                                                color: "#ffffff"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.rootWidget && newTagInput.text.trim().length > 0) {
                                                        root.rootWidget.addTag(newTagInput.text.trim())
                                                        newTagInput.text = ""
                                                        root.tagMenuOpen = false
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // -----------------------------------------------------
                        // 2. STEUERUNGS-BUTTONS (Start/Pause, Speichern, Zurücksetzen)
                        // -----------------------------------------------------
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Style.space(8)

                            Button {
                                text: root.rootWidget && root.rootWidget.isRunning ? "Pause" : "Start"
                                iconText: root.rootWidget && root.rootWidget.isRunning ? "󰏤 " : "󰐊 "
                                bordered: true
                                selected: root.rootWidget && root.rootWidget.isRunning
                                fontSize: Style.font.bodySmall
                                onClicked: if (root.rootWidget) root.rootWidget.toggleRunning()
                            }

                            Button {
                                text: "Speichern"
                                iconText: "󰆓 "
                                bordered: true
                                fontSize: Style.font.bodySmall
                                onClicked: if (root.rootWidget) root.rootWidget.finishAndSave()
                            }

                            Button {
                                text: "Reset"
                                iconText: "󰑐 "
                                bordered: true
                                fontSize: Style.font.bodySmall
                                onClicked: if (root.rootWidget) root.rootWidget.resetTimer()
                            }
                        }

                        // -----------------------------------------------------
                        // 3. MODUS & PHASEN
                        // -----------------------------------------------------
                        RowLayout {
                            width: parent.width

                            Text {
                                text: "MODUS"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                color: root.dim
                            }

                            Item { Layout.fillWidth: true }

                            Row {
                                spacing: Style.space(4)

                                Button {
                                    text: "Pomodoro"
                                    iconText: "󰄉 "
                                    selected: root.rootWidget && root.rootWidget.activeMode === "pomodoro"
                                    bordered: true
                                    fontSize: Style.font.caption
                                    onClicked: if (root.rootWidget) root.rootWidget.setMode("pomodoro")
                                }

                                Button {
                                    text: "Stoppuhr"
                                    iconText: "󱎫 "
                                    selected: root.rootWidget && root.rootWidget.activeMode === "tracker"
                                    bordered: true
                                    fontSize: Style.font.caption
                                    onClicked: if (root.rootWidget) root.rootWidget.setMode("tracker")
                                }
                            }
                        }

                        // Pomodoro-Phasen
                        Column {
                            width: parent.width
                            spacing: Style.space(4)
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
                                    text: "Zyklus " + ((root.rootWidget ? (root.rootWidget.pomodoroCyclesCompleted % 4) : 0) + 1) + " von 4"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    color: root.dim
                                }
                            }

                            Row {
                                spacing: Style.space(4)

                                Button {
                                    text: "Fokus (25m)"
                                    selected: root.rootWidget && root.rootWidget.pomodoroPhase === "work"
                                    bordered: true
                                    fontSize: Style.font.caption
                                    onClicked: if (root.rootWidget) root.rootWidget.setPomodoroPhase("work")
                                }

                                Button {
                                    text: "Pause (5m)"
                                    selected: root.rootWidget && root.rootWidget.pomodoroPhase === "shortBreak"
                                    bordered: true
                                    fontSize: Style.font.caption
                                    onClicked: if (root.rootWidget) root.rootWidget.setPomodoroPhase("shortBreak")
                                }

                                Button {
                                    text: "Lang (15m)"
                                    selected: root.rootWidget && root.rootWidget.pomodoroPhase === "longBreak"
                                    bordered: true
                                    fontSize: Style.font.caption
                                    onClicked: if (root.rootWidget) root.rootWidget.setPomodoroPhase("longBreak")
                                }
                            }
                        }

                        PanelSeparator {
                            foreground: root.fg
                        }

                        // -----------------------------------------------------
                        // 4. STUNDEN-ÜBERSICHT NACH FACH / TAG
                        // -----------------------------------------------------
                        Column {
                            width: parent.width
                            spacing: Style.space(8)

                            RowLayout {
                                width: parent.width

                                Text {
                                    text: "GELERNT NACH FACH"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                    color: root.dim
                                }

                                Item { Layout.fillWidth: true }

                                Row {
                                    spacing: Style.space(4)

                                    Button {
                                        text: "Gesamt"
                                        selected: root.tagStatsScope === "all"
                                        bordered: true
                                        fontSize: Style.font.caption * 0.9
                                        onClicked: root.tagStatsScope = "all"
                                    }

                                    Button {
                                        text: "Heute"
                                        selected: root.tagStatsScope === "today"
                                        bordered: true
                                        fontSize: Style.font.caption * 0.9
                                        onClicked: root.tagStatsScope = "today"
                                    }
                                }
                            }

                            // Rangliste der Fächer
                            Column {
                                width: parent.width
                                spacing: Style.space(8)

                                Repeater {
                                    model: root.tagStatsData.tags

                                    Column {
                                        width: parent.width
                                        spacing: Style.space(3)

                                        RowLayout {
                                            width: parent.width

                                            Text {
                                                text: "🏷️ " + modelData.tag
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.bodySmall
                                                font.bold: true
                                                color: (root.rootWidget && root.rootWidget.activeTag === modelData.tag) ? Color.accent : root.fg
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                text: modelData.hoursDec + " · " + modelData.percent + "%"
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption
                                                color: root.dim
                                            }
                                        }

                                        // Verteilungsbalken
                                        Rectangle {
                                            width: parent.width
                                            height: Style.space(5)
                                            radius: Style.space(2.5)
                                            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)

                                            Rectangle {
                                                width: Math.max(Style.space(4), parent.width * (modelData.totalSeconds / Math.max(1, root.tagStatsData.grandTotalSeconds)))
                                                height: parent.height
                                                radius: Style.space(2.5)
                                                color: (root.rootWidget && root.rootWidget.activeTag === modelData.tag) ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.75)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        PanelSeparator {
                            foreground: root.fg
                        }

                        // -----------------------------------------------------
                        // 5. 7-ZEILEN GITHUB-AKTIVITÄTSGRAPH (14 Wochen für schmale Breite)
                        // -----------------------------------------------------
                        Column {
                            width: parent.width
                            spacing: Style.space(8)

                            RowLayout {
                                width: parent.width

                                Text {
                                    text: "AKTIVITÄTSGRAPH (14 WOCHEN)"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                    color: root.dim
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: root.heatmapData.streakDays + " Tage Streak 🔥"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                    color: Color.accent
                                }
                            }

                            // GitHub-Grid
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Style.space(3)

                                // Spalte mit Wochentagen
                                Column {
                                    spacing: Style.space(3)
                                    Repeater {
                                        model: ["Mo", "", "Mi", "", "Fr", "", "So"]
                                        Text {
                                            width: Style.space(14)
                                            height: Style.space(12)
                                            text: modelData
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption * 0.72
                                            color: root.faint
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }

                                // 14 Wochenspalten
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

                            // Detail-Box bei Hover
                            Rectangle {
                                width: parent.width
                                height: Style.space(32)
                                radius: Style.space(4)
                                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
                                border.width: 1
                                border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - Style.space(14)
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: {
                                        if (root.hoveredCell) {
                                            var base = root.hoveredCell.dateStr + " — " + root.hoveredCell.focusTimeStr + " (" + root.hoveredCell.hoursDec + ")"
                                            if (root.hoveredCell.dominantTags && root.hoveredCell.dominantTags.length > 0) {
                                                return base + " · " + root.hoveredCell.dominantTags
                                            }
                                            return base
                                        }
                                        return "Kästchen berühren für Details"
                                    }
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    color: root.hoveredCell ? root.fg : root.dim
                                }
                            }

                            // Kennzahlen-Karten
                            RowLayout {
                                width: parent.width
                                spacing: Style.space(6)

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Style.space(38)
                                    radius: Style.space(4)
                                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)

                                    Column {
                                        anchors.centerIn: parent
                                        Text {
                                            text: "HEUTE"
                                            font.pixelSize: Style.font.caption * 0.75
                                            font.bold: true
                                            color: root.dim
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: root.heatmapData.todayHours
                                            font.pixelSize: Style.font.bodySmall
                                            font.bold: true
                                            color: root.fg
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Style.space(38)
                                    radius: Style.space(4)
                                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)

                                    Column {
                                        anchors.centerIn: parent
                                        Text {
                                            text: "GESAMT"
                                            font.pixelSize: Style.font.caption * 0.75
                                            font.bold: true
                                            color: root.dim
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: root.heatmapData.totalHours
                                            font.pixelSize: Style.font.bodySmall
                                            font.bold: true
                                            color: root.fg
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Style.space(38)
                                    radius: Style.space(4)
                                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)

                                    Column {
                                        anchors.centerIn: parent
                                        Text {
                                            text: "SESSIONS"
                                            font.pixelSize: Style.font.caption * 0.75
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
                    // SLIDE 2: System-Uptime & Programm-Nutzung
                    // =========================================================
                    Column {
                        width: parent.width
                        spacing: Style.space(12)
                        visible: root.currentTab === 1

                        // -----------------------------------------------------
                        // System-Uptime Hero-Karte
                        // -----------------------------------------------------
                        Rectangle {
                            width: parent.width
                            height: Style.space(70)
                            radius: Style.space(6)
                            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
                            border.width: 1
                            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Style.space(12)
                                spacing: Style.space(12)

                                Rectangle {
                                    width: Style.space(42)
                                    height: Style.space(42)
                                    radius: Style.space(8)
                                    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰍹"
                                        font.pixelSize: Style.font.display
                                        color: Color.accent
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: Style.space(2)

                                    Text {
                                        text: "SYSTEMLAUFZEIT (UPTIME)"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption * 0.8
                                        font.bold: true
                                        color: root.dim
                                    }

                                    Text {
                                        text: Model.formatUptime(root.rootWidget ? root.rootWidget.systemUptimeSeconds : 0)
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.heading
                                        font.bold: true
                                        color: root.fg
                                    }

                                    Text {
                                        text: "Einschaltdauer des Computers"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption * 0.85
                                        color: root.faint
                                    }
                                }
                            }
                        }

                        PanelSeparator {
                            foreground: root.fg
                        }

                        // -----------------------------------------------------
                        // Stunden in Programmen verbracht
                        // -----------------------------------------------------
                        RowLayout {
                            width: parent.width

                            Text {
                                text: "PROGRAMMNUTZUNG"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                color: root.dim
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: root.appUsageData.totalHours
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                color: Color.accent
                            }
                        }

                        // Zeitraum-Umschalter
                        Row {
                            spacing: Style.space(4)

                            Button {
                                text: "Session"
                                selected: root.appScope === "current"
                                bordered: true
                                fontSize: Style.font.caption
                                onClicked: root.appScope = "current"
                            }

                            Button {
                                text: "Heute"
                                selected: root.appScope === "today"
                                bordered: true
                                fontSize: Style.font.caption
                                onClicked: root.appScope = "today"
                            }

                            Button {
                                text: "Gesamt"
                                selected: root.appScope === "all"
                                bordered: true
                                fontSize: Style.font.caption
                                onClicked: root.appScope = "all"
                            }
                        }

                        // Filter nach Fach/Tag
                        Column {
                            width: parent.width
                            spacing: Style.space(4)

                            Text {
                                text: "NACH FACH FILTERN"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption * 0.8
                                font.bold: true
                                color: root.dim
                            }

                            Flow {
                                width: parent.width
                                spacing: Style.space(4)

                                Rectangle {
                                    height: Style.space(22)
                                    width: allTagLabel.implicitWidth + Style.space(12)
                                    radius: Style.space(11)
                                    color: (root.appTagFilter === "")
                                        ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                                        : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                                    border.width: 1
                                    border.color: (root.appTagFilter === "") ? Color.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)

                                    Text {
                                        id: allTagLabel
                                        anchors.centerIn: parent
                                        text: "Alle"
                                        font.pixelSize: Style.font.caption
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
                                        height: Style.space(22)
                                        width: tLabel.implicitWidth + Style.space(12)
                                        radius: Style.space(11)
                                        color: (root.appTagFilter === modelData)
                                            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                                            : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                                        border.width: 1
                                        border.color: (root.appTagFilter === modelData) ? Color.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)

                                        Text {
                                            id: tLabel
                                            anchors.centerIn: parent
                                            text: "🏷️ " + modelData
                                            font.pixelSize: Style.font.caption
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

                        // Rangliste der Programme & Stunden
                        Column {
                            width: parent.width
                            spacing: Style.space(10)
                            visible: root.appUsageData.apps.length > 0

                            Repeater {
                                model: root.appUsageData.apps

                                Column {
                                    width: parent.width
                                    spacing: Style.space(3)

                                    RowLayout {
                                        width: parent.width

                                        Text {
                                            text: "󰆍 " + modelData.app
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.bodySmall
                                            font.bold: true
                                            color: root.fg
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: modelData.hoursDec + " (" + modelData.percent + "%)"
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption
                                            color: root.dim
                                        }
                                    }

                                    // Balken für App-Nutzung
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

                        // Leerer Zustand wenn keine App-Daten für diesen Filter
                        Rectangle {
                            width: parent.width
                            height: Style.space(100)
                            radius: Style.space(6)
                            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
                            visible: root.appUsageData.apps.length === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: Style.space(4)

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰄶"
                                    font.pixelSize: Style.font.title
                                    color: root.faint
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Keine Programmnutzung erfasst"
                                    font.pixelSize: Style.font.caption
                                    color: root.dim
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
