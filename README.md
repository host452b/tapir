# Tapir

A macOS keyboard automation tool that sends automated key events to any target application. Built with Tauri v2 (Rust) + React + TypeScript, using the CGEvent API to post events via the HID event tap.

> **Tapir** — a cute animal whose name starts with "tap", which is exactly what this tool does: tapping keys for you.

## Features

- **Window Scanner** — discover all visible windows with process hierarchy info (parent/child, sub-windows)
- **Window Search** — filter by app name, window title, or PID
- **3 Step Modes**
  - **KEY** — single key press with optional modifiers (Cmd / Ctrl / Opt / Shift)
  - **TEXT** — type a string character by character, optionally press Enter
  - **COMBO** — prefix key -> text -> suffix key (e.g. Tab -> "hello" -> Enter)
- **Sequence Builder** — chain multiple steps, drag-to-reorder, duplicate, remove
- **Repeat Mode** — infinite loop or finite N-cycle with quick-pick presets
- **Interval Control** — configurable delay between steps (100ms - 10,000,000ms)
- **Live Progress** — animated LED progress bar, send counter, cycle tracker
- **Event Log** — timestamped log of every key event, state change, and error
- **Accessibility Management** — built-in permission check and grant flow

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Rust, Tauri v2 |
| Frontend | React 18, TypeScript, Zustand |
| Build | Vite, Cargo |
| macOS APIs | CGEvent (FFI), CGWindowList, AXIsProcessTrusted |
| Theme | Flexoki Light, Menlo monospace |
| Target | macOS 14.0+ (Sonoma), App Store sandbox compatible |

## Prerequisites

- macOS 14.0+
- Rust toolchain (`rustup`, stable)
- Node.js 18+ & npm
- Xcode Command Line Tools (`xcode-select --install`)

## Quick Start

```bash
# Install dependencies
npm install

# Development with hot reload
npm run tauri dev
```

## Build

```bash
# Debug build
npm run build:debug

# Release build (.app + .dmg)
npm run build:release

# Mac App Store build
npm run build:mas
```

See [docs/build_release.md](docs/build_release.md) for full build guide including code signing, notarization, and App Store submission.

## Clean

```bash
npm run clean            # Remove ALL artifacts
npm run clean:frontend   # Remove node_modules + dist
npm run clean:rust       # Remove src-tauri/target
npm run clean:release    # Remove release bundles only
```

## Usage

Tapir uses a guided 4-step workflow:

### Step 0: SYSTEM — Permissions

- Check and grant Accessibility permission
- Required for sending key events to other apps

### Step 1: TARGET — Select Windows

- Click **SCAN** to discover all visible windows
- Search and filter, click to multi-select targets
- Selected windows receive key events when sending

### Step 2: KEYS — Configure Sequence

- Add **KEY** / **TEXT** / **COMBO** steps
- Configure modifiers, text content, prefix/suffix keys
- Drag to reorder, duplicate, or delete steps
- Set the interval between steps

### Step 3: CONTROL — Send & Monitor

- Choose repeat mode: infinite loop or N cycles
- **START** / **PAUSE** / **RESUME** / **STOP**
- Watch the event log and progress indicators

## Project Structure

```
src-tauri/src/
├── main.rs                    # Tauri entry, command registration
├── core/
│   ├── key_codes.rs           # macOS CGKeyCode mapping (72 keys)
│   ├── key_sender.rs          # CGEvent synthesis & HID posting
│   ├── window_scanner.rs      # CGWindowList + sysctl process tree
│   ├── accessibility.rs       # AXIsProcessTrusted FFI
│   └── process.rs             # Process alive validation
├── models/
│   ├── key_step.rs            # KeyStep, StepMode
│   ├── window_info.rs         # WindowInfo with hierarchy
│   ├── log_entry.rs           # LogEntry, SendingState, SenderStatus
│   └── error.rs               # TapirError enum
├── state/
│   └── sender_state.rs        # SenderManager state machine
└── commands/
    ├── accessibility.rs       # Permission IPC commands
    ├── window.rs              # Scan/validate IPC commands
    └── sender.rs              # Send control IPC commands

src/
├── App.tsx                    # Layout + step routing
├── components/
│   ├── TitleBar.tsx           # Custom title bar
│   ├── Sidebar.tsx            # Step navigation
│   ├── StatusBar.tsx          # Footer status
│   ├── SystemView.tsx         # Step 0: permissions
│   ├── WindowSelector.tsx     # Step 1: target selection
│   ├── KeyConfig.tsx          # Step 2: sequence builder
│   ├── SendControl.tsx        # Step 3: send & monitor
│   ├── EventLog.tsx           # Timestamped event log
│   └── ui/                    # Pixel UI atom components
├── hooks/
│   ├── useAppState.ts         # Zustand store
│   └── useTauriCommand.ts     # Tauri IPC wrappers
├── theme/
│   ├── flexoki.ts             # Color palette
│   └── global.css             # CSS variables
└── types/
    └── models.ts              # TypeScript type definitions
```

## Technical Notes

- **App Sandbox enabled** — compatible with Mac App Store distribution
- **CGEvent.post(HID)** — key events posted to the HID event tap (frontmost window receives)
- **Window activation** — `NSRunningApplication.activate()` brings target to foreground before sending
- **Text input** — characters typed via `CGEventKeyboardSetUnicodeString` on virtual key events
- **Window scanning** — two-pass `CGWindowListCopyWindowInfo` (all + on-screen) with layer-0 filter
- **Process tree** — single-pass `sysctl(KERN_PROC_ALL)` builds parent-child hierarchy
- **State machine** — tokio-based send/validation loops with `CancellationToken` + `Notify`
- **IPC** — 10 Tauri commands + 3 event channels (log, state-change, targets-invalidated)

## License

MIT License. See [LICENSE](LICENSE) for details.
