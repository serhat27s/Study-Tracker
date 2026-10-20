# Study Tracker

An Omarchy status bar plugin for tracking study sessions, subjects, consistency goals, and session depth.

![Preview](preview.png)

## Features

- **Focus Timer**: Pomodoro (*Standard*, *Deep Work*, *Ultradian* presets + custom intervals) and Stopwatch with desktop notifications, auto-save (`≥ 1m`).
- **Subjects**: Instant search, creation, archiving.
- **Activity Heatmap**: Full-year scrollable calendar grid with month jump, hover details, and streak counter.
- **Statistics**: Daily goal tracker (Hours or Blocks with optional weekend rest days), subject donut chart, and session depth breakdown (*Deep*, *Focused*, *Shallow*).

## Controls & Shortcuts

- **Bar Widget**: `Left Click` toggle panel · `Right Click` start / pause
- **Panel**: `Space`/`Enter` start / pause · `r`/`s` reset · `m` switch mode · `t` subjects · `1`/`2` or `←`/`→` switch tabs · `Esc` close

## Install & Manage

```sh
# Install 
omarchy plugin add https://github.com/sersah/Study-Tracker.git --enable

# Update / Remove
omarchy plugin update io.github.sersah.study-tracker
omarchy plugin remove io.github.sersah.study-tracker
```

Data is stored in `~/.local/share/study-tracker/data.json`.
