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

    // Timer-Modi & Dauern (in Sekunden)
    property string activeMode: "pomodoro" // "pomodoro" | "tracker"
    property string pomodoroPhase: "work"  // "work" | "shortBreak" | "longBreak"
    property int pomodoroWorkDuration: 1500       // 25m
    property int pomodoroShortBreakDuration: 300  // 5m
    property int pomodoroLongBreakDuration: 900   // 15m
    property int pomodoroCyclesTarget: 4          // 4 Zyklen
    property int pomodoroCyclesCompleted: 0

    property string activeTag: "Mathe"
    property var recentTags: ["Mathe", "Programmieren", "Physik", "Lesen", "Recherche"]
    property var tagColors: ({})

    property int remainingSeconds: 1500
    property int elapsedSeconds: 0
    property int sessionDuration: 0        // Sekunden der laufenden Session
    property bool isRunning: false

    // System-Uptime in Sekunden
    property int systemUptimeSeconds: 0

    // App-Nutzung für aktive Session: { [appName]: seconds }
    property var currentAppUsage: ({})

    // Gespeicherte Sessions: [ { id, tag, mode, duration, timestamp, app_usage } ]
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
    // Speicherung & Persistenz
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
                    if (parsed && Array.isArray(parsed.history) && parsed.history.length > 0) {
                        var hasReal = parsed.history.some(function(s) {
                            return s.id && String(s.id).indexOf("sess_") === 0
                        })
                        if (!hasReal && parsed.history.length <= 15) {
                            root.history = Model.defaultSampleHistory()
                            root.saveToDisk()
                        } else {
                            root.history = parsed.history
                        }
                    } else {
                        root.history = Model.defaultSampleHistory()
                        root.saveToDisk()
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
                    root.saveToDisk()
                }
            } catch (e) {
                root.history = Model.defaultSampleHistory()
                root.saveToDisk()
            }
            root.storageReady = true
        }
        onLoadFailed: {
            root.history = Model.defaultSampleHistory()
            root.saveToDisk()
            root.storageReady = true
        }
    }

    function saveToDisk() {
        var payload = {
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
    // System-Uptime Ermittlung
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
    // Aktives Fenster Tracking & Session Ticker
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
                var app = root.getCurrentActiveApp()
                var usage = Object.assign({}, root.currentAppUsage)
                usage[app] = (usage[app] || 0) + 1
                root.currentAppUsage = usage
                root.sessionDuration += 1

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
    // Statuswechsel & Aktionen
    // -------------------------------------------------------------------------
    function handlePomodoroFinished() {
        root.isRunning = false
        if (root.pomodoroPhase === "work") {
            root.pomodoroCyclesCompleted += 1
            root.notify("Pomodoro beendet! 🍅", "Großartige Lerneinheit! Zeit für eine Pause.")
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
            root.notify("Pause vorbei! ☕", "Bereit für den nächsten Fokus-Block?")
            root.pomodoroPhase = "work"
            root.remainingSeconds = root.pomodoroWorkDuration
        }
    }

    function saveSessionRecord() {
        if (root.sessionDuration <= 0) return
        var newRecord = {
            id: "sess_" + Date.now(),
            tag: root.activeTag || "Allgemein",
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
        if (root.sessionDuration >= 60 && (root.activeMode !== "pomodoro" || root.pomodoroPhase === "work")) {
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
        root.isRunning = false
        root.activeMode = mode
        if (mode === "pomodoro") {
            root.remainingSeconds = (root.pomodoroPhase === "work") ? root.pomodoroWorkDuration : (root.pomodoroPhase === "shortBreak" ? root.pomodoroShortBreakDuration : root.pomodoroLongBreakDuration)
        } else {
            root.elapsedSeconds = 0
        }
    }

    function setPomodoroPhase(phase) {
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

    function setTagColor(tag, colorHex) {
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
        root.saveToDisk()
    }

    function removeTag(tag) {
        var clean = String(tag).trim()
        var tags = root.recentTags.slice()
        var idx = tags.indexOf(clean)
        if (idx !== -1) {
            tags.splice(idx, 1)
            if (tags.length === 0) tags = ["Allgemein"]
            root.recentTags = tags
            if (root.activeTag === clean) {
                root.activeTag = tags[0]
            }
            if (root.tagColors && root.tagColors[clean]) {
                var nextColors = Object.assign({}, root.tagColors)
                delete nextColors[clean]
                root.tagColors = nextColors
            }
            root.saveToDisk()
        }
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

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: (root.isRunning ? (root.activeMode === "pomodoro" ? "󰄉 " : "󰔛 ") : (root.activeMode === "pomodoro" ? "󰔟 " : "󱎫 ")) + root.formattedTime() + " · 🏷️ " + root.activeTag
        tooltipText: "Study Tracker (" + (root.activeMode === "pomodoro" ? (root.pomodoroPhase === "work" ? "Pomodoro" : "Pause") : "Stoppuhr") + ") — Klick: Panel öffnen, Rechtsklick: " + (root.isRunning ? "Pause" : "Start")
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton) root.toggle()
            else if (buttonCode === Qt.RightButton) root.toggleRunning()
        }
    }
}
