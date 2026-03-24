# Tapir Rust Rewrite — Design Spec

## Overview

Rewrite Tapir (macOS keyboard automation tool) from SwiftUI to Rust, targeting Apple App Store distribution. The app sends automated keyboard events to target application windows through a guided 4-step workflow.

**Stack**: Tauri v2 + React + TypeScript (frontend) + Rust (backend/core)
**Theme**: Flexoki Light, Menlo monospace, pixel-inspired UI components
**Target**: macOS 14.0+ (Sonoma), App Store with sandbox enabled
**Motivation**: Performance/memory safety + future cross-platform potential

---

## 1. Architecture

### Layered Design

```
┌─────────────────────────────────────────────┐
│  React + TypeScript (Flexoki Light UI)      │  ← WebView
├─────────────────────────────────────────────┤
│  Tauri IPC (commands + events)              │  ← Bridge
├─────────────────────────────────────────────┤
│  commands/  (thin Tauri command handlers)   │
├─────────────────────────────────────────────┤
│  state/     (SenderManager state machine)   │
├─────────────────────────────────────────────┤
│  core/      (pure Rust, no Tauri deps)      │  ← Portable
├─────────────────────────────────────────────┤
│  macOS APIs (CGEvent, CGWindowList, AX)     │  ← FFI
└─────────────────────────────────────────────┘
```

**Principle**: `core/` has zero Tauri dependency — pure Rust business logic that can be extracted into an independent crate for future platforms.

### Project Structure

```
tapir-rs/
├── src-tauri/
│   ├── Cargo.toml
│   ├── tauri.conf.json
│   ├── Tapir.entitlements
│   ├── Info.plist
│   ├── icons/
│   └── src/
│       ├── main.rs
│       ├── commands/
│       │   ├── mod.rs
│       │   ├── accessibility.rs
│       │   ├── window.rs
│       │   ├── sender.rs
│       │   └── system.rs
│       ├── core/
│       │   ├── mod.rs
│       │   ├── key_sender.rs
│       │   ├── window_scanner.rs
│       │   ├── accessibility.rs
│       │   ├── process.rs
│       │   └── key_codes.rs
│       ├── models/
│       │   ├── mod.rs
│       │   ├── key_step.rs
│       │   ├── window_info.rs
│       │   └── log_entry.rs
│       └── state/
│           ├── mod.rs
│           └── sender_state.rs
├── src/
│   ├── index.html
│   ├── main.tsx
│   ├── App.tsx
│   ├── components/
│   │   ├── TitleBar.tsx
│   │   ├── Sidebar.tsx
│   │   ├── StatusBar.tsx
│   │   ├── SystemView.tsx
│   │   ├── WindowSelector.tsx
│   │   ├── KeyConfig.tsx
│   │   ├── SendControl.tsx
│   │   ├── EventLog.tsx
│   │   └── ui/
│   │       ├── PixelPanel.tsx
│   │       ├── PixelButton.tsx
│   │       ├── PixelBadge.tsx
│   │       └── PixelDivider.tsx
│   ├── hooks/
│   │   ├── useAppState.ts
│   │   ├── useTauriCommand.ts
│   │   └── useEventLog.ts
│   ├── theme/
│   │   ├── flexoki.ts
│   │   └── global.css
│   ├── types/
│   │   └── models.ts
│   └── lib/
│       └── keycodes.ts
├── package.json
├── tsconfig.json
├── vite.config.ts
└── scripts/
    └── gen_icon.py
```

---

## 2. Rust Backend

### Dependencies

```toml
[dependencies]
tauri = { version = "2", features = ["macos-private-api"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }
tokio-util = "0.7"          # CancellationToken
core-graphics = "0.24"      # CGEvent, CGWindowList
core-foundation = "0.10"    # CFString, CFArray, CFDictionary
libc = "0.2"                # sysctl, kill(pid,0)
```

### core/key_sender.rs — Key Event Synthesis

Three sending modes matching StepMode:

```rust
pub async fn send_key(pid: i32, key_code: u16, modifiers: Vec<Modifier>) -> Result<()>
pub async fn send_text(pid: i32, text: &str, append_enter: bool) -> Result<()>
pub async fn send_combo(pid: i32, text: &str, prefix: Option<u16>, suffix: Option<u16>) -> Result<()>
```

**Sandbox adaptation**: Instead of `CGEvent.postToPid()` (blocked in sandbox):
1. Activate target window via `NSRunningApplication.activate()` (public API)
2. Send via `CGEvent.post(.cghidEventTap)` to HID event stream (frontmost window receives)
3. Optionally switch back to Tapir window after sequence completes

Timing: 5-8ms inter-character delay, user-configurable step interval (100ms - 10,000,000ms).

### core/window_scanner.rs — Window Discovery

```rust
pub fn scan_windows() -> Result<Vec<WindowInfo>>
```

- `CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID)` for all windows
- Single-pass `sysctl(KERN_PROC_ALL)` to build process parent-child tree
- Filters out Tapir's own PID and desktop elements (WindowServer, Dock)
- Returns `Vec<WindowInfo>` with hierarchy: parent PID, child count, sub-window count

### core/accessibility.rs — Permission Management

```rust
pub fn is_trusted() -> bool
pub fn request_with_prompt() -> bool
pub fn open_settings()
```

FFI to `AXIsProcessTrusted()`, `AXIsProcessTrustedWithOptions()`, and `NSWorkspace.open(URL)`.

### core/process.rs — Process Validation

```rust
pub fn is_process_alive(pid: i32) -> bool   // kill(pid, 0)
pub fn is_window_valid(window_id: u32, pid: i32) -> bool
```

### core/key_codes.rs — macOS CGKeyCode Mapping

Complete lookup table: key name string → CGKeyCode u16. Covers A-Z, 0-9, F1-F12, arrows, modifiers, punctuation, Enter, Tab, Escape, Space, Delete, etc.

### state/sender_state.rs — Send Orchestration

```rust
pub struct SenderManager {
    state: Arc<Mutex<SendingState>>,       // Idle | Running | Paused
    send_count: Arc<AtomicU64>,
    cycles_completed: Arc<AtomicU64>,
    cancel_token: Option<CancellationToken>,
    validation_handle: Option<JoinHandle<()>>,
}

impl SenderManager {
    pub async fn start(&mut self, targets, steps, interval_ms, repeat_count, event_emitter)
    pub fn pause(&self)
    pub fn resume(&self)
    pub fn stop(&mut self)
    pub fn status(&self) -> SenderStatus
}
```

- `start()` spawns two tokio tasks:
  - **Send loop**: iterates steps, sends to all targets (activating each in turn), respects interval, tracks cycles
  - **Validation loop**: every 3s checks `is_process_alive()` for all targets, emits `targets-invalidated` event for dead ones, auto-pauses if all targets gone
- `pause()`/`resume()` via `tokio::sync::Notify`
- `stop()` via `CancellationToken` for graceful shutdown
- Logs pushed to frontend via Tauri `AppHandle.emit()`

### Tauri Commands (IPC Interface)

```rust
#[tauri::command] fn check_permission() -> bool
#[tauri::command] fn request_permission() -> bool
#[tauri::command] fn open_settings()
#[tauri::command] fn scan_windows() -> Vec<WindowInfo>
#[tauri::command] fn validate_windows(pids: Vec<i32>) -> Vec<i32>
#[tauri::command] fn start_sending(targets: Vec<WindowInfo>, steps: Vec<KeyStep>, interval_ms: u64, repeat_count: Option<u64>)
#[tauri::command] fn pause_sending()
#[tauri::command] fn resume_sending()
#[tauri::command] fn stop_sending()
#[tauri::command] fn get_sender_status() -> SenderStatus
```

### Tauri Events (Rust → Frontend Push)

| Event | Payload | Purpose |
|-------|---------|---------|
| `tapir://log` | `LogEntry` | Timestamped log entry |
| `tapir://state-change` | `SendingState` | idle/running/paused transition |
| `tapir://targets-invalidated` | `Vec<i32>` | PIDs of closed processes |

---

## 3. Data Models

### KeyStep

```rust
#[derive(Serialize, Deserialize, Clone)]
pub struct KeyStep {
    pub id: String,                    // UUID
    pub mode: StepMode,                // Key | Text | Combo
    pub key_name: String,              // for Key mode
    pub with_command: bool,
    pub with_shift: bool,
    pub with_option: bool,
    pub with_control: bool,
    pub text_content: String,          // for Text/Combo mode
    pub append_enter: bool,            // for Text mode
    pub has_prefix_key: bool,          // for Combo mode
    pub prefix_key_name: String,
    pub has_suffix_key: bool,
    pub suffix_key_name: String,
}

#[derive(Serialize, Deserialize, Clone)]
pub enum StepMode { Key, Text, Combo }
```

### WindowInfo

```rust
#[derive(Serialize, Deserialize, Clone)]
pub struct WindowInfo {
    pub id: u32,
    pub owner_name: String,
    pub window_name: String,
    pub pid: i32,
    pub parent_pid: i32,
    pub is_child_process: bool,
    pub child_process_count: u32,
    pub sub_window_count: u32,
    pub is_on_screen: bool,
}
```

### LogEntry

```rust
#[derive(Serialize, Deserialize, Clone)]
pub struct LogEntry {
    pub id: String,                    // UUID
    pub timestamp: String,             // ISO 8601
    pub entry_type: String,            // "key" | "state" | "error" | "warn"
    pub message: String,
}
```

### SenderStatus

```rust
#[derive(Serialize, Deserialize)]
pub struct SenderStatus {
    pub state: SendingState,
    pub send_count: u64,
    pub cycles_completed: u64,
}

#[derive(Serialize, Deserialize, Clone)]
pub enum SendingState { Idle, Running, Paused }
```

---

## 4. React Frontend

### State Management — Zustand

```typescript
interface AppState {
  currentStep: 0 | 1 | 2 | 3
  hasPermission: boolean
  scannedWindows: WindowInfo[]
  selectedWindows: WindowInfo[]
  searchQuery: string
  keySteps: KeyStep[]
  intervalMs: number
  sendingState: 'idle' | 'running' | 'paused'
  sendCount: number
  cyclesCompleted: number
  repeatCount: number | null  // null = infinite loop
  logEntries: LogEntry[]      // max 500
  autoScroll: boolean
  toast: { message: string; color: string } | null
}
```

### Flexoki Light Theme — CSS Variables

```css
:root {
  --bg-primary:    #FFFCF0;
  --bg-secondary:  #F2F0E5;
  --bg-tertiary:   #E6E4D9;
  --bg-active:     #DAD8CE;

  --text-primary:  #100F0F;
  --text-secondary:#6F6E69;
  --text-dim:      #878580;
  --text-muted:    #B7B5AC;

  --border:        #E6E4D9;
  --border-light:  #F2F0E5;

  --red:     #AF3029;    --red-light:     #D14D41;
  --orange:  #BC5215;    --orange-light:  #DA702C;
  --yellow:  #AD8301;    --yellow-light:  #D0A215;
  --green:   #66800B;    --green-light:   #879A39;
  --cyan:    #24837B;    --cyan-light:    #3AA99F;
  --blue:    #205EA6;    --blue-light:    #4385BE;
  --purple:  #5E409D;    --purple-light:  #8B7EC8;
  --magenta: #A02F6F;    --magenta-light: #CE5D97;

  --accent:   var(--cyan);
  --success:  var(--green);
  --warning:  var(--orange);
  --error:    var(--red);
  --info:     var(--blue);

  --font-mono: 'Menlo', 'SF Mono', monospace;
  --radius-sm: 4px;
  --radius-md: 6px;
  --radius-lg: 8px;
  --shadow-panel:  0 1px 3px rgba(16,15,15,0.08);
  --shadow-button: 0 1px 2px rgba(16,15,15,0.12);
}
```

### UI Components

**PixelPanel**: Card container with `bg-secondary`, 1px border, optional accent header bar, soft shadow.

**PixelButton**: Three variants:
- Default: `bg-tertiary`, hover lifts + shadow deepens
- Primary: accent color bg, white text
- Danger: red bg
- Press animation: `translateY(1px)`, all transitions 120ms ease

**PixelBadge**: Capsule shape, semantic colors (cyan=targets, green=keys, magenta=state).

**PixelDivider**: 1px `border` color separator.

### 4-Step Workflow Pages

| Step | Component | Layout |
|------|-----------|--------|
| 0 Permission | `SystemView` | Centered card: status indicator + grant button + instructions |
| 1 Target | `WindowSelector` | Top search bar + scan button, scrollable window list below |
| 2 Keys | `KeyConfig` | Top sequence preview flow, step card list with drag-to-reorder |
| 3 Control | `SendControl` | Large state display + counter + progress bar + buttons, EventLog below |

### Overall Layout

- **Left sidebar** (200px): Step circles with badges, progress dots, sequence mini-preview, current send state
- **Main content**: Active step page
- **Bottom StatusBar**: Fixed, shows permission status / target label / send count / interval / state
- **TitleBar**: Custom (no native decorations), app branding, target/key count badges, version
- **Toast**: Overlay notification, auto-dismiss 1.8s

### Drag & Drop

`@dnd-kit/core` for KeyStep reorder with smooth animations.

### Tauri IPC Wrapper

```typescript
import { invoke } from '@tauri-apps/api/core'
import { listen } from '@tauri-apps/api/event'

// Listen for Rust-pushed events
listen('tapir://log', (e) => addLogEntry(e.payload))
listen('tapir://state-change', (e) => setSendingState(e.payload))
listen('tapir://targets-invalidated', (e) => handleInvalidTargets(e.payload))
```

---

## 5. App Store Compliance

### Entitlements

```xml
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
```

### Privacy Declarations

```xml
<key>NSAccessibilityUsageDescription</key>
<string>Tapir needs Accessibility permission to send keyboard events to other applications.</string>
```

### Tauri Config

- `decorations: false` — custom title bar
- `minimumSystemVersion: "14.0"`
- Bundle targets: `["dmg", "app"]`

### App Review Considerations

| Item | Strategy |
|------|----------|
| Sandbox | Enabled, minimal entitlements |
| Accessibility | User-initiated grant, usage description in Info.plist |
| Minimum OS | macOS 14.0 (Sonoma) |
| Private APIs | None — CGEvent/AX are public frameworks |
| Window activation | `NSRunningApplication.activate()` — public API |
| Content safety | Utility app, no user-generated content |

---

## 6. Sandbox Key Sending Strategy

**Current (SwiftUI, no sandbox)**: `CGEvent.postToPid(pid)` — sends directly to background process.

**New (Rust, sandboxed)**:
1. `NSRunningApplication(pid).activate(options: .activateIgnoringOtherApps)` — bring target to front
2. Short delay (50ms) for window to activate
3. `CGEvent.post(tap: .cghidEventTap)` — send to HID stream (frontmost receives)
4. For multi-target: cycle through targets, activating each before sending

**Behavioral difference**: Target window must be frontmost to receive events. Multi-target sends involve visible window switching.

**Fallback if CGEvent.post blocked in sandbox**:
1. AppleScript bridge: `osascript -e 'tell application "X" to keystroke "Y"'` (needs `com.apple.security.automation.apple-events` entitlement)
2. Abandon App Store, use Developer ID notarized distribution

---

## 7. Development Phases

| Phase | Content | Goal |
|-------|---------|------|
| P0 | CGEvent sandbox PoC | Validate core feasibility |
| P1 | Rust core modules | key_sender, window_scanner, accessibility, process |
| P2 | Tauri scaffold + IPC | Project structure, commands, event channels |
| P3 | React UI skeleton | Flexoki Light theme, layout framework, routing |
| P4 | Step 0 — Permission | Full permission check flow |
| P5 | Step 1 — Target | Scan + search + multi-select |
| P6 | Step 2 — Keys | KEY/TEXT/COMBO modes + drag reorder |
| P7 | Step 3 — Control | State machine + loop/repeat + event log |
| P8 | Integration polish | Animations, Toast, StatusBar, edge cases |
| P9 | App Store packaging | Signing, sandbox verification, submission |

## 8. Testing Strategy

- **core/ unit tests**: Key code mappings, process tree construction, state machine transitions
- **Integration tests**: Tests requiring Accessibility permission marked `#[ignore]`, skipped in CI, run locally
- **Frontend tests**: Vitest + React Testing Library — component rendering + state flow

## 9. Known Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| CGEvent.post blocked in sandbox | Core feature broken | P0 PoC validates first; AppleScript fallback |
| `core-graphics` crate gaps | Need hand-written unsafe FFI | Fill gaps in core/, encapsulate unsafe |
| Tauri v2 macOS signing flow | Packaging/submission issues | Follow Tauri official App Store guide |
| Drag reorder performance | Lag with many KeySteps | Virtual list + controlled re-renders |
| Window activation latency | Delay between target switch | 50ms activation delay, user-visible switching |
