// Model.js - Kernlogik für Study Tracker (Pomodoro, Stoppuhr, Tag-Statistiken, Heatmap & Uptime)

function padZero(n) {
    return n < 10 ? "0" + n : "" + n;
}

function dateKey(d) {
    var date = (d instanceof Date) ? d : new Date(d);
    return date.getFullYear() + "-" + padZero(date.getMonth() + 1) + "-" + padZero(date.getDate());
}

function formatSeconds(total) {
    if (!total || total < 0) total = 0;
    var hrs = Math.floor(total / 3600);
    var mins = Math.floor((total % 3600) / 60);
    var secs = total % 60;
    if (hrs > 0) {
        return hrs + ":" + (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs;
    }
    return (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs;
}

function formatDurationHuman(total) {
    if (!total || total <= 0) return "0 Min.";
    var hrs = Math.floor(total / 3600);
    var mins = Math.floor((total % 3600) / 60);
    var secs = total % 60;
    if (hrs > 0) {
        return mins > 0 ? (hrs + " Std. " + mins + " Min.") : (hrs + " Std.");
    }
    if (mins > 0) {
        return mins + " Min.";
    }
    return secs + " Sek.";
}

function formatHoursDecimal(total) {
    if (!total || total <= 0) return "0.0 Std.";
    var h = (total / 3600).toFixed(1);
    return h + " Std.";
}

function formatUptime(totalSec) {
    if (!totalSec || totalSec <= 0) return "0 Min.";
    var days = Math.floor(totalSec / 86400);
    var hrs = Math.floor((totalSec % 86400) / 3600);
    var mins = Math.floor((totalSec % 3600) / 60);
    var parts = [];
    if (days > 0) parts.push(days + (days === 1 ? " Tag" : " Tage"));
    if (hrs > 0) parts.push(hrs + (hrs === 1 ? " Std." : " Std."));
    if (mins > 0 || parts.length === 0) parts.push(mins + " Min.");
    return parts.join(", ");
}

var TAG_COLORS = [
    "#e84393", // Pink
    "#4cd137", // Green
    "#00a8ff", // Blue
    "#c56cf0", // Lavender
    "#fdcb6e", // Yellow
    "#ff6b6b", // Red
    "#10ac84", // Teal
    "#575fcf"  // Indigo
];

function tagColor(tagName, index) {
    if (typeof index === "number" && index >= 0) {
        return TAG_COLORS[index % TAG_COLORS.length];
    }
    var hash = 0;
    var str = String(tagName || "");
    for (var i = 0; i < str.length; i++) {
        hash = ((hash << 5) - hash) + str.charCodeAt(i);
        hash |= 0;
    }
    return TAG_COLORS[Math.abs(hash) % TAG_COLORS.length];
}

var MONAT_NAMEN = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"];
var TAGE_NAMEN = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];

function formatDateReadable(keyStr) {
    if (!keyStr) return "";
    var parts = keyStr.split("-");
    if (parts.length !== 3) return keyStr;
    var d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
    var dayIdx = (d.getDay() + 6) % 7;
    return TAGE_NAMEN[dayIdx] + ", " + d.getDate() + ". " + MONAT_NAMEN[d.getMonth()];
}

// -----------------------------------------------------------------------------
// Tag-Stunden-Auswertung ("Wie viele Stunden für welches Fach/Tag")
// -----------------------------------------------------------------------------
// Prüft, ob ein Zeitstempel in den Zeitraum fällt: "today" | "week" (letzte 7 Tage) | sonst alles
function inScope(timestamp, scope) {
    if (scope === "today") {
        return dateKey(new Date(timestamp)) === dateKey(new Date());
    }
    if (scope === "week") {
        var now = new Date();
        var start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 6);
        return new Date(timestamp).getTime() >= start.getTime();
    }
    return true;
}

function aggregateTagStats(history, scope) {
    var historyList = Array.isArray(history) ? history : [];
    var tagMap = {};

    var grandTotalSeconds = 0;
    for (var i = 0; i < historyList.length; i++) {
        var sess = historyList[i];
        if (!sess || !sess.duration) continue;
        if (!inScope(sess.timestamp, scope)) continue;
        var tag = sess.tag || "Allgemein";
        if (!tagMap[tag]) {
            tagMap[tag] = { tag: tag, totalSeconds: 0, sessionCount: 0 };
        }
        tagMap[tag].totalSeconds += sess.duration;
        tagMap[tag].sessionCount += 1;
        grandTotalSeconds += sess.duration;
    }

    var list = [];
    var maxSeconds = 0;
    for (var t in tagMap) {
        var item = tagMap[t];
        if (item.totalSeconds > maxSeconds) maxSeconds = item.totalSeconds;
        list.push(item);
    }
    list.sort(function(a, b) { return b.totalSeconds - a.totalSeconds; });

    for (var j = 0; j < list.length; j++) {
        var it = list[j];
        it.formatted = formatDurationHuman(it.totalSeconds);
        it.hoursDec = formatHoursDecimal(it.totalSeconds);
        it.percent = grandTotalSeconds > 0 ? Math.round((it.totalSeconds / grandTotalSeconds) * 100) : 0;
        it.ratio = maxSeconds > 0 ? (it.totalSeconds / maxSeconds) : 0;
    }

    return {
        tags: list,
        grandTotalSeconds: grandTotalSeconds,
        grandTotalFormatted: formatDurationHuman(grandTotalSeconds),
        grandTotalHours: formatHoursDecimal(grandTotalSeconds)
    };
}

// -----------------------------------------------------------------------------
// 7-Zeilen GitHub Aktivitätsgraph (Montag bis Sonntag)
// -----------------------------------------------------------------------------
function buildHeatmap(history, numWeeks) {
    if (!numWeeks || numWeeks < 1) numWeeks = 14;
    var historyList = Array.isArray(history) ? history : [];

    var dayMap = {};
    for (var i = 0; i < historyList.length; i++) {
        var sess = historyList[i];
        if (!sess || !sess.timestamp || !sess.duration) continue;
        var dk = dateKey(new Date(sess.timestamp));
        if (!dayMap[dk]) {
            dayMap[dk] = { totalSeconds: 0, tags: {} };
        }
        dayMap[dk].totalSeconds += sess.duration;
        var tag = sess.tag || "Allgemein";
        dayMap[dk].tags[tag] = (dayMap[dk].tags[tag] || 0) + sess.duration;
    }

    var today = new Date();
    var todayDk = dateKey(today);
    // Montag = 0, Sonntag = 6
    var todayDayOfWeek = (today.getDay() + 6) % 7;

    var currentMon = new Date(today.getFullYear(), today.getMonth(), today.getDate() - todayDayOfWeek);
    currentMon.setHours(0, 0, 0, 0);

    var startMon = new Date(currentMon.getTime() - (numWeeks - 1) * 7 * 86400000);

    var weeks = [];
    var totalSecondsLogged = 0;
    var todaySeconds = (dayMap[todayDk] ? dayMap[todayDk].totalSeconds : 0);

    for (var w = 0; w < numWeeks; w++) {
        var days = [];
        for (var d = 0; d < 7; d++) {
            var cellDate = new Date(startMon.getTime() + (w * 7 + d) * 86400000);
            var dk = dateKey(cellDate);
            var isFuture = cellDate.getTime() > today.getTime() && dk !== todayDk;
            var isToday = (dk === todayDk);
            var info = dayMap[dk] || { totalSeconds: 0, tags: {} };
            var sec = info.totalSeconds;
            var mins = Math.round(sec / 60);

            var level = 0;
            if (mins >= 120) level = 4;
            else if (mins >= 60) level = 3;
            else if (mins >= 30) level = 2;
            else if (mins > 0) level = 1;

            var tagArr = [];
            for (var t in info.tags) {
                tagArr.push({ tag: t, sec: info.tags[t] });
            }
            tagArr.sort(function(a, b) { return b.sec - a.sec; });
            var dominantTagsStr = tagArr.map(function(item) {
                return item.tag + ": " + formatDurationHuman(item.sec);
            }).join(" · ");

            days.push({
                dateKey: dk,
                dateStr: formatDateReadable(dk),
                dayOfWeek: d,
                weekIndex: w,
                isToday: isToday,
                isFuture: isFuture,
                totalSeconds: sec,
                totalMinutes: mins,
                focusTimeStr: sec > 0 ? formatDurationHuman(sec) : "0 Min.",
                hoursDec: formatHoursDecimal(sec),
                level: level,
                dominantTags: dominantTagsStr
            });
        }
        weeks.push(days);
    }

    var streak = 0;
    var checkDate = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    if ((dayMap[dateKey(checkDate)] ? dayMap[dateKey(checkDate)].totalSeconds : 0) === 0) {
        checkDate.setDate(checkDate.getDate() - 1);
    }
    while (true) {
        var k = dateKey(checkDate);
        if (dayMap[k] && dayMap[k].totalSeconds > 0) {
            streak++;
            checkDate.setDate(checkDate.getDate() - 1);
        } else {
            break;
        }
    }

    for (var k2 in dayMap) {
        totalSecondsLogged += dayMap[k2].totalSeconds;
    }

    return {
        weeks: weeks,
        totalSeconds: totalSecondsLogged,
        todaySeconds: todaySeconds,
        todayFormatted: formatDurationHuman(todaySeconds),
        todayHours: formatHoursDecimal(todaySeconds),
        totalFormatted: formatDurationHuman(totalSecondsLogged),
        totalHours: formatHoursDecimal(totalSecondsLogged),
        streakDays: streak,
        sessionCount: historyList.length
    };
}

// -----------------------------------------------------------------------------
// Programm-Nutzung (Stunden pro App)
// -----------------------------------------------------------------------------
function aggregateAppUsage(history, currentAppUsage, scope, selectedTag) {
    var historyList = Array.isArray(history) ? history : [];
    var appTotals = {};
    var todayDk = dateKey(new Date());

    function addUsage(appUsageMap) {
        if (!appUsageMap) return;
        for (var app in appUsageMap) {
            var val = appUsageMap[app] || 0;
            if (val > 0) {
                appTotals[app] = (appTotals[app] || 0) + val;
            }
        }
    }

    if (scope === "current") {
        addUsage(currentAppUsage);
    } else {
        for (var i = 0; i < historyList.length; i++) {
            var sess = historyList[i];
            if (!sess) continue;
            if (selectedTag && selectedTag !== "" && sess.tag !== selectedTag) {
                continue;
            }
            if (!inScope(sess.timestamp, scope)) continue;
            addUsage(sess.app_usage);
        }
        if (!selectedTag || selectedTag === "") {
            addUsage(currentAppUsage);
        }
    }

    var appList = [];
    var grandTotal = 0;
    var maxSec = 0;
    for (var appName in appTotals) {
        var sec = appTotals[appName];
        grandTotal += sec;
        if (sec > maxSec) maxSec = sec;
        appList.push({
            app: appName,
            seconds: sec
        });
    }

    appList.sort(function(a, b) { return b.seconds - a.seconds; });

    for (var j = 0; j < appList.length; j++) {
        var it = appList[j];
        it.formatted = formatDurationHuman(it.seconds);
        it.hoursDec = formatHoursDecimal(it.seconds);
        it.percent = grandTotal > 0 ? Math.round((it.seconds / grandTotal) * 100) : 0;
        it.ratio = maxSec > 0 ? (it.seconds / maxSec) : 0;
    }

    return {
        apps: appList,
        totalSeconds: grandTotal,
        totalFormatted: formatDurationHuman(grandTotal),
        totalHours: formatHoursDecimal(grandTotal)
    };
}

// -----------------------------------------------------------------------------
// Realistische Beispieldaten auf Deutsch
// -----------------------------------------------------------------------------
function defaultSampleHistory() {
    var now = new Date();
    var list = [];
    var tags = ["Mathe", "Programmieren", "Physik", "Lesen", "Recherche"];
    var apps = ["antigravity", "firefox", "alacritty", "code", "obsidian"];

    for (var d = 13; d >= 0; d--) {
        if (d % 4 === 1 && d !== 1) continue;
        var count = (d % 3 === 0) ? 2 : 1;
        for (var c = 0; c < count; c++) {
            var sessDate = new Date(now.getTime() - d * 86400000 - (c * 2 + 1) * 3600000);
            var tag = tags[(d + c) % tags.length];
            var dur = ((d % 2 === 0 ? 30 : 50) + c * 20) * 60;
            var app1 = apps[(d) % apps.length];
            var app2 = apps[(d + 1) % apps.length];
            var appMap = {};
            appMap[app1] = Math.round(dur * 0.7);
            appMap[app2] = dur - appMap[app1];

            list.push({
                id: "sample_" + sessDate.getTime() + "_" + c,
                tag: tag,
                mode: (dur <= 1800 ? "pomodoro" : "tracker"),
                duration: dur,
                timestamp: sessDate.toISOString(),
                app_usage: appMap
            });
        }
    }
    return list;
}
