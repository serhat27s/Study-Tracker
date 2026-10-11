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

    // 0: Fokus (Timer + Aktivität), 1: Statistik (Stunden pro Fach), 2: System (Uptime + Programme)
    property int currentTab: 0

    property bool tagMenuOpen: false
    property real tagMenuX: 0
    property real tagMenuY: 0
    property bool pomodoroSettingsOpen: false

    property string tagStatsScope: "week"   // "today" | "week" | "all"
    property string appScope: "today"       // "current" | "today" | "week" | "all"
    property string appTagFilter: ""        // "" = alle Fächer
    property var hoveredCell: null
    property int heatmapYear: new Date().getFullYear()

    // Feste Panelgröße – 420x560 kompakter Standard
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
    readonly property string activeTag: w ? w.activeTag : "Allgemein"

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
        : { year: root.heatmapYear, weeks: [], numWeeks: 0, todayWeekIndex: 0, totalSeconds: 0, yearHours: "0.0 Std.", todayHours: "0.0 Std.", totalHours: "0.0 Std.", streakDays: 0, sessionCount: 0 }

    readonly property var tagStatsData: w
        ? Model.aggregateTagStats(w.history, root.tagStatsScope)
        : { tags: [], grandTotalSeconds: 0, grandTotalFormatted: "0 Min.", grandTotalHours: "0.0 Std." }

    readonly property var weekStats: w
        ? Model.aggregateTagStats(w.history, "week")
        : { grandTotalHours: "0.0 Std." }

    readonly property var appUsageData: w
        ? Model.aggregateAppUsage(w.history, w.currentAppUsage, root.appScope, root.appTagFilter)
        : { apps: [], totalSeconds: 0, totalFormatted: "0 Min.", totalHours: "0.0 Std." }

    function colorForTag(name) {
        var tags = w ? w.recentTags : []
        var idx = tags.indexOf(name)
        return Model.tagColor(name, idx)
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
            if (w) w.refreshUptime()
            Qt.callLater(root.scrollToCurrent)
        }
    }

    function open() {
        if (w) w.refreshUptime()
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
        if (i === 2 && w) w.refreshUptime()
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
        root.tagMenuX = Math.max(0, Math.min(keyCatcher.width - menuW, p.x + tagPill.width / 2 - menuW / 2))
        root.tagMenuY = p.y + tagPill.height + Style.space(6)
        root.tagMenuOpen = true
        Qt.callLater(function() { tagInput.forceActiveFocus() })
    }

    function closeTagMenu() {
        if (!root.tagMenuOpen) return
        root.tagMenuOpen = false
        tagInput.text = ""
        keyCatcher.forceActiveFocus()
    }

    function submitNewTag() {
        var t = tagInput.text.trim()
        if (w && t.length > 0) w.addTag(t)
        root.closeTagMenu()
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
                        { value: "0", label: "Fokus", icon: "󰔛" },
                        { value: "1", label: "Statistik", icon: "󰄨" },
                        { value: "2", label: "System", icon: "󰍹" }
                    ]
                    onPicked: function(v) { root.setTab(parseInt(v)) }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.currentTab

                    // =========================================================
                    // TAB 1: FOKUS
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

                            // ---------------- Timer-Karte ----------------
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

                                    // Modus
                                    Segmented {
                                        width: parent.width
                                        fg: root.fg
                                        value: root.isPomodoro ? "pomodoro" : "tracker"
                                        options: [
                                            { value: "pomodoro", label: "Pomodoro", icon: "󰄉" },
                                            { value: "tracker", label: "Stoppuhr", icon: "󱎫" }
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
                                                    var state = root.running ? "" : (isPaused ? " · pausiert" : " · bereit")
                                                    if (!root.isPomodoro) return "Stoppuhr" + (root.running ? " · läuft" : (isPaused ? " · pausiert" : " · bereit"))
                                                    if (root.w.pomodoroPhase === "shortBreak") return "Kurze Pause (" + Math.round(root.w.pomodoroShortBreakDuration / 60) + "m)" + state
                                                    if (root.w.pomodoroPhase === "longBreak") return "Lange Pause (" + Math.round(root.w.pomodoroLongBreakDuration / 60) + "m)" + state
                                                    return "Fokus (" + Math.round(root.w.pomodoroWorkDuration / 60) + "m)" + state
                                                }
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption
                                                color: root.dim
                                            }

                                            // Zyklus-Punkte (nur Pomodoro)
                                            Row {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: Style.space(4)
                                                visible: root.isPomodoro

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

                                    // Pomodoro-Presets (Standard, Deep Work, Ultradian) mit Einstellungs-Button bzw. Info-Zeile (Stoppuhr)
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
                                                { value: "standard", label: "Standard", tip: "Standard: 25m Fokus · 5m Pause · 15m Lang" },
                                                { value: "deepWork", label: "Deep Work", tip: "Deep Work: 50m Fokus · 10m Pause · 30m Lang" },
                                                { value: "ultradian", label: "Ultradian", tip: "Ultradian: 90m Fokus · 20m Pause" }
                                            ]
                                            onPicked: function(v) {
                                                if (!root.w) return
                                                if (v === "standard") root.w.setPomodoroPreset(25, 5, 15)
                                                else if (v === "deepWork") root.w.setPomodoroPreset(50, 10, 30)
                                                else if (v === "ultradian") root.w.setPomodoroPreset(90, 20, 20)
                                            }
                                        }

                                        // Button zum Öffnen der Pomodoro-Zeiteinstellungen
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
                                                text: "Pomodoro-Dauer anpassen (Fokus & Pausen)"
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
                                                    text: "POMODORO ZEITEN ANPASSEN"
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

                                            // 3 Stepper-Zeilen: Fokus, Kurze Pause, Lange Pause
                                            Repeater {
                                                model: [
                                                    { phase: "work", icon: "🎯", label: "Fokus-Zeit", step: 5, min: 5, max: 120 },
                                                    { phase: "shortBreak", icon: "☕", label: "Kurze Pause", step: 1, min: 1, max: 30 },
                                                    { phase: "longBreak", icon: "🛋️", label: "Lange Pause", step: 5, min: 5, max: 60 }
                                                ]

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

                                                    // Stepper: [-]  X Min.  [+]
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

                                                        // Anzeige Minuten
                                                        Rectangle {
                                                            width: Style.space(54)
                                                            height: Style.space(24)
                                                            radius: Style.space(5)
                                                            color: root.surface
                                                            border.width: 1
                                                            border.color: root.hairline

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: Math.round(stepperRow.currentSec / 60) + " Min."
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

                                    // Stoppuhr Info-Zeile
                                    Text {
                                        width: parent.width
                                        visible: !root.isPomodoro
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: "Heute gelernt: " + root.heatmapData.todayHours
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        color: root.dim
                                    }

                                    // Steuerung
                                    RowLayout {
                                        width: parent.width
                                        spacing: Style.space(8)

                                        // Primärer Start/Pause-Button
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

                                        // Zurücksetzen-Button (speichert angefangene Sessions ab 1 Min. automatisch)
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
                                                text: "Zurücksetzen (r)"
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
                                            text: "AKTIVITÄT " + root.heatmapYear
                                        }

                                        // Navigation: Monate scrollen & Heute
                                        Row {
                                            spacing: Style.space(3)

                                            // Nach links (frühere Monate)
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
                                                    text: "Frühere Monate anzeigen"
                                                }
                                            }

                                            // Nach rechts (spätere Monate)
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
                                                    text: "Spätere Monate anzeigen"
                                                }
                                            }

                                            // Heute-Button
                                            Rectangle {
                                                height: Style.space(20)
                                                implicitWidth: heuteLabel.implicitWidth + Style.space(10)
                                                radius: Style.space(4)
                                                color: heuteMouse.containsMouse ? root.surfaceHover : "transparent"
                                                border.width: 1
                                                border.color: root.hairline

                                                Text {
                                                    id: heuteLabel
                                                    anchors.centerIn: parent
                                                    text: "Heute"
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.caption * 0.82
                                                    color: root.fg
                                                }

                                                MouseArea {
                                                    id: heuteMouse
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
                                                    visible: heuteMouse.containsMouse
                                                    text: "Zu aktuellen Monaten / Heute springen"
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: "󰈸 " + root.heatmapData.streakDays + " Tage Streak"
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

                                        // Wochentage links (Mo, Mi, Fr, So)
                                        Column {
                                            id: weekdayCol
                                            y: Style.space(15) // Offset für Monatsleiste oben
                                            spacing: Style.space(3)

                                            Repeater {
                                                model: ["Mo", "", "Mi", "", "Fr", "", "So"]
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
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Legende unten rechts (unten links frei)
                                    RowLayout {
                                        width: parent.width
                                        height: Style.space(18)
                                        spacing: Style.space(8)

                                        Item { Layout.fillWidth: true }

                                        Row {
                                            spacing: Style.space(3)
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "weniger"
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
                                                text: "mehr"
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
                    // TAB 2: STATISTIK (Stunden pro Fach)
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
                                label: "HEUTE"
                                value: root.heatmapData.todayHours
                                valueColor: Color.accent
                            }
                            StatTile {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                fg: root.fg
                                label: "7 TAGE"
                                value: root.weekStats.grandTotalHours
                            }
                            StatTile {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                fg: root.fg
                                label: "GESAMT"
                                value: root.heatmapData.totalHours
                            }
                            StatTile {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                fg: root.fg
                                label: "STREAK"
                                value: root.heatmapData.streakDays + " Tage"
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.space(8)

                            SectionLabel {
                                Layout.fillWidth: true
                                fg: root.fg
                                text: "STUNDEN NACH FACH"
                            }
                            Segmented {
                                Layout.preferredWidth: Style.space(180)
                                Layout.preferredHeight: Style.space(26)
                                fg: root.fg
                                value: root.tagStatsScope
                                options: [
                                    { value: "today", label: "Heute" },
                                    { value: "week", label: "Woche" },
                                    { value: "all", label: "Gesamt" }
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
                                        text: modelData.sessionCount + " Sessions · " + modelData.hoursDec + " · Klick: als aktives Fach setzen"
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: tagList.count === 0
                                text: "Noch keine Lernzeit in diesem Zeitraum"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                color: root.dim
                            }
                        }
                    }

                    // =========================================================
                    // TAB 3: SYSTEM (Uptime + Programme)
                    // =========================================================
                    ColumnLayout {
                        spacing: Style.space(12)

                        // Uptime-Karte
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(64)
                            radius: Style.space(12)
                            color: root.surface
                            border.width: 1
                            border.color: root.hairline

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Style.space(12)
                                spacing: Style.space(12)

                                Rectangle {
                                    Layout.preferredWidth: Style.space(40)
                                    Layout.preferredHeight: Style.space(40)
                                    radius: Style.space(10)
                                    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰔟"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.iconLarge
                                        color: Color.accent
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: Style.space(2)

                                    SectionLabel {
                                        width: parent.width
                                        fg: root.fg
                                        font.pixelSize: Style.font.caption * 0.85
                                        text: "SYSTEM LÄUFT SEIT"
                                    }
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: Model.formatUptime(root.w ? root.w.systemUptimeSeconds : 0)
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.heading
                                        font.bold: true
                                        color: root.fg
                                    }
                                }

                                Column {
                                    spacing: Style.space(2)

                                    Text {
                                        anchors.right: parent.right
                                        text: "GESTARTET"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption * 0.85
                                        font.bold: true
                                        color: root.dim
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        text: {
                                            var up = root.w ? root.w.systemUptimeSeconds : 0
                                            if (up <= 0) return "–"
                                            var d = new Date(Date.now() - up * 1000)
                                            return Model.padZero(d.getHours()) + ":" + Model.padZero(d.getMinutes()) + " Uhr"
                                        }
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.bodySmall
                                        font.bold: true
                                        color: root.fg
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            SectionLabel {
                                Layout.fillWidth: true
                                fg: root.fg
                                text: "PROGRAMMNUTZUNG"
                            }
                            Text {
                                text: root.appUsageData.totalFormatted
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
                                { value: "today", label: "Heute" },
                                { value: "week", label: "Woche" },
                                { value: "all", label: "Gesamt" }
                            ]
                            onPicked: function(v) { root.appScope = v }
                        }

                        // Fach-Filter: horizontal scrollbar, feste Höhe
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
                                    text: modelData === "" ? "Alle Fächer" : modelData
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

                                        // Initiale als App-"Icon"
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

                            Column {
                                anchors.centerIn: parent
                                visible: appList.count === 0
                                spacing: Style.space(4)

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰄶"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.display
                                    color: root.faint
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.appScope === "current"
                                        ? "Starte den Timer, um Programme zu erfassen"
                                        : "Keine Programmnutzung in diesem Zeitraum"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    color: root.dim
                                }
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // Tag-Menü (schwebt über dem Inhalt → Panelgröße bleibt konstant)
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
                width: Style.space(230)
                height: tagMenuCol.implicitHeight + Style.space(16)
                radius: Style.space(10)
                color: Color.popups.background
                border.width: 1
                border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
                visible: opacity > 0
                opacity: root.tagMenuOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                // Klicks im Menü nicht zum Schließen durchreichen
                MouseArea { anchors.fill: parent }

                Column {
                    id: tagMenuCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Style.space(8)
                    spacing: Style.space(6)

                    // Eingabe ganz oben: tippen → neues Fach anlegen
                    RowLayout {
                        width: parent.width
                        spacing: Style.space(6)

                        TextField {
                            id: tagInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: Style.space(30)
                            foreground: root.fg
                            placeholderText: "Neues Fach…"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            maximumLength: 24
                            onAccepted: root.submitNewTag()
                            Keys.onEscapePressed: root.closeTagMenu()
                        }

                        Rectangle {
                            Layout.preferredWidth: Style.space(30)
                            Layout.preferredHeight: Style.space(30)
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

                    // Gefilterte Liste vorhandener Fächer
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
                            readonly property bool sel: modelData === root.activeTag
                            readonly property color tagCol: root.colorForTag(modelData)
                            width: tagMenuList.width
                            height: tagMenuList.rowH
                            radius: Style.space(6)
                            color: sel ? Qt.rgba(tagCol.r, tagCol.g, tagCol.b, 0.18)
                                       : (rowMouse.containsMouse ? root.surfaceHover : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Style.space(8)
                                anchors.rightMargin: Style.space(6)
                                spacing: Style.space(8)

                                Rectangle {
                                    Layout.preferredWidth: Style.space(8)
                                    Layout.preferredHeight: Style.space(8)
                                    radius: Style.space(4)
                                    color: tagCol
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
                                Text {
                                    visible: sel && !rowMouse.containsMouse
                                    text: "󰄬"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.caption
                                    color: tagCol
                                }
                                Text {
                                    visible: rowMouse.containsMouse
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
                                        onClicked: if (root.w) root.w.removeTag(modelData)
                                    }
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                anchors.rightMargin: Style.space(24)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.w) root.w.activeTag = modelData
                                    root.closeTagMenu()
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: tagMenuList.count === 0
                            text: "Enter → \"" + tagInput.text.trim() + "\" anlegen"
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            color: root.dim
                        }
                    }
                }
            }
        }
    }
}
