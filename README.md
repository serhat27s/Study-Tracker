# Study Tracker — Omarchy Quattro QML Plugin

A modular study and productivity tracker widget for the Omarchy status bar, featuring dual timer modes, tagging, a 7-row GitHub-style activity contribution heatmap, and an application usage breakdown slide.

## Features

- **Dual Timer Modes**:
  - **Pomodoro Mode**: 25m focus / 5m short break / 15m long break cycles with cycle tracking (`Cycle X of 4`) and desktop notifications (`notify-send`) on completion.
  - **Stopwatch / Tracker Mode**: Open-ended stopwatch for continuous tracking.
- **Tagging System**:
  - Live session tagging (e.g. `Math`, `Coding`, `Research`, `Reading`).
  - Quick-select chips for recent tags.
  - Custom tag input field (press Enter to assign and save).
- **7-Row GitHub-style Activity Heatmap**:
  - 14-week compact contribution grid (Monday to Sunday rows).
  - Dynamic cell color scaling based on daily focus minutes.
  - Interactive cell inspection displaying date, total focus time, and dominant tags.
  - Metrics row: Current streak counter, Today's focus time, Total focus time, and total sessions.
- **Application Usage Breakdown**:
  - Real-time active window tracking via `Quickshell.Hyprland` (`Hyprland.activeToplevel`).
  - Scope filters: **Current Session**, **Today**, **All Time**.
  - Tag filter: View application breakdown for specific study subjects or all tags.
  - Ranked bar charts showing application names, usage duration, and percentage share.
- **Persistent Local Storage**:
  - Saves completed sessions and recent tags locally to `~/.local/share/study-tracker/data.json`.
  - Automatic pre-population with sample history on first launch so heatmaps and graphs are instantly visual.

## Omarchy Rules Compliance

- **Framework**: Omarchy Quattro (Quickshell Qt6 QML).
- **Imports**: `qs.Ui` and `qs.Commons`.
- **Layout Primitives**:
  - `BarWidget.qml` inherits `BarWidget`, exports `opened`, `injectPanel()`, and `WidgetButton`.
  - `Panel.qml` inherits `Panel`, wraps children inside `KeyboardPanel` and `PanelKeyCatcher`.
  - Spacing & typography strictly use `Style.space(...)` and `Style.font.*`.
  - Palette derived from `root.barForeground` and `Color.*`.
- **State Management**:
  - Shared timer state and window tracking owned by `BarWidget.qml` and exposed to `Panel.qml` via `root.rootWidget`.

## Installation & Activation

To install into your local Omarchy plugins:

```bash
mkdir -p ~/.config/omarchy/plugins/io.github.yourname.study-tracker
cp -r /home/serhat/Documents/antigravity/nifty-hertz/* ~/.config/omarchy/plugins/io.github.yourname.study-tracker/
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.yourname.study-tracker --section center
```
