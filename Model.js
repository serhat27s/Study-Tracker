// Model.js - Core logic for Study Tracker (Pomodoro, Stopwatch, Subject Stats, Heatmap & Uptime)

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
    if (!total || total <= 0) return "0 min";
    var hrs = Math.floor(total / 3600);
    var mins = Math.floor((total % 3600) / 60);
    var secs = total % 60;
    if (hrs > 0) {
        return mins > 0 ? (hrs + (hrs === 1 ? " hr " : " hrs ") + mins + " min") : (hrs + (hrs === 1 ? " hr" : " hrs"));
    }
    if (mins > 0) {
        return mins + " min";
    }
    return secs + " sec";
}

function formatHoursDecimal(total) {
    if (!total || total <= 0) return "0.0 hrs";
    var h = (total / 3600).toFixed(1);
    return h + (h === "1.0" ? " hr" : " hrs");
}

var TAG_COLORS = [
    "#3b82f6", // Blue
    "#10b981", // Emerald
    "#f59e0b", // Amber
    "#ec4899", // Pink
    "#8b5cf6", // Purple
    "#06b6d4", // Cyan
    "#ef4444", // Red
    "#84cc16", // Lime
    "#6366f1", // Indigo
    "#14b8a6", // Teal
    "#d946ef", // Fuchsia
    "#eab308", // Yellow
    "#f97316", // Orange
    "#64748b"  // Slate
];

var DEFAULT_TAG_COLORS = {
    // English defaults
    "Math": "#3b82f6",
    "Coding": "#10b981",
    "Physics": "#8b5cf6",
    "Reading": "#f59e0b",
    "Research": "#06b6d4",
    "English": "#ec4899",
    "General": "#64748b",
    // Backward compatibility for existing German tags
    "Mathe": "#3b82f6",
    "Programmieren": "#10b981",
    "Physik": "#8b5cf6",
    "Lesen": "#f59e0b",
    "Recherche": "#06b6d4",
    "Allgemein": "#64748b"
};

function tagColor(tagName, customMap) {
    var tag = String(tagName || "").trim();
    if (!tag) return TAG_COLORS[0];
    if (customMap && typeof customMap === "object" && customMap[tag]) {
        return customMap[tag];
    }
    if (DEFAULT_TAG_COLORS[tag]) {
        return DEFAULT_TAG_COLORS[tag];
    }
    var hash = 0;
    var str = tag.toLowerCase();
    for (var i = 0; i < str.length; i++) {
        hash = ((hash << 5) - hash) + str.charCodeAt(i);
        hash |= 0;
    }
    return TAG_COLORS[Math.abs(hash) % TAG_COLORS.length];
}

// -----------------------------------------------------------------------------
// Color Utilities (HSV, Hex conversion & Random Color Generation)
// -----------------------------------------------------------------------------
function hsvToRgb(h, s, v) {
    var r, g, b;
    var i = Math.floor(h * 6);
    var f = h * 6 - i;
    var p = v * (1 - s);
    var q = v * (1 - f * s);
    var t = v * (1 - (1 - f) * s);
    switch (i % 6) {
        case 0: r = v; g = t; b = p; break;
        case 1: r = q; g = v; b = p; break;
        case 2: r = p; g = v; b = t; break;
        case 3: r = p; g = q; b = v; break;
        case 4: r = t; g = p; b = v; break;
        case 5: r = v; g = p; b = q; break;
    }
    return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)];
}

function rgbToHsv(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    var max = Math.max(r, g, b), min = Math.min(r, g, b);
    var h = 0, s, v = max;
    var d = max - min;
    s = max === 0 ? 0 : d / max;
    if (max === min) {
        h = 0;
    } else {
        switch (max) {
            case r: h = (g - b) / d + (g < b ? 6 : 0); break;
            case g: h = (b - r) / d + 2; break;
            case b: h = (r - g) / d + 4; break;
        }
        h /= 6;
    }
    return [h, s, v];
}

function hexToRgb(hex) {
    if (!hex || typeof hex !== "string") return null;
    hex = hex.replace("#", "").trim();
    if (hex.length === 3) {
        hex = hex.charAt(0) + hex.charAt(0) + hex.charAt(1) + hex.charAt(1) + hex.charAt(2) + hex.charAt(2);
    }
    if (hex.length !== 6) return null;
    var num = parseInt(hex, 16);
    if (isNaN(num)) return null;
    return [(num >> 16) & 255, (num >> 8) & 255, num & 255];
}

function rgbToHex(r, g, b) {
    var toH = function(c) {
        var s = Math.max(0, Math.min(255, Math.round(c))).toString(16);
        return s.length === 1 ? "0" + s : s;
    };
    return "#" + toH(r) + toH(g) + toH(b);
}

function hsvToHex(h, s, v) {
    var rgb = hsvToRgb(h, s, v);
    return rgbToHex(rgb[0], rgb[1], rgb[2]);
}

function hexToHsv(hex) {
    var rgb = hexToRgb(hex);
    if (!rgb) return [0, 1, 1];
    return rgbToHsv(rgb[0], rgb[1], rgb[2]);
}

function randomCuratedOrHex(curatedPalette) {
    if (Math.random() < 0.5 && curatedPalette && curatedPalette.length > 0) {
        var idx = Math.floor(Math.random() * curatedPalette.length);
        return curatedPalette[idx];
    }
    var h = Math.random();
    var s = 0.65 + Math.random() * 0.35;
    var v = 0.80 + Math.random() * 0.20;
    return hsvToHex(h, s, v);
}

var MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
var DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

function formatDateReadable(keyStr) {
    if (!keyStr) return "";
    var parts = keyStr.split("-");
    if (parts.length !== 3) return keyStr;
    var year = parseInt(parts[0], 10);
    var d = new Date(year, parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
    var dayIdx = (d.getDay() + 6) % 7;
    var res = DAY_NAMES[dayIdx] + ", " + MONTH_NAMES[d.getMonth()] + " " + d.getDate();
    if (year !== (new Date()).getFullYear()) {
        res += " " + year;
    }
    return res;
}

// -----------------------------------------------------------------------------
// Subject Hours Analysis ("How many hours for which subject/tag")
// -----------------------------------------------------------------------------
// Checks whether a timestamp falls into the scope: "today" | "week" (last 7 days) | all
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
        var tag = sess.tag || "General";
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
// 7-Row GitHub Activity Graph: Calendar year (January to December)
// -----------------------------------------------------------------------------
function buildHeatmap(history, year) {
    var targetYear = (typeof year === "number" && year >= 2000) ? Math.round(year) : new Date().getFullYear();
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

    // Start: Monday of week containing Jan 1
    var jan1 = new Date(targetYear, 0, 1);
    var jan1Day = (jan1.getDay() + 6) % 7; // Monday = 0, Sunday = 6
    var startMon = new Date(targetYear, 0, 1 - jan1Day);
    startMon.setHours(0, 0, 0, 0);

    // End: Sunday of week containing Dec 31
    var dec31 = new Date(targetYear, 11, 31);
    var dec31Day = (dec31.getDay() + 6) % 7;
    var endSun = new Date(targetYear, 11, 31 + (6 - dec31Day));
    endSun.setHours(23, 59, 59, 999);

    var totalDays = Math.round((endSun.getTime() - startMon.getTime()) / 86400000) + 1;
    var numWeeks = Math.round(totalDays / 7);

    var weeks = [];
    var yearSecondsLogged = 0;
    var totalSecondsLogged = 0;
    var todaySeconds = (dayMap[todayDk] ? dayMap[todayDk].totalSeconds : 0);
    var todayWeekIndex = -1;

    for (var w = 0; w < numWeeks; w++) {
        var days = [];
        var monthLabel = "";
        for (var d = 0; d < 7; d++) {
            var cellDate = new Date(startMon.getFullYear(), startMon.getMonth(), startMon.getDate() + w * 7 + d);
            var dk = dateKey(cellDate);
            var isOutsideYear = (cellDate.getFullYear() !== targetYear);
            var isFuture = (cellDate.getTime() > today.getTime() && dk !== todayDk);
            var isToday = (dk === todayDk);
            var info = dayMap[dk] || { totalSeconds: 0, tags: {} };
            var sec = info.totalSeconds;
            var mins = Math.round(sec / 60);

            if (isToday) {
                todayWeekIndex = w;
            }

            if (!isOutsideYear) {
                yearSecondsLogged += sec;
                if (cellDate.getDate() === 1 || (w === 0 && cellDate.getDate() === jan1.getDate())) {
                    monthLabel = MONTH_NAMES[cellDate.getMonth()];
                }
            }

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
                isOutsideYear: isOutsideYear,
                totalSeconds: sec,
                totalMinutes: mins,
                focusTimeStr: sec > 0 ? formatDurationHuman(sec) : "0 min",
                hoursDec: formatHoursDecimal(sec),
                level: level,
                dominantTags: dominantTagsStr,
                monthLabel: ""
            });
        }
        if (days.length > 0) {
            days[0].monthLabel = monthLabel;
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
        year: targetYear,
        weeks: weeks,
        numWeeks: numWeeks,
        todayWeekIndex: (todayWeekIndex >= 0 ? todayWeekIndex : (targetYear < today.getFullYear() ? (numWeeks - 1) : 0)),
        totalSeconds: totalSecondsLogged,
        yearSeconds: yearSecondsLogged,
        todaySeconds: todaySeconds,
        todayFormatted: formatDurationHuman(todaySeconds),
        todayHours: formatHoursDecimal(todaySeconds),
        yearFormatted: formatDurationHuman(yearSecondsLogged),
        yearHours: formatHoursDecimal(yearSecondsLogged),
        totalFormatted: formatDurationHuman(totalSecondsLogged),
        totalHours: formatHoursDecimal(totalSecondsLogged),
        streakDays: streak,
        sessionCount: historyList.length
    };
}

// -----------------------------------------------------------------------------
// Application Usage (Hours per app)
// -----------------------------------------------------------------------------
function aggregateAppUsage(history, currentAppUsage, scope, selectedTag) {
    var historyList = Array.isArray(history) ? history : [];
    var appTotals = {};

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
// Consistency Tracker (Daily Goal: Hours or Blocks, Weekends Off/On, Streak & 30d Hit Rate)
// -----------------------------------------------------------------------------
function blockPresetMinutes(preset) {
    if (preset === "ultradian") return 90;
    if (preset === "deepWork") return 50;
    return 25;
}

function blockPresetName(preset) {
    if (preset === "ultradian") return "Ultradian";
    if (preset === "deepWork") return "Deep Work";
    return "Standard";
}

function formatHoursMinutesCompact(totalSeconds) {
    var sec = Math.max(0, Math.floor(totalSeconds || 0));
    var h = Math.floor(sec / 3600);
    var m = Math.floor((sec % 3600) / 60);
    return h + "h " + padZero(m) + "m";
}

function sessionBlocksCount(durationSeconds, blockMinutes) {
    var dur = Math.max(0, Math.floor(durationSeconds || 0));
    var bMin = blockMinutes || 25;
    var blockSec = bMin * 60;
    var graceSec = 120; // 2 minutes grace period for stopping slightly before end
    if (dur < blockSec - graceSec) return 0;
    return Math.floor((dur + graceSec) / blockSec);
}

function calculateConsistency(history, liveSessionSeconds, config) {
    var historyList = Array.isArray(history) ? history : [];
    var cfg = config || {};
    var goalMode = cfg.goalMode === "blocks" ? "blocks" : "hours";
    var targetHours = (typeof cfg.targetHours === "number" && cfg.targetHours >= 0.5) ? cfg.targetHours : 4.0;
    var targetBlocks = (typeof cfg.targetBlocks === "number" && cfg.targetBlocks >= 1) ? Math.round(cfg.targetBlocks) : 2;
    var blockPreset = cfg.blockPreset || "deepWork";
    var weekendsEnabled = Boolean(cfg.weekendsEnabled);
    var bMin = blockPresetMinutes(blockPreset);
    var bName = blockPresetName(blockPreset);
    var blockSec = bMin * 60;

    var dayMap = {};
    function ensureDay(k) {
        if (!dayMap[k]) {
            dayMap[k] = { seconds: 0, blocks: 0 };
        }
        return dayMap[k];
    }

    for (var i = 0; i < historyList.length; i++) {
        var sess = historyList[i];
        if (!sess || !sess.duration || !sess.timestamp) continue;
        var k = dateKey(new Date(sess.timestamp));
        var dObj = ensureDay(k);
        dObj.seconds += sess.duration;
        dObj.blocks += sessionBlocksCount(sess.duration, bMin);
    }

    var now = new Date();
    var today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    var todayKey = dateKey(today);

    var liveSec = Math.max(0, Math.floor(liveSessionSeconds || 0));
    if (liveSec > 0) {
        var tObj = ensureDay(todayKey);
        tObj.seconds += liveSec;
        tObj.blocks += sessionBlocksCount(liveSec, bMin);
    }

    var targetSec = Math.round(targetHours * 3600);
    function isDayMet(k) {
        var dObj = dayMap[k];
        if (!dObj) return false;
        if (goalMode === "blocks") {
            return dObj.blocks >= targetBlocks;
        }
        return dObj.seconds >= targetSec;
    }

    // Header badge text: e.g. "🎯 4h" or "🎯 2× 50m"
    var tgtHoursClean = (targetHours % 1 === 0) ? String(targetHours) : targetHours.toFixed(1);
    var badgeText = goalMode === "blocks"
        ? ("🎯 " + targetBlocks + "× " + bMin + "m")
        : ("🎯 " + tgtHoursClean + "h");

    // Today progress
    var todayData = dayMap[todayKey] || { seconds: 0, blocks: 0 };
    var todayProgressRatio = 0;
    var todayValueStr = "";
    var todayPercent = 0;

    if (goalMode === "blocks") {
        var completedLiveBlocks = sessionBlocksCount(liveSec, bMin);
        var remLiveSec = Math.max(0, liveSec - completedLiveBlocks * blockSec);
        var partialBlock = (liveSec > 0 && remLiveSec > 0) ? Math.min(0.95, remLiveSec / blockSec) : 0;
        var effectiveBlocks = todayData.blocks + partialBlock;
        todayProgressRatio = Math.max(0, Math.min(1, effectiveBlocks / Math.max(1, targetBlocks)));
        todayPercent = Math.min(100, Math.round((effectiveBlocks / Math.max(1, targetBlocks)) * 100));
        todayValueStr = todayData.blocks + " / " + targetBlocks + " " + bName;
    } else {
        todayProgressRatio = Math.max(0, Math.min(1, todayData.seconds / Math.max(1, targetSec)));
        todayPercent = Math.min(100, Math.round((todayData.seconds / Math.max(1, targetSec)) * 100));
        todayValueStr = formatHoursMinutesCompact(todayData.seconds) + " / " + formatHoursMinutesCompact(targetSec);
    }

    var todayTargetStr = todayPercent + "%";

    // Current Week (Mon - Sun)
    var todayDow = (today.getDay() + 6) % 7; // 0 = Mon .. 6 = Sun
    var monday = new Date(today.getFullYear(), today.getMonth(), today.getDate() - todayDow);
    var weekDays = [];
    var weekMetCount = 0;
    var weekRequiredCount = weekendsEnabled ? 7 : 5;

    for (var w = 0; w < 7; w++) {
        var cellDate = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + w);
        var cKey = dateKey(cellDate);
        var dEntry = dayMap[cKey] || { seconds: 0, blocks: 0 };
        var isWeekend = (w >= 5);
        var isRestDay = !weekendsEnabled && isWeekend;
        var isFuture = cellDate.getTime() > today.getTime();
        var isToday = (cKey === todayKey);
        var met = !isFuture && !isRestDay && isDayMet(cKey);

        if (met) {
            weekMetCount++;
        }

        var cellRatio = 0;
        if (!isFuture) {
            cellRatio = isToday
                ? todayProgressRatio
                : (goalMode === "blocks"
                    ? Math.min(1, dEntry.blocks / Math.max(1, targetBlocks))
                    : Math.min(1, dEntry.seconds / Math.max(1, targetSec)));
        }
        var cellPct = Math.round(cellRatio * 100);

        var statusText = "—";
        if (isRestDay) {
            statusText = "Rest";
        } else if (met) {
            statusText = "✓";
        } else if (!isFuture && (isToday || dEntry.seconds > 0)) {
            statusText = cellPct + "%";
        }

        var bottomText = goalMode === "blocks"
            ? (dEntry.blocks + "/" + targetBlocks)
            : ((dEntry.seconds / 3600).toFixed(1) + "h");

        weekDays.push({
            dayIndex: w,
            label: DAY_NAMES[w],
            shortLabel: DAY_NAMES[w],
            dateStr: formatDateReadable(cKey),
            isToday: isToday,
            isFuture: isFuture,
            isWeekend: isWeekend,
            isRestDay: isRestDay,
            met: met,
            seconds: dEntry.seconds,
            blocks: dEntry.blocks,
            ratio: cellRatio,
            statusText: statusText,
            bottomText: bottomText,
            valueText: bottomText
        });
    }

    // Goal Streak (consecutive required days met; rest days don't break streak)
    var goalStreak = 0;
    var checkDate = new Date(today.getFullYear(), today.getMonth(), today.getDate());

    for (var step = 0; step < 366; step++) {
        var kCheck = dateKey(checkDate);
        var dow = (checkDate.getDay() + 6) % 7;
        var isRest = !weekendsEnabled && (dow >= 5);
        var metCheck = isDayMet(kCheck);

        if (isRest) {
            // Rest day: skip without breaking or incrementing streak
        } else if (step === 0) {
            if (metCheck) {
                goalStreak++;
            }
            // If today is not met yet, keep streak alive from yesterday
        } else {
            if (metCheck) {
                goalStreak++;
            } else {
                break;
            }
        }
        checkDate.setDate(checkDate.getDate() - 1);
    }

    // 30-Day Hit Rate (percentage of required days met in the last 30 days)
    var reqTotal30 = 0;
    var reqMet30 = 0;
    for (var d30 = 0; d30 < 30; d30++) {
        var dt = new Date(today.getFullYear(), today.getMonth(), today.getDate() - d30);
        var k30 = dateKey(dt);
        var dow30 = (dt.getDay() + 6) % 7;
        var isRest30 = !weekendsEnabled && (dow30 >= 5);
        if (!isRest30) {
            reqTotal30++;
            if (isDayMet(k30)) reqMet30++;
        }
    }
    var hitRate30 = reqTotal30 > 0 ? Math.min(100, Math.round((reqMet30 / reqTotal30) * 100)) : 0;

    return {
        goalMode: goalMode,
        targetHours: targetHours,
        targetBlocks: targetBlocks,
        blockPreset: blockPreset,
        blockMinutes: bMin,
        weekendsEnabled: weekendsEnabled,
        badgeText: badgeText,
        todaySeconds: todayData.seconds,
        todayBlocks: todayData.blocks,
        todayMet: isDayMet(todayKey),
        todayIsRest: !weekendsEnabled && (todayDow >= 5),
        todayProgressRatio: todayProgressRatio,
        todayPercent: todayPercent,
        todayValueStr: todayValueStr,
        todayTargetStr: todayTargetStr,
        weekDays: weekDays,
        weekMetCount: weekMetCount,
        weekRequiredCount: weekRequiredCount,
        goalStreak: goalStreak,
        hitRate30: hitRate30,
        reqMet30: reqMet30,
        reqTotal30: reqTotal30
    };
}

// -----------------------------------------------------------------------------
// Sample history with English default subjects
// -----------------------------------------------------------------------------
function defaultSampleHistory() {
    var now = new Date();
    var list = [];
    var tags = ["Math", "Coding", "Physics", "Reading", "Research", "English"];
    var apps = ["alacritty", "firefox", "code", "obsidian", "terminal"];

    // Generate realistic study sessions across the entire year (364 days = 52 weeks)
    for (var d = 364; d >= 0; d--) {
        // Rest days: ~2 days per week, plus some variance
        var dayOfWeek = (new Date(now.getTime() - d * 86400000).getDay() + 6) % 7;
        var skip = (d > 14 && (d % 7 === 5 || (d % 11 === 0 && dayOfWeek === 6)));
        if (skip) continue;

        var count = (d % 5 === 0) ? 2 : (d % 9 === 0 ? 3 : 1);
        for (var c = 0; c < count; c++) {
            var sessDate = new Date(now.getTime() - d * 86400000 - (c * 2 + 1) * 3600000);
            var tag = tags[(d + c) % tags.length];
            var dur = ((d % 3 === 0 ? 25 : (d % 2 === 0 ? 50 : 30)) + c * 15) * 60;
            var app1 = apps[(d) % apps.length];
            var app2 = apps[(d + 1) % apps.length];
            var appMap = {};
            appMap[app1] = Math.round(dur * 0.75);
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
