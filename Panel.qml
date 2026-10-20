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

    // 0: Focus (Timer + Activity Graph), 1: Statistics (Consistency, Subject Hours & Session Depth)
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
    property bool consistencySettingsOpen: false

    readonly property var colorPalette: Model.TAG_COLORS

    property string tagStatsScope: "week"   // "today" | "week" | "month" | "all"
    property string hoveredSubjectTag: ""
    property var hoveredCell: null
    property int heatmapYear: new Date().getFullYear()

    // Panel dimensions: 440x590 for comfortable typography and layout
    readonly property int panelWidth: Style.space(440)
    readonly property int panelInnerHeight: Style.space(590)

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
    readonly property var listedTags: w ? w.recentTags : []

    function isTagListed(name) {
        var clean = String(name || "").trim().toLowerCase()
        if (clean.length === 0) return false
        var tags = root.listedTags || []
        for (var i = 0; i < tags.length; i++) {
            if (String(tags[i]).trim().toLowerCase() === clean) return true
        }
        return false
    }

    readonly property int phaseTotal: w ? w.phaseDuration() : 1500
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

    readonly property var heatmapData: (w && root.opened && root.currentTab === 0)
        ? Model.buildHeatmap(w.history, root.heatmapYear)
        : { year: root.heatmapYear, weeks: [], numWeeks: 0, todayWeekIndex: 0, totalSeconds: 0, yearHours: "0.0 hrs", todayHours: "0.0 hrs", streakDays: 0 }

    readonly property var tagStatsData: (w && root.opened && root.currentTab === 1)
        ? Model.aggregateTagStats(w.history, root.tagStatsScope)
        : { tags: [], grandTotalSeconds: 0, grandTotalHours: "0.0 hrs" }

    readonly property var sessionQualityData: (w && root.opened && root.currentTab === 1)
        ? Model.calculateSessionQuality(w.history, root.tagStatsScope)
        : { totalSeconds: 0, totalCount: 0, avgMinutes: 0, deepRatio: 0, focusedRatio: 0, shallowRatio: 0, deepPct: 0, tiers: [] }

    readonly property var consistencyData: (w && root.opened && root.currentTab === 1)
        ? Model.calculateConsistency(w.history, Math.floor((w.isStudySession ? w.sessionDuration : 0) / 60) * 60, {
            goalMode: w.goalMode,
            targetHours: w.goalTargetHours,
            targetBlocks: w.goalTargetBlocks,
            blockPreset: w.goalBlockPreset,
            weekendsEnabled: w.goalWeekendsEnabled
        })
        : {
            goalMode: "hours", targetHours: 4.0, targetBlocks: 2, blockPreset: "deepWork", blockMinutes: 50,
            weekendsEnabled: false, badgeText: "🎯 4h",
            weekDays: [], weekMetCount: 0, weekRequiredCount: 5,
            goalStreak: 0, hitRate30: 0, reqMet30: 0, reqTotal30: 22
        }

    function colorForTag(name) {
        if (!name) return Color.accent
        var colors = w ? w.tagColors : null
        return Model.tagColor(name, colors)
    }

    function getPomodoroDuration(phase) {
        return w ? w.phaseDuration(phase) : 1500
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
        root.hoveredSubjectTag = ""
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
        root.activeColorTarget = ""
        root.newTagColor = ""
        tagInput.text = ""
        Qt.callLater(function() {
            root.tagMenuOpen = false
            keyCatcher.forceActiveFocus()
        })
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
        property real fontSize: Style.font.bodySmall
        signal picked(string value)

        implicitHeight: Style.space(30)
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

    // Abschnittsüberschrift
    component SectionLabel: Text {
        property color fg: Color.foreground
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        font.letterSpacing: 0.6
        color: Qt.darker(fg, 1.5)
    }

    component ColorSlider: RowLayout {
        id: cSlider
        property string label: ""
        property real value: 0.0
        property string displayValue: ""
        property color thumbColor: "#ffffff"
        property Gradient trackGradient: null
        signal moved(real newValue)
        signal released()

        width: parent ? parent.width : 0
        spacing: Style.space(6)

        Text {
            Layout.preferredWidth: Style.space(28)
            text: cSlider.label
            font.family: Style.font.family
            font.pixelSize: Style.font.caption * 0.88
            font.bold: true
            color: root.dim
        }

        Item {
            id: trackBox
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(16)

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(10)
                radius: Style.space(5)
                border.width: 1
                border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.2)
                gradient: cSlider.trackGradient
            }

            Rectangle {
                id: thumb
                width: Style.space(16)
                height: Style.space(16)
                radius: width / 2
                x: Math.max(0, Math.min(trackBox.width - width, cSlider.value * (trackBox.width - width)))
                anchors.verticalCenter: parent.verticalCenter
                color: cSlider.thumbColor
                border.width: 2
                border.color: "#ffffff"
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function updateVal(mouse) {
                    var usable = trackBox.width - thumb.width
                    if (usable <= 0) return
                    var rx = Math.max(0, Math.min(usable, mouse.x - thumb.width / 2))
                    cSlider.moved(rx / usable)
                }

                onPressed: function(mouse) { updateVal(mouse) }
                onPositionChanged: function(mouse) { if (pressed) updateVal(mouse) }
                onReleased: cSlider.released()
            }
        }

        Text {
            Layout.preferredWidth: Style.space(36)
            horizontalAlignment: Text.AlignRight
            text: cSlider.displayValue
            font.family: Style.font.family
            font.pixelSize: Style.font.caption * 0.88
            color: root.fg
        }
    }

    component ValueStepper: Row {
        id: vStepper
        property string displayText: ""
        property real buttonSize: Style.space(26)
        property real valueWidth: Style.space(58)
        signal decremented()
        signal incremented()

        spacing: Style.space(4)

        Rectangle {
            width: vStepper.buttonSize
            height: vStepper.buttonSize
            radius: Style.space(5)
            color: stepMinusMouse.containsMouse ? root.surfaceHover : root.surface
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
                id: stepMinusMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: vStepper.decremented()
            }
        }

        Rectangle {
            width: vStepper.valueWidth
            height: vStepper.buttonSize
            radius: Style.space(5)
            color: root.surface
            border.width: 1
            border.color: root.hairline

            Text {
                anchors.centerIn: parent
                text: vStepper.displayText
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                color: Color.accent
            }
        }

        Rectangle {
            width: vStepper.buttonSize
            height: vStepper.buttonSize
            radius: Style.space(5)
            color: stepPlusMouse.containsMouse ? root.surfaceHover : root.surface
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
                id: stepPlusMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: vStepper.incremented()
            }
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
            blocked: root.tagMenuOpen || (typeof tagInput !== "undefined" && tagInput && tagInput.activeFocus) || (typeof customHexInput !== "undefined" && customHexInput && customHexInput.activeFocus)

            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }
            onActivateRequested: if (root.w) root.w.toggleRunning()
            onMoveRequested: function(dx, dy) {
                if (dx !== 0) root.setTab((root.currentTab + dx + 2) % 2)
            }
            onTextKey: function(t) {
                if (t === "1") root.setTab(0)
                else if (t === "2") root.setTab(1)
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
                    Layout.preferredHeight: Style.space(34)
                    fg: root.fg
                    fontSize: Style.font.body
                    value: "" + root.currentTab
                    options: [
                        { value: "0", label: "Focus", icon: "󰔛" },
                        { value: "1", label: "Statistics", icon: "󰄨" }
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
                                                text: root.w ? root.w.displayTime : "25:00"
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
                                                height: Style.space(30)
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
                                                        font.pixelSize: Style.font.body
                                                        font.bold: true
                                                        color: root.fg
                                                    }
                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: root.tagMenuOpen ? "󰅃" : "󰅀"
                                                        font.family: Style.font.family
                                                        font.pixelSize: Style.font.bodySmall
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
                                        height: Style.space(18)

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
                                                font.pixelSize: Style.font.bodySmall
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
                                                        readonly property int done: {
                                                            if (!root.w) return 0
                                                            if (root.w.pomodoroPhase === "longBreak") return 4
                                                            return root.w.pomodoroCyclesCompleted % 4
                                                        }
                                                        width: Style.space(7)
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
                                            Layout.preferredHeight: Style.space(28)
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
                                            Layout.preferredWidth: Style.space(28)
                                            Layout.preferredHeight: Style.space(28)
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
                                                font.pixelSize: Style.font.bodySmall
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
                                                    font.pixelSize: Style.font.caption
                                                    font.bold: true
                                                    color: Color.accent
                                                }

                                                Item { Layout.fillWidth: true }

                                                Text {
                                                    text: "✕"
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.bodySmall
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
                                                        font.pixelSize: Style.font.bodySmall
                                                        color: root.fg
                                                        Layout.fillWidth: true
                                                    }

                                                    ValueStepper {
                                                        displayText: Math.round(stepperRow.currentSec / 60) + " min"
                                                        buttonSize: Style.space(26)
                                                        valueWidth: Style.space(58)
                                                        onDecremented: {
                                                            if (!root.w) return
                                                            var curMins = Math.round(stepperRow.currentSec / 60)
                                                            var nextMins = Math.max(modelData.min, curMins - modelData.step)
                                                            root.w.setPomodoroDuration(modelData.phase, nextMins * 60)
                                                        }
                                                        onIncremented: {
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

                                    // Stopwatch info line
                                    Text {
                                        width: parent.width
                                        visible: !root.isPomodoro
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: "Studied today: " + root.heatmapData.todayHours
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.bodySmall
                                        color: root.dim
                                    }

                                    // Controls
                                    RowLayout {
                                        width: parent.width
                                        spacing: Style.space(8)

                                        // Primary Start/Pause button
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Style.space(36)
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
                                            Layout.preferredWidth: Style.space(36)
                                            Layout.preferredHeight: Style.space(36)
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
                                                width: Style.space(22)
                                                height: Style.space(22)
                                                radius: Style.space(4)
                                                color: scrollLeftMouse.containsMouse ? root.surfaceHover : "transparent"
                                                border.width: 1
                                                border.color: root.hairline

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰅁"
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.bodySmall
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
                                                width: Style.space(22)
                                                height: Style.space(22)
                                                radius: Style.space(4)
                                                color: scrollRightMouse.containsMouse ? root.surfaceHover : "transparent"
                                                border.width: 1
                                                border.color: root.hairline

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰅂"
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.bodySmall
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
                                                height: Style.space(22)
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
                                                    font.pixelSize: Style.font.caption
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
                                            font.pixelSize: Style.font.bodySmall
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
                                                    width: Style.space(22)
                                                    height: Style.space(11)
                                                    text: modelData
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.caption * 0.85
                                                    color: root.dim
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                            }
                                        }

                                        // Scrollbarer Bereich für alle Kalenderwochen des Jahres
                                        Flickable {
                                            id: heatmapFlick
                                            width: parent.width - weekdayCol.width - Style.space(6)
                                            height: heatmapWeeksCol.implicitHeight + Style.space(9)
                                            clip: true
                                            contentWidth: Math.max(heatmapWeeksCol.implicitWidth, (Style.space(11) + Style.space(3)) * (root.heatmapData.weeks ? root.heatmapData.weeks.length : 53))
                                            contentHeight: height
                                            boundsBehavior: Flickable.StopAtBounds
                                            flickableDirection: Flickable.HorizontalFlick

                                            ScrollBar.horizontal: ScrollBar {
                                                id: heatmapScrollBar
                                                policy: ScrollBar.AsNeeded
                                                implicitHeight: Style.space(6)
                                                contentItem: Rectangle {
                                                    implicitHeight: Style.space(4)
                                                    radius: height / 2
                                                    color: heatmapScrollBar.pressed
                                                        ? Color.accent
                                                        : (heatmapScrollBar.hovered ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.70) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.28))
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                }
                                                background: Item {
                                                    implicitHeight: Style.space(6)
                                                }
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
                                                                font.pixelSize: Style.font.caption * 0.85
                                                                color: root.dim
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
                                            font.pixelSize: Style.font.bodySmall
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
                                                font.pixelSize: Style.font.caption
                                                color: root.dim
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
                                                font.pixelSize: Style.font.caption
                                                color: root.dim
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // =========================================================
                    // TAB 2: STATISTICS (Consistency, Subject Hours & Session Depth)
                    // =========================================================
                    ColumnLayout {
                        spacing: Style.space(8)

                        // =====================================================
                        // 1. Consistency Tracker Card (Always Current Week)
                        // =====================================================
                        Rectangle {
                            id: consistencyCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: consistencyCol.implicitHeight + Style.space(22)
                            Behavior on Layout.preferredHeight { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            radius: Style.space(12)
                            color: root.surface
                            border.width: 1
                            border.color: root.hairline

                            readonly property var cData: root.consistencyData
                            readonly property bool isBlocks: cData.goalMode === "blocks"

                            ColumnLayout {
                                id: consistencyCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Style.space(11)
                                spacing: Style.space(8)

                                // 1. Header: CONSISTENCY TRACKER + [ 🎯 4h ] [ ⚙️ ]
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.space(6)

                                    SectionLabel {
                                        Layout.fillWidth: true
                                        fg: root.fg
                                        text: "CONSISTENCY TRACKER"
                                    }

                                    // Goal summary pill [ 🎯 4h ] (click toggles settings drawer)
                                    Rectangle {
                                        height: Style.space(24)
                                        implicitWidth: goalBadgeText.implicitWidth + Style.space(16)
                                        radius: Style.space(6)
                                        color: badgeMouse.containsMouse ? root.surfaceHover : root.surface
                                        border.width: 1
                                        border.color: root.consistencySettingsOpen ? Color.accent : root.hairline

                                        Text {
                                            id: goalBadgeText
                                            anchors.centerIn: parent
                                            text: consistencyCard.cData.badgeText
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption
                                            font.bold: true
                                            color: root.fg
                                        }

                                        MouseArea {
                                            id: badgeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.consistencySettingsOpen = !root.consistencySettingsOpen
                                        }

                                        PanelToolTip {
                                            visible: badgeMouse.containsMouse
                                            text: "Click to configure daily goal & weekend rest days"
                                        }
                                    }

                                    // Gear button [ ⚙️ ]
                                    Rectangle {
                                        Layout.preferredWidth: Style.space(24)
                                        Layout.preferredHeight: Style.space(24)
                                        radius: Style.space(6)
                                        color: root.consistencySettingsOpen
                                            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
                                            : (consGearMouse.containsMouse ? root.surfaceHover : root.surface)
                                        border.width: 1
                                        border.color: root.consistencySettingsOpen ? Color.accent : root.hairline

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰒓"
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.bodySmall
                                            color: root.consistencySettingsOpen ? Color.accent : root.fg
                                        }

                                        MouseArea {
                                            id: consGearMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.consistencySettingsOpen = !root.consistencySettingsOpen
                                        }

                                        PanelToolTip {
                                            visible: consGearMouse.containsMouse
                                            text: "Consistency Goal Settings"
                                        }
                                    }
                                }

                                // Collapsible Goal Settings Drawer (when ⚙️ is clicked)
                                Rectangle {
                                    Layout.fillWidth: true
                                    visible: root.consistencySettingsOpen
                                    implicitHeight: consSettingsCol.implicitHeight + Style.space(14)
                                    radius: Style.space(8)
                                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
                                    border.width: 1
                                    border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)

                                    ColumnLayout {
                                        id: consSettingsCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: Style.space(7)
                                        spacing: Style.space(6)

                                        // Row A: Mode [ Hours | Blocks ] + Checkbox [✓] Weekends
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Style.space(10)

                                            Segmented {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: Style.space(24)
                                                fg: root.fg
                                                value: consistencyCard.cData.goalMode
                                                options: [
                                                    { value: "hours", label: "Hours" },
                                                    { value: "blocks", label: "Blocks" }
                                                ]
                                                onPicked: function(v) {
                                                    if (root.w) root.w.setConsistencyConfig({ goalMode: v })
                                                }
                                            }

                                            // Checkbox: [✓] Weekends
                                            Rectangle {
                                                height: Style.space(24)
                                                implicitWidth: wkndChkRow.implicitWidth + Style.space(14)
                                                radius: Style.space(6)
                                                color: wkndChkMouse.containsMouse ? root.surfaceHover : "transparent"

                                                Row {
                                                    id: wkndChkRow
                                                    anchors.centerIn: parent
                                                    spacing: Style.space(6)

                                                    Rectangle {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: Style.space(15)
                                                        height: Style.space(15)
                                                        radius: Style.space(4)
                                                        color: consistencyCard.cData.weekendsEnabled
                                                            ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
                                                            : root.surface
                                                        border.width: 1
                                                        border.color: consistencyCard.cData.weekendsEnabled ? Color.accent : root.dim

                                                        Text {
                                                            anchors.centerIn: parent
                                                            visible: consistencyCard.cData.weekendsEnabled
                                                            text: "✓"
                                                            font.family: Style.font.family
                                                            font.pixelSize: Style.font.caption * 0.9
                                                            font.bold: true
                                                            color: Color.accent
                                                        }
                                                    }

                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "Weekends"
                                                        font.family: Style.font.family
                                                        font.pixelSize: Style.font.caption
                                                        font.bold: true
                                                        color: consistencyCard.cData.weekendsEnabled ? root.fg : root.dim
                                                    }
                                                }

                                                MouseArea {
                                                    id: wkndChkMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (root.w) root.w.setConsistencyConfig({ goalWeekendsEnabled: !consistencyCard.cData.weekendsEnabled })
                                                    }
                                                }

                                                PanelToolTip {
                                                    visible: wkndChkMouse.containsMouse
                                                    text: consistencyCard.cData.weekendsEnabled
                                                        ? "Weekends enabled (Mon–Sun required)"
                                                        : "Weekends off (Sat & Sun are Rest Days)"
                                                }
                                            }
                                        }

                                        // Row B: Hours -> "Daily Goal" + Stepper | Blocks -> Segmented [Ultradian 90m | Deep Work 50m] + Stepper
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Style.space(8)

                                            Text {
                                                visible: !consistencyCard.isBlocks
                                                Layout.fillWidth: true
                                                text: "Daily Goal"
                                                font.family: Style.font.family
                                                font.pixelSize: Style.font.caption
                                                font.bold: true
                                                color: root.dim
                                            }

                                            Segmented {
                                                visible: consistencyCard.isBlocks
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: Style.space(24)
                                                fg: root.fg
                                                value: consistencyCard.cData.blockPreset
                                                options: [
                                                    { value: "ultradian", label: "Ultradian 90m", tip: "Ultradian Block (90m, 2m grace)" },
                                                    { value: "deepWork", label: "Deep Work 50m", tip: "Deep Work Block (50m, 2m grace)" }
                                                ]
                                                onPicked: function(v) {
                                                    if (root.w) root.w.setConsistencyConfig({ goalBlockPreset: v })
                                                }
                                            }

                                            ValueStepper {
                                                displayText: consistencyCard.isBlocks
                                                    ? (consistencyCard.cData.targetBlocks + "x")
                                                    : (consistencyCard.cData.targetHours.toFixed(1) + "h")
                                                buttonSize: Style.space(24)
                                                valueWidth: Style.space(consistencyCard.isBlocks ? 40 : 54)
                                                onDecremented: {
                                                    if (!root.w) return
                                                    if (consistencyCard.isBlocks) {
                                                        root.w.setConsistencyConfig({ goalTargetBlocks: consistencyCard.cData.targetBlocks - 1 })
                                                    } else {
                                                        root.w.setConsistencyConfig({ goalTargetHours: consistencyCard.cData.targetHours - 0.5 })
                                                    }
                                                }
                                                onIncremented: {
                                                    if (!root.w) return
                                                    if (consistencyCard.isBlocks) {
                                                        root.w.setConsistencyConfig({ goalTargetBlocks: consistencyCard.cData.targetBlocks + 1 })
                                                    } else {
                                                        root.w.setConsistencyConfig({ goalTargetHours: consistencyCard.cData.targetHours + 0.5 })
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // 2. THIS WEEK (Mon–Sun) + 4 / 5 Days ✓ + 7 Day Tiles
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.space(5)

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "THIS WEEK (Mon–Sun)"
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption
                                            font.bold: true
                                            font.letterSpacing: 0.4
                                            color: root.dim
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: consistencyCard.cData.weekMetCount + " / " + consistencyCard.cData.weekRequiredCount + " Days ✓"
                                            font.family: Style.font.family
                                            font.pixelSize: Style.font.caption
                                            font.bold: true
                                            color: consistencyCard.cData.weekMetCount >= consistencyCard.cData.weekRequiredCount ? Color.accent : root.fg
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Style.space(5)

                                        Repeater {
                                            model: consistencyCard.cData.weekDays

                                            Rectangle {
                                                id: dayTile
                                                Layout.fillWidth: true
                                                Layout.preferredWidth: 1
                                                Layout.preferredHeight: Style.space(54)
                                                radius: Style.space(7)
                                                color: {
                                                    if (modelData.met) return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
                                                    if (modelData.isRestDay) return Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.02)
                                                    return Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
                                                }
                                                border.width: modelData.isToday ? 2 : (modelData.met ? 1.5 : 0)
                                                border.color: modelData.met
                                                    ? Color.accent
                                                    : (modelData.isToday ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.85) : "transparent")

                                                // Dashed border for Rest Days (┌ ─ ─ ┐)
                                                Canvas {
                                                    anchors.fill: parent
                                                    visible: modelData.isRestDay && !modelData.isToday && !modelData.met
                                                    onWidthChanged: requestPaint()
                                                    onHeightChanged: requestPaint()
                                                    onPaint: {
                                                        var ctx = getContext("2d")
                                                        ctx.clearRect(0, 0, width, height)
                                                        ctx.strokeStyle = Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.22)
                                                        ctx.lineWidth = 1
                                                        if (ctx.setLineDash) ctx.setLineDash([4, 3])
                                                        var r = Style.space(7)
                                                        var x = 0.5, y = 0.5, w = width - 1, h = height - 1
                                                        ctx.beginPath()
                                                        ctx.moveTo(x + r, y)
                                                        ctx.lineTo(x + w - r, y)
                                                        ctx.quadraticCurveTo(x + w, y, x + w, y + r)
                                                        ctx.lineTo(x + w, y + h - r)
                                                        ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
                                                        ctx.lineTo(x + r, y + h)
                                                        ctx.quadraticCurveTo(x, y + h, x, y + h - r)
                                                        ctx.lineTo(x, y + r)
                                                        ctx.quadraticCurveTo(x, y, x + r, y)
                                                        ctx.closePath()
                                                        ctx.stroke()
                                                    }
                                                }

                                                Column {
                                                    anchors.centerIn: parent
                                                    spacing: Style.space(1)

                                                    // Line 1: Day Name (Mon, Tue, Wed...)
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: modelData.label
                                                        font.family: Style.font.family
                                                        font.pixelSize: Style.font.caption * 0.92
                                                        font.bold: modelData.isToday || modelData.met
                                                        color: modelData.met
                                                            ? Color.accent
                                                            : (modelData.isToday ? root.fg : (modelData.isRestDay ? root.faint : root.dim))
                                                    }

                                                    // Line 2: Status (✓, 69%, —, Rest)
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: modelData.statusText
                                                        font.family: Style.font.family
                                                        font.pixelSize: Style.font.caption
                                                        font.bold: modelData.met || modelData.isToday
                                                        color: modelData.met
                                                            ? Color.accent
                                                            : (modelData.isToday ? root.fg : (modelData.isRestDay ? root.faint : root.dim))
                                                    }

                                                    // Line 3: Hours or Blocks (4.2h, 0.0h, 2/2) — hidden on Rest Days
                                                    Text {
                                                        visible: !modelData.isRestDay
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: modelData.bottomText
                                                        font.family: Style.font.family
                                                        font.pixelSize: Style.font.caption * 0.88
                                                        font.bold: modelData.met
                                                        color: modelData.met ? Color.accent : (modelData.isToday ? root.dim : root.faint)
                                                    }
                                                }

                                                MouseArea {
                                                    id: wkTileMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                }

                                                PanelToolTip {
                                                    visible: wkTileMouse.containsMouse
                                                    text: modelData.dateStr + " · " + Model.formatDurationHuman(modelData.seconds)
                                                        + (consistencyCard.isBlocks ? (" (" + modelData.blocks + " Blocks)") : "")
                                                        + (modelData.isRestDay ? " · Rest Day" : "")
                                                }
                                            }
                                        }
                                    }
                                }

                                // 3. Footer Line: 🔥 Goal Streak: 6 Days        📊 30d Hit Rate: 82% (18/22)
                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "🔥 Goal Streak: " + consistencyCard.cData.goalStreak
                                            + (consistencyCard.cData.goalStreak === 1 ? " Day" : " Days")
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                        color: consistencyCard.cData.goalStreak > 0 ? root.fg : root.dim
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: "📊 30d Hit Rate: " + consistencyCard.cData.hitRate30 + "% (" + consistencyCard.cData.reqMet30 + "/" + consistencyCard.cData.reqTotal30 + ")"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                        color: consistencyCard.cData.hitRate30 >= 80 ? Color.accent : root.fg
                                    }
                                }
                            }
                        }

                        // =====================================================
                        // Central Analytics Filter Bar: ANALYTICS + [ Today | Week | Month | Total ]
                        // =====================================================
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Style.space(2)
                            spacing: Style.space(8)

                            SectionLabel {
                                Layout.fillWidth: true
                                fg: root.fg
                                text: "ANALYTICS"
                            }

                            Segmented {
                                Layout.preferredWidth: Style.space(236)
                                Layout.preferredHeight: Style.space(26)
                                fg: root.fg
                                value: root.tagStatsScope
                                options: [
                                    { value: "today", label: "Today" },
                                    { value: "week", label: "Week" },
                                    { value: "month", label: "Month" },
                                    { value: "all", label: "Total" }
                                ]
                                onPicked: function(v) {
                                    root.hoveredSubjectTag = ""
                                    root.tagStatsScope = v
                                }
                            }
                        }

                        // =====================================================
                        // 2. Hours by Subject Card (Side-by-Side Donut & Subject List)
                        // =====================================================
                        Rectangle {
                            id: subjectStatsArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Style.space(12)
                            color: root.surface
                            border.width: 1
                            border.color: root.hairline

                            readonly property var hoveredItem: {
                                var list = root.tagStatsData.tags || []
                                for (var i = 0; i < list.length; i++) {
                                    if (list[i].tag === root.hoveredSubjectTag) return list[i]
                                }
                                return null
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Style.space(12)
                                spacing: Style.space(8)

                                SectionLabel {
                                    Layout.fillWidth: true
                                    fg: root.fg
                                    text: "HOURS BY SUBJECT"
                                }

                                // Side-by-Side Content: Donut Left, Subject Breakdown Right
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: Style.space(16)
                                        visible: (root.tagStatsData.tags ? root.tagStatsData.tags.length : 0) > 0

                                        // Left: Donut Chart
                                        Item {
                                            id: donutContainer
                                            Layout.preferredWidth: Style.space(132)
                                            Layout.preferredHeight: Style.space(132)
                                            Layout.alignment: Qt.AlignVCenter
                                            readonly property real ringWidth: Style.space(16)
                                            readonly property real hoverRingWidth: Style.space(19)

                                            Canvas {
                                                id: donutCanvas
                                                anchors.fill: parent
                                                antialiasing: true

                                                readonly property var tagsModel: root.tagStatsData.tags || []
                                                readonly property int grandTotal: root.tagStatsData.grandTotalSeconds || 0
                                                readonly property string hoveredTag: root.hoveredSubjectTag
                                                readonly property var customColors: root.w ? root.w.tagColors : null

                                                onTagsModelChanged: requestPaint()
                                                onGrandTotalChanged: requestPaint()
                                                onHoveredTagChanged: requestPaint()
                                                onCustomColorsChanged: requestPaint()
                                                onWidthChanged: requestPaint()
                                                onHeightChanged: requestPaint()

                                                onPaint: {
                                                    var ctx = getContext("2d")
                                                    ctx.clearRect(0, 0, width, height)

                                                    var list = tagsModel
                                                    var total = grandTotal
                                                    if (!list || list.length === 0 || total <= 0) return

                                                    var cx = width / 2
                                                    var cy = height / 2
                                                    var ringW = donutContainer.ringWidth
                                                    var hoverRingW = donutContainer.hoverRingWidth
                                                    var baseRadius = Math.min(cx, cy) - hoverRingW / 2 - Style.space(2)

                                                    var startAngle = -Math.PI / 2
                                                    var gap = list.length > 1 ? 0.03 : 0

                                                    for (var i = 0; i < list.length; i++) {
                                                        var item = list[i]
                                                        var fraction = item.totalSeconds / total
                                                        var sweep = fraction * Math.PI * 2
                                                        if (sweep <= 0) continue

                                                        var isHov = (hoveredTag === item.tag)
                                                        var isDimmed = (hoveredTag !== "" && !isHov)
                                                        var colHex = String(root.colorForTag(item.tag))

                                                        var actualGap = sweep > gap * 1.5 ? gap : 0
                                                        var a0 = startAngle + actualGap / 2
                                                        var a1 = startAngle + sweep - actualGap / 2

                                                        ctx.beginPath()
                                                        ctx.arc(cx, cy, baseRadius, a0, a1, false)
                                                        ctx.lineWidth = isHov ? hoverRingW : ringW
                                                        ctx.strokeStyle = colHex
                                                        ctx.globalAlpha = isDimmed ? 0.35 : 1.0
                                                        ctx.stroke()

                                                        startAngle += sweep
                                                    }
                                                    ctx.globalAlpha = 1.0
                                                }
                                            }

                                            // Center label: Hours on top, Period / Subject below
                                            Column {
                                                anchors.centerIn: parent
                                                width: Style.space(86)
                                                spacing: Style.space(1)

                                                Text {
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                    text: subjectStatsArea.hoveredItem
                                                        ? subjectStatsArea.hoveredItem.hoursDec
                                                        : root.tagStatsData.grandTotalHours
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.body
                                                    font.bold: true
                                                    color: root.fg
                                                }

                                                Text {
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                    text: subjectStatsArea.hoveredItem
                                                        ? subjectStatsArea.hoveredItem.tag
                                                        : (root.tagStatsScope === "today" ? "Today" : (root.tagStatsScope === "week" ? "7 Days" : (root.tagStatsScope === "month" ? "30 Days" : "Total")))
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.caption
                                                    font.bold: Boolean(subjectStatsArea.hoveredItem)
                                                    font.strikeout: Boolean(subjectStatsArea.hoveredItem && (root.listedTags, !root.isTagListed(subjectStatsArea.hoveredItem.tag)))
                                                    color: subjectStatsArea.hoveredItem
                                                        ? root.colorForTag(subjectStatsArea.hoveredItem.tag)
                                                        : root.dim
                                                }
                                            }

                                            MouseArea {
                                                id: donutMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: root.hoveredSubjectTag !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor

                                                function tagAtPos(mx, my) {
                                                    var list = root.tagStatsData.tags || []
                                                    var total = root.tagStatsData.grandTotalSeconds || 0
                                                    if (!list.length || total <= 0) return ""
                                                    var cx = width / 2
                                                    var cy = height / 2
                                                    var dx = mx - cx
                                                    var dy = my - cy
                                                    var dist = Math.sqrt(dx * dx + dy * dy)
                                                    var ringW = donutContainer.hoverRingWidth
                                                    var baseRadius = Math.min(cx, cy) - ringW / 2 - Style.space(2)
                                                    if (dist < baseRadius - ringW * 0.75 || dist > baseRadius + ringW * 0.75) {
                                                        return ""
                                                    }
                                                    var angle = Math.atan2(dy, dx) - (-Math.PI / 2)
                                                    if (angle < 0) angle += Math.PI * 2
                                                    var targetFrac = angle / (Math.PI * 2)
                                                    var acc = 0
                                                    for (var i = 0; i < list.length; i++) {
                                                        var frac = list[i].totalSeconds / total
                                                        if (targetFrac >= acc && targetFrac <= acc + frac) {
                                                            return list[i].tag
                                                        }
                                                        acc += frac
                                                    }
                                                    return ""
                                                }

                                                onPositionChanged: function(mouse) {
                                                    root.hoveredSubjectTag = tagAtPos(mouse.x, mouse.y)
                                                }
                                                onExited: root.hoveredSubjectTag = ""
                                                onClicked: function(mouse) {
                                                    var t = tagAtPos(mouse.x, mouse.y)
                                                    if (t === "" || !root.w) return
                                                    if (root.isTagListed(t)) root.w.addTag(t)
                                                    else root.w.recoverTag(t)
                                                }
                                            }
                                        }

                                        // Right: Subject Breakdown Legend List
                                        ListView {
                                            id: tagList
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            readonly property real contentH: count * Style.space(28) + Math.max(0, count - 1) * spacing
                                            topMargin: Math.max(0, (height - contentH) / 2)
                                            clip: true
                                            spacing: Style.space(3)
                                            boundsBehavior: Flickable.StopAtBounds
                                            model: root.tagStatsData.tags
                                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                            delegate: Rectangle {
                                                readonly property color tagCol: root.colorForTag(modelData.tag)
                                                readonly property bool isActive: modelData.tag === root.activeTag
                                                readonly property bool isHov: root.hoveredSubjectTag === modelData.tag
                                                readonly property bool isListed: (root.listedTags, root.isTagListed(modelData.tag))
                                                width: tagList.width
                                                height: Style.space(28)
                                                radius: Style.space(6)
                                                color: (tagRowMouse.containsMouse || isHov)
                                                    ? root.surfaceHover
                                                    : (isActive ? Qt.rgba(tagCol.r, tagCol.g, tagCol.b, 0.10) : "transparent")
                                                border.width: isActive ? 1 : 0
                                                border.color: Qt.rgba(tagCol.r, tagCol.g, tagCol.b, 0.45)

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: Style.space(8)
                                                    anchors.rightMargin: Style.space(8)
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
                                                        font.bold: isActive || isHov
                                                        font.strikeout: !isListed
                                                        color: isListed ? root.fg : root.dim
                                                    }
                                                    Text {
                                                        text: modelData.hoursDec
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
                                                        font.pixelSize: Style.font.bodySmall
                                                        color: root.dim
                                                    }
                                                }

                                                MouseArea {
                                                    id: tagRowMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onEntered: root.hoveredSubjectTag = modelData.tag
                                                    onExited: if (root.hoveredSubjectTag === modelData.tag) root.hoveredSubjectTag = ""
                                                    onClicked: {
                                                        if (!root.w) return
                                                        if (isListed) root.w.addTag(modelData.tag)
                                                        else root.w.recoverTag(modelData.tag)
                                                    }
                                                }

                                                PanelToolTip {
                                                    visible: tagRowMouse.containsMouse
                                                    text: modelData.sessionCount + " Sessions · " + modelData.formatted
                                                        + (isListed ? " · Click: set as active subject" : " · Click: recover archived subject")
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: (root.tagStatsData.tags ? root.tagStatsData.tags.length : 0) === 0
                                        text: (!root.w || root.w.history.length === 0)
                                            ? "No study activity yet"
                                            : "No sessions logged for " + (root.tagStatsScope === "today" ? "Today" : (root.tagStatsScope === "week" ? "the last 7 days" : (root.tagStatsScope === "month" ? "the last 30 days" : "Total")))
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.bodySmall
                                        color: root.dim
                                    }
                                }
                            }
                        }

                        // =====================================================
                        // 3. Session Depth & Quality Card
                        // =====================================================
                        Rectangle {
                            id: qualityCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: qualityCol.implicitHeight + Style.space(24)
                            radius: Style.space(12)
                            color: root.surface
                            border.width: 1
                            border.color: root.hairline

                            readonly property var qData: root.sessionQualityData
                            readonly property color deepCol: Color.accent
                            readonly property color focusedCol: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.50)
                            readonly property color shallowCol: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.22)

                            ColumnLayout {
                                id: qualityCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Style.space(12)
                                spacing: Style.space(8)

                                // Header: SESSION DEPTH & QUALITY + Deep Work: 68%
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.space(6)

                                    SectionLabel {
                                        Layout.fillWidth: true
                                        fg: root.fg
                                        text: "SESSION DEPTH & QUALITY"
                                    }

                                    Text {
                                        text: qualityCard.qData.totalCount > 0
                                            ? ("Deep Work: " + qualityCard.qData.deepPct + "%")
                                            : "No sessions"
                                        font.family: Style.font.family
                                        font.pixelSize: Style.font.caption
                                        font.bold: true
                                        color: qualityCard.qData.deepPct >= 50 ? Color.accent : root.dim
                                    }
                                }

                                // Stacked Distribution Bar (Deep | Focused | Shallow)
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Style.space(8)
                                    radius: height / 2
                                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)
                                    clip: true

                                    Row {
                                        id: depthBarRow
                                        anchors.fill: parent
                                        spacing: Style.space(2)
                                        visible: qualityCard.qData.totalSeconds > 0
                                        readonly property int activeCount: (qualityCard.qData.deepRatio > 0 ? 1 : 0)
                                            + (qualityCard.qData.focusedRatio > 0 ? 1 : 0)
                                            + (qualityCard.qData.shallowRatio > 0 ? 1 : 0)
                                        readonly property real usableWidth: Math.max(0, width - spacing * Math.max(0, activeCount - 1))

                                        Rectangle {
                                            width: depthBarRow.usableWidth * qualityCard.qData.deepRatio
                                            height: parent.height
                                            radius: height / 2
                                            color: qualityCard.deepCol
                                            visible: qualityCard.qData.deepRatio > 0
                                        }
                                        Rectangle {
                                            width: depthBarRow.usableWidth * qualityCard.qData.focusedRatio
                                            height: parent.height
                                            radius: height / 2
                                            color: qualityCard.focusedCol
                                            visible: qualityCard.qData.focusedRatio > 0
                                        }
                                        Rectangle {
                                            width: depthBarRow.usableWidth * qualityCard.qData.shallowRatio
                                            height: parent.height
                                            radius: height / 2
                                            color: qualityCard.shallowCol
                                            visible: qualityCard.qData.shallowRatio > 0
                                        }
                                    }
                                }

                                // 3 Quality Tier Tiles: Deep (≥50m) | Focused (25–50m) | Shallow (<25m)
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.space(6)

                                    Repeater {
                                        model: qualityCard.qData.tiers

                                        Rectangle {
                                            readonly property bool isDeep: modelData.key === "deep"
                                            readonly property bool isFocused: modelData.key === "focused"
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            Layout.preferredHeight: Style.space(56)
                                            radius: Style.space(8)
                                            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
                                            border.width: isDeep && modelData.seconds > 0 ? 1.5 : 1
                                            border.color: isDeep && modelData.seconds > 0
                                                ? Color.accent
                                                : root.hairline

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: Style.space(2)

                                                Row {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    spacing: Style.space(4)

                                                    Rectangle {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: Style.space(7)
                                                        height: width
                                                        radius: width / 2
                                                        color: isDeep ? qualityCard.deepCol : (isFocused ? qualityCard.focusedCol : qualityCard.shallowCol)
                                                    }

                                                    Text {
                                                        text: modelData.label + " (" + modelData.subLabel + ")"
                                                        font.family: Style.font.family
                                                        font.pixelSize: Style.font.caption * 0.90
                                                        font.bold: true
                                                        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.85)
                                                    }
                                                }

                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: modelData.hoursText + " · " + modelData.percent + "%"
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.bodySmall
                                                    font.bold: true
                                                    color: root.fg
                                                }

                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: modelData.count + (modelData.count === 1 ? " session" : " sessions")
                                                    font.family: Style.font.family
                                                    font.pixelSize: Style.font.caption * 0.86
                                                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.55)
                                                }
                                            }

                                            MouseArea {
                                                id: qTierMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                            }

                                            PanelToolTip {
                                                visible: qTierMouse.containsMouse
                                                text: modelData.label + " (" + modelData.subLabel + ") · "
                                                    + Model.formatDurationHuman(modelData.seconds) + " across "
                                                    + modelData.count + (modelData.count === 1 ? " session" : " sessions")
                                            }
                                        }
                                    }
                                }
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
                width: Style.space(290)
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
                            Layout.preferredWidth: Style.space(30)
                            Layout.preferredHeight: Style.space(30)
                            radius: Style.space(15)
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
                            Layout.preferredHeight: Style.space(30)
                            foreground: root.fg
                            placeholderText: "New Subject…"
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                            maximumLength: 24
                            Keys.onReturnPressed: function(event) {
                                event.accepted = true
                                root.submitNewTag()
                            }
                            Keys.onEnterPressed: function(event) {
                                event.accepted = true
                                root.submitNewTag()
                            }
                            Keys.onEscapePressed: function(event) {
                                event.accepted = true
                                if (root.activeColorTarget.length > 0) colorPaletteCard.cancelAndClose()
                                else root.closeTagMenu()
                            }
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

                    // Filtered list of existing subjects
                    ListView {
                        id: tagMenuList
                        readonly property var filtered: {
                            var all = root.w ? root.w.recentTags : []
                            var q = tagInput.text.trim().toLowerCase()
                            if (q.length === 0) return all
                            return all.filter(function(t) { return t.toLowerCase().indexOf(q) !== -1 })
                        }
                        readonly property real rowH: Style.space(38)
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
                                    if (root.w) root.w.addTag(modelData)
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
                                    font.pixelSize: Style.font.body
                                    font.bold: sel
                                    color: root.fg
                                }

                                // Color palette icon
                                Text {
                                    id: tagPalIcon
                                    Layout.rightMargin: Style.space(2)
                                    visible: isColorTarget || tagRowItem.isHovered
                                    text: "󰏘"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.body * 1.25
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
                                    font.pixelSize: Style.font.body * 1.25
                                    color: tagCol
                                }

                                // Archive icon
                                Text {
                                    visible: tagRowItem.isHovered
                                    text: "󰀼"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.body * 1.25
                                    color: trashMouse.containsMouse ? Color.accent : root.dim

                                    MouseArea {
                                        id: trashMouse
                                        anchors.fill: parent
                                        anchors.margins: -Style.space(4)
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.w) {
                                            if (root.activeColorTarget === modelData) root.activeColorTarget = ""
                                            root.w.removeTag(modelData)
                                        }
                                    }

                                    PanelToolTip {
                                        visible: trashMouse.containsMouse
                                        text: "Archive subject"
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
                            font.pixelSize: Style.font.bodySmall
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
                    property string initialHex: ""
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
                            initialHex = root.newTagColor
                            hex = root.newTagColor.length > 0 ? root.newTagColor : (root.w ? Model.tagColor("", null) : "#3b82f6")
                        } else {
                            var customMap = root.w ? root.w.tagColors : null
                            initialHex = (customMap && customMap[root.activeColorTarget]) ? String(customMap[root.activeColorTarget]) : ""
                            hex = root.colorForTag(root.activeColorTarget)
                        }
                        syncHsvFromHex(hex)
                    }

                    function cancelAndClose() {
                        if (root.activeColorTarget === "__new__") {
                            root.newTagColor = initialHex
                        } else if (root.w && root.activeColorTarget.length > 0) {
                            root.w.setTagColor(root.activeColorTarget, initialHex, false)
                        }
                        root.activeColorTarget = ""
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
                        applyColorToTarget(hex, true)
                    }

                    function applyColorToTarget(hex, skipSave) {
                        if (root.activeColorTarget === "__new__") {
                            root.newTagColor = hex
                        } else if (root.w && root.activeColorTarget.length > 0) {
                            root.w.setTagColor(root.activeColorTarget, hex, skipSave)
                        }
                    }

                    function selectSwatch(hex) {
                        applyColorToTarget(hex, false)
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
                                font.pixelSize: Style.font.bodySmall
                                font.bold: true
                                color: root.fg
                            }

                            Text {
                                text: "✕"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.bodySmall
                                color: closePalMouse.containsMouse ? root.fg : root.dim

                                MouseArea {
                                    id: closePalMouse
                                    anchors.fill: parent
                                    anchors.margins: -Style.space(4)
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.w) root.w.saveToDisk()
                                        root.activeColorTarget = ""
                                    }
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
                                        font.pixelSize: Style.font.caption * 0.85
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
                        ColorSlider {
                            label: "Hue"
                            value: colorPaletteCard.hueVal
                            displayValue: Math.round(colorPaletteCard.hueVal * 360) + "°"
                            thumbColor: Qt.hsva(colorPaletteCard.hueVal, 1.0, 1.0, 1.0)
                            trackGradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.00; color: "#ff0000" }
                                GradientStop { position: 0.17; color: "#ffff00" }
                                GradientStop { position: 0.33; color: "#00ff00" }
                                GradientStop { position: 0.50; color: "#00ffff" }
                                GradientStop { position: 0.67; color: "#0000ff" }
                                GradientStop { position: 0.83; color: "#ff00ff" }
                                GradientStop { position: 1.00; color: "#ff0000" }
                            }
                            onMoved: function(v) {
                                colorPaletteCard.hueVal = v
                                colorPaletteCard.applyFromSliders()
                            }
                            onReleased: if (root.w) root.w.saveToDisk()
                        }

                        ColorSlider {
                            label: "Sat"
                            value: colorPaletteCard.satVal
                            displayValue: Math.round(colorPaletteCard.satVal * 100) + "%"
                            thumbColor: Qt.hsva(colorPaletteCard.hueVal, colorPaletteCard.satVal, colorPaletteCard.briVal, 1.0)
                            trackGradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.hsva(colorPaletteCard.hueVal, 0.0, colorPaletteCard.briVal, 1.0) }
                                GradientStop { position: 1.0; color: Qt.hsva(colorPaletteCard.hueVal, 1.0, colorPaletteCard.briVal, 1.0) }
                            }
                            onMoved: function(v) {
                                colorPaletteCard.satVal = v
                                colorPaletteCard.applyFromSliders()
                            }
                            onReleased: if (root.w) root.w.saveToDisk()
                        }

                        ColorSlider {
                            label: "Bri"
                            value: colorPaletteCard.briVal
                            displayValue: Math.round(colorPaletteCard.briVal * 100) + "%"
                            thumbColor: Qt.hsva(colorPaletteCard.hueVal, colorPaletteCard.satVal, colorPaletteCard.briVal, 1.0)
                            trackGradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#000000" }
                                GradientStop { position: 1.0; color: Qt.hsva(colorPaletteCard.hueVal, colorPaletteCard.satVal, 1.0, 1.0) }
                            }
                            onMoved: function(v) {
                                colorPaletteCard.briVal = v
                                colorPaletteCard.applyFromSliders()
                            }
                            onReleased: if (root.w) root.w.saveToDisk()
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
                                Layout.preferredHeight: Style.space(28)
                                foreground: root.fg
                                placeholderText: "#HEX (e.g. #3b82f6)"
                                font.family: Style.font.family
                                font.pixelSize: Style.font.bodySmall
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
                                        colorPaletteCard.applyColorToTarget(h, true)
                                        colorPaletteCard.isSyncing = false
                                    }
                                }
                                Keys.onReturnPressed: function(event) {
                                    event.accepted = true
                                    var h = text.trim()
                                    if (h.indexOf("#") !== 0 && h.length > 0) h = "#" + h
                                    if (Model.hexToRgb(h)) {
                                        colorPaletteCard.selectSwatch(h)
                                    }
                                }
                                Keys.onEnterPressed: function(event) {
                                    event.accepted = true
                                    var h = text.trim()
                                    if (h.indexOf("#") !== 0 && h.length > 0) h = "#" + h
                                    if (Model.hexToRgb(h)) {
                                        colorPaletteCard.selectSwatch(h)
                                    }
                                }
                                Keys.onEscapePressed: function(event) {
                                    event.accepted = true
                                    colorPaletteCard.cancelAndClose()
                                }
                            }

                            Rectangle {
                                id: randomBtn
                                Layout.preferredHeight: Style.space(28)
                                Layout.preferredWidth: Style.space(34)
                                radius: Style.space(5)
                                color: randomMouse.containsMouse ? root.surfaceHover : root.surface
                                border.width: 1
                                border.color: randomMouse.containsMouse ? Color.accent : root.hairline

                                Text {
                                    anchors.centerIn: parent
                                    text: "🎲"
                                    font.family: Style.font.family
                                    font.pixelSize: Style.font.bodySmall
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
