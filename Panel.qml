import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
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

    // 0: Focus (Timer + Activity Graph), 1: Statistics (Hours per Subject), 2: Activity (Study Session Apps)
    property int currentTab: 0

    property bool tagMenuOpen: false
    property real tagMenuX: 0
    property real tagMenuY: 0
    property string activeColorTarget: "" // "" | "__new__" | tagName
    onActiveColorTargetChanged: {
        if (root.activeColorTarget.length > 0 && typeof colorPaletteCard !== "undefined" && colorPaletteCard) {
            colorPaletteCard.syncFromTarget()
        }
    }
    property string newTagColor: ""       // "" (Auto) or custom hex for newly added tag
    property real paletteTargetY: 0
    property bool pomodoroSettingsOpen: false

    readonly property var colorPalette: [
        "#ef4444", // Red
        "#f97316", // Orange
        "#f59e0b", // Amber
        "#eab308", // Yellow
        "#84cc16", // Lime
        "#10b981", // Emerald
        "#14b8a6", // Teal
        "#06b6d4", // Cyan
        "#3b82f6", // Blue
        "#6366f1", // Indigo
        "#8b5cf6", // Purple
        "#d946ef", // Fuchsia
        "#ec4899", // Pink
        "#64748b"  // Slate
    ]

    property string tagStatsScope: "week"   // "today" | "week" | "all"
    property string appScope: "today"       // "current" | "today" | "week" | "all"
    property string appTagFilter: ""        // "" = all subjects
    property var hoveredCell: null
    property int heatmapYear: new Date().getFullYear()

    // Fixed panel dimensions: 420x560 compact standard
    readonly property int panelWidth: Style.space(420)
    readonly property int panelInnerHeight: Style.space(560)

    readonly property color fg: root.barForeground
    readonly property color dim: Qt.darker(fg, 1.5)
    readonly property color faint: Qt.darker(fg, 2.2)
    readonly property color surface: Qt.rgba(fg.r, fg.g, fg.b, 0.05)
    readonly property color surfaceHover: Qt.rgba(fg.r, fg.g, fg.b, 0.09)
    readonly property color hairline: Qt.rgba(fg.r, fg.g, fg.b, 0.10)

    readonly property var w: root.rootWidget
    readonly property bool running: w ? w.isRunning : false
    readonly property bool isPomodoro: w ? w.activeMode === "pomodoro" : true
    readonly property string activeTag: w ? w.activeTag : "General"

    readonly property int phaseTotal: {
        if (!w) return 1500
        if (w.pomodoroPhase === "shortBreak") return w.pomodoroShortBreakDuration
        if (w.pomodoroPhase === "longBreak") return w.pomodoroLongBreakDuration
        return w.pomodoroWorkDuration
    }
    readonly property real timerProgress: {
        if (!w) return 0
        if (isPomodoro) return Math.max(0, Math.min(1, 1 - w.remainingSeconds / Math.max(1, phaseTotal)))
        return (w.elapsedSeconds % 3600) / 3600
    }

    readonly property string currentPomodoroPreset: {
        if (!w) return "standard"
        var workMin = Math.round(w.pomodoroWorkDuration / 60)
        var shortMin = Math.round(w.pomodoroShortBreakDuration / 60)
        if (workMin === 50 && shortMin === 10) return "deepWork"
        if (workMin === 90 && shortMin === 20) return "ultradian"
        if (workMin === 25 && shortMin === 5) return "standard"
        return ""
    }

    readonly property var heatmapData: w
        ? Model.buildHeatmap(w.history, root.heatmapYear)
        : { year: root.heatmapYear, weeks: [], numWeeks: 0, todayWeekIndex: 0, totalSeconds: 0, yearHours: "0.0 hrs", todayHours: "0.0 hrs", totalHours: "0.0 hrs", streakDays: 0, sessionCount: 0 }

    readonly property var tagStatsData: w
        ? Model.aggregateTagStats(w.history, root.tagStatsScope)
        : { tags: [], grandTotalSeconds: 0, grandTotalFormatted: "0 min", grandTotalHours: "0.0 hrs" }

    readonly property var weekStats: w
        ? Model.aggregateTagStats(w.history, "week")
        : { grandTotalHours: "0.0 hrs" }

    readonly property var appUsageData: w
        ? Model.aggregateAppUsage(w.history, w.currentAppUsage, root.appScope, root.appTagFilter)
        : { apps: [], totalSeconds: 0, totalFormatted: "0 min", totalHours: "0.0 hrs" }

    function colorForTag(name) {
        if (!name) return Color.accent
        var colors = w ? w.tagColors : null
        return Model.tagColor(name, colors)
    }

    function getPomodoroDuration(phase) {
        if (!w) return 1500
        if (phase === "work") return w.pomodoroWorkDuration
        if (phase === "shortBreak") return w.pomodoroShortBreakDuration
        if (phase === "longBreak") return w.pomodoroLongBreakDuration
        return 1500
    }

    function scrollToCurrent() {
        if (typeof heatmapFlick === "undefined" || !heatmapFlick) return
        var colW = Style.space(11) + Style.space(3)
        var totalCols = (root.heatmapData && root.heatmapData.weeks) ? root.heatmapData.weeks.length : 53
        var todayIdx = (root.heatmapData && typeof root.heatmapData.todayWeekIndex === "number") ? root.heatmapData.todayWeekIndex : -1
        if (todayIdx < 0) {
            todayIdx = Math.min(totalCols - 1, 40)
        }
        var flickW = heatmapFlick.width
        var totalW = totalCols * colW
        var maxX = Math.max(0, totalW - flickW)
        // Ansicht auf die letzten ~3 Monate bis heute zentrieren (heute am rechten Rand des sichtbaren Bereichs)
        var targetX = Math.round((todayIdx + 1.5) * colW - flickW)
        heatmapFlick.contentX = Math.max(0, Math.min(maxX, targetX))
    }

    onHeatmapYearChanged: Qt.callLater(root.scrollToCurrent)

    onOpenedChanged: {
        if (root.opened) {
            Qt.callLater(root.scrollToCurrent)
        }
    }

    function open() {
        root.controller.show()
        Qt.callLater(root.scrollToCurrent)
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

    function setTab(i) {
        root.closeTagMenu()
        root.hoveredCell = null
        root.currentTab = i
        if (i === 0) Qt.callLater(root.scrollToCurrent)
    }

    function openTagMenu() {
        if (root.currentTab !== 0) {
            root.currentTab = 0
            Qt.callLater(root.openTagMenu)
            return
        }
        var p = tagPill.mapToItem(keyCatcher, 0, 0)
        var menuW = tagMenu.width
        root.tagMenuX = Math.max(Style.space(8), Math.min(keyCatcher.width - menuW - Style.space(8), p.x + tagPill.width / 2 - menuW / 2))
        root.tagMenuY = p.y + tagPill.height + Style.space(6)
        root.tagMenuOpen = true
        root.activeColorTarget = ""
        root.newTagColor = ""
        Qt.callLater(function() { tagInput.forceActiveFocus() })
    }

    function closeTagMenu() {
        if (!root.tagMenuOpen) return
        root.tagMenuOpen = false
        root.activeColorTarget = ""
        root.newTagColor = ""
        tagInput.text = ""
        keyCatcher.forceActiveFocus()
    }

    function submitNewTag() {
        var t = tagInput.text.trim()
        if (w && t.length > 0) w.addTag(t, root.newTagColor)
        root.closeTagMenu()
    }

    function openColorPaletteForTag(tagName, item) {
        if (root.activeColorTarget === tagName) {
            root.activeColorTarget = ""
            return
        }
        root.activeColorTarget = tagName

        if (tagName === "__new__") {
            root.paletteTargetY = Style.space(42)
        } else if (item && typeof tagMenu !== "undefined" && tagMenu) {
            var pos = item.mapToItem(tagMenu, 0, 0)
            var itemY = pos.y
            var itemH = item.height
            var palH = (typeof colorPaletteCard !== "undefined" && colorPaletteCard && colorPaletteCard.implicitHeight > 0)
                ? colorPaletteCard.implicitHeight : Style.space(200)

            // Dynamically position palette above or below item
            var topLimit = Style.space(42)
            if (itemY - palH - Style.space(4) >= topLimit) {
                root.paletteTargetY = itemY - palH - Style.space(4)
            } else {
                root.paletteTargetY = itemY + itemH + Style.space(4)
            }
        }
    }

    // =========================================================================
    // Wiederverwendbare Bausteine
    // =========================================================================

    // Segment-Umschalter mit gleich breiten Segmenten (läuft nie über)
    component Segmented: Rectangle {
        id: seg
        property var options: []        // [{ value, label, icon? }]
        property string value: ""
        property color fg: Color.foreground
        property real fontSize: Style.font.caption
        signal picked(string value)

        implicitHeight: Style.space(28)
        radius: Style.space(8)
        color: Qt.rgba(fg.r, fg.g, fg.b, 0.06)

        Row {
            anchors.fill: parent
            anchors.margins: Style.space(2)

            Repeater {
                model: seg.options

                Rectangle {
                    readonly property bool sel: modelData.value === seg.value
                    width: (seg.width - Style.space(4)) / Math.max(1, seg.options.length)
                    height: parent.height
                    radius: Style.space(6)
                    color: sel
                        ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20)
                        : (segMouse.containsMouse ? Qt.rgba(seg.fg.r, seg.fg.g, seg.fg.b, 0.06) : "transparent")
                    border.width: sel ? 1 : 0
                    border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.55)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - Style.space(8)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: (modelData.icon ? modelData.icon + "  " : "") + modelData.label
                        font.family: Style.font.family
                        font.pixelSize: seg.fontSize
                        font.bold: parent.sel
                        color: parent.sel ? Color.accent : Qt.darker(seg.fg, 1.35)
                    }

                    MouseArea {
                        id: segMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seg.picked(modelData.value)
                    }

                    PanelToolTip {
                        visible: segMouse.containsMouse && Boolean(modelData.tip && modelData.tip.length > 0)
                        text: modelData.tip || ""
                    }
                }
            }
        }
    }

    // Kleine Kennzahl-Kachel
    component StatTile: Rectangle {
        id: tile
        property string label: ""
        property string value: ""
        property color fg: Color.foreground
        property color valueColor: fg

        implicitHeight: Style.space(50)
        radius: Style.space(8)
        color: Qt.rgba(fg.r, fg.g, fg.b, 0.05)

        Column {
            anchors.centerIn: parent
            width: parent.width - Style.space(8)
            spacing: Style.space(2)

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: tile.label
                font.family: Style.font.family
                font.pixelSize: Style.font.caption * 0.85
                font.bold: true
                color: Qt.darker(tile.fg, 1.5)
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: tile.value
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
                color: tile.valueColor
            }
        }
    }

    // Abschnittsüberschrift
    component SectionLabel: Text {
        property color fg: Color.foreground
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.6
        color: Qt.darker(fg, 1.5)
    }

    // Wiederverwendbarer Empty State
    component EmptyState: Column {
        id: es
        property string icon: "󰄨"
        property string title: ""
        property string description: ""
        property color fg: root.fg
        property color dimColor: root.dim

        spacing: Style.space(8)
        width: parent ? Math.min(parent.width - Style.space(32), Style.space(280)) : Style.space(260)

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(46)
            height: Style.space(46)
            radius: width / 2
            color: Qt.rgba(es.fg.r, es.fg.g, es.fg.b, 0.05)
            border.width: 1
            border.color: root.hairline

            Text {
                anchors.centerIn: parent
                text: es.icon
                font.family: Style.font.family
                font.pixelSize: Style.font.iconLarge * 1.25
                color: es.dimColor
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: es.title
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            color: es.fg
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: es.description
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            lineHeight: 1.25
            color: es.dimColor
        }
    }

    // =========================================================================
    // Panel
    // =========================================================================
    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(root.panelWidth)
        contentHeight: panel.fittedContentHeight(root.panelInnerHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            blocked: root.tagMenuOpen

            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }
            onActivateRequested: if (root.w) root.w.toggleRunning()
            onMoveRequested: function(dx, dy) {
                if (dx !== 0) root.setTab((root.currentTab + dx + 3) % 3)
            }
            onTextKey: function(t) {
                if (t === "1") root.setTab(0)
                else if (t === "2") root.setTab(1)
                else if (t === "3") root.setTab(2)
                else if ((t === "r" || t === "s") && root.w) root.w.resetTimer()
                else if (t === "m" && root.w) root.w.setMode(root.isPomodoro ? "tracker" : "pomodoro")
                else if (t === "t") root.openTagMenu()
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: Style.space(12)

                // -------------------------------------------------------------
                // Tab-Leiste
                // -------------------------------------------------------------
                Segmented {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(30)
                    fg: root.fg
                    fontSize: Style.font.bodySmall
                    value: "" + root.currentTab
                    options: [
                        { value: "0", label: "Focus", icon: "󰔛" },
                        { value: "1", label: "Statistics", icon: "󰄨" },
                        { value: "2", label: "Activity", icon: "󰍹" }
                    ]
                    onPicked: function(v) { root.setTab(parseInt(v)) }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.currentTab

                    // =========================================================
                    // TAB 1: FOCUS
                    // =========================================================
                    Flickable {
                        id: focusFlick
                        clip: true
                        contentWidth: width
                        contentHeight: focusCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height

                        Column {
                            id: focusCol
                            width: focusFlick.width
                            spacing: Style.space(14)

                            // ---------------- Timer Card ----------------
                            Rectangle {
                                width: parent.width
                                implicitHeight: timerCol.implicitHeight + Style.space(28)
                                radius: Style.space(12)
                                color: root.surface
                                border.width: 1
                                border.color: root.running
                                    ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.45)
                                    : root.hairline

                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                Column {
                                    id: timerCol
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: Style.space(14)
                                    spacing: Style.space(10)

                                    // Mode
                                    Segmented {
                                        width: parent.width
                                        fg: root.fg
                                        value: root.isPomodoro ? "pomodoro" : "tracker"
                                        options: [
                                            { value: "pomodoro", label: "Pomodoro", icon: "󰄉" },
                                            { value: "tracker", label: "Stopwatch", icon: "󱎫" }
                                        ]
                                        onPicked: function(v) { if (root.w) root.w.setMode(v) }
                                    }

                                    // Zeit + Tag rechts daneben
                                    Item {
                                        width: parent.width
                                        height: Style.space(58)

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: Style.space(14)

                                            Text {
                                                id: timeText
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.w ? root.w.formattedTime() : "25:00"
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.displayLarge * 1.6
                                                font.bold: true
                                                color: root.running ? Color.accent : root.fg
                                                Behavior on color { ColorAnimation { duration: 200 } }
                                            }

                                            // Tag-Pill
                                            Rectangle {
                                                id: tagPill
                                                anchors.verticalCenter: parent.verticalCenter
                                                readonly property color tagCol: root.colorForTag(root.activeTag)
                                                height: Style.space(28)
                                                width: tagPillRow.implicitWidth + Style.space(20)
                                                radius: height / 2
                                                color: tagPillMouse.containsMouse || root.tagMenuOpen
                                                    ? Qt.rgba(tagCol.r, tagCol.g, tagCol.b, 0.28)
                                                    : Qt.rgba(tagCol.r, tagCol.g, tagCol.b, 0.16)
                                                border.width: 1
                                                border.color: Qt.rgba(tagCol.r, tagCol.g, tagCol.b, 0.6)

                                                Row {
                                                    id: tagPillRow
                                                    anchors.centerIn: parent
                                                    spacing: Style.space(6)

                                                    Rectangle {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: Style.space(8)
                                                        height: width
                                                        radius: width / 2
                                                        color: tagPill.tagCol
                                                    }
                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: Math.min(implicitWidth, Style.space(96))
                                                        elide: Text.ElideRight
                                                        text: root.activeTag
                                                        font.family: Style.font.family
                                                        font.pixelSize: Style.font.bodySmall
                                                        font.bold: true
                                                        color: root.fg
                                                    }
                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: root.tagMenuOpen ? "󰅃" : "󰅀"
                                                        font.family: Style.font.family
                                                        font.pixelSize: Style.font.caption
                                                        color: root.dim
                                                    }
                                                }

                                                MouseArea {
                                                    id: tagPillMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.tagMenuOpen ? root.closeTagMenu() : root.openTagMenu()
                                                }
                                            }
                                        }
                                    }

                                    // Phase / Status
                                    Item {
                                        width: parent.width
                                        height: Style.space(16)

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: Style.space(8)

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: {
                                                    if (!root.w) return ""
                                                    var isPaused = !root.running && (root.w.sessionDuration > 0 || (root.isPomodoro && root.w.remainingSeconds !== root.phaseTotal))
                                                    var state = root.running ? "" : (isPaused ? " · paused" : " · ready")
                                                    if (!root.isPomodoro) return "Stopwatch" + (root.running ? " · running" : (isPaused ? " · paused" : " · ready"))
                                                    if (root.w.pomodoroPhase === "shortBreak") {
                                                        var hasNoLong = root.w.pomodoroLongBreakDuration <= 0
                                                        return (hasNoLong ? "Break (" : "Short Break (") + Math.round(root.w.pomodoroShortBreakDuration / 60) + "m)" + state
                                                    }
                                                    if (root.w.pomodoroPhase === "longBreak") return "Long Break (" + Math.round(root.w.pomodoroLongBreakDuration / 60) + "m)" + state
                                                    return "Focus (" + Math.round(root.w.pomodoroWorkDuration / 60) + "m)" + state
                                                }
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption
                                                color: root.dim
                                            }

                                            // Zyklus-Punkte (nur Pomodoro mit langer Pause)
                                            Row {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: Style.space(4)
                                                visible: root.isPomodoro && (!root.w || root.w.pomodoroLongBreakDuration > 0)

                                                Repeater {
                                                    model: 4
                                                    Rectangle {
                                                        readonly property int done: root.w ? root.w.pomodoroCyclesCompleted % 4 : 0
                                                        width: Style.space(6)
                                                        height: width
                                                        radius: width / 2
                                                        color: index < done ? Color.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Fortschrittsbalken
                                    Rectangle {
                                        width: parent.width
                                        height: Style.space(4)
                                        radius: height / 2
                                        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)

                                        Rectangle {
                                            width: parent.width * root.timerProgress
                                            height: parent.height
                                            radius: height / 2
                                            color: Color.accent
                                            Behavior on width { NumberAnimation { duration: 300 } }
                                        }
                                    }

                                    // Pomodoro Presets (Standard, Deep Work, Ultradian) & Settings button
                                    RowLayout {
                                        width: parent.width
                                        visible: root.isPomodoro
                                        spacing: Style.space(6)

                                        Segmented {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Style.space(26)
                                            fg: root.fg
                                            value: root.currentPomodoroPreset
                                            options: [
                                                { value: "standard", label: "Standard", tip: "Standard: 25m Focus · 5m Break · 15m Long" },
                                                { value: "deepWork", label: "Deep Work", tip: "Deep Work: 50m Focus · 10m Break · 30m Long" },
                                                { value: "ultradian", label: "Ultradian", tip: "Ultradian: 90m Focus · 20m Break" }
                                            ]
                                            onPicked: function(v) {
                                                if (!root.w) return
                                                if (v === "standard") root.w.setPomodoroPreset(25, 5, 15)
                                                else if (v === "deepWork") root.w.setPomodoroPreset(50, 10, 30)
                                                else if (v === "ultradian") root.w.setPomodoroPreset(90, 20, 0)
                                            }
                                        }

                                        // Button to open Pomodoro duration settings
                                        Rectangle {
                                            Layout.preferredWidth: Style.space(26)
                                            Layout.preferredHeight: Style.space(26)
                                            radius: Style.space(6)
                                            color: root.pomodoroSettingsOpen
                                                ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                                                : (pomoGearMouse.containsMouse ? root.surfaceHover : root.surface)
                                            border.width: 1
                                            border.color: root.pomodoroSettingsOpen ? Color.accent : root.hairline

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰒓"
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption
                                                color: root.pomodoroSettingsOpen ? Color.accent : root.fg
                                            }

                                            MouseArea {
                                                id: pomoGearMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.pomodoroSettingsOpen = !root.pomodoroSettingsOpen
                                            }

                                            PanelToolTip {
                                                visible: pomoGearMouse.containsMouse
                                                text: "Adjust Pomodoro duration (Focus & Breaks)"
                                            }
                                        }
                                    }

                                    // Ausklappbare Zeiteinstellungen für Pomodoro
                                    Rectangle {
                                        width: parent.width
                                        visible: root.isPomodoro && root.pomodoroSettingsOpen
                                        implicitHeight: pomoSettingsCol.implicitHeight + Style.space(16)
                                        radius: Style.space(10)
                                        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
                                        border.width: 1
                                        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)

                                        Column {
                                            id: pomoSettingsCol
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: Style.space(10)
                                            spacing: Style.space(8)

                                            RowLayout {
                                                width: parent.width

                                                Text {
                                                    text: "ADJUST POMODORO TIMES"
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.caption * 0.85
                                                    font.bold: true
                                                    color: Color.accent
                                                }

                                                Item { Layout.fillWidth: true }

                                                Text {
                                                    text: "✕"
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.caption
                                                    color: closePomoMouse.containsMouse ? root.fg : root.dim

                                                    MouseArea {
                                                        id: closePomoMouse
                                                        anchors.fill: parent
                                                        anchors.margins: -Style.space(4)
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.pomodoroSettingsOpen = false
                                                    }
                                                }
                                            }

                                            // Stepper rows: Focus, Break, Long Break
                                            Repeater {
                                                model: {
                                                    var isNoLongBreak = root.w && root.w.pomodoroLongBreakDuration <= 0
                                                    var list = [
                                                        { phase: "work", icon: "🎯", label: "Focus Duration", step: 5, min: 5, max: 120 },
                                                        { phase: "shortBreak", icon: "☕", label: isNoLongBreak ? "Break" : "Short Break", step: 1, min: 1, max: 60 }
                                                    ]
                                                    if (!isNoLongBreak) {
                                                        list.push({ phase: "longBreak", icon: "🛋️", label: "Long Break", step: 5, min: 5, max: 60 })
                                                    }
                                                    return list
                                                }

                                                RowLayout {
                                                    id: stepperRow
                                                    width: parent.width
                                                    spacing: Style.space(6)
                                                    readonly property int currentSec: root.getPomodoroDuration(modelData.phase)

                                                    Text {
                                                        text: modelData.icon + " " + modelData.label
                                                        font.family: Style.font.family
                                                        font.pixelSize: Style.font.caption
                                                        color: root.fg
                                                        Layout.fillWidth: true
                                                    }

                                                    // Stepper: [-]  X min  [+]
                                                    Row {
                                                        spacing: Style.space(4)

                                                        // Minus Button
                                                        Rectangle {
                                                            width: Style.space(24)
                                                            height: Style.space(24)
                                                            radius: Style.space(5)
                                                            color: minusMouse.containsMouse ? root.surfaceHover : root.surface
                                                            border.width: 1
                                                            border.color: root.hairline

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "−"
                                                                font.family: Style.font.family
                                                                font.pixelSize: Style.font.bodySmall
                                                                font.bold: true
                                                                color: root.fg
                                                            }

                                                            MouseArea {
                                                                id: minusMouse
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    if (!root.w) return
                                                                    var curMins = Math.round(stepperRow.currentSec / 60)
                                                                    var nextMins = Math.max(modelData.min, curMins - modelData.step)
                                                                    root.w.setPomodoroDuration(modelData.phase, nextMins * 60)
                                                                }
                                                            }
                                                        }

                                                        // Minutes display
                                                        Rectangle {
                                                            width: Style.space(54)
                                                            height: Style.space(24)
                                                            radius: Style.space(5)
                                                            color: root.surface
                                                            border.width: 1
                                                            border.color: root.hairline

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: Math.round(stepperRow.currentSec / 60) + " min"
                                                                font.family: Style.font.family
                                                                font.pixelSize: Style.font.caption
                                                                font.bold: true
                                                                color: Color.accent
                                                            }
                                                        }

                                                        // Plus Button
                                                        Rectangle {
                                                            width: Style.space(24)
                                                            height: Style.space(24)
                                                            radius: Style.space(5)
                                                            color: plusMouse.containsMouse ? root.surfaceHover : root.surface
                                                            border.width: 1
                                                            border.color: root.hairline

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "+"
                                                                font.family: Style.font.family
                                                                font.pixelSize: Style.font.bodySmall
                                                                font.bold: true
                                                                color: root.fg
                                                            }

                                                            MouseArea {
                                                                id: plusMouse
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    if (!root.w) return
                                                                    var curMins = Math.round(stepperRow.currentSec / 60)
                                                                    var nextMins = Math.min(modelData.max, curMins + modelData.step)
                                                                    root.w.setPomodoroDuration(modelData.phase, nextMins * 60)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Stopwatch info line
                                    Text {
                                        width: parent.width
                                        visible: !root.isPomodoro
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: "Studied today: " + root.heatmapData.todayHours
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        color: root.dim
                                    }

                                    // Controls
                                    RowLayout {
                                        width: parent.width
                                        spacing: Style.space(8)

                                        // Primary Start/Pause button
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Style.space(34)
                                            radius: Style.space(8)
                                            color: root.running
                                                ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, startMouse.containsMouse ? 0.30 : 0.20)
                                                : (startMouse.containsMouse ? Qt.lighter(Color.accent, 1.12) : Color.accent)
                                            border.width: root.running ? 1 : 0
                                            border.color: Color.accent

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.running ? "󰏤  Pause" : "󰐊  Start"
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.body
                                                font.bold: true
                                                color: root.running ? Color.accent : Color.popups.background
                                            }

                                            MouseArea {
                                                id: startMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (root.w) root.w.toggleRunning()
                                            }
                                        }

                                        // Reset button (automatically logs started sessions >= 1 min)
                                        Rectangle {
                                            readonly property bool canReset: root.w && (
                                                root.running
                                                || root.w.sessionDuration > 0
                                                || (root.isPomodoro && root.w.remainingSeconds !== root.phaseTotal)
                                                || (!root.isPomodoro && root.w.elapsedSeconds > 0)
                                            )
                                            Layout.preferredWidth: Style.space(34)
                                            Layout.preferredHeight: Style.space(34)
                                            radius: Style.space(8)
                                            color: resetMouse.containsMouse && canReset ? root.surfaceHover : root.surface
                                            border.width: 1
                                            border.color: root.hairline
                                            opacity: canReset ? 1 : 0.4

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰑐"
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.icon
                                                color: root.fg
                                            }

                                            MouseArea {
                                                id: resetMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: parent.canReset
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: if (root.w) root.w.resetTimer()
                                            }

                                            PanelToolTip {
                                                visible: resetMouse.containsMouse
                                                text: "Reset (r)"
                                            }
                                        }
                                    }
                                }
                            }

                            // ---------------- Aktivitätsgraph (52-53 Wochen mit horizontalem Scrollen) ----------------
                            Rectangle {
                                width: parent.width
                                implicitHeight: heatmapSectionCol.implicitHeight + Style.space(24)
                                radius: Style.space(12)
                                color: root.surface
                                border.width: 1
                                border.color: root.hairline

                                Column {
                                    id: heatmapSectionCol
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: Style.space(12)
                                    spacing: Style.space(8)

                                    RowLayout {
                                        width: parent.width

                                        SectionLabel {
                                            fg: root.fg
                                            text: "ACTIVITY " + root.heatmapYear
                                        }

                                        // Navigation: scroll months & Today
                                        Row {
                                            spacing: Style.space(3)

                                            // Left (earlier months)
                                            Rectangle {
                                                width: Style.space(20)
                                                height: Style.space(20)
                                                radius: Style.space(4)
                                                color: scrollLeftMouse.containsMouse ? root.surfaceHover : "transparent"
                                                border.width: 1
                                                border.color: root.hairline

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰅁"
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.caption
                                                    color: root.dim
                                                }

                                                MouseArea {
                                                    id: scrollLeftMouse
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (heatmapFlick) {
                                                            var step = (Style.space(11) + Style.space(3)) * 4
                                                            heatmapFlick.contentX = Math.max(0, heatmapFlick.contentX - step)
                                                        }
                                                    }
                                                }

                                                PanelToolTip {
                                                    visible: scrollLeftMouse.containsMouse
                                                    text: "View earlier months"
                                                }
                                            }

                                            // Right (later months)
                                            Rectangle {
                                                width: Style.space(20)
                                                height: Style.space(20)
                                                radius: Style.space(4)
                                                color: scrollRightMouse.containsMouse ? root.surfaceHover : "transparent"
                                                border.width: 1
                                                border.color: root.hairline

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰅂"
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.caption
                                                    color: root.dim
                                                }

                                                MouseArea {
                                                    id: scrollRightMouse
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (heatmapFlick) {
                                                            var step = (Style.space(11) + Style.space(3)) * 4
                                                            var maxX = Math.max(0, heatmapFlick.contentWidth - heatmapFlick.width)
                                                            heatmapFlick.contentX = Math.min(maxX, heatmapFlick.contentX + step)
                                                        }
                                                    }
                                                }

                                                PanelToolTip {
                                                    visible: scrollRightMouse.containsMouse
                                                    text: "View later months"
                                                }
                                            }

                                            // Today Button
                                            Rectangle {
                                                height: Style.space(20)
                                                implicitWidth: todayLabel.implicitWidth + Style.space(10)
                                                radius: Style.space(4)
                                                color: todayMouse.containsMouse ? root.surfaceHover : "transparent"
                                                border.width: 1
                                                border.color: root.hairline

                                                Text {
                                                    id: todayLabel
                                                    anchors.centerIn: parent
                                                    text: "Today"
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.caption * 0.82
                                                    color: root.fg
                                                }

                                                MouseArea {
                                                    id: todayMouse
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (root.heatmapYear !== new Date().getFullYear()) {
                                                            root.heatmapYear = new Date().getFullYear()
                                                        }
                                                        root.scrollToCurrent()
                                                    }
                                                }

                                                PanelToolTip {
                                                    visible: todayMouse.containsMouse
                                                    text: "Jump to current months / Today"
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: "󰈸 " + root.heatmapData.streakDays + (root.heatmapData.streakDays === 1 ? " Day Streak" : " Days Streak")
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption
                                            font.bold: true
                                            color: root.heatmapData.streakDays > 0 ? Color.accent : root.dim
                                        }
                                    }

                                    // Kalenderjahr-Grid (Januar bis Dezember mit horizontalem Scrollen)
                                    Row {
                                        width: parent.width
                                        spacing: Style.space(6)

                                        // Weekdays left (Mon, Wed, Fri, Sun)
                                        Column {
                                            id: weekdayCol
                                            y: Style.space(15) // Offset for top month row
                                            spacing: Style.space(3)

                                            Repeater {
                                                model: ["Mon", "", "Wed", "", "Fri", "", "Sun"]
                                                Text {
                                                    width: Style.space(18)
                                                    height: Style.space(11)
                                                    text: modelData
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.caption * 0.72
                                                    color: root.faint
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                            }
                                        }

                                        // Scrollbarer Bereich für alle Kalenderwochen des Jahres
                                        Flickable {
                                            id: heatmapFlick
                                            width: parent.width - weekdayCol.width - Style.space(6)
                                            height: heatmapWeeksCol.implicitHeight + Style.space(6)
                                            clip: true
                                            contentWidth: Math.max(heatmapWeeksCol.implicitWidth, (Style.space(11) + Style.space(3)) * (root.heatmapData.weeks ? root.heatmapData.weeks.length : 53))
                                            contentHeight: height
                                            boundsBehavior: Flickable.StopAtBounds
                                            flickableDirection: Flickable.HorizontalFlick

                                            ScrollBar.horizontal: ScrollBar {
                                                policy: ScrollBar.AsNeeded
                                            }

                                            WheelHandler {
                                                target: null
                                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                                onWheel: function(event) {
                                                    var delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                                                    if (delta !== 0) {
                                                        var step = -delta * 0.5
                                                        var newX = heatmapFlick.contentX + step
                                                        var maxX = Math.max(0, heatmapFlick.contentWidth - heatmapFlick.width)
                                                        heatmapFlick.contentX = Math.max(0, Math.min(maxX, newX))
                                                        event.accepted = true
                                                    }
                                                }
                                            }

                                            Component.onCompleted: Qt.callLater(root.scrollToCurrent)

                                            Column {
                                                id: heatmapWeeksCol
                                                spacing: Style.space(3)

                                                // Monatsbeschriftung oben (Jan bis Dez)
                                                Row {
                                                    spacing: Style.space(3)

                                                    Repeater {
                                                        model: root.heatmapData.weeks

                                                        Item {
                                                            width: Style.space(11)
                                                            height: Style.space(12)

                                                            Text {
                                                                visible: modelData[0] && modelData[0].monthLabel && modelData[0].monthLabel.length > 0
                                                                text: modelData[0] ? (modelData[0].monthLabel || "") : ""
                                                                font.family: Style.font.family
                                                                font.pixelSize: Style.font.caption * 0.75
                                                                color: root.faint
                                                            }
                                                        }
                                                    }
                                                }

                                                // Wochenspalten
                                                Row {
                                                    spacing: Style.space(3)

                                                    Repeater {
                                                        model: root.heatmapData.weeks

                                                        Column {
                                                            spacing: Style.space(3)

                                                            Repeater {
                                                                model: modelData

                                                                Rectangle {
                                                                    width: Style.space(11)
                                                                    height: Style.space(11)
                                                                    radius: Style.space(2)
                                                                    color: {
                                                                        if (modelData.isOutsideYear) return "transparent"
                                                                        if (modelData.level === 4) return Color.accent
                                                                        if (modelData.level === 3) return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.75)
                                                                        if (modelData.level === 2) return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.50)
                                                                        if (modelData.level === 1) return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                                                                        if (modelData.isFuture) return Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
                                                                        return Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                                                                    }
                                                                    border.width: (modelData.isToday || cellMouse.containsMouse) ? 1 : 0
                                                                    border.color: cellMouse.containsMouse ? root.fg : Color.accent

                                                                    MouseArea {
                                                                        id: cellMouse
                                                                        anchors.fill: parent
                                                                        hoverEnabled: !modelData.isOutsideYear
                                                                        onEntered: root.hoveredCell = modelData
                                                                        onExited: if (root.hoveredCell === modelData) root.hoveredCell = null

                                                                        PanelToolTip {
                                                                            visible: cellMouse.containsMouse && !modelData.isOutsideYear
                                                                            delay: 150
                                                                            text: (modelData.isToday ? (modelData.dateStr + " (Today)") : modelData.dateStr) + " · " + (modelData.totalSeconds > 0 ? modelData.focusTimeStr : "No study time")
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Legend bottom right
                                    RowLayout {
                                        width: parent.width
                                        height: Style.space(18)
                                        spacing: Style.space(8)

                                        // Hover readout: Date & study time
                                        Text {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            visible: Boolean(root.hoveredCell && !root.hoveredCell.isOutsideYear)
                                            text: root.hoveredCell
                                                ? ((root.hoveredCell.isToday ? (root.hoveredCell.dateStr + " (Today)") : root.hoveredCell.dateStr) + ": " + (root.hoveredCell.totalSeconds > 0 ? root.hoveredCell.focusTimeStr : "No study time"))
                                                : ""
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption * 0.85
                                            font.bold: true
                                            color: root.fg
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            visible: !Boolean(root.hoveredCell && !root.hoveredCell.isOutsideYear)
                                        }

                                        Row {
                                            spacing: Style.space(3)
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "less"
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption * 0.8
                                                color: root.faint
                                            }
                                            Repeater {
                                                model: [0.07, 0.25, 0.5, 0.75, 1.0]
                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: Style.space(9)
                                                    height: width
                                                    radius: Style.space(2)
                                                    color: index === 0
                                                        ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07)
                                                        : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, modelData)
                                                }
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "more"
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption * 0.8
                                                color: root.faint
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // =========================================================
                    // TAB 2: STATISTICS (Hours per Subject)
                    // =========================================================
                    ColumnLayout {
                        spacing: Style.space(12)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(6)

                            StatTile {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                fg: root.fg
                                label: "TODAY"
                                value: root.heatmapData.todayHours
                                valueColor: Color.accent
                            }
                            StatTile {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                fg: root.fg
                                label: "7 DAYS"
                                value: root.weekStats.grandTotalHours
                            }
                            StatTile {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                fg: root.fg
                                label: "TOTAL"
                                value: root.heatmapData.totalHours
                            }
                            StatTile {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                fg: root.fg
                                label: "STREAK"
                                value: root.heatmapData.streakDays + (root.heatmapData.streakDays === 1 ? " Day" : " Days")
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(8)

                            SectionLabel {
                                Layout.fillWidth: true
                                fg: root.fg
                                text: "HOURS BY SUBJECT"
                            }
                            Segmented {
                                Layout.preferredWidth: Style.space(180)
                                Layout.preferredHeight: Style.space(26)
                                fg: root.fg
                                value: root.tagStatsScope
                                options: [
                                    { value: "today", label: "Today" },
                                    { value: "week", label: "Week" },
                                    { value: "all", label: "Total" }
                                ]
                                onPicked: function(v) { root.tagStatsScope = v }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ListView {
                                id: tagList
                                anchors.fill: parent
                                clip: true
                                spacing: Style.space(6)
                                boundsBehavior: Flickable.StopAtBounds
                                model: root.tagStatsData.tags
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                delegate: Rectangle {
                                    readonly property color tagCol: root.colorForTag(modelData.tag)
                                    readonly property bool isActive: modelData.tag === root.activeTag
                                    width: tagList.width
                                    height: Style.space(50)
                                    radius: Style.space(8)
                                    color: tagRowMouse.containsMouse ? root.surfaceHover : root.surface
                                    border.width: isActive ? 1 : 0
                                    border.color: Qt.rgba(tagCol.r, tagCol.g, tagCol.b, 0.5)

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: Style.space(10)
                                        spacing: Style.space(6)

                                        RowLayout {
                                            width: parent.width
                                            spacing: Style.space(8)

                                            Rectangle {
                                                width: Style.space(8)
                                                height: width
                                                radius: width / 2
                                                color: tagCol
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                                text: modelData.tag
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.bodySmall
                                                font.bold: true
                                                color: root.fg
                                            }
                                            Text {
                                                text: modelData.formatted
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.bodySmall
                                                font.bold: true
                                                color: root.fg
                                            }
                                            Text {
                                                Layout.preferredWidth: Style.space(34)
                                                horizontalAlignment: Text.AlignRight
                                                text: modelData.percent + "%"
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption
                                                color: root.dim
                                            }
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: Style.space(5)
                                            radius: height / 2
                                            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)

                                            Rectangle {
                                                width: Math.max(height, parent.width * modelData.ratio)
                                                height: parent.height
                                                radius: height / 2
                                                color: tagCol
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: tagRowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.w) root.w.activeTag = modelData.tag
                                    }

                                    PanelToolTip {
                                        visible: tagRowMouse.containsMouse
                                        text: modelData.sessionCount + " Sessions · " + modelData.hoursDec + " · Click: set as active subject"
                                    }
                                }
                            }

                            EmptyState {
                                anchors.centerIn: parent
                                visible: tagList.count === 0
                                icon: "󰄨"
                                title: root.heatmapData.totalSeconds === 0 ? "No Study Activity Yet" : "No Sessions in This Period"
                                description: root.heatmapData.totalSeconds === 0
                                    ? "Start a focus timer or stopwatch in the Focus tab to begin tracking subject statistics."
                                    : "No study sessions were logged during the selected timeframe (" + (root.tagStatsScope === "today" ? "Today" : (root.tagStatsScope === "week" ? "Last 7 Days" : "Total")) + ")."
                            }
                        }
                    }

                    // =========================================================
                    // =========================================================
                    // TAB 3: ACTIVITY (Study Session Apps)
                    // =========================================================
                    ColumnLayout {
                        spacing: Style.space(12)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(6)

                            StatTile {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                fg: root.fg
                                label: "STATUS"
                                value: {
                                    if (!root.running) return "Idle"
                                    if (root.isPomodoro && root.w && root.w.pomodoroPhase !== "work") return "Break"
                                    return "Tracking"
                                }
                                valueColor: {
                                    if (!root.running) return root.dim
                                    if (root.isPomodoro && root.w && root.w.pomodoroPhase !== "work") return root.dim
                                    return Color.accent
                                }
                            }
                            StatTile {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                fg: root.fg
                                label: "SESSION"
                                value: (root.w && root.w.sessionDuration > 0) ? Model.formatDurationHuman(root.w.sessionDuration) : "0 min"
                            }
                            StatTile {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                fg: root.fg
                                label: "TOTAL"
                                value: root.appUsageData.totalFormatted
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            SectionLabel {
                                Layout.fillWidth: true
                                fg: root.fg
                                text: "STUDY SESSION ACTIVITY"
                            }
                            Text {
                                text: root.appUsageData.apps ? (root.appUsageData.apps.length + (root.appUsageData.apps.length === 1 ? " App" : " Apps")) : "0 Apps"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                color: Color.accent
                            }
                        }

                        Segmented {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(26)
                            fg: root.fg
                            value: root.appScope
                            options: [
                                { value: "current", label: "Session" },
                                { value: "today", label: "Today" },
                                { value: "week", label: "Week" },
                                { value: "all", label: "Total" }
                            ]
                            onPicked: function(v) { root.appScope = v }
                        }

                        // Subject Filter: horizontally scrollable, fixed height
                        ListView {
                            id: filterList
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(24)
                            orientation: ListView.Horizontal
                            spacing: Style.space(6)
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            enabled: root.appScope !== "current"
                            opacity: enabled ? 1 : 0.35
                            model: [""].concat(root.w ? root.w.recentTags : [])

                            delegate: Rectangle {
                                readonly property bool sel: root.appTagFilter === modelData
                                readonly property color chipCol: modelData === "" ? Color.accent : root.colorForTag(modelData)
                                height: filterList.height
                                width: chipText.implicitWidth + Style.space(18)
                                radius: height / 2
                                color: sel ? Qt.rgba(chipCol.r, chipCol.g, chipCol.b, 0.22)
                                           : (chipMouse.containsMouse ? root.surfaceHover : root.surface)
                                border.width: 1
                                border.color: sel ? chipCol : root.hairline

                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: modelData === "" ? "All Subjects" : modelData
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    font.bold: parent.sel
                                    color: parent.sel ? root.fg : root.dim
                                }

                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.appTagFilter = modelData
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ListView {
                                id: appList
                                anchors.fill: parent
                                clip: true
                                spacing: Style.space(10)
                                boundsBehavior: Flickable.StopAtBounds
                                model: root.appUsageData.apps
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                delegate: Column {
                                    width: appList.width
                                    spacing: Style.space(4)

                                    RowLayout {
                                        width: parent.width
                                        spacing: Style.space(8)

                                        // Initial as app icon
                                        Rectangle {
                                            Layout.preferredWidth: Style.space(22)
                                            Layout.preferredHeight: Style.space(22)
                                            radius: Style.space(6)
                                            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.app.length > 0 ? modelData.app.charAt(0).toUpperCase() : "?"
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption
                                                font.bold: true
                                                color: Color.accent
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            text: modelData.app
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.bodySmall
                                            font.bold: true
                                            color: root.fg
                                        }
                                        Text {
                                            text: modelData.formatted
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption
                                            color: root.fg
                                        }
                                        Text {
                                            Layout.preferredWidth: Style.space(34)
                                            horizontalAlignment: Text.AlignRight
                                            text: modelData.percent + "%"
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption
                                            color: root.dim
                                        }
                                    }

                                    Rectangle {
                                        x: Style.space(30)
                                        width: parent.width - Style.space(30)
                                        height: Style.space(4)
                                        radius: height / 2
                                        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)

                                        Rectangle {
                                            width: Math.max(height, parent.width * modelData.ratio)
                                            height: parent.height
                                            radius: height / 2
                                            color: Color.accent
                                        }
                                    }
                                }
                            }

                            EmptyState {
                                anchors.centerIn: parent
                                visible: appList.count === 0
                                icon: "󰍹"
                                title: root.appScope === "current"
                                    ? (root.isPomodoro && root.w && root.w.pomodoroPhase !== "work"
                                        ? "Break in Progress"
                                        : (root.running ? "Tracking Activity…" : "Timer is Idle"))
                                    : (root.appTagFilter !== "" ? "No Data for \"" + root.appTagFilter + "\"" : "No Activity Data")
                                description: root.appScope === "current"
                                    ? (root.isPomodoro && root.w && root.w.pomodoroPhase !== "work"
                                        ? "App tracking is paused during breaks. Activity is only recorded while studying."
                                        : (root.running
                                            ? "Your active application is being recorded for this session."
                                            : "Start the study timer to track application activity in real time."))
                                    : (root.appTagFilter !== ""
                                        ? "No application activity was recorded under this subject during the selected period."
                                        : "No active application usage recorded in this period. Start studying to log app activity.")
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // Subject Menu (floats above content → panel dimensions stay constant)
            // -----------------------------------------------------------------
            MouseArea {
                anchors.fill: parent
                z: 50
                visible: root.tagMenuOpen
                onClicked: root.closeTagMenu()
            }

            Rectangle {
                id: tagMenu
                z: 51
                x: root.tagMenuX
                y: root.tagMenuY
                width: Style.space(280)
                height: Math.max(tagMenuCol.implicitHeight + Style.space(16), root.activeColorTarget.length > 0 ? (root.paletteTargetY + (typeof colorPaletteCard !== "undefined" && colorPaletteCard && colorPaletteCard.implicitHeight > 0 ? colorPaletteCard.implicitHeight : Style.space(200)) + Style.space(12)) : 0)
                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                radius: Style.space(10)
                color: Color.popups.background
                border.width: 1
                border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
                visible: opacity > 0
                opacity: root.tagMenuOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                // Do not propagate clicks inside menu to close area
                MouseArea { anchors.fill: parent }

                Column {
                    id: tagMenuCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Style.space(8)
                    spacing: Style.space(6)

                    // Input on top: color preview + type → create new subject
                    RowLayout {
                        id: tagInputRow
                        width: parent.width
                        spacing: Style.space(6)

                        // Color picker button for new subject
                        Rectangle {
                            id: newTagColorBtn
                            Layout.preferredWidth: Style.space(28)
                            Layout.preferredHeight: Style.space(28)
                            radius: Style.space(14)
                            readonly property color previewCol: root.newTagColor.length > 0
                                ? root.newTagColor
                                : (tagInput.text.trim().length > 0 ? Model.tagColor(tagInput.text.trim(), root.w ? root.w.tagColors : null) : Color.accent)
                            color: previewCol
                            border.width: root.activeColorTarget === "__new__" ? 2 : 1
                            border.color: root.activeColorTarget === "__new__" ? root.fg : Qt.rgba(0, 0, 0, 0.25)

                            Text {
                                anchors.centerIn: parent
                                visible: root.newTagColor.length === 0 && tagInput.text.trim().length === 0
                                text: "󰏘"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.iconLarge
                                color: "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.openColorPaletteForTag("__new__", newTagColorBtn)
                                }
                            }

                            PanelToolTip {
                                visible: parent.containsMouse || false
                                text: root.newTagColor.length > 0 ? ("Selected color: " + root.newTagColor) : "Choose color (optional)"
                            }
                        }

                        TextField {
                            id: tagInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(28)
                            foreground: root.fg
                            placeholderText: "New Subject…"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            maximumLength: 24
                            onAccepted: root.submitNewTag()
                            Keys.onEscapePressed: {
                                if (root.activeColorTarget.length > 0) root.activeColorTarget = ""
                                else root.closeTagMenu()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: Style.space(28)
                            Layout.preferredHeight: Style.space(28)
                            radius: Style.space(6)
                            readonly property bool can: tagInput.text.trim().length > 0
                            color: can ? Color.accent : root.surface
                            Text {
                                anchors.centerIn: parent
                                text: "󰐕"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.icon
                                color: parent.can ? Color.popups.background : root.dim
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.submitNewTag()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: root.hairline
                    }

                    // Filtered list of existing subjects
                    ListView {
                        id: tagMenuList
                        readonly property var filtered: {
                            var all = root.w ? root.w.recentTags : []
                            var q = tagInput.text.trim().toLowerCase()
                            if (q.length === 0) return all
                            return all.filter(function(t) { return t.toLowerCase().indexOf(q) !== -1 })
                        }
                        readonly property real rowH: Style.space(28)
                        width: parent.width
                        height: Math.max(rowH, Math.min(filtered.length, 6) * (rowH + spacing))
                        implicitHeight: height
                        spacing: Style.space(2)
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: filtered
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            id: tagRowItem
                            readonly property bool sel: modelData === root.activeTag
                            readonly property color tagCol: root.colorForTag(modelData)
                            readonly property bool isColorTarget: root.activeColorTarget === modelData
                            readonly property bool isHovered: rowHover.hovered || rowMouse.containsMouse || dotMouse.containsMouse || palIconMouse.containsMouse || trashMouse.containsMouse
                            width: tagMenuList.width
                            height: tagMenuList.rowH
                            radius: Style.space(6)
                            color: isColorTarget
                                ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
                                : (sel ? Qt.rgba(tagCol.r, tagCol.g, tagCol.b, 0.18)
                                       : (tagRowItem.isHovered ? root.surfaceHover : "transparent"))

                            HoverHandler {
                                id: rowHover
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.w) root.w.activeTag = modelData
                                    root.closeTagMenu()
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Style.space(8)
                                anchors.rightMargin: Style.space(6)
                                spacing: Style.space(6)

                                // Clickable color dot
                                Rectangle {
                                    id: tagDotBtn
                                    Layout.preferredWidth: Style.space(12)
                                    Layout.preferredHeight: Style.space(12)
                                    radius: Style.space(6)
                                    color: tagCol
                                    border.width: isColorTarget ? 2 : (dotMouse.containsMouse ? 1.5 : 1)
                                    border.color: isColorTarget ? Color.accent : (dotMouse.containsMouse ? root.fg : Qt.rgba(0, 0, 0, 0.2))

                                    MouseArea {
                                        id: dotMouse
                                        anchors.fill: parent
                                        anchors.margins: -Style.space(4)
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.openColorPaletteForTag(modelData, tagRowItem)
                                        }
                                    }

                                    PanelToolTip {
                                        visible: dotMouse.containsMouse
                                        text: "Customize color for “" + modelData + "”"
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: modelData
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.bodySmall
                                    font.bold: sel
                                    color: root.fg
                                }

                                // Color palette icon
                                Text {
                                    id: tagPalIcon
                                    visible: isColorTarget || tagRowItem.isHovered
                                    text: "󰏘"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    color: isColorTarget ? Color.accent : (palIconMouse.containsMouse ? Color.accent : root.dim)

                                    MouseArea {
                                        id: palIconMouse
                                        anchors.fill: parent
                                        anchors.margins: -Style.space(4)
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.openColorPaletteForTag(modelData, tagRowItem)
                                        }
                                    }

                                    PanelToolTip {
                                        visible: palIconMouse.containsMouse
                                        text: "Customize color"
                                    }
                                }

                                // Checkmark when active
                                Text {
                                    visible: sel && !tagRowItem.isHovered && !isColorTarget
                                    text: "󰄬"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    color: tagCol
                                }

                                // Trash icon
                                Text {
                                    visible: tagRowItem.isHovered
                                    text: "󰆴"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    color: trashMouse.containsMouse ? Color.urgent : root.dim

                                    MouseArea {
                                        id: trashMouse
                                        anchors.fill: parent
                                        anchors.margins: -Style.space(4)
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.w) {
                                            if (root.activeColorTarget === modelData) root.activeColorTarget = ""
                                            if (root.appTagFilter === modelData) root.appTagFilter = ""
                                            root.w.removeTag(modelData)
                                        }
                                    }

                                    PanelToolTip {
                                        visible: trashMouse.containsMouse
                                        text: "Delete subject"
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: tagMenuList.count === 0
                            text: "Enter → create \"" + tagInput.text.trim() + "\""
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            color: root.dim
                        }
                    }
                }

                // Floating / tracking color picker menu (directly positioned above selected tag)
                Rectangle {
                    id: colorPaletteCard
                    z: 60
                    x: Style.space(8)
                    width: parent.width - Style.space(16)
                    y: root.paletteTargetY
                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    implicitHeight: colorPickerCol.implicitHeight + Style.space(16)
                    radius: Style.space(8)
                    color: Color.popups.background
                    border.width: 1.5
                    border.color: Color.accent
                    visible: opacity > 0
                    opacity: root.activeColorTarget.length > 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    property real hueVal: 0.0
                    property real satVal: 1.0
                    property real briVal: 1.0
                    property bool isSyncing: false

                    readonly property color currentColor: {
                        if (root.activeColorTarget === "__new__") {
                            return root.newTagColor.length > 0 ? root.newTagColor : Color.accent
                        }
                        return root.colorForTag(root.activeColorTarget)
                    }

                    function syncFromTarget() {
                        if (!root.activeColorTarget || root.activeColorTarget.length === 0) return
                        var hex = ""
                        if (root.activeColorTarget === "__new__") {
                            hex = root.newTagColor.length > 0 ? root.newTagColor : (root.w ? Model.tagColor("", null) : "#3b82f6")
                        } else {
                            hex = root.colorForTag(root.activeColorTarget)
                        }
                        syncHsvFromHex(hex)
                    }

                    function syncHsvFromHex(hexStr) {
                        if (!hexStr) return
                        var hexNorm = String(hexStr).trim()
                        if (hexNorm.indexOf("#") !== 0) hexNorm = "#" + hexNorm
                        var hsv = Model.hexToHsv(hexNorm)
                        isSyncing = true
                        hueVal = hsv[0]
                        satVal = hsv[1]
                        briVal = hsv[2]
                        customHexInput.text = hexNorm.toLowerCase()
                        isSyncing = false
                    }

                    function applyFromSliders() {
                        if (isSyncing) return
                        var hex = Model.hsvToHex(hueVal, satVal, briVal)
                        isSyncing = true
                        customHexInput.text = hex
                        isSyncing = false
                        applyColorToTarget(hex)
                    }

                    function applyColorToTarget(hex) {
                        if (root.activeColorTarget === "__new__") {
                            root.newTagColor = hex
                        } else if (root.w && root.activeColorTarget.length > 0) {
                            root.w.setTagColor(root.activeColorTarget, hex)
                        }
                    }

                    function selectSwatch(hex) {
                        applyColorToTarget(hex)
                        syncHsvFromHex(hex)
                    }

                    function pickRandomColor() {
                        var hex = Model.randomCuratedOrHex(root.colorPalette)
                        selectSwatch(hex)
                    }

                    Component.onCompleted: syncFromTarget()

                    // Do not propagate clicks inside palette to list underneath
                    MouseArea { anchors.fill: parent }

                    Column {
                        id: colorPickerCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Style.space(8)
                        spacing: Style.space(6)

                        // Title row
                        RowLayout {
                            width: parent.width
                            spacing: Style.space(6)

                            Rectangle {
                                Layout.preferredWidth: Style.space(12)
                                Layout.preferredHeight: Style.space(12)
                                radius: Style.space(6)
                                color: colorPaletteCard.currentColor
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.4)
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.activeColorTarget === "__new__"
                                    ? "Color for new subject:"
                                    : "Color for “" + root.activeColorTarget + "”:"
                                elide: Text.ElideRight
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption * 0.85
                                font.bold: true
                                color: root.fg
                            }

                            Text {
                                text: "✕"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                color: closePalMouse.containsMouse ? root.fg : root.dim

                                MouseArea {
                                    id: closePalMouse
                                    anchors.fill: parent
                                    anchors.margins: -Style.space(4)
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activeColorTarget = ""
                                }
                            }
                        }

                        // Curated Swatches Grid: A 2-row grid of 7 circular color swatches
                        Grid {
                            id: swatchesGrid
                            anchors.horizontalCenter: parent.horizontalCenter
                            columns: 7
                            rows: 2
                            rowSpacing: Style.space(6)
                            columnSpacing: Style.space(6)

                            Repeater {
                                model: root.colorPalette

                                Rectangle {
                                    id: swatchCircle
                                    width: Style.space(24)
                                    height: Style.space(24)
                                    radius: width / 2
                                    color: modelData
                                    readonly property bool isCurrent: {
                                        var cur = root.activeColorTarget === "__new__"
                                            ? root.newTagColor
                                            : (root.w && root.w.tagColors ? root.w.tagColors[root.activeColorTarget] : "")
                                        return Boolean(cur && cur.toLowerCase() === modelData.toLowerCase())
                                    }
                                    border.width: isCurrent ? 2.5 : (swatchMouse.containsMouse ? 2 : 1)
                                    border.color: isCurrent ? "#ffffff" : (swatchMouse.containsMouse ? Color.accent : Qt.rgba(0, 0, 0, 0.35))
                                    scale: swatchMouse.containsMouse ? 1.12 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 90 } }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: parent.isCurrent
                                        text: "✓"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption * 0.75
                                        font.bold: true
                                        color: "#ffffff"
                                    }

                                    MouseArea {
                                        id: swatchMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: colorPaletteCard.selectSwatch(modelData)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.hairline
                        }

                        // Interactive HSV Chooser: Hue, Saturation, Brightness Sliders
                        // Hue Slider (0° - 360°)
                        RowLayout {
                            width: parent.width
                            spacing: Style.space(6)

                            Text {
                                Layout.preferredWidth: Style.space(24)
                                text: "Hue"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption * 0.75
                                font.bold: true
                                color: root.dim
                            }

                            Item {
                                id: hueTrackBox
                                Layout.fillWidth: true
                                Layout.preferredHeight: Style.space(16)

                                Rectangle {
                                    id: hueTrack
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: Style.space(10)
                                    radius: Style.space(5)
                                    border.width: 1
                                    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.2)
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.00; color: "#ff0000" }
                                        GradientStop { position: 0.17; color: "#ffff00" }
                                        GradientStop { position: 0.33; color: "#00ff00" }
                                        GradientStop { position: 0.50; color: "#00ffff" }
                                        GradientStop { position: 0.67; color: "#0000ff" }
                                        GradientStop { position: 0.83; color: "#ff00ff" }
                                        GradientStop { position: 1.00; color: "#ff0000" }
                                    }
                                }

                                Rectangle {
                                    id: hueThumb
                                    width: Style.space(16)
                                    height: Style.space(16)
                                    radius: width / 2
                                    x: Math.max(0, Math.min(hueTrackBox.width - width, colorPaletteCard.hueVal * (hueTrackBox.width - width)))
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Qt.hsva(colorPaletteCard.hueVal, 1.0, 1.0, 1.0)
                                    border.width: 2
                                    border.color: "#ffffff"
                                }

                                MouseArea {
                                    id: hueMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true

                                    function updateVal(mouse) {
                                        var usable = hueTrackBox.width - hueThumb.width
                                        if (usable <= 0) return
                                        var rx = Math.max(0, Math.min(usable, mouse.x - hueThumb.width / 2))
                                        colorPaletteCard.hueVal = rx / usable
                                        colorPaletteCard.applyFromSliders()
                                    }

                                    onPressed: function(mouse) { updateVal(mouse) }
                                    onPositionChanged: function(mouse) { if (pressed) updateVal(mouse) }
                                }
                            }

                            Text {
                                Layout.preferredWidth: Style.space(32)
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(colorPaletteCard.hueVal * 360) + "°"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption * 0.75
                                color: root.fg
                            }
                        }

                        // Saturation Slider (0% - 100%)
                        RowLayout {
                            width: parent.width
                            spacing: Style.space(6)

                            Text {
                                Layout.preferredWidth: Style.space(24)
                                text: "Sat"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption * 0.75
                                font.bold: true
                                color: root.dim
                            }

                            Item {
                                id: satTrackBox
                                Layout.fillWidth: true
                                Layout.preferredHeight: Style.space(16)

                                Rectangle {
                                    id: satTrack
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: Style.space(10)
                                    radius: Style.space(5)
                                    border.width: 1
                                    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.2)
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: Qt.hsva(colorPaletteCard.hueVal, 0.0, colorPaletteCard.briVal, 1.0) }
                                        GradientStop { position: 1.0; color: Qt.hsva(colorPaletteCard.hueVal, 1.0, colorPaletteCard.briVal, 1.0) }
                                    }
                                }

                                Rectangle {
                                    id: satThumb
                                    width: Style.space(16)
                                    height: Style.space(16)
                                    radius: width / 2
                                    x: Math.max(0, Math.min(satTrackBox.width - width, colorPaletteCard.satVal * (satTrackBox.width - width)))
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Qt.hsva(colorPaletteCard.hueVal, colorPaletteCard.satVal, colorPaletteCard.briVal, 1.0)
                                    border.width: 2
                                    border.color: "#ffffff"
                                }

                                MouseArea {
                                    id: satMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true

                                    function updateVal(mouse) {
                                        var usable = satTrackBox.width - satThumb.width
                                        if (usable <= 0) return
                                        var rx = Math.max(0, Math.min(usable, mouse.x - satThumb.width / 2))
                                        colorPaletteCard.satVal = rx / usable
                                        colorPaletteCard.applyFromSliders()
                                    }

                                    onPressed: function(mouse) { updateVal(mouse) }
                                    onPositionChanged: function(mouse) { if (pressed) updateVal(mouse) }
                                }
                            }

                            Text {
                                Layout.preferredWidth: Style.space(32)
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(colorPaletteCard.satVal * 100) + "%"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption * 0.75
                                color: root.fg
                            }
                        }

                        // Brightness Slider (0% - 100%)
                        RowLayout {
                            width: parent.width
                            spacing: Style.space(6)

                            Text {
                                Layout.preferredWidth: Style.space(24)
                                text: "Bri"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption * 0.75
                                font.bold: true
                                color: root.dim
                            }

                            Item {
                                id: briTrackBox
                                Layout.fillWidth: true
                                Layout.preferredHeight: Style.space(16)

                                Rectangle {
                                    id: briTrack
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: Style.space(10)
                                    radius: Style.space(5)
                                    border.width: 1
                                    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.2)
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "#000000" }
                                        GradientStop { position: 1.0; color: Qt.hsva(colorPaletteCard.hueVal, colorPaletteCard.satVal, 1.0, 1.0) }
                                    }
                                }

                                Rectangle {
                                    id: briThumb
                                    width: Style.space(16)
                                    height: Style.space(16)
                                    radius: width / 2
                                    x: Math.max(0, Math.min(briTrackBox.width - width, colorPaletteCard.briVal * (briTrackBox.width - width)))
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Qt.hsva(colorPaletteCard.hueVal, colorPaletteCard.satVal, colorPaletteCard.briVal, 1.0)
                                    border.width: 2
                                    border.color: "#ffffff"
                                }

                                MouseArea {
                                    id: briMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true

                                    function updateVal(mouse) {
                                        var usable = briTrackBox.width - briThumb.width
                                        if (usable <= 0) return
                                        var rx = Math.max(0, Math.min(usable, mouse.x - briThumb.width / 2))
                                        colorPaletteCard.briVal = rx / usable
                                        colorPaletteCard.applyFromSliders()
                                    }

                                    onPressed: function(mouse) { updateVal(mouse) }
                                    onPositionChanged: function(mouse) { if (pressed) updateVal(mouse) }
                                }
                            }

                            Text {
                                Layout.preferredWidth: Style.space(32)
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(colorPaletteCard.briVal * 100) + "%"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption * 0.75
                                color: root.fg
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.hairline
                        }

                        // Bottom Row: Optional HEX field and 🎲 Random / Shuffle button
                        RowLayout {
                            width: parent.width
                            spacing: Style.space(6)

                            TextField {
                                id: customHexInput
                                Layout.fillWidth: true
                                Layout.preferredHeight: Style.space(26)
                                foreground: root.fg
                                placeholderText: "#HEX (e.g. #3b82f6)"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption * 0.85
                                maximumLength: 7
                                onTextChanged: {
                                    if (colorPaletteCard.isSyncing) return
                                    var h = text.trim()
                                    if (h.indexOf("#") !== 0 && h.length > 0) h = "#" + h
                                    if (Model.hexToRgb(h)) {
                                        colorPaletteCard.isSyncing = true
                                        var hsv = Model.hexToHsv(h)
                                        colorPaletteCard.hueVal = hsv[0]
                                        colorPaletteCard.satVal = hsv[1]
                                        colorPaletteCard.briVal = hsv[2]
                                        colorPaletteCard.applyColorToTarget(h)
                                        colorPaletteCard.isSyncing = false
                                    }
                                }
                                onAccepted: {
                                    var h = text.trim()
                                    if (h.indexOf("#") !== 0 && h.length > 0) h = "#" + h
                                    if (Model.hexToRgb(h)) {
                                        colorPaletteCard.selectSwatch(h)
                                    }
                                }
                            }

                            Rectangle {
                                id: randomBtn
                                Layout.preferredHeight: Style.space(26)
                                Layout.preferredWidth: Style.space(32)
                                radius: Style.space(5)
                                color: randomMouse.containsMouse ? root.surfaceHover : root.surface
                                border.width: 1
                                border.color: randomMouse.containsMouse ? Color.accent : root.hairline

                                Text {
                                    anchors.centerIn: parent
                                    text: "🎲"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                }

                                MouseArea {
                                    id: randomMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: colorPaletteCard.pickRandomColor()
                                }

                                PanelToolTip {
                                    visible: randomMouse.containsMouse
                                    text: "Random color (🎲)"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
