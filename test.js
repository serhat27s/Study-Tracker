const assert = require("assert");
const fs = require("fs");
const vm = require("vm");

const code = fs.readFileSync(__dirname + "/Model.js", "utf8");
const Model = {};
vm.runInNewContext(code, Model);

// 1. Time & Date formatting
assert.strictEqual(Model.formatSeconds(0), "00:00");
assert.strictEqual(Model.formatSeconds(65), "01:05");
assert.strictEqual(Model.formatSeconds(3661), "1:01:01");
assert.strictEqual(Model.formatDurationHuman(0), "0 min");
assert.strictEqual(Model.formatDurationHuman(45), "45 sec");
assert.strictEqual(Model.formatDurationHuman(3600), "1 hr");
assert.strictEqual(Model.formatDurationHuman(5400), "1 hr 30 min");
assert.strictEqual(Model.formatHoursDecimal(5400), "1.5 hrs");

// 2. Color & HSV conversions
assert.deepStrictEqual(Array.from(Model.hexToRgb("#ff0000")), [255, 0, 0]);
assert.strictEqual(Model.hexToRgb("invalid"), null);
const hsv = Model.hexToHsv("#3b82f6");
assert.strictEqual(Model.hsvToHex(hsv[0], hsv[1], hsv[2]), "#3b82f6");
assert.strictEqual(Model.tagColor("Math", { Math: "#123456" }), "#123456");
assert.strictEqual(Model.tagColor("math", { Math: "#123456" }), "#123456");
assert.strictEqual(Model.tagColor("MATH", null), "#3b82f6");

// 3. Subject stats aggregation (including case-insensitive tag merging)
const now = new Date();
const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 12, 0, 0);
const history = [
    { id: "1", tag: "Math", duration: 1800, timestamp: now.toISOString() },
    { id: "2", tag: "Physics", duration: 3600, timestamp: yesterday.toISOString() }
];

const todayStats = Model.aggregateTagStats(history, "today");
assert.strictEqual(todayStats.grandTotalSeconds, 1800);
assert.strictEqual(todayStats.tags.length, 1);
assert.strictEqual(todayStats.tags[0].tag, "Math");

const caseStats = Model.aggregateTagStats([
    { id: "c1", tag: "Math", duration: 1200, timestamp: now.toISOString() },
    { id: "c2", tag: "math", duration: 600, timestamp: yesterday.toISOString() }
], "all");
assert.strictEqual(caseStats.tags.length, 1);
assert.strictEqual(caseStats.tags[0].tag, "Math");
assert.strictEqual(caseStats.tags[0].totalSeconds, 1800);
assert.strictEqual(caseStats.tags[0].sessionCount, 2);

const weekStats = Model.aggregateTagStats(history, "week");
assert.strictEqual(weekStats.grandTotalSeconds, 5400);
assert.strictEqual(weekStats.tags[0].tag, "Physics");

// 4. Heatmap & Streak calculation
const hm = Model.buildHeatmap(history, now.getFullYear());
assert.strictEqual(hm.streakDays, 2);
assert.strictEqual(hm.todaySeconds, 1800);
assert.strictEqual(hm.totalSeconds, 5400);
assert.ok(hm.weeks.length >= 52 && hm.weeks.length <= 54);
assert.strictEqual(hm.weeks[0].length, 7);

// 5. Consistency Tracker (Hours & Blocks modes, 2m grace period, live session, Weekends & Streak)
assert.strictEqual(Model.blockPresetMinutes("ultradian"), 90);
assert.strictEqual(Model.blockPresetMinutes("deepWork"), 50);
assert.strictEqual(Model.blockPresetMinutes("unknown"), 50);
assert.strictEqual(Model.sessionBlocksCount(87 * 60, 90), 0); // 87m < 90m - 2m
assert.strictEqual(Model.sessionBlocksCount(88 * 60, 90), 1); // 88m >= 90m - 2m (2m grace)
assert.strictEqual(Model.sessionBlocksCount(180 * 60, 90), 2); // 180m = 2x Ultradian

const consHours = Model.calculateConsistency(history, 1800, {
    goalMode: "hours",
    targetHours: 1.0,
    weekendsEnabled: true
});
assert.strictEqual(consHours.goalStreak, 2); // Today (1h) + Yesterday (1h)
assert.strictEqual(consHours.weekDays.length, 7);

const consBlocks = Model.calculateConsistency(
    [{ id: "b1", tag: "Coding", duration: 180 * 60, timestamp: now.toISOString() }],
    88 * 60,
    { goalMode: "blocks", targetBlocks: 3, blockPreset: "ultradian", weekendsEnabled: false }
);
const todayIdx = (now.getDay() + 6) % 7;
assert.strictEqual(consBlocks.weekDays[todayIdx].blocks, 3); // 2 from 180m + 1 from 88m live

// Live session crossing midnight (00:30 local on Wednesday Oct 14, 2026, 90m live -> 60m Tue + 30m Wed)
const wedEarly = new Date(2026, 9, 14, 0, 30, 0);
const consLiveCross = Model.calculateConsistency([], 90 * 60, {
    goalMode: "blocks",
    targetBlocks: 1,
    blockPreset: "deepWork",
    weekendsEnabled: true,
    now: wedEarly
});
const wedIdx = (wedEarly.getDay() + 6) % 7;
assert.strictEqual(consLiveCross.weekDays[wedIdx - 1].seconds, 60 * 60);
assert.strictEqual(consLiveCross.weekDays[wedIdx - 1].blocks, 1);
assert.strictEqual(consLiveCross.weekDays[wedIdx].seconds, 30 * 60);
assert.strictEqual(consLiveCross.weekDays[wedIdx].blocks, 0);

// 6. Midnight session splitting (22:00 -> 01:00 = 2h day 1 + 1h day 2)
const afterMidnight = new Date(2026, 9, 14, 1, 0, 0); // 01:00 local time
const splitRecs = Model.splitSessionRecords(3 * 3600, afterMidnight, "Coding", "tracker");
assert.strictEqual(splitRecs.length, 2);
assert.strictEqual(splitRecs[0].duration, 3600);  // 00:00..01:00 on Oct 14
assert.strictEqual(splitRecs[0].fullDuration, 0);
assert.strictEqual(Model.dateKey(new Date(splitRecs[0].timestamp)), "2026-10-14");
assert.strictEqual(splitRecs[1].duration, 7200);  // 22:00..24:00 on Oct 13 (no 1s loss, primary segment)
assert.strictEqual(splitRecs[1].fullDuration, 3 * 3600);
assert.strictEqual(Model.dateKey(new Date(splitRecs[1].timestamp)), "2026-10-13");

// Verify that midnight-split sessions preserve blocks on the majority day & match today/all stats
const todayEarly = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 30, 0);
const cross90 = Model.splitSessionRecords(90 * 60, todayEarly, "Coding", "pomodoro");
assert.strictEqual(cross90.length, 2);
assert.strictEqual(cross90[0].fullDuration, 0);
assert.strictEqual(cross90[1].fullDuration, 90 * 60);
const crossBlocks = Model.calculateConsistency(cross90, 0, { goalMode: "blocks", targetBlocks: 1, blockPreset: "ultradian" });
assert.strictEqual(crossBlocks.weekDays[todayIdx].blocks, 0); // Only 30m today
if (todayIdx > 0) assert.strictEqual(crossBlocks.weekDays[todayIdx - 1].blocks, 1); // 60m yesterday gets the block
const crossTagAll = Model.aggregateTagStats(cross90, "all");
assert.strictEqual(crossTagAll.tags[0].sessionCount, 1);
const crossQual = Model.calculateSessionQuality(cross90, "all");
assert.strictEqual(crossQual.totalCount, 1);
assert.strictEqual(crossQual.totalSeconds, 90 * 60);
assert.strictEqual(crossQual.tiers[0].count, 1); // Classified as Deep (>= 50m)
assert.strictEqual(crossQual.tiers[1].count, 0);
assert.strictEqual(crossQual.tiers[2].count, 0);
const crossTagToday = Model.aggregateTagStats(cross90, "today");
const crossQualToday = Model.calculateSessionQuality(cross90, "today");
assert.strictEqual(crossTagToday.grandTotalSeconds, 30 * 60);
assert.strictEqual(crossTagToday.tags[0].sessionCount, 1);
assert.strictEqual(crossQualToday.totalSeconds, 30 * 60);
assert.strictEqual(crossQualToday.totalCount, 1);
assert.strictEqual(crossQualToday.tiers[0].seconds, 30 * 60);

// Also verify when majority of a midnight-split session is after midnight (30m yesterday + 60m today)
const todayOneAm = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 1, 0, 0);
const cross90TodayMaj = Model.splitSessionRecords(90 * 60, todayOneAm, "Coding", "pomodoro");
assert.strictEqual(cross90TodayMaj[0].fullDuration, 90 * 60);
assert.strictEqual(cross90TodayMaj[1].fullDuration, 0);
const crossBlocksTodayMaj = Model.calculateConsistency(cross90TodayMaj, 0, { goalMode: "blocks", targetBlocks: 1, blockPreset: "ultradian" });
assert.strictEqual(crossBlocksTodayMaj.weekDays[todayIdx].blocks, 1);
assert.strictEqual(Model.calculateSessionQuality(cross90TodayMaj, "week").totalCount, 1);
assert.strictEqual(Model.calculateSessionQuality(cross90TodayMaj, "today").totalSeconds, 60 * 60);

// 7. Rest-day streak bridging across weekends when weekendsEnabled is false
const streakHist = [];
let expectedRequiredStreak = 0;
for (let d = 1; d <= 5; d++) {
    const dt = new Date(now.getFullYear(), now.getMonth(), now.getDate() - d, 12, 0, 0);
    const dow = (dt.getDay() + 6) % 7;
    if (dow < 5) {
        streakHist.push({ id: "s_" + d, tag: "Math", duration: 4 * 3600, timestamp: dt.toISOString() });
        expectedRequiredStreak++;
    }
}
const bridged = Model.calculateConsistency(streakHist, 0, {
    goalMode: "hours",
    targetHours: 4.0,
    weekendsEnabled: false
});
assert.strictEqual(bridged.goalStreak, expectedRequiredStreak);

// 8. Deep Work Quality (Shallow <25m, Focused 25-50m, Deep >=50m)
const qualHist = [
    { id: "q1", tag: "Math", duration: 15 * 60, timestamp: now.toISOString() },   // Shallow (900s)
    { id: "q2", tag: "Coding", duration: 30 * 60, timestamp: now.toISOString() }, // Focused (1800s)
    { id: "q3", tag: "Physics", duration: 90 * 60, timestamp: now.toISOString() } // Deep (5400s)
];
const qual = Model.calculateSessionQuality(qualHist, "today");
assert.strictEqual(qual.totalCount, 3);
assert.strictEqual(qual.tiers[0].count, 1); // Deep
assert.strictEqual(qual.tiers[1].count, 1); // Focused
assert.strictEqual(qual.tiers[2].count, 1); // Shallow
assert.strictEqual(qual.deepPct, 67);

console.log("All Model.js tests passed.");
