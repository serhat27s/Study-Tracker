# Study Tracker

An Omarchy status bar plugin for tracking study sessions, subjects, consistency goals, and session depth.

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
- **Statistics & Consistency**
  - **Consistency Tracker**: Daily goal tracking by **Hours** (`0.5h–12h`) or **Blocks** (*Ultradian 90m* / *Deep Work 50m* with 2-minute grace), optional Weekend Rest Days (`Mon–Fri` vs `Mon–Sun`), weekly day tiles, **Goal Streak**, and **30d Hit Rate**.
  - **Hours by Subject**: Interactive donut chart and ranked legend of study hours and share per subject across **Today**, **Week**, **Month**, and **Total**.
  - **Session Depth & Quality**: Categorizes sessions into **Deep** (`≥ 50m`), **Focused** (`25–50m`), and **Shallow** (`< 25m`) with a stacked distribution bar.

## Controls & Shortcuts

**Bar Widget**
- `Left Click`: Open / close panel
- `Right Click`: Start / pause timer

**Panel Keyboard Shortcuts**
- `Space` / `Enter`: Start / pause timer
- `r` / `s`: Reset timer
- `m`: Toggle between Pomodoro and Stopwatch
- `t`: Open subject menu
- `1` / `2` or `←` / `→`: Switch between *Focus* and *Statistics* tabs
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
