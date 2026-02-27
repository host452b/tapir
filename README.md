# Tapir

A macOS desktop tool that sends automated keyboard events to any target application window. Built with Flutter and native Swift, using the macOS CGEvent API to post key events directly to a specific process by PID.

> **Tapir** — a cute animal whose name starts with "tap", which is exactly what this tool does: tapping keys for you.

## Features

- **Window Scanner** — discover all visible windows with process hierarchy info (parent/child, sub-windows)
- **Window Search** — filter window list by name or PID for quick targeting
- **3 Step Modes**
  - **KEY** — single key press with optional modifiers (Cmd / Ctrl / Opt / Shift)
  - **TEXT** — type a string character by character, optionally press Enter
  - **COMBO** — prefix key → text → suffix key (e.g. Tab → "hello" → Enter)
- **Sequence Builder** — chain multiple steps, drag-to-reorder, duplicate, remove
- **Repeat Mode** — infinite loop or finite N-cycle mode with quick-pick presets and auto-stop
- **Interval Control** — configurable delay between steps (100ms – 10,000,000ms)
- **Live Progress** — animated LED progress bar, send counter, cycle tracker
- **Event Log** — timestamped log of every key event, state change, and error
- **Accessibility Management** — built-in permission check and grant flow

## Prerequisites

- **macOS** 12.0 or later
- **Flutter SDK** 3.9.2+ (stable channel)
- **Xcode** 15.0+ with Command Line Tools installed

Verify your environment:

```bash
flutter doctor
```

## Build & Run (Debug)

```bash
# clone the repo
git clone <repo-url> && cd tapir

flutter clean
# install dependencies
flutter pub get

# run in debug mode (launches the app directly)
flutter run -d macos
```

The debug build enables hot-reload and the Dart DevTools debugger.

## Build for Release

```bash
# compile optimized release binary
flutter build macos --release
```

The output is located at:

```
build/macos/Build/Products/Release/Tapir.app
```

## Package as DMG

To distribute as a `.dmg` disk image:

```bash
# 1. build release first
flutter build macos --release

# 2. create a DMG using hdiutil
hdiutil create -volname "Tapir" \
  -srcfolder build/macos/Build/Products/Release/Tapir.app \
  -ov -format UDZO \
  Tapir.dmg
```

This produces `Tapir.dmg` in the project root. Users can open it and drag `Tapir.app` to their Applications folder.

## Install

### From Release Build

1. Copy `Tapir.app` from `build/macos/Build/Products/Release/` to `/Applications/`
2. On first launch, macOS may block the app — go to **System Settings → Privacy & Security** and click **Open Anyway**
3. Grant **Accessibility** permission when prompted (required for sending key events to other apps)

### From DMG

1. Open `Tapir.dmg`
2. Drag `Tapir.app` into `Applications`
3. Launch and grant Accessibility permission

### Accessibility Permission

Tapir requires macOS Accessibility access to post CGEvent key events to other processes.

- The app will prompt automatically on first launch
- You can also grant manually: **System Settings → Privacy & Security → Accessibility** → toggle Tapir on
- If permission doesn't take effect after granting, run:
  ```bash
  tccutil reset Accessibility
  ```
  Then restart the app and re-grant.

## Usage

Tapir has 4 tabs accessed via the left sidebar:

### 1. TARGET — Select Target Window

- Click **SCAN** to discover all visible windows
- Use the **search bar** to filter by app name, window title, or PID
- Click a window row to select it as the target
- A **SELECTED** badge confirms your selection; click the **×** button or **DESELECT** to clear
- A next-step hint appears after selection to guide you to the KEYS tab

### 2. KEYS — Configure Key Sequence

- Click **KEY** / **TEXT** / **COMBO** to add a step:
  - **KEY** — pick a key from the dropdown, toggle modifiers (Cmd/Ctrl/Opt/Shift)
  - **TEXT** — type a string, optionally append Enter
  - **COMBO** — set PREFIX key → text → SUFFIX key (great for chat automation)
- Use the **3-segment selector** (KEY / TXT / CMB) on any step to switch its mode directly
- Use **drag handle** (≡) or **arrow buttons** (▲▼) to reorder — all buttons have tooltips on hover
- Use the **duplicate button** (⎘) to clone a step
- Use the **× button** to delete
- Adjust the **INTERVAL** between steps using the +/- buttons or direct input
- Invalid interval values flash a red border for feedback

### 3. CONTROL — Start / Monitor / Stop

- Set **REPEAT MODE** using the segment selector: **∞ LOOP** (infinite) or **N× REPEAT** (finite cycles)
- For finite mode, use quick-pick buttons (1/3/5/10/50/100) or type a custom count
- Click **▶ START** to begin sending
- Monitor the **LED progress bar**, **send count**, and **cycle progress**
- Use **PAUSE** to temporarily halt, **▶ RESUME** to continue
- Click **STOP** to terminate and reset
- The **EVENT LOG** shows timestamped entries — toggle **AUTO** scroll and use **CLEAR** to reset

### 4. SYSTEM — Permissions & Info

- Check Accessibility permission status
- Click **GRANT** to open System Settings
- Click **CHECK** to re-verify
- Expand **TROUBLESHOOTING** for common fixes

## Project Structure

```
lib/
├── main.dart                   # app entry point
├── pages/
│   └── home_page.dart          # main page with sidebar navigation
├── models/
│   ├── key_step.dart           # step model (key / text / combo modes)
│   └── window_info.dart        # window info with process hierarchy
├── services/
│   ├── key_sender_service.dart # send loop, repeat count, state machine
│   └── native_bridge.dart      # method channel to Swift native layer
├── widgets/
│   ├── window_selector.dart    # window list with search/filter
│   ├── key_config_panel.dart   # step editor, interval, drag-reorder
│   ├── send_control_panel.dart # start/pause/stop, progress, readout
│   ├── event_log.dart          # scrollable timestamped log
│   └── permission_banner.dart  # accessibility permission UI
├── constants/
│   └── key_codes.dart          # macOS virtual key code mapping
└── theme/
    └── retro_theme.dart        # retro-futurism color palette & widgets

macos/Runner/
├── KeySenderPlugin.swift       # native CGEvent sending & window scanning
├── MainFlutterWindow.swift     # plugin registration & window setup
├── AppDelegate.swift           # app lifecycle
├── DebugProfile.entitlements   # sandbox disabled + JIT for debug
└── Release.entitlements        # sandbox disabled for release
```

## Technical Notes

- **App Sandbox is disabled** — required for `CGEvent.postToPid()` to work across processes
- **CGEvent API** — key events are synthesized using `CGEvent(keyboardEventSource:virtualKey:keyDown:)` and posted via `postToPid()`
- **Text input** — characters are typed using `keyboardSetUnicodeString()` on dummy key events
- **Window scanning** — uses `CGWindowListCopyWindowInfo` with on-screen-only filter
- **Process tree** — built via `sysctl` KERN_PROC queries, single-pass child map construction
- **Key dispatch** — runs on `DispatchQueue.global(qos: .userInitiated)` to avoid blocking the Flutter main thread

## License

MIT License. See [LICENSE](LICENSE) for details.
