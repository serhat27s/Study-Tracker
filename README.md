# Study Tracker

An Omarchy status bar plugin for tracking study sessions, subjects, and active application usage.

## Features

- **Focus Timer**
  - **Pomodoro**: Configurable work, short break, and long break intervals with presets (*Standard* 25/5/15m, *Deep Work* 50/10/30m, *Ultradian* 90/20m) and desktop notifications (`notify-send`).
  - **Stopwatch**: Open-ended session timer.
  - **Auto-Save**: Completed blocks and interrupted sessions (≥ 1 min) are logged automatically when resetting, switching modes, or changing subjects.
- **Subject Management**
  - Filterable subject menu with instant search, creation, and deletion.
  - Custom subject colors via 14 curated swatches, interactive HSV sliders, `#HEX` input, or random color generation.
- **Full-Year Activity Heatmap**
  - Horizontally scrollable 52–53 week GitHub-style calendar grid (Jan–Dec) with month navigation, *Today* jump, hover inspection, and daily streak counter.
- **Subject Statistics**
  - Interactive donut chart and ranked legend of study hours, session counts, and share per subject across **Today**, **Week** (7 days), and **Total**.
- **Application Activity Tracking**
  - Tracks active windows via `Quickshell.Hyprland` (`Hyprland.activeToplevel`) during active study phases (automatically paused during breaks).
  - Filterable by timeframe (**Session**, **Today**, **Week**, **Total**) and by subject.

## Controls & Shortcuts

**Bar Widget**
- `Left Click`: Open / close panel
- `Right Click`: Start / pause timer

**Panel Keyboard Shortcuts**
- `Space` / `Enter`: Start / pause timer
- `r` / `s`: Reset timer
- `m`: Toggle between Pomodoro and Stopwatch
- `t`: Open subject menu
- `1` / `2` / `3` or `←` / `→`: Switch between *Focus*, *Statistics*, and *Activity* tabs
- `Esc`: Close menu or panel

## Installation

Copy the plugin to your Omarchy plugins directory and enable it:

```bash
mkdir -p ~/.config/omarchy/plugins/io.github.yourname.study-tracker
cp -r ./* ~/.config/omarchy/plugins/io.github.yourname.study-tracker/
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.yourname.study-tracker --section center
```

## Data Storage

Session history, subjects, custom colors, and timer settings are stored in `~/.local/share/study-tracker/data.json`. On first launch, sample history is generated so the heatmap and charts are populated immediately.
