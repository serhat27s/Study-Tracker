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
assert.strictEqual(Model.tagColor("Math", null), "#3b82f6");

// 3. Subject stats & App usage aggregation
const now = new Date();
const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 12, 0, 0);
const history = [
    { id: "1", tag: "Math", duration: 1800, timestamp: now.toISOString(), app_usage: { code: 1200, firefox: 600 } },
    { id: "2", tag: "Physics", duration: 3600, timestamp: yesterday.toISOString(), app_usage: { obsidian: 3600 } }
];

const todayStats = Model.aggregateTagStats(history, "today");
assert.strictEqual(todayStats.grandTotalSeconds, 1800);
assert.strictEqual(todayStats.tags.length, 1);
assert.strictEqual(todayStats.tags[0].tag, "Math");

const weekStats = Model.aggregateTagStats(history, "week");
assert.strictEqual(weekStats.grandTotalSeconds, 5400);
assert.strictEqual(weekStats.tags[0].tag, "Physics");

const appCurrent = Model.aggregateAppUsage(history, { alacritty: 300 }, "current", "");
assert.strictEqual(appCurrent.totalSeconds, 300);
assert.strictEqual(appCurrent.apps[0].app, "alacritty");

const appMath = Model.aggregateAppUsage(history, null, "all", "Math");
assert.strictEqual(appMath.totalSeconds, 1800);

const appPhysics = Model.aggregateAppUsage(history, null, "all", "Physics");
assert.strictEqual(appPhysics.totalSeconds, 3600);

// 4. Heatmap & Streak calculation
const hm = Model.buildHeatmap(history, now.getFullYear());
assert.strictEqual(hm.streakDays, 2);
assert.strictEqual(hm.todaySeconds, 1800);
assert.strictEqual(hm.totalSeconds, 5400);
assert.ok(hm.weeks.length >= 52 && hm.weeks.length <= 54);
assert.strictEqual(hm.weeks[0].length, 7);

// 5. Consistency Tracker (Hours & Blocks modes, 2m grace period, live session, Weekends & Streak)
assert.strictEqual(Model.sessionBlocksCount(87 * 60, 90), 0); // 87m < 90m - 2m
assert.strictEqual(Model.sessionBlocksCount(88 * 60, 90), 1); // 88m >= 90m - 2m (2m grace)
assert.strictEqual(Model.sessionBlocksCount(180 * 60, 90), 2); // 180m = 2x Ultradian

const consHours = Model.calculateConsistency(history, 1800, {
    goalMode: "hours",
    targetHours: 1.0,
    weekendsEnabled: true
});
assert.strictEqual(consHours.todaySeconds, 3600); // 1800 logged + 1800 live
assert.strictEqual(consHours.todayMet, true);
assert.strictEqual(consHours.goalStreak, 2); // Today (1h) + Yesterday (1h)
assert.strictEqual(consHours.weekDays.length, 7);

const consBlocks = Model.calculateConsistency(
    [{ id: "b1", tag: "Coding", duration: 180 * 60, timestamp: now.toISOString() }],
    88 * 60,
    { goalMode: "blocks", targetBlocks: 3, blockPreset: "ultradian", weekendsEnabled: false }
);
assert.strictEqual(consBlocks.todayBlocks, 3); // 2 from 180m + 1 from 88m live
assert.strictEqual(consBlocks.todayMet, true);

console.log("All Model.js tests passed.");
