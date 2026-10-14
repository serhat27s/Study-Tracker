import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
    id: root
    moduleName: "io.github.yourname.study-tracker"

    // Timer modes & durations (in seconds)
    property string activeMode: "pomodoro" // "pomodoro" | "tracker"
    property string pomodoroPhase: "work"  // "work" | "shortBreak" | "longBreak"
    property int pomodoroWorkDuration: 1500       // 25m
    property int pomodoroShortBreakDuration: 300  // 5m
    property int pomodoroLongBreakDuration: 900   // 15m
    property int pomodoroCyclesTarget: 4          // 4 cycles
    property int pomodoroCyclesCompleted: 0

    property string activeTag: "Math"
    property var recentTags: ["Math", "Coding", "Physics", "Reading", "Research"]
    property var tagColors: ({})

    property int remainingSeconds: 1500
    property int elapsedSeconds: 0
    property int sessionDuration: 0        // Seconds of running session
    property bool isRunning: false

    // System uptime in seconds
    property int systemUptimeSeconds: 0

    // True when timer is in an active study session (stopwatch or pomodoro work phase)
    readonly property bool isStudySession: (root.activeMode !== "pomodoro" || root.pomodoroPhase === "work")

    // App usage for active session: { [appName]: seconds }
    property var currentAppUsage: ({})

    // Saved sessions: [ { id, tag, mode, duration, timestamp, app_usage } ]
    property var history: []

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

    function open() { if (panelLoader.item) panelLoader.item.open() }
    function close() { if (panelLoader.item) panelLoader.item.close() }
    function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
    function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

    function injectPanel() {
        if (!panelLoader.item) return
        panelLoader.item.bar = root.bar
        panelLoader.item.anchorItem = button
        panelLoader.item.hostWidget = root
        panelLoader.item.rootWidget = root
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onBarChanged: injectPanel()

    // -------------------------------------------------------------------------
    // Storage & Persistence
    // -------------------------------------------------------------------------
    readonly property string dataDir: Quickshell.env("HOME") + "/.local/share/study-tracker"
    readonly property string dataPath: dataDir + "/data.json"
    property bool storageReady: false

    Process {
        id: ensureDir
        command: ["mkdir", "-p", root.dataDir]
        onExited: dataFile.path = root.dataPath
    }

    FileView {
        id: dataFile
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                var content = text()
                if (content && content.length > 0) {
                    var parsed = JSON.parse(content)
                    if (parsed && Array.isArray(parsed.history)) {
                        var hasReal = parsed.history.some(function(s) {
                            return s.id && String(s.id).indexOf("sess_") === 0
                        })
                        if (!parsed.initialized && !hasReal && parsed.history.length <= 15) {
                            root.history = Model.defaultSampleHistory()
                            root.storageReady = true
                            root.saveToDisk()
                        } else {
                            root.history = parsed.history
                        }
                    } else {
                        root.history = Model.defaultSampleHistory()
                        root.storageReady = true
                        root.saveToDisk()
                    }
                    if (parsed && parsed.activeTag && String(parsed.activeTag).trim().length > 0) {
                        root.activeTag = String(parsed.activeTag).trim()
                    }
                    if (parsed && Array.isArray(parsed.recentTags) && parsed.recentTags.length > 0) {
                        root.recentTags = parsed.recentTags
                    }
                    if (parsed && parsed.tagColors && typeof parsed.tagColors === "object") {
                        root.tagColors = parsed.tagColors
                    }
                    if (parsed.pomodoroWorkDuration && Number(parsed.pomodoroWorkDuration) > 0)
                        root.pomodoroWorkDuration = Number(parsed.pomodoroWorkDuration)
                    if (parsed.pomodoroShortBreakDuration && Number(parsed.pomodoroShortBreakDuration) > 0)
                        root.pomodoroShortBreakDuration = Number(parsed.pomodoroShortBreakDuration)
                    if (parsed.hasOwnProperty && parsed.hasOwnProperty("pomodoroLongBreakDuration") && !isNaN(Number(parsed.pomodoroLongBreakDuration)))
                        root.pomodoroLongBreakDuration = Math.max(0, Number(parsed.pomodoroLongBreakDuration))
                    else if (parsed.pomodoroLongBreakDuration && Number(parsed.pomodoroLongBreakDuration) > 0)
                        root.pomodoroLongBreakDuration = Number(parsed.pomodoroLongBreakDuration)
                    if (parsed.pomodoroCyclesTarget && Number(parsed.pomodoroCyclesTarget) > 0)
                        root.pomodoroCyclesTarget = Number(parsed.pomodoroCyclesTarget)
                    if (!root.isRunning && root.activeMode === "pomodoro") {
                        root.remainingSeconds = (root.pomodoroPhase === "work")
                            ? root.pomodoroWorkDuration
                            : (root.pomodoroPhase === "shortBreak" ? root.pomodoroShortBreakDuration : root.pomodoroLongBreakDuration)
                    }
                } else {
                    root.history = Model.defaultSampleHistory()
                    root.storageReady = true
                    root.saveToDisk()
                }
            } catch (e) {
                console.warn("StudyTracker: data.json read error, preserving file:", e)
            }
            root.storageReady = true
        }
        onLoadFailed: {
            root.history = Model.defaultSampleHistory()
            root.storageReady = true
            root.saveToDisk()
        }
    }

    function saveToDisk() {
        if (!root.storageReady) return
        var payload = {
            initialized: true,
            activeTag: root.activeTag,
            history: root.history,
            recentTags: root.recentTags,
            tagColors: root.tagColors,
            pomodoroWorkDuration: root.pomodoroWorkDuration,
            pomodoroShortBreakDuration: root.pomodoroShortBreakDuration,
            pomodoroLongBreakDuration: root.pomodoroLongBreakDuration,
            pomodoroCyclesTarget: root.pomodoroCyclesTarget,
            lastSaved: new Date().toISOString()
        }
        dataFile.setText(JSON.stringify(payload, null, 2))
    }

    // -------------------------------------------------------------------------
    // System Uptime Tracking
    // -------------------------------------------------------------------------
    Process {
        id: uptimeProc
        command: ["sh", "-c", "cut -d' ' -f1 /proc/uptime"]
        stdout: StdioCollector {
            id: uptimeCollector
            waitForEnd: true
            onStreamFinished: {
                var raw = uptimeCollector.text.trim()
                var sec = parseFloat(raw)
                if (!isNaN(sec)) {
                    root.systemUptimeSeconds = Math.floor(sec)
                }
            }
        }
    }

    function refreshUptime() {
        if (!uptimeProc.running) uptimeProc.running = true
    }

    Component.onCompleted: {
        ensureDir.running = true
        root.refreshUptime()
    }

    // -------------------------------------------------------------------------
    // Active Window Tracking & Session Ticker
    // -------------------------------------------------------------------------
    function getCurrentActiveApp() {
        try {
            if (typeof Hyprland !== "undefined" && Hyprland.activeToplevel) {
                var top = Hyprland.activeToplevel
                var ipc = top.lastIpcObject
                if (ipc && ipc.class && ipc.class.length > 0) return ipc.class
                if (ipc && ipc.initialClass && ipc.initialClass.length > 0) return ipc.initialClass
                if (top.title && top.title.length > 0) return top.title
            }
        } catch (e) {
            // fallback
        }
        return "Desktop"
    }

    Timer {
        id: sessionTicker
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            if (root.systemUptimeSeconds > 0) {
                root.systemUptimeSeconds += 1
            }

            if (root.isRunning) {
                if (root.isStudySession) {
                    var app = root.getCurrentActiveApp()
                    var usage = Object.assign({}, root.currentAppUsage)
                    usage[app] = (usage[app] || 0) + 1
                    root.currentAppUsage = usage
                    root.sessionDuration += 1
                }

                if (root.activeMode === "pomodoro") {
                    if (root.remainingSeconds > 0) {
                        root.remainingSeconds -= 1
                    }
                    if (root.remainingSeconds <= 0) {
                        root.handlePomodoroFinished()
                    }
                } else {
                    root.elapsedSeconds += 1
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // State Transitions & Actions
    // -------------------------------------------------------------------------
    function handlePomodoroFinished() {
        root.isRunning = false
        if (root.pomodoroPhase === "work") {
            root.pomodoroCyclesCompleted += 1
            root.notify("Pomodoro Finished! 🍅", "Great focus session! Time for a break.")
            if (root.sessionDuration > 0) {
                root.saveSessionRecord()
            }
            var target = root.pomodoroCyclesTarget > 0 ? root.pomodoroCyclesTarget : 4
            if (root.pomodoroLongBreakDuration > 0 && root.pomodoroCyclesCompleted % target === 0) {
                root.pomodoroPhase = "longBreak"
                root.remainingSeconds = root.pomodoroLongBreakDuration
            } else {
                root.pomodoroPhase = "shortBreak"
                root.remainingSeconds = root.pomodoroShortBreakDuration
            }
        } else {
            root.notify("Break Over! ☕", "Ready for the next focus block?")
            root.pomodoroPhase = "work"
            root.remainingSeconds = root.pomodoroWorkDuration
        }
    }

    function saveSessionRecord() {
        if (root.sessionDuration <= 0) return
        var newRecord = {
            id: "sess_" + Date.now(),
            tag: root.activeTag || "General",
            mode: root.activeMode,
            duration: root.sessionDuration,
            timestamp: new Date().toISOString(),
            app_usage: Object.assign({}, root.currentAppUsage)
        }
        var nextHistory = root.history.slice()
        nextHistory.unshift(newRecord)
        root.history = nextHistory

        root.sessionDuration = 0
        root.currentAppUsage = ({})

        root.saveToDisk()
    }

    function finishAndSave() {
        root.resetTimer()
    }

    function resetTimer() {
        root.isRunning = false
        if (root.sessionDuration >= 60 && root.isStudySession) {
            root.saveSessionRecord()
        } else {
            root.sessionDuration = 0
            root.currentAppUsage = ({})
        }
        if (root.activeMode === "pomodoro") {
            root.remainingSeconds = (root.pomodoroPhase === "work") ? root.pomodoroWorkDuration : (root.pomodoroPhase === "shortBreak" ? root.pomodoroShortBreakDuration : root.pomodoroLongBreakDuration)
        } else {
            root.elapsedSeconds = 0
        }
    }

    function toggleRunning() {
        root.isRunning = !root.isRunning
    }

    function setMode(mode) {
        if (root.activeMode === mode) return
        if (root.sessionDuration >= 60 && root.isStudySession) {
            root.saveSessionRecord()
        } else {
            root.sessionDuration = 0
            root.currentAppUsage = ({})
        }
        root.isRunning = false
        root.activeMode = mode
        if (mode === "pomodoro") {
            root.remainingSeconds = (root.pomodoroPhase === "work") ? root.pomodoroWorkDuration : (root.pomodoroPhase === "shortBreak" ? root.pomodoroShortBreakDuration : root.pomodoroLongBreakDuration)
        } else {
            root.elapsedSeconds = 0
        }
    }

    function setPomodoroPhase(phase) {
        if (root.sessionDuration >= 60 && root.isStudySession) {
            root.saveSessionRecord()
        } else {
            root.sessionDuration = 0
            root.currentAppUsage = ({})
        }
        root.isRunning = false
        if (phase === "longBreak" && root.pomodoroLongBreakDuration <= 0) {
            phase = "shortBreak"
        }
        root.pomodoroPhase = phase
        if (phase === "work") root.remainingSeconds = root.pomodoroWorkDuration
        else if (phase === "shortBreak") root.remainingSeconds = root.pomodoroShortBreakDuration
        else if (phase === "longBreak") root.remainingSeconds = root.pomodoroLongBreakDuration
    }

    function setPomodoroDuration(phase, seconds) {
        if (!seconds || seconds <= 0) return
        var sec = Math.round(seconds)
        if (phase === "work") {
            root.pomodoroWorkDuration = sec
            if (!root.isRunning && root.pomodoroPhase === "work" && root.activeMode === "pomodoro") {
                root.remainingSeconds = sec
            }
        } else if (phase === "shortBreak") {
            root.pomodoroShortBreakDuration = sec
            if (!root.isRunning && root.pomodoroPhase === "shortBreak" && root.activeMode === "pomodoro") {
                root.remainingSeconds = sec
            }
        } else if (phase === "longBreak") {
            root.pomodoroLongBreakDuration = sec
            if (!root.isRunning && root.pomodoroPhase === "longBreak" && root.activeMode === "pomodoro") {
                root.remainingSeconds = sec
            }
        }
        root.saveToDisk()
    }

    function setPomodoroPreset(workMin, shortBreakMin, longBreakMin) {
        root.pomodoroWorkDuration = Math.round(workMin * 60)
        root.pomodoroShortBreakDuration = Math.round(shortBreakMin * 60)
        root.pomodoroLongBreakDuration = Math.round((longBreakMin || 0) * 60)
        if (root.pomodoroLongBreakDuration <= 0 && root.pomodoroPhase === "longBreak") {
            root.pomodoroPhase = "shortBreak"
        }
        if (!root.isRunning && root.activeMode === "pomodoro") {
            if (root.pomodoroPhase === "work") root.remainingSeconds = root.pomodoroWorkDuration
            else if (root.pomodoroPhase === "shortBreak") root.remainingSeconds = root.pomodoroShortBreakDuration
            else if (root.pomodoroPhase === "longBreak") root.remainingSeconds = root.pomodoroLongBreakDuration
        }
        root.saveToDisk()
    }

    function addTag(tag, customColor) {
        var clean = String(tag).trim()
        if (clean.length === 0) return
        root.activeTag = clean
        var tags = root.recentTags.slice()
        var idx = tags.indexOf(clean)
        if (idx !== -1) {
            tags.splice(idx, 1)
        }
        tags.unshift(clean)
        if (tags.length > 20) tags = tags.slice(0, 20)
        root.recentTags = tags
        if (customColor && String(customColor).trim().length > 0) {
            var c = String(customColor).trim()
            if (c.indexOf("#") !== 0) c = "#" + c
            var nextColors = Object.assign({}, root.tagColors)
            nextColors[clean] = c
            root.tagColors = nextColors
        }
        root.saveToDisk()
    }

    function setTagColor(tag, colorHex, skipSave) {
        var clean = String(tag).trim()
        if (clean.length === 0) return
        var next = Object.assign({}, root.tagColors)
        if (colorHex && String(colorHex).trim().length > 0) {
            var c = String(colorHex).trim()
            if (c.indexOf("#") !== 0) c = "#" + c
            next[clean] = c
        } else {
            delete next[clean]
        }
        root.tagColors = next
        if (!skipSave) root.saveToDisk()
    }

    function removeTag(tag) {
        var clean = String(tag || "").trim()
        if (clean.length === 0) return

        // 1. Remove from recentTags (case-insensitive check)
        var tags = root.recentTags.slice()
        var idx = -1
        for (var i = 0; i < tags.length; i++) {
            if (String(tags[i]).trim().toLowerCase() === clean.toLowerCase()) {
                idx = i
                break
            }
        }
        if (idx !== -1) {
            tags.splice(idx, 1)
        }
        if (tags.length === 0) tags = ["General"]
        root.recentTags = tags

        // 2. If activeTag is this tag, switch to first remaining tag
        if (String(root.activeTag).trim().toLowerCase() === clean.toLowerCase()) {
            root.activeTag = tags[0]
            if (!root.isRunning) {
                root.sessionDuration = 0
                root.currentAppUsage = ({})
            }
        }

        // 3. Remove custom color if present
        if (root.tagColors) {
            var nextColors = Object.assign({}, root.tagColors)
            var hadColor = false
            for (var cKey in nextColors) {
                if (String(cKey).trim().toLowerCase() === clean.toLowerCase()) {
                    delete nextColors[cKey]
                    hadColor = true
                }
            }
            if (hadColor) {
                root.tagColors = nextColors
            }
        }

        // 4. Purge all sessions matching this tag from history so it doesn't mess up stats
        var nextHistory = root.history.filter(function(sess) {
            if (!sess) return false
            var sessTag = String(sess.tag || "").trim().toLowerCase()
            return sessTag !== clean.toLowerCase()
        })
        root.history = nextHistory

        // 5. Persist to disk
        root.saveToDisk()
    }

    function formattedTime() {
        var total = (root.activeMode === "pomodoro") ? root.remainingSeconds : root.elapsedSeconds
        return Model.formatSeconds(total)
    }

    function notify(title, body) {
        try {
            Quickshell.execDetached(["notify-send", "--app-name=Study Tracker", "--icon=alarm-symbolic", title, body])
        } catch (e) {
            console.warn("StudyTracker notify error:", e)
        }
    }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
    }

    readonly property real openPanelIndicatorWidth: {
        if (!root.isRunning && typeof iconGlyph !== "undefined" && iconGlyph)
            return Math.max(Style.space(12), Math.round(iconGlyph.tightWidth))
        if (root.bar && root.bar.vertical)
            return Style.bar.iconSlot
        return button.labelWidth
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        labelVisible: root.isRunning
        fixedWidth: (root.bar && root.bar.vertical) ? -1 : (root.isRunning ? -1 : Style.bar.iconSlot)
        text: {
            if (!root.isRunning) {
                return "\uf19d"
            }
            return (root.activeMode === "pomodoro" ? "󰄉 " : "󰔛 ") + root.formattedTime() + " · 🏷️ " + root.activeTag
        }
        tooltipText: "Study Tracker (" + (root.activeMode === "pomodoro" ? (root.pomodoroPhase === "work" ? "Pomodoro" : "Break") : "Stopwatch") + ") — Click: Open panel, Right-click: " + (root.isRunning ? "Pause" : "Start")
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton) root.toggle()
            else if (buttonCode === Qt.RightButton) root.toggleRunning()
        }

        OpticalGlyph {
            id: iconGlyph
            visible: !root.isRunning
            anchors.fill: parent
            text: "\uf19d"
            fontFamily: button.fontFamily
            fontSize: button.fontSize
            color: button.active && button.useActiveColor ? button.activeColor : button.foreground
        }
    }
}
