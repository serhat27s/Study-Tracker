// Model.js - Core data calculations and formatting for Study Tracker

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
    if (!total || total <= 0) return "0m";
    var hrs = Math.floor(total / 3600);
    var mins = Math.floor((total % 3600) / 60);
    var secs = total % 60;
    if (hrs > 0) {
        return mins > 0 ? (hrs + "h " + mins + "m") : (hrs + "h");
    }
    if (mins > 0) {
        return mins + "m";
    }
    return secs + "s";
}

var MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
var DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

function formatDateReadable(keyStr) {
    if (!keyStr) return "";
    var parts = keyStr.split("-");
    if (parts.length !== 3) return keyStr;
    var d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
    var dayIdx = (d.getDay() + 6) % 7;
    return DAY_NAMES[dayIdx] + ", " + MONTH_NAMES[d.getMonth()] + " " + d.getDate();
}

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
        var tag = sess.tag || "General";
        dayMap[dk].tags[tag] = (dayMap[dk].tags[tag] || 0) + sess.duration;
    }

    var today = new Date();
    var todayDk = dateKey(today);
    // Monday = 0, Sunday = 6
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
                focusTimeStr: sec > 0 ? formatDurationHuman(sec) : "0m",
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
        streakDays: streak,
        sessionCount: historyList.length
    };
}

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
            if (scope === "today") {
                var dk = dateKey(new Date(sess.timestamp));
                if (dk !== todayDk) continue;
            }
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
        it.percent = grandTotal > 0 ? Math.round((it.seconds / grandTotal) * 100) : 0;
        it.ratio = maxSec > 0 ? (it.seconds / maxSec) : 0;
    }

    return {
        apps: appList,
        totalSeconds: grandTotal,
        totalFormatted: formatDurationHuman(grandTotal)
    };
}

function defaultSampleHistory() {
    var now = new Date();
    var list = [];
    var tags = ["Coding", "Math", "Reading", "Research", "General"];
    var apps = ["antigravity", "firefox", "terminal", "code", "obsidian"];

    for (var d = 13; d >= 0; d--) {
        if (d % 4 === 1 && d !== 1) continue;
        var count = (d % 3 === 0) ? 2 : 1;
        for (var c = 0; c < count; c++) {
            var sessDate = new Date(now.getTime() - d * 86400000 - (c * 2 + 1) * 3600000);
            var tag = tags[(d + c) % tags.length];
            var dur = ((d % 2 === 0 ? 25 : 45) + c * 15) * 60;
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
