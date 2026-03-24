# Tapir Rust Rewrite — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite Tapir (macOS keyboard automation tool) from SwiftUI to Rust (Tauri v2 + React + TypeScript), targeting App Store distribution with Flexoki Light theme.

**Architecture:** Tauri v2 backend with layered Rust core (zero Tauri deps) for macOS FFI (CGEvent, CGWindowList, AX), thin Tauri command layer for IPC, and React + TypeScript + Zustand frontend with custom pixel-art UI components.

**Tech Stack:** Rust, Tauri v2, React 18, TypeScript, Zustand, Vite, @dnd-kit, core-graphics crate, objc2 crate, Vitest

**Spec:** `docs/superpowers/specs/2026-03-24-tapir-rust-rewrite-design.md`

**Existing SwiftUI reference:** `TapirApp/` directory (read-only reference, do not modify)

**IMPORTANT — Key name changes**: The Rust version removes spaces from key names vs the SwiftUI version (`"Forward Delete"` → `"ForwardDelete"`, `"Page Up"` → `"PageUp"`). This is an intentional breaking change — no migration from SwiftUI config is needed since this is a full rewrite.

---

## Task 0: P0 — CGEvent Sandbox Proof of Concept

**Files:**
- Create: `poc/src-tauri/Cargo.toml`
- Create: `poc/src-tauri/tauri.conf.json`
- Create: `poc/src-tauri/Poc.entitlements`
- Create: `poc/src-tauri/src/main.rs`
- Create: `poc/src/index.html`
- Create: `poc/src/main.tsx`
- Create: `poc/package.json`

This is the single most important task. The spec's Section 6 identifies CGEvent sandbox behavior as the primary architectural risk. We must validate before building the full app.

- [ ] **Step 1: Create a minimal Tauri v2 project in poc/ directory**

```bash
cd /Users/joejiang/Desktop/tapir
npm create tauri-app@latest poc -- --template react-ts --manager npm
```

- [ ] **Step 2: Enable sandbox in poc/src-tauri/Poc.entitlements**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
</dict>
</plist>
```

Reference this entitlements file in `poc/src-tauri/tauri.conf.json` under `bundle.macOS.entitlements`.

- [ ] **Step 3: Add CGEvent test command to poc/src-tauri/src/main.rs**

```rust
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use core_graphics::event::{CGEvent, CGEventFlags};
use core_graphics::event_source::{CGEventSource, CGEventSourceStateID};

extern "C" {
    fn CGEventPost(tap: u32, event: core_graphics::sys::CGEventRef);
    fn AXIsProcessTrusted() -> bool;
}

const HID_EVENT_TAP: u32 = 0;

#[tauri::command]
fn test_cgevent_post() -> String {
    let trusted = unsafe { AXIsProcessTrusted() };
    if !trusted {
        return "NOT TRUSTED — grant accessibility permission first".into();
    }

    let source = match CGEventSource::new(CGEventSourceStateID::HIDSystemState) {
        Ok(s) => s,
        Err(_) => return "FAIL: cannot create event source".into(),
    };

    // Try sending a Space key to the frontmost app
    let key_down = match CGEvent::new_keyboard_event(source.clone(), 49, true) {
        Ok(e) => e,
        Err(_) => return "FAIL: cannot create key down event".into(),
    };
    let key_up = match CGEvent::new_keyboard_event(source.clone(), 49, false) {
        Ok(e) => e,
        Err(_) => return "FAIL: cannot create key up event".into(),
    };

    unsafe {
        CGEventPost(HID_EVENT_TAP, key_down.as_ptr());
        std::thread::sleep(std::time::Duration::from_millis(10));
        CGEventPost(HID_EVENT_TAP, key_up.as_ptr());
    }

    "SUCCESS: CGEvent.post(HID) executed — check if the frontmost app received a Space key".into()
}

#[tauri::command]
fn check_permission() -> bool {
    unsafe { AXIsProcessTrusted() }
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![test_cgevent_post, check_permission])
        .run(tauri::generate_context!())
        .expect("error");
}
```

Add `core-graphics = "0.24"` to `poc/src-tauri/Cargo.toml` dependencies.

- [ ] **Step 4: Add test UI to poc/src/main.tsx**

Simple React page with two buttons: "Check Permission" and "Test CGEvent Post". Display result from each command.

- [ ] **Step 5: Build as a release .app bundle (NOT dev build)**

```bash
cd /Users/joejiang/Desktop/tapir/poc
npm run tauri build
```

CRITICAL: Sandbox restrictions differ between debug and release builds. The PoC MUST be tested as a bundled `.app`.

- [ ] **Step 6: Test the sandbox behavior**

1. Open `poc/src-tauri/target/release/bundle/macos/poc.app`
2. Grant Accessibility permission in System Settings
3. Open TextEdit and bring it to the foreground
4. Click "Test CGEvent Post" in the PoC app
5. Check if TextEdit received a Space character

**Expected outcomes:**
- **SUCCESS**: Space appears in TextEdit → **Path A confirmed**, proceed with full implementation
- **FAIL**: No character received → Test Path B (AppleScript), add `com.apple.security.automation.apple-events` entitlement and use `NSAppleScript` to send `tell application "TextEdit" to keystroke " "`
- **BOTH FAIL**: Fall back to Path C (Developer ID distribution without sandbox)

- [ ] **Step 7: Document the result and clean up**

Record which path (A/B/C) works. If Path B or C, update `src-tauri/Tapir.entitlements` and `core/key_sender.rs` approach in subsequent tasks accordingly.

```bash
rm -rf poc/
```

- [ ] **Step 8: Commit PoC result note**

```bash
git commit --allow-empty -m "chore: P0 sandbox PoC validated — Path A/B/C confirmed"
```

---

## Task 1: Tauri v2 + React + TypeScript Project Scaffold

**Files:**
- Create: `src-tauri/Cargo.toml`
- Create: `src-tauri/tauri.conf.json`
- Create: `src-tauri/build.rs`
- Create: `src-tauri/Tapir.entitlements`
- Create: `src-tauri/Info.plist`
- Create: `src-tauri/src/main.rs`
- Create: `src/index.html`
- Create: `src/main.tsx`
- Create: `src/App.tsx`
- Create: `package.json`
- Create: `tsconfig.json`
- Create: `tsconfig.node.json`
- Create: `vite.config.ts`
- Modify: `.gitignore`

- [ ] **Step 1: Initialize Tauri v2 project**

Run:
```bash
cd /Users/joejiang/Desktop/tapir
npm create tauri-app@latest tapir-rs -- --template react-ts --manager npm
```

Then move contents from `tapir-rs/` into project root (merge, don't overwrite existing files).

- [ ] **Step 2: Configure Cargo.toml with all dependencies**

File: `src-tauri/Cargo.toml`

```toml
[package]
name = "tapir"
version = "2.0.0"
edition = "2021"

[build-dependencies]
tauri-build = { version = "2", features = [] }

[dependencies]
tauri = { version = "2", features = ["macos-private-api"] }
tauri-plugin-shell = "2"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }
tokio-util = { version = "0.7", features = ["rt"] }
uuid = { version = "1", features = ["v4"] }
chrono = "0.4"

[target.'cfg(target_os = "macos")'.dependencies]
core-graphics = "0.24"
core-foundation = "0.10"
objc2 = "0.6"
objc2-foundation = "0.3"
objc2-app-kit = "0.3"
libc = "0.2"
```

- [ ] **Step 3: Configure tauri.conf.json**

File: `src-tauri/tauri.conf.json`

```json
{
  "$schema": "https://raw.githubusercontent.com/nicedoc/unpkg/main/packages/tauri-apps/api/config-2.json",
  "productName": "Tapir",
  "version": "2.0.0",
  "identifier": "com.tapir.app",
  "build": {
    "frontendDist": "../dist",
    "devUrl": "http://localhost:1420",
    "beforeDevCommand": "npm run dev",
    "beforeBuildCommand": "npm run build"
  },
  "app": {
    "macOSPrivateApi": true,
    "windows": [
      {
        "title": "Tapir",
        "width": 960,
        "height": 640,
        "minWidth": 800,
        "minHeight": 560,
        "resizable": true,
        "decorations": false
      }
    ]
  },
  "bundle": {
    "active": true,
    "targets": ["dmg", "app"],
    "icon": [
      "icons/32x32.png",
      "icons/128x128.png",
      "icons/128x128@2x.png",
      "icons/icon.icns",
      "icons/icon.ico"
    ],
    "macOS": {
      "minimumSystemVersion": "14.0",
      "entitlements": "Tapir.entitlements"
    }
  }
}
```

- [ ] **Step 4: Create Tapir.entitlements**

File: `src-tauri/Tapir.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 5: Create Info.plist**

File: `src-tauri/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSAccessibilityUsageDescription</key>
    <string>Tapir needs Accessibility permission to send keyboard events to other applications.</string>
</dict>
</plist>
```

- [ ] **Step 6: Create minimal Rust entry point**

File: `src-tauri/src/main.rs`

```rust
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

- [ ] **Step 7: Create minimal React entry point**

File: `src/main.tsx`

```tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './theme/global.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
```

File: `src/App.tsx`

```tsx
export default function App() {
  return <div style={{ fontFamily: 'Menlo, monospace', padding: 20 }}>Tapir v2.0</div>
}
```

File: `src/theme/global.css` (placeholder):

```css
:root {
  --bg-primary: #FFFCF0;
  --text-primary: #100F0F;
}

body {
  margin: 0;
  background: var(--bg-primary);
  color: var(--text-primary);
}
```

- [ ] **Step 8: Update .gitignore**

Append to `.gitignore`:

```
node_modules/
dist/
src-tauri/target/
```

- [ ] **Step 9: Install npm dependencies**

Run:
```bash
cd /Users/joejiang/Desktop/tapir
npm install
```

- [ ] **Step 10: Verify project builds and runs**

Run:
```bash
cd /Users/joejiang/Desktop/tapir
npm run tauri dev
```

Expected: Tauri window opens showing "Tapir v2.0" on a cream background.

- [ ] **Step 11: Commit**

```bash
git add src-tauri/ src/ package.json tsconfig.json tsconfig.node.json vite.config.ts index.html .gitignore
git commit -m "feat: initialize Tauri v2 + React + TypeScript scaffold"
```

---

## Task 2: Rust Data Models

**Files:**
- Create: `src-tauri/src/models/mod.rs`
- Create: `src-tauri/src/models/key_step.rs`
- Create: `src-tauri/src/models/window_info.rs`
- Create: `src-tauri/src/models/log_entry.rs`
- Create: `src-tauri/src/models/error.rs`
- Modify: `src-tauri/src/main.rs`

- [ ] **Step 1: Create models/mod.rs**

```rust
pub mod error;
pub mod key_step;
pub mod log_entry;
pub mod window_info;

pub use error::TapirError;
pub use key_step::{KeyStep, StepMode};
pub use log_entry::LogEntry;
pub use window_info::WindowInfo;
```

- [ ] **Step 2: Create models/error.rs**

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum TapirError {
    NoPermission,
    EventCreationFailed { message: String },
    InvalidTarget { pid: i32 },
    NoStepsConfigured,
    WindowScanFailed { message: String },
    SendFailed { message: String },
}

impl std::fmt::Display for TapirError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            TapirError::NoPermission => write!(f, "Accessibility permission not granted"),
            TapirError::EventCreationFailed { message } => write!(f, "Event creation failed: {message}"),
            TapirError::InvalidTarget { pid } => write!(f, "Invalid target process: {pid}"),
            TapirError::NoStepsConfigured => write!(f, "No key steps configured"),
            TapirError::WindowScanFailed { message } => write!(f, "Window scan failed: {message}"),
            TapirError::SendFailed { message } => write!(f, "Send failed: {message}"),
        }
    }
}

impl std::error::Error for TapirError {}

impl From<TapirError> for tauri::ipc::InvokeError {
    fn from(err: TapirError) -> Self {
        // Serialize to a serde_json::Value so the frontend receives a parsed object
        // (not a double-serialized string). The frontend catch handler gets
        // { type: "noPermission" } or { type: "sendFailed", message: "..." } directly.
        let value = serde_json::to_value(&err).unwrap_or(serde_json::Value::String(err.to_string()));
        tauri::ipc::InvokeError::from(value)
    }
}
```

- [ ] **Step 3: Create models/key_step.rs**

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct KeyStep {
    pub id: String,
    pub mode: StepMode,
    pub key_name: String,
    pub with_command: bool,
    pub with_shift: bool,
    pub with_option: bool,
    pub with_control: bool,
    pub text_content: String,
    pub append_enter: bool,
    pub has_prefix_key: bool,
    pub prefix_key_name: String,
    pub has_suffix_key: bool,
    pub suffix_key_name: String,
}

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum StepMode {
    Key,
    Text,
    Combo,
}
```

- [ ] **Step 4: Create models/window_info.rs**

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct WindowInfo {
    pub id: u32,
    pub owner_name: String,
    pub window_name: String,
    pub pid: i32,
    pub parent_pid: i32,
    pub parent_windowed_pid: i32,
    pub is_child_process: bool,
    pub child_process_count: u32,
    pub sub_window_count: u32,
    pub is_on_screen: bool,
}
```

- [ ] **Step 5: Create models/log_entry.rs**

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct LogEntry {
    pub id: String,
    pub timestamp: String,
    pub entry_type: String,
    pub message: String,
}

impl LogEntry {
    pub fn new(entry_type: &str, message: &str) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            timestamp: chrono::Utc::now().to_rfc3339(),
            entry_type: entry_type.to_string(),
            message: message.to_string(),
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum SendingState {
    Idle,
    Running,
    Paused,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct SenderStatus {
    pub state: SendingState,
    pub send_count: u64,
    pub cycles_completed: u64,
}
```

- [ ] **Step 6: Register models module in main.rs**

Add `mod models;` to `src-tauri/src/main.rs`.

- [ ] **Step 7: Verify compilation**

Run:
```bash
cd /Users/joejiang/Desktop/tapir/src-tauri
cargo check
```

Expected: Compiles with no errors.

- [ ] **Step 8: Commit**

```bash
git add src-tauri/src/models/ src-tauri/src/main.rs
git commit -m "feat: add Rust data models (KeyStep, WindowInfo, LogEntry, TapirError)"
```

---

## Task 3: Rust Core — Key Codes Mapping

**Files:**
- Create: `src-tauri/src/core/mod.rs`
- Create: `src-tauri/src/core/key_codes.rs`
- Create: `src-tauri/tests/key_codes_test.rs`
- Modify: `src-tauri/src/main.rs`

- [ ] **Step 1: Write failing test for key_codes**

File: `src-tauri/tests/key_codes_test.rs`

```rust
use tapir::core::key_codes;

#[test]
fn test_lookup_letter_keys() {
    assert_eq!(key_codes::lookup("A"), Some(0));
    assert_eq!(key_codes::lookup("S"), Some(1));
    assert_eq!(key_codes::lookup("D"), Some(2));
    assert_eq!(key_codes::lookup("Z"), Some(6));
}

#[test]
fn test_lookup_special_keys() {
    assert_eq!(key_codes::lookup("Return"), Some(36));
    assert_eq!(key_codes::lookup("Tab"), Some(48));
    assert_eq!(key_codes::lookup("Space"), Some(49));
    assert_eq!(key_codes::lookup("Delete"), Some(51));
    assert_eq!(key_codes::lookup("Escape"), Some(53));
}

#[test]
fn test_lookup_function_keys() {
    assert_eq!(key_codes::lookup("F1"), Some(122));
    assert_eq!(key_codes::lookup("F12"), Some(111));
}

#[test]
fn test_lookup_arrow_keys() {
    assert_eq!(key_codes::lookup("Left"), Some(123));
    assert_eq!(key_codes::lookup("Right"), Some(124));
    assert_eq!(key_codes::lookup("Down"), Some(125));
    assert_eq!(key_codes::lookup("Up"), Some(126));
}

#[test]
fn test_lookup_unknown_key() {
    assert_eq!(key_codes::lookup("INVALID"), None);
}

#[test]
fn test_all_key_names_non_empty() {
    let names = key_codes::all_key_names();
    assert!(!names.is_empty());
    assert!(names.len() > 50);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/joejiang/Desktop/tapir/src-tauri && cargo test --test key_codes_test`

Expected: FAIL — module not found.

- [ ] **Step 3: Create core/mod.rs**

```rust
pub mod key_codes;
```

- [ ] **Step 4: Create core/key_codes.rs with full mapping**

```rust
use std::collections::HashMap;
use std::sync::LazyLock;

static KEY_CODE_MAP: LazyLock<HashMap<&'static str, u16>> = LazyLock::new(|| {
    let mut m = HashMap::new();
    // Letters
    m.insert("A", 0); m.insert("S", 1); m.insert("D", 2); m.insert("F", 3);
    m.insert("H", 4); m.insert("G", 5); m.insert("Z", 6); m.insert("X", 7);
    m.insert("C", 8); m.insert("V", 9); m.insert("B", 11); m.insert("Q", 12);
    m.insert("W", 13); m.insert("E", 14); m.insert("R", 15); m.insert("Y", 16);
    m.insert("T", 17); m.insert("O", 31); m.insert("U", 32); m.insert("I", 34);
    m.insert("P", 35); m.insert("L", 37); m.insert("J", 38); m.insert("K", 40);
    m.insert("N", 45); m.insert("M", 46);
    // Numbers
    m.insert("1", 18); m.insert("2", 19); m.insert("3", 20); m.insert("4", 21);
    m.insert("5", 23); m.insert("6", 22); m.insert("7", 26); m.insert("8", 28);
    m.insert("9", 25); m.insert("0", 29);
    // Symbols
    m.insert("=", 24); m.insert("-", 27); m.insert("]", 30); m.insert("[", 33);
    m.insert("'", 39); m.insert(";", 41); m.insert("\\", 42); m.insert(",", 43);
    m.insert("/", 44); m.insert(".", 47); m.insert("`", 50);
    // Special
    m.insert("Return", 36); m.insert("Tab", 48); m.insert("Space", 49);
    m.insert("Delete", 51); m.insert("Escape", 53); m.insert("ForwardDelete", 117);
    // Function
    m.insert("F1", 122); m.insert("F2", 120); m.insert("F3", 99); m.insert("F4", 118);
    m.insert("F5", 96); m.insert("F6", 97); m.insert("F7", 98); m.insert("F8", 100);
    m.insert("F9", 101); m.insert("F10", 109); m.insert("F11", 103); m.insert("F12", 111);
    // Arrows
    m.insert("Left", 123); m.insert("Right", 124); m.insert("Down", 125); m.insert("Up", 126);
    // Navigation
    m.insert("Home", 115); m.insert("End", 119); m.insert("PageUp", 116); m.insert("PageDown", 121);
    m
});

/// Look up a CGKeyCode by key name. Returns None if not found.
pub fn lookup(name: &str) -> Option<u16> {
    KEY_CODE_MAP.get(name).copied()
}

/// Return all known key names, sorted alphabetically.
pub fn all_key_names() -> Vec<&'static str> {
    let mut names: Vec<&str> = KEY_CODE_MAP.keys().copied().collect();
    names.sort();
    names
}
```

- [ ] **Step 5: Add lib.rs for test visibility**

File: `src-tauri/src/lib.rs`

```rust
pub mod core;
pub mod models;
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd /Users/joejiang/Desktop/tapir/src-tauri && cargo test --test key_codes_test`

Expected: All 6 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add src-tauri/src/core/ src-tauri/src/lib.rs src-tauri/tests/
git commit -m "feat: add key code mapping table with tests"
```

---

## Task 4: Rust Core — Accessibility Service

**Files:**
- Create: `src-tauri/src/core/accessibility.rs`
- Modify: `src-tauri/src/core/mod.rs`

- [ ] **Step 1: Create core/accessibility.rs**

```rust
#[cfg(target_os = "macos")]
mod macos {
    use std::ptr;

    #[link(name = "ApplicationServices", kind = "framework")]
    extern "C" {
        fn AXIsProcessTrusted() -> bool;
        fn AXIsProcessTrustedWithOptions(options: *const std::ffi::c_void) -> bool;
    }

    use core_foundation::base::TCFType;
    use core_foundation::boolean::CFBoolean;
    use core_foundation::dictionary::CFDictionary;
    use core_foundation::string::CFString;

    pub fn is_trusted() -> bool {
        unsafe { AXIsProcessTrusted() }
    }

    pub fn request_with_prompt() -> bool {
        let key = CFString::new("AXTrustedCheckOptionPrompt");
        let value = CFBoolean::true_value();
        let options = CFDictionary::from_CFType_pairs(&[(key, value)]);
        unsafe { AXIsProcessTrustedWithOptions(options.as_concrete_TypeRef() as *const _) }
    }

    pub fn open_settings() {
        let url_str = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
        // Use objc2 to call NSWorkspace.shared.open(URL)
        use objc2_foundation::{NSString, NSURL};
        use objc2_app_kit::NSWorkspace;
        unsafe {
            let url_string = NSString::from_str(url_str);
            if let Some(url) = NSURL::URLWithString(&url_string) {
                let workspace = NSWorkspace::sharedWorkspace();
                workspace.openURL(&url);
            }
        }
    }
}

#[cfg(not(target_os = "macos"))]
mod macos {
    pub fn is_trusted() -> bool { false }
    pub fn request_with_prompt() -> bool { false }
    pub fn open_settings() {}
}

pub use macos::*;
```

- [ ] **Step 2: Add to core/mod.rs**

```rust
pub mod accessibility;
pub mod key_codes;
```

- [ ] **Step 3: Verify compilation**

Run: `cd /Users/joejiang/Desktop/tapir/src-tauri && cargo check`

Expected: Compiles. (Cannot unit test accessibility — requires system permission.)

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/core/
git commit -m "feat: add accessibility permission FFI (AXIsProcessTrusted)"
```

---

## Task 5: Rust Core — Process Validator

**Files:**
- Create: `src-tauri/src/core/process.rs`
- Modify: `src-tauri/src/core/mod.rs`

- [ ] **Step 1: Create core/process.rs**

```rust
/// Check if a process is alive by sending signal 0.
pub fn is_process_alive(pid: i32) -> bool {
    if pid <= 0 {
        return false;
    }
    unsafe { libc::kill(pid, 0) == 0 }
}

/// Check if a window still exists, falling back to PID alive check.
#[cfg(target_os = "macos")]
pub fn is_window_valid(window_id: u32, pid: i32) -> bool {
    use core_foundation::base::TCFType;
    use core_graphics::window::{
        kCGNullWindowID, kCGWindowListExcludeDesktopElements, kCGWindowListOptionAll,
        kCGWindowNumber, CGWindowListCopyWindowInfo,
    };

    let info = unsafe {
        CGWindowListCopyWindowInfo(
            kCGWindowListOptionAll | kCGWindowListExcludeDesktopElements,
            kCGNullWindowID,
        )
    };

    if let Some(info) = info {
        let count = unsafe { core_foundation::array::CFArray::wrap_under_get_rule(info) };
        for i in 0..count.len() {
            let dict = unsafe {
                let raw = core_foundation::array::CFArray::get_value(&count, i);
                core_foundation::dictionary::CFDictionary::wrap_under_get_rule(
                    raw as core_foundation::dictionary::CFDictionaryRef,
                )
            };
            if let Some(num) = dict.find(unsafe { &kCGWindowNumber }) {
                let num = unsafe {
                    core_foundation::number::CFNumber::wrap_under_get_rule(*num as *const _)
                };
                if let Some(wid) = num.to_i64() {
                    if wid as u32 == window_id {
                        return true;
                    }
                }
            }
        }
    }

    // Fallback: check if process is alive
    is_process_alive(pid)
}

#[cfg(not(target_os = "macos"))]
pub fn is_window_valid(_window_id: u32, pid: i32) -> bool {
    is_process_alive(pid)
}
```

- [ ] **Step 2: Add to core/mod.rs**

Add: `pub mod process;`

- [ ] **Step 3: Verify compilation**

Run: `cd /Users/joejiang/Desktop/tapir/src-tauri && cargo check`

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/core/
git commit -m "feat: add process validator (kill signal 0 + window existence check)"
```

---

## Task 6: Rust Core — Window Scanner

**Files:**
- Create: `src-tauri/src/core/window_scanner.rs`
- Modify: `src-tauri/src/core/mod.rs`

- [ ] **Step 1: Create core/window_scanner.rs**

```rust
use crate::models::{TapirError, WindowInfo};
use core_foundation::base::TCFType;
use core_foundation::dictionary::CFDictionaryRef;
use core_foundation::number::CFNumber;
use core_foundation::string::CFString;
use std::collections::{HashMap, HashSet};

#[cfg(target_os = "macos")]
pub fn scan_windows() -> Result<Vec<WindowInfo>, TapirError> {
    let my_pid = std::process::id() as i32;

    // Pass 1: all windows (excluding desktop elements)
    let all_windows = get_raw_windows(
        core_graphics::window::kCGWindowListOptionAll
            | core_graphics::window::kCGWindowListExcludeDesktopElements,
    )
    .map_err(|e| TapirError::WindowScanFailed { message: e })?;

    // Pass 2: on-screen windows for is_on_screen flag
    let on_screen_ids: HashSet<u32> = get_raw_windows(
        core_graphics::window::kCGWindowListOptionOnScreenOnly
            | core_graphics::window::kCGWindowListExcludeDesktopElements,
    )
    .unwrap_or_default()
    .iter()
    .filter_map(|w| Some(w.id))
    .collect();

    // Filter: layer 0, not self, has name
    let filtered: Vec<&RawWindow> = all_windows
        .iter()
        .filter(|w| w.layer == 0)
        .filter(|w| w.pid != my_pid)
        .filter(|w| !w.owner_name.is_empty() || !w.window_name.is_empty())
        .collect();

    // Build process tree via sysctl
    let child_map = build_child_pid_map();

    // Collect unique PIDs and their parent PIDs
    let pids: HashSet<i32> = filtered.iter().map(|w| w.pid).collect();
    let mut pid_parent: HashMap<i32, i32> = HashMap::new();
    for &pid in &pids {
        pid_parent.insert(pid, get_parent_pid(pid));
    }

    // Build windowed-parent relationships
    let mut pid_to_windowed_parent: HashMap<i32, i32> = HashMap::new();
    for &pid in &pids {
        let ppid = pid_parent.get(&pid).copied().unwrap_or(0);
        if ppid > 0 && pids.contains(&ppid) {
            pid_to_windowed_parent.insert(pid, ppid);
        }
    }

    // Count children and sub-windows per PID
    let mut child_count: HashMap<i32, u32> = HashMap::new();
    for (&pid, &parent) in &pid_to_windowed_parent {
        if parent > 0 {
            *child_count.entry(parent).or_default() += 1;
        }
    }

    let mut sub_window_count: HashMap<i32, u32> = HashMap::new();
    for w in &filtered {
        *sub_window_count.entry(w.pid).or_default() += 1;
    }

    // Build result
    let result: Vec<WindowInfo> = filtered
        .iter()
        .map(|w| {
            let parent_windowed = pid_to_windowed_parent.get(&w.pid).copied().unwrap_or(0);
            WindowInfo {
                id: w.id,
                owner_name: w.owner_name.clone(),
                window_name: w.window_name.clone(),
                pid: w.pid,
                parent_pid: pid_parent.get(&w.pid).copied().unwrap_or(0),
                parent_windowed_pid: parent_windowed,
                is_child_process: parent_windowed > 0,
                child_process_count: child_count.get(&w.pid).copied().unwrap_or(0),
                sub_window_count: sub_window_count.get(&w.pid).copied().unwrap_or(0),
                is_on_screen: on_screen_ids.contains(&w.id),
            }
        })
        .collect();

    Ok(result)
}

// --- Private helpers ---

struct RawWindow {
    id: u32,
    pid: i32,
    layer: i32,
    owner_name: String,
    window_name: String,
}

fn get_raw_windows(options: u32) -> Result<Vec<RawWindow>, String> {
    use core_graphics::window::{kCGNullWindowID, CGWindowListCopyWindowInfo};

    let info = unsafe { CGWindowListCopyWindowInfo(options, kCGNullWindowID) };
    let info = match info {
        Some(i) => i,
        None => return Err("CGWindowListCopyWindowInfo returned null".into()),
    };

    let array = unsafe { core_foundation::array::CFArray::wrap_under_get_rule(info) };
    let mut windows = Vec::new();

    for i in 0..array.len() {
        let raw = unsafe { core_foundation::array::CFArray::get_value(&array, i) };
        let dict = unsafe {
            core_foundation::dictionary::CFDictionary::wrap_under_get_rule(
                raw as CFDictionaryRef,
            )
        };

        use core_graphics::window::{
            kCGWindowLayer, kCGWindowName, kCGWindowNumber, kCGWindowOwnerName,
            kCGWindowOwnerPID,
        };
        let id = cf_dict_get_i64_key(&dict, unsafe { &kCGWindowNumber }).unwrap_or(0) as u32;
        let pid = cf_dict_get_i64_key(&dict, unsafe { &kCGWindowOwnerPID }).unwrap_or(0) as i32;
        let layer = cf_dict_get_i64_key(&dict, unsafe { &kCGWindowLayer }).unwrap_or(-1) as i32;
        let owner_name = cf_dict_get_string_key(&dict, unsafe { &kCGWindowOwnerName }).unwrap_or_default();
        let window_name = cf_dict_get_string_key(&dict, unsafe { &kCGWindowName }).unwrap_or_default();

        windows.push(RawWindow {
            id,
            pid,
            layer,
            owner_name,
            window_name,
        });
    }

    Ok(windows)
}

fn cf_dict_get_i64_key(
    dict: &core_foundation::dictionary::CFDictionary,
    key: &CFString,
) -> Option<i64> {
    dict.find(key.as_CFTypeRef())
        .and_then(|val| {
            let num = unsafe { CFNumber::wrap_under_get_rule(*val as *const _) };
            num.to_i64()
        })
}

fn cf_dict_get_string_key(
    dict: &core_foundation::dictionary::CFDictionary,
    key: &CFString,
) -> Option<String> {
    dict.find(key.as_CFTypeRef())
        .map(|val| {
            let s = unsafe { CFString::wrap_under_get_rule(*val as *const _) };
            s.to_string()
        })
}

fn get_parent_pid(pid: i32) -> i32 {
    use libc::{c_int, c_void, sysctl, CTL_KERN, KERN_PROC, KERN_PROC_PID};
    use std::mem;

    let mut mib: [c_int; 4] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid];
    let mut info: libc::kinfo_proc = unsafe { mem::zeroed() };
    let mut size = mem::size_of::<libc::kinfo_proc>();

    let ret = unsafe {
        sysctl(
            mib.as_mut_ptr(),
            4,
            &mut info as *mut _ as *mut c_void,
            &mut size,
            std::ptr::null_mut(),
            0,
        )
    };

    if ret == 0 && size > 0 {
        info.kp_eproc.e_ppid
    } else {
        0
    }
}

fn build_child_pid_map() -> HashMap<i32, Vec<i32>> {
    use libc::{c_int, c_void, sysctl, CTL_KERN, KERN_PROC, KERN_PROC_ALL};
    use std::mem;

    let mut mib: [c_int; 3] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL];
    let mut size: usize = 0;

    // First call: get buffer size
    let ret = unsafe { sysctl(mib.as_mut_ptr(), 3, std::ptr::null_mut(), &mut size, std::ptr::null_mut(), 0) };
    if ret != 0 || size == 0 {
        return HashMap::new();
    }

    let count = size / mem::size_of::<libc::kinfo_proc>();
    let mut buf: Vec<libc::kinfo_proc> = vec![unsafe { mem::zeroed() }; count];

    let ret = unsafe {
        sysctl(
            mib.as_mut_ptr(),
            3,
            buf.as_mut_ptr() as *mut c_void,
            &mut size,
            std::ptr::null_mut(),
            0,
        )
    };

    if ret != 0 {
        return HashMap::new();
    }

    let actual_count = size / mem::size_of::<libc::kinfo_proc>();
    let mut map: HashMap<i32, Vec<i32>> = HashMap::new();

    for i in 0..actual_count {
        let proc_info = &buf[i];
        let pid = proc_info.kp_proc.p_pid;
        let ppid = proc_info.kp_eproc.e_ppid;
        if ppid != pid && pid > 0 {
            map.entry(ppid).or_default().push(pid);
        }
    }

    map
}

#[cfg(not(target_os = "macos"))]
pub fn scan_windows() -> Result<Vec<WindowInfo>, TapirError> {
    Ok(vec![])
}
```

- [ ] **Step 2: Add to core/mod.rs**

Add: `pub mod window_scanner;`

- [ ] **Step 3: Verify compilation**

Run: `cd /Users/joejiang/Desktop/tapir/src-tauri && cargo check`

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/core/
git commit -m "feat: add window scanner with process tree building via sysctl"
```

---

## Task 7: Rust Core — Key Event Sender

**Files:**
- Create: `src-tauri/src/core/key_sender.rs`
- Modify: `src-tauri/src/core/mod.rs`

- [ ] **Step 1: Create core/key_sender.rs**

```rust
use crate::models::TapirError;
use std::thread;
use std::time::Duration;

#[cfg(target_os = "macos")]
mod macos {
    use super::*;
    use core_graphics::event::{CGEvent, CGEventFlags, CGEventTapLocation, EventField};
    use core_graphics::event_source::{CGEventSource, CGEventSourceStateID};

    // Manual FFI for functions not in the crate
    extern "C" {
        fn CGEventPost(tap: u32, event: core_graphics::sys::CGEventRef);
        fn CGEventKeyboardSetUnicodeString(
            event: core_graphics::sys::CGEventRef,
            length: u64,
            string: *const u16,
        );
    }

    const HID_EVENT_TAP: u32 = 0; // kCGHIDEventTap

    fn create_source() -> Result<CGEventSource, TapirError> {
        CGEventSource::new(CGEventSourceStateID::HIDSystemState)
            .map_err(|_| TapirError::EventCreationFailed {
                message: "Failed to create CGEventSource".into(),
            })
    }

    fn post_event(event: &CGEvent) {
        unsafe {
            CGEventPost(HID_EVENT_TAP, event.as_ptr());
        }
    }

    fn build_flags(modifiers: &[String]) -> CGEventFlags {
        let mut flags = CGEventFlags::empty();
        for m in modifiers {
            match m.as_str() {
                "command" => flags |= CGEventFlags::CGEventFlagCommand,
                "shift" => flags |= CGEventFlags::CGEventFlagShift,
                "option" | "alt" => flags |= CGEventFlags::CGEventFlagAlternate,
                "control" => flags |= CGEventFlags::CGEventFlagControl,
                _ => {}
            }
        }
        flags
    }

    fn post_single_key(
        source: &CGEventSource,
        key_code: u16,
        flags: CGEventFlags,
    ) -> Result<(), TapirError> {
        let key_down = CGEvent::new_keyboard_event(source.clone(), key_code, true)
            .map_err(|_| TapirError::EventCreationFailed {
                message: format!("Failed to create keyDown for code {key_code}"),
            })?;
        let key_up = CGEvent::new_keyboard_event(source.clone(), key_code, false)
            .map_err(|_| TapirError::EventCreationFailed {
                message: format!("Failed to create keyUp for code {key_code}"),
            })?;

        key_down.set_flags(flags);
        key_up.set_flags(flags);

        post_event(&key_down);
        thread::sleep(Duration::from_millis(10));
        post_event(&key_up);

        Ok(())
    }

    /// Activate a target window by PID so it becomes frontmost.
    pub fn activate_window(pid: i32) -> Result<(), TapirError> {
        use objc2_app_kit::{NSApplicationActivationOptions, NSRunningApplication, NSWorkspace};

        unsafe {
            let workspace = NSWorkspace::sharedWorkspace();
            let running_apps = workspace.runningApplications();

            for app in running_apps.iter() {
                if app.processIdentifier() == pid {
                    let _ = app.activateWithOptions(
                        NSApplicationActivationOptions::ActivateIgnoringOtherApps,
                    );
                    thread::sleep(Duration::from_millis(50));
                    return Ok(());
                }
            }
        }
        Err(TapirError::InvalidTarget { pid })
    }

    pub fn send_key(key_code: u16, modifiers: Vec<String>) -> Result<(), TapirError> {
        let source = create_source()?;
        let flags = build_flags(&modifiers);
        post_single_key(&source, key_code, flags)
    }

    pub fn send_text(text: &str, append_enter: bool) -> Result<(), TapirError> {
        let source = create_source()?;

        for ch in text.chars() {
            let mut utf16_buf: [u16; 2] = [0; 2];
            let encoded = ch.encode_utf16(&mut utf16_buf);

            let key_down = CGEvent::new_keyboard_event(source.clone(), 0, true)
                .map_err(|_| TapirError::EventCreationFailed {
                    message: "Failed to create text keyDown".into(),
                })?;
            let key_up = CGEvent::new_keyboard_event(source.clone(), 0, false)
                .map_err(|_| TapirError::EventCreationFailed {
                    message: "Failed to create text keyUp".into(),
                })?;

            unsafe {
                CGEventKeyboardSetUnicodeString(
                    key_down.as_ptr(),
                    encoded.len() as u64,
                    encoded.as_ptr(),
                );
                CGEventKeyboardSetUnicodeString(
                    key_up.as_ptr(),
                    encoded.len() as u64,
                    encoded.as_ptr(),
                );
            }

            post_event(&key_down);
            thread::sleep(Duration::from_millis(5));
            post_event(&key_up);
            thread::sleep(Duration::from_millis(8));
        }

        if append_enter {
            thread::sleep(Duration::from_millis(10));
            post_single_key(&source, 36, CGEventFlags::empty())?; // Return key
        }

        Ok(())
    }

    pub fn send_combo(
        text: &str,
        prefix_key_code: Option<u16>,
        suffix_key_code: Option<u16>,
    ) -> Result<(), TapirError> {
        let source = create_source()?;

        // Prefix key
        if let Some(prefix) = prefix_key_code {
            post_single_key(&source, prefix, CGEventFlags::empty())?;
            thread::sleep(Duration::from_millis(30));
        }

        // Type text
        for ch in text.chars() {
            let mut utf16_buf: [u16; 2] = [0; 2];
            let encoded = ch.encode_utf16(&mut utf16_buf);

            let key_down = CGEvent::new_keyboard_event(source.clone(), 0, true)
                .map_err(|_| TapirError::EventCreationFailed {
                    message: "Failed to create combo text keyDown".into(),
                })?;
            let key_up = CGEvent::new_keyboard_event(source.clone(), 0, false)
                .map_err(|_| TapirError::EventCreationFailed {
                    message: "Failed to create combo text keyUp".into(),
                })?;

            unsafe {
                CGEventKeyboardSetUnicodeString(
                    key_down.as_ptr(),
                    encoded.len() as u64,
                    encoded.as_ptr(),
                );
                CGEventKeyboardSetUnicodeString(
                    key_up.as_ptr(),
                    encoded.len() as u64,
                    encoded.as_ptr(),
                );
            }

            post_event(&key_down);
            thread::sleep(Duration::from_millis(5));
            post_event(&key_up);
            thread::sleep(Duration::from_millis(8));
        }

        // Suffix key
        if let Some(suffix) = suffix_key_code {
            thread::sleep(Duration::from_millis(20));
            post_single_key(&source, suffix, CGEventFlags::empty())?;
        }

        Ok(())
    }
}

#[cfg(not(target_os = "macos"))]
mod macos {
    use crate::models::TapirError;
    pub fn activate_window(_pid: i32) -> Result<(), TapirError> { Ok(()) }
    pub fn send_key(_key_code: u16, _modifiers: Vec<String>) -> Result<(), TapirError> { Ok(()) }
    pub fn send_text(_text: &str, _append_enter: bool) -> Result<(), TapirError> { Ok(()) }
    pub fn send_combo(_text: &str, _prefix: Option<u16>, _suffix: Option<u16>) -> Result<(), TapirError> { Ok(()) }
}

pub use macos::*;
```

- [ ] **Step 2: Add to core/mod.rs**

Add: `pub mod key_sender;`

- [ ] **Step 3: Verify compilation**

Run: `cd /Users/joejiang/Desktop/tapir/src-tauri && cargo check`

Note: The `activate_window` function may need adjustment based on actual objc2 API. Fix any compilation issues with the objc2 bindings.

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/core/
git commit -m "feat: add key event sender (CGEvent post to HID, text, combo)"
```

---

## Task 8: Rust State — Sender Manager

**Files:**
- Create: `src-tauri/src/state/mod.rs`
- Create: `src-tauri/src/state/sender_state.rs`
- Modify: `src-tauri/src/lib.rs`

- [ ] **Step 1: Write failing test for state machine transitions**

File: `src-tauri/tests/sender_state_test.rs`

```rust
use tapir::models::log_entry::SendingState;

#[test]
fn test_sending_state_serialization() {
    let idle = SendingState::Idle;
    let json = serde_json::to_string(&idle).unwrap();
    assert_eq!(json, r#""idle""#);

    let running = SendingState::Running;
    let json = serde_json::to_string(&running).unwrap();
    assert_eq!(json, r#""running""#);

    let paused = SendingState::Paused;
    let json = serde_json::to_string(&paused).unwrap();
    assert_eq!(json, r#""paused""#);
}
```

- [ ] **Step 2: Run test to verify serialization**

Run: `cd /Users/joejiang/Desktop/tapir/src-tauri && cargo test --test sender_state_test`

Expected: PASS

- [ ] **Step 3: Create state/mod.rs**

```rust
pub mod sender_state;
pub use sender_state::SenderManager;
```

- [ ] **Step 4: Create state/sender_state.rs**

```rust
use crate::core::{key_codes, key_sender, process};
use crate::models::{KeyStep, LogEntry, StepMode, TapirError, WindowInfo};
use crate::models::log_entry::{SenderStatus, SendingState};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use tauri::{AppHandle, Emitter};
use tokio::sync::Notify;
use tokio_util::sync::CancellationToken;

pub struct SenderManager {
    state: Arc<Mutex<SendingState>>,
    send_count: Arc<AtomicU64>,
    cycles_completed: Arc<AtomicU64>,
    cancel_token: Option<CancellationToken>,
    pause_notify: Arc<Notify>,
    app_handle: AppHandle,
}

impl SenderManager {
    pub fn new(app_handle: AppHandle) -> Self {
        Self {
            state: Arc::new(Mutex::new(SendingState::Idle)),
            send_count: Arc::new(AtomicU64::new(0)),
            cycles_completed: Arc::new(AtomicU64::new(0)),
            cancel_token: None,
            pause_notify: Arc::new(Notify::new()),
            app_handle,
        }
    }

    pub fn status(&self) -> SenderStatus {
        SenderStatus {
            state: self.state.lock().unwrap().clone(),
            send_count: self.send_count.load(Ordering::Relaxed),
            cycles_completed: self.cycles_completed.load(Ordering::Relaxed),
        }
    }

    pub fn start(
        &mut self,
        targets: Vec<WindowInfo>,
        steps: Vec<KeyStep>,
        interval_ms: u64,
        repeat_count: Option<u64>,
    ) -> Result<(), TapirError> {
        if steps.is_empty() {
            return Err(TapirError::NoStepsConfigured);
        }
        if targets.is_empty() {
            return Err(TapirError::InvalidTarget { pid: 0 });
        }

        // Reset state
        self.send_count.store(0, Ordering::Relaxed);
        self.cycles_completed.store(0, Ordering::Relaxed);
        *self.state.lock().unwrap() = SendingState::Running;

        let token = CancellationToken::new();
        self.cancel_token = Some(token.clone());

        self.emit_state_change();
        self.emit_log("state", &format!(
            "Started: {} target(s), {} step(s), {}ms interval, {}",
            targets.len(),
            steps.len(),
            interval_ms,
            match repeat_count {
                Some(n) => format!("{n} cycles"),
                None => "infinite loop".into(),
            }
        ));

        // Shared target list — validation loop removes dead targets
        let shared_targets = Arc::new(Mutex::new(targets.clone()));

        // Spawn send loop
        let send_state = self.state.clone();
        let send_count = self.send_count.clone();
        let cycles = self.cycles_completed.clone();
        let pause = self.pause_notify.clone();
        let send_token = token.clone();
        let app = self.app_handle.clone();
        let send_targets = shared_targets.clone();
        let send_steps = steps.clone();

        tokio::spawn(async move {
            let mut step_index: usize = 0;

            loop {
                if send_token.is_cancelled() {
                    break;
                }

                // Check if paused
                {
                    let state = send_state.lock().unwrap().clone();
                    if state == SendingState::Paused {
                        drop(state);
                        pause.notified().await;
                        continue;
                    }
                }

                // Send current step to all live targets
                let step = &send_steps[step_index];
                let current_targets = send_targets.lock().unwrap().clone();
                if current_targets.is_empty() {
                    *send_state.lock().unwrap() = SendingState::Paused;
                    let _ = app.emit("tapir://state-change", SendingState::Paused);
                    let _ = app.emit("tapir://log", LogEntry::new("warn", "All targets lost — paused"));
                    pause.notified().await;
                    continue;
                }
                for target in &current_targets {
                    if send_token.is_cancelled() {
                        return;
                    }

                    // Activate target window
                    if let Err(e) = key_sender::activate_window(target.pid) {
                        let _ = app.emit("tapir://log", LogEntry::new("warn", &format!("Failed to activate PID {}: {e}", target.pid)));
                        continue;
                    }

                    // Send the step
                    let result = send_step(step);
                    if let Err(e) = &result {
                        let _ = app.emit("tapir://log", LogEntry::new("error", &format!("Send error: {e}")));
                    } else {
                        send_count.fetch_add(1, Ordering::Relaxed);
                        let _ = app.emit("tapir://log", LogEntry::new("key", &format!(
                            "Sent {} to {}",
                            step_display_name(step),
                            target.owner_name
                        )));
                    }
                }

                // Advance step
                step_index = (step_index + 1) % send_steps.len();
                if step_index == 0 {
                    let c = cycles.fetch_add(1, Ordering::Relaxed) + 1;
                    if let Some(max) = repeat_count {
                        if c >= max {
                            *send_state.lock().unwrap() = SendingState::Idle;
                            let _ = app.emit("tapir://state-change", SendingState::Idle);
                            let _ = app.emit("tapir://log", LogEntry::new("state", &format!("Completed {c} cycle(s)")));
                            return;
                        }
                    }
                }

                // Wait interval
                tokio::select! {
                    _ = tokio::time::sleep(std::time::Duration::from_millis(interval_ms)) => {},
                    _ = send_token.cancelled() => { return; },
                }
            }
        });

        // Spawn validation loop
        let val_token = token.clone();
        let val_state = self.state.clone();
        let val_app = self.app_handle.clone();
        let val_targets = shared_targets.clone();

        tokio::spawn(async move {
            loop {
                tokio::select! {
                    _ = tokio::time::sleep(std::time::Duration::from_secs(3)) => {},
                    _ = val_token.cancelled() => { return; },
                }

                let state = val_state.lock().unwrap().clone();
                if state == SendingState::Idle {
                    return;
                }

                let mut dead_pids = Vec::new();
                {
                    let targets = val_targets.lock().unwrap();
                    for target in targets.iter() {
                        if !process::is_process_alive(target.pid) {
                            dead_pids.push(target.pid);
                        }
                    }
                }

                if !dead_pids.is_empty() {
                    // Remove dead targets from the shared list
                    {
                        let mut targets = val_targets.lock().unwrap();
                        targets.retain(|t| !dead_pids.contains(&t.pid));
                    }
                    let _ = val_app.emit("tapir://targets-invalidated", &dead_pids);
                    let _ = val_app.emit("tapir://log", LogEntry::new("warn", &format!(
                        "{} target(s) no longer available",
                        dead_pids.len()
                    )));
                }
            }
        });

        Ok(())
    }

    pub fn pause(&mut self) {
        let mut state = self.state.lock().unwrap();
        if *state == SendingState::Running {
            *state = SendingState::Paused;
            self.emit_state_change();
            self.emit_log("state", "Paused");
        }
    }

    pub fn resume(&mut self) {
        let mut state = self.state.lock().unwrap();
        if *state == SendingState::Paused {
            *state = SendingState::Running;
            drop(state);
            self.pause_notify.notify_one();
            self.emit_state_change();
            self.emit_log("state", "Resumed");
        }
    }

    pub fn stop(&mut self) {
        if let Some(token) = self.cancel_token.take() {
            token.cancel();
        }
        let count = self.send_count.load(Ordering::Relaxed);
        let cycles = self.cycles_completed.load(Ordering::Relaxed);
        *self.state.lock().unwrap() = SendingState::Idle;
        self.emit_state_change();
        self.emit_log("state", &format!("Stopped. Sent {count} event(s), {cycles} cycle(s)"));
    }

    fn emit_state_change(&self) {
        let state = self.state.lock().unwrap().clone();
        let _ = self.app_handle.emit("tapir://state-change", state);
    }

    fn emit_log(&self, entry_type: &str, message: &str) {
        let _ = self.app_handle.emit("tapir://log", LogEntry::new(entry_type, message));
    }
}

fn send_step(step: &KeyStep) -> Result<(), TapirError> {
    match step.mode {
        StepMode::Key => {
            let code = key_codes::lookup(&step.key_name)
                .ok_or_else(|| TapirError::SendFailed {
                    message: format!("Unknown key: {}", step.key_name),
                })?;
            let mut modifiers = Vec::new();
            if step.with_command { modifiers.push("command".to_string()); }
            if step.with_shift { modifiers.push("shift".to_string()); }
            if step.with_option { modifiers.push("option".to_string()); }
            if step.with_control { modifiers.push("control".to_string()); }
            key_sender::send_key(code, modifiers)
        }
        StepMode::Text => {
            key_sender::send_text(&step.text_content, step.append_enter)
        }
        StepMode::Combo => {
            let prefix = if step.has_prefix_key {
                key_codes::lookup(&step.prefix_key_name)
            } else {
                None
            };
            let suffix = if step.has_suffix_key {
                key_codes::lookup(&step.suffix_key_name)
            } else {
                None
            };
            key_sender::send_combo(&step.text_content, prefix, suffix)
        }
    }
}

fn step_display_name(step: &KeyStep) -> String {
    match step.mode {
        StepMode::Key => {
            let mut parts = Vec::new();
            if step.with_command { parts.push("Cmd"); }
            if step.with_shift { parts.push("Shift"); }
            if step.with_option { parts.push("Opt"); }
            if step.with_control { parts.push("Ctrl"); }
            parts.push(&step.key_name);
            parts.join("+")
        }
        StepMode::Text => {
            let preview: String = step.text_content.chars().take(20).collect();
            format!("\"{}\"", preview)
        }
        StepMode::Combo => "Combo".to_string(),
    }
}
```

- [ ] **Step 5: Update lib.rs**

```rust
pub mod core;
pub mod models;
pub mod state;
```

- [ ] **Step 6: Verify compilation**

Run: `cd /Users/joejiang/Desktop/tapir/src-tauri && cargo check`

- [ ] **Step 7: Commit**

```bash
git add src-tauri/src/state/ src-tauri/src/lib.rs src-tauri/tests/
git commit -m "feat: add SenderManager state machine with send/validation loops"
```

---

## Task 9: Tauri Commands (IPC Layer)

**Files:**
- Create: `src-tauri/src/commands/mod.rs`
- Create: `src-tauri/src/commands/accessibility.rs`
- Create: `src-tauri/src/commands/window.rs`
- Create: `src-tauri/src/commands/sender.rs`
- Modify: `src-tauri/src/main.rs`

- [ ] **Step 1: Create commands/mod.rs**

```rust
pub mod accessibility;
pub mod sender;
pub mod window;
```

- [ ] **Step 2: Create commands/accessibility.rs**

```rust
use crate::core::accessibility;

#[tauri::command]
pub fn check_permission() -> bool {
    accessibility::is_trusted()
}

#[tauri::command]
pub fn request_permission() -> bool {
    accessibility::request_with_prompt()
}

#[tauri::command]
pub fn open_settings() {
    accessibility::open_settings();
}
```

- [ ] **Step 3: Create commands/window.rs**

```rust
use crate::core::{process, window_scanner};
use crate::models::{TapirError, WindowInfo};

#[tauri::command]
pub fn scan_windows() -> Result<Vec<WindowInfo>, TapirError> {
    window_scanner::scan_windows()
}

#[tauri::command]
pub fn validate_windows(windows: Vec<(u32, i32)>) -> Vec<i32> {
    windows
        .iter()
        .filter(|(wid, pid)| process::is_window_valid(*wid, *pid))
        .map(|(_, pid)| *pid)
        .collect()
}
```

- [ ] **Step 4: Create commands/sender.rs**

```rust
use crate::models::log_entry::SenderStatus;
use crate::models::{KeyStep, TapirError, WindowInfo};
use crate::state::SenderManager;
use std::sync::Mutex;
use tauri::State;

pub struct SenderState(pub Mutex<Option<SenderManager>>);

#[tauri::command]
pub fn start_sending(
    state: State<'_, SenderState>,
    app_handle: tauri::AppHandle,
    targets: Vec<WindowInfo>,
    steps: Vec<KeyStep>,
    interval_ms: u64,
    repeat_count: Option<u64>,
) -> Result<(), TapirError> {
    let mut lock = state.0.lock().unwrap();
    let manager = lock.get_or_insert_with(|| SenderManager::new(app_handle.clone()));
    manager.start(targets, steps, interval_ms, repeat_count)
}

#[tauri::command]
pub fn pause_sending(state: State<'_, SenderState>) {
    if let Some(manager) = state.0.lock().unwrap().as_mut() {
        manager.pause();
    }
}

#[tauri::command]
pub fn resume_sending(state: State<'_, SenderState>) {
    if let Some(manager) = state.0.lock().unwrap().as_mut() {
        manager.resume();
    }
}

#[tauri::command]
pub fn stop_sending(state: State<'_, SenderState>) {
    if let Some(manager) = state.0.lock().unwrap().as_mut() {
        manager.stop();
    }
}

#[tauri::command]
pub fn get_sender_status(state: State<'_, SenderState>) -> SenderStatus {
    state
        .0
        .lock()
        .unwrap()
        .as_ref()
        .map(|m| m.status())
        .unwrap_or(SenderStatus {
            state: crate::models::log_entry::SendingState::Idle,
            send_count: 0,
            cycles_completed: 0,
        })
}
```

- [ ] **Step 5: Update main.rs with all commands and state**

```rust
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod core;
mod models;
mod state;

use commands::sender::SenderState;
use std::sync::Mutex;

fn main() {
    tauri::Builder::default()
        .manage(SenderState(Mutex::new(None)))
        .invoke_handler(tauri::generate_handler![
            commands::accessibility::check_permission,
            commands::accessibility::request_permission,
            commands::accessibility::open_settings,
            commands::window::scan_windows,
            commands::window::validate_windows,
            commands::sender::start_sending,
            commands::sender::pause_sending,
            commands::sender::resume_sending,
            commands::sender::stop_sending,
            commands::sender::get_sender_status,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

- [ ] **Step 6: Verify compilation**

Run: `cd /Users/joejiang/Desktop/tapir/src-tauri && cargo check`

- [ ] **Step 7: Commit**

```bash
git add src-tauri/src/commands/ src-tauri/src/main.rs
git commit -m "feat: wire up Tauri IPC commands for all core operations"
```

---

## Task 10: Frontend — TypeScript Types & Theme

**Files:**
- Create: `src/types/models.ts`
- Create: `src/lib/keycodes.ts`
- Create: `src/theme/flexoki.ts`
- Modify: `src/theme/global.css`

- [ ] **Step 1: Create src/types/models.ts**

```typescript
export type StepMode = 'key' | 'text' | 'combo'

export interface KeyStep {
  id: string
  mode: StepMode
  keyName: string
  withCommand: boolean
  withShift: boolean
  withOption: boolean
  withControl: boolean
  textContent: string
  appendEnter: boolean
  hasPrefixKey: boolean
  prefixKeyName: string
  hasSuffixKey: boolean
  suffixKeyName: string
}

export interface WindowInfo {
  id: number
  ownerName: string
  windowName: string
  pid: number
  parentPid: number
  parentWindowedPid: number
  isChildProcess: boolean
  childProcessCount: number
  subWindowCount: number
  isOnScreen: boolean
}

export interface LogEntry {
  id: string
  timestamp: string
  entryType: string
  message: string
}

export type SendingState = 'idle' | 'running' | 'paused'

export interface SenderStatus {
  state: SendingState
  sendCount: number
  cyclesCompleted: number
}

export type TapirError =
  | { type: 'noPermission' }
  | { type: 'eventCreationFailed'; message: string }
  | { type: 'invalidTarget'; pid: number }
  | { type: 'noStepsConfigured' }
  | { type: 'windowScanFailed'; message: string }
  | { type: 'sendFailed'; message: string }

export function createKeyStep(mode: StepMode = 'key'): KeyStep {
  return {
    id: crypto.randomUUID(),
    mode,
    keyName: 'Return',
    withCommand: false,
    withShift: false,
    withOption: false,
    withControl: false,
    textContent: '',
    appendEnter: true,
    hasPrefixKey: false,
    prefixKeyName: '',
    hasSuffixKey: true,
    suffixKeyName: 'Return',
  }
}
```

- [ ] **Step 2: Create src/lib/keycodes.ts**

```typescript
export const letterKeys = [
  'A','B','C','D','E','F','G','H','I','J','K','L','M',
  'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
]

export const numberKeys = ['0','1','2','3','4','5','6','7','8','9']

export const specialKeys = [
  'Return','Tab','Space','Delete','Escape','ForwardDelete',
  '=','-',']','[',"'",';','\\',',','/','.','\`',
]

export const functionKeys = [
  'F1','F2','F3','F4','F5','F6','F7','F8','F9','F10','F11','F12',
]

export const arrowKeys = ['Left','Right','Down','Up']

export const navigationKeys = ['Home','End','PageUp','PageDown']

export const allKeyNames = [
  ...letterKeys, ...numberKeys, ...specialKeys,
  ...functionKeys, ...arrowKeys, ...navigationKeys,
]
```

- [ ] **Step 3: Create src/theme/flexoki.ts**

```typescript
export const flexoki = {
  bg: {
    primary:   '#FFFCF0',
    secondary: '#F2F0E5',
    tertiary:  '#E6E4D9',
    active:    '#DAD8CE',
  },
  text: {
    primary:   '#100F0F',
    secondary: '#6F6E69',
    dim:       '#878580',
    muted:     '#B7B5AC',
  },
  border:      '#E6E4D9',
  borderLight: '#F2F0E5',
  red:         '#AF3029',
  orange:      '#BC5215',
  yellow:      '#AD8301',
  green:       '#66800B',
  cyan:        '#24837B',
  blue:        '#205EA6',
  purple:      '#5E409D',
  magenta:     '#A02F6F',
  redLight:    '#D14D41',
  orangeLight: '#DA702C',
  yellowLight: '#D0A215',
  greenLight:  '#879A39',
  cyanLight:   '#3AA99F',
  blueLight:   '#4385BE',
  purpleLight: '#8B7EC8',
  magentaLight:'#CE5D97',
} as const
```

- [ ] **Step 4: Write full global.css with Flexoki Light tokens**

File: `src/theme/global.css`

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
  --font-display: 24px;
  --font-title: 14px;
  --font-body: 12px;
  --font-caption: 10px;
  --font-micro: 9px;

  --radius-sm: 4px;
  --radius-md: 6px;
  --radius-lg: 8px;
  --shadow-panel:  0 1px 3px rgba(16,15,15,0.08);
  --shadow-button: 0 1px 2px rgba(16,15,15,0.12);
}

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: var(--font-mono);
  font-size: var(--font-body);
  background: var(--bg-primary);
  color: var(--text-primary);
  overflow: hidden;
  user-select: none;
  -webkit-user-select: none;
}

::-webkit-scrollbar {
  width: 6px;
}

::-webkit-scrollbar-track {
  background: transparent;
}

::-webkit-scrollbar-thumb {
  background: var(--border);
  border-radius: 3px;
}

::-webkit-scrollbar-thumb:hover {
  background: var(--text-muted);
}
```

- [ ] **Step 5: Commit**

```bash
git add src/types/ src/lib/ src/theme/
git commit -m "feat: add TypeScript types, keycode lists, and Flexoki Light theme"
```

---

## Task 11: Frontend — Zustand State Store

**Files:**
- Create: `src/hooks/useAppState.ts`
- Create: `src/hooks/useTauriCommand.ts`

- [ ] **Step 1: Install Zustand**

Run: `cd /Users/joejiang/Desktop/tapir && npm install zustand`

- [ ] **Step 2: Create src/hooks/useAppState.ts**

```typescript
import { create } from 'zustand'
import { KeyStep, LogEntry, SendingState, WindowInfo, createKeyStep } from '../types/models'

interface AppState {
  // Workflow
  currentStep: 0 | 1 | 2 | 3
  setCurrentStep: (step: 0 | 1 | 2 | 3) => void

  // Permission
  hasPermission: boolean
  setHasPermission: (v: boolean) => void

  // Windows
  scannedWindows: WindowInfo[]
  setScannedWindows: (w: WindowInfo[]) => void
  selectedWindows: WindowInfo[]
  toggleWindow: (w: WindowInfo) => void
  deselectWindow: (id: number) => void
  clearSelection: () => void
  searchQuery: string
  setSearchQuery: (q: string) => void

  // Key steps
  keySteps: KeyStep[]
  addKeyStep: (mode: KeyStep['mode']) => void
  removeKeyStep: (id: string) => void
  updateKeyStep: (id: string, updates: Partial<KeyStep>) => void
  duplicateKeyStep: (id: string) => void
  reorderKeySteps: (from: number, to: number) => void
  intervalMs: number
  setIntervalMs: (ms: number) => void

  // Sending
  sendingState: SendingState
  setSendingState: (s: SendingState) => void
  sendCount: number
  setSendCount: (n: number) => void
  cyclesCompleted: number
  setCyclesCompleted: (n: number) => void
  repeatCount: number | null
  setRepeatCount: (n: number | null) => void

  // Log
  logEntries: LogEntry[]
  addLogEntry: (entry: LogEntry) => void
  clearLog: () => void
  autoScroll: boolean
  setAutoScroll: (v: boolean) => void

  // Toast
  toast: { message: string; color: string } | null
  showToast: (message: string, color?: string) => void

  // Derived
  canProceedToTarget: () => boolean
  canProceedToKeys: () => boolean
  canProceedToControl: () => boolean
  isEditable: () => boolean
}

export const useAppState = create<AppState>((set, get) => ({
  currentStep: 0,
  setCurrentStep: (step) => set({ currentStep: step }),

  hasPermission: false,
  setHasPermission: (v) => set({ hasPermission: v }),

  scannedWindows: [],
  setScannedWindows: (w) => set({ scannedWindows: w }),
  selectedWindows: [],
  toggleWindow: (w) => set((s) => {
    const exists = s.selectedWindows.find((sw) => sw.id === w.id)
    return {
      selectedWindows: exists
        ? s.selectedWindows.filter((sw) => sw.id !== w.id)
        : [...s.selectedWindows, w],
    }
  }),
  deselectWindow: (id) => set((s) => ({
    selectedWindows: s.selectedWindows.filter((w) => w.id !== id),
  })),
  clearSelection: () => set({ selectedWindows: [] }),
  deselectByPid: (pid: number) => set((s) => ({
    selectedWindows: s.selectedWindows.filter((w) => w.pid !== pid),
  })),
  searchQuery: '',
  setSearchQuery: (q) => set({ searchQuery: q }),

  keySteps: [],
  addKeyStep: (mode) => set((s) => ({
    keySteps: [...s.keySteps, createKeyStep(mode)],
  })),
  removeKeyStep: (id) => set((s) => ({
    keySteps: s.keySteps.filter((k) => k.id !== id),
  })),
  updateKeyStep: (id, updates) => set((s) => ({
    keySteps: s.keySteps.map((k) => (k.id === id ? { ...k, ...updates } : k)),
  })),
  duplicateKeyStep: (id) => set((s) => {
    const idx = s.keySteps.findIndex((k) => k.id === id)
    if (idx === -1) return s
    const copy = { ...s.keySteps[idx], id: crypto.randomUUID() }
    const next = [...s.keySteps]
    next.splice(idx + 1, 0, copy)
    return { keySteps: next }
  }),
  reorderKeySteps: (from, to) => set((s) => {
    const next = [...s.keySteps]
    const [item] = next.splice(from, 1)
    next.splice(to, 0, item)
    return { keySteps: next }
  }),
  intervalMs: 500,
  setIntervalMs: (ms) => set({ intervalMs: ms }),

  sendingState: 'idle',
  setSendingState: (s) => set({ sendingState: s }),
  sendCount: 0,
  setSendCount: (n) => set({ sendCount: n }),
  cyclesCompleted: 0,
  setCyclesCompleted: (n) => set({ cyclesCompleted: n }),
  repeatCount: null,
  setRepeatCount: (n) => set({ repeatCount: n }),

  logEntries: [],
  addLogEntry: (entry) => set((s) => ({
    logEntries: [...s.logEntries.slice(-499), entry],
  })),
  clearLog: () => set({ logEntries: [] }),
  autoScroll: true,
  setAutoScroll: (v) => set({ autoScroll: v }),

  toast: null,
  showToast: (message, color = 'var(--cyan)') => {
    set({ toast: { message, color } })
    setTimeout(() => set({ toast: null }), 1800)
  },

  canProceedToTarget: () => get().hasPermission,
  canProceedToKeys: () => get().selectedWindows.length > 0,
  canProceedToControl: () => get().keySteps.length > 0,
  isEditable: () => get().sendingState === 'idle',

  // Reset all state, return to permission step
  reset: () => set({
    currentStep: 0,
    scannedWindows: [],
    selectedWindows: [],
    searchQuery: '',
    keySteps: [],
    intervalMs: 500,
    sendingState: 'idle',
    sendCount: 0,
    cyclesCompleted: 0,
    repeatCount: null,
    logEntries: [],
    toast: null,
  }),
}))
```

- [ ] **Step 3: Create src/hooks/useTauriCommand.ts**

```typescript
import { invoke } from '@tauri-apps/api/core'
import { listen, UnlistenFn } from '@tauri-apps/api/event'
import { useEffect } from 'react'
import { useAppState } from './useAppState'
import type { KeyStep, LogEntry, SenderStatus, SendingState, WindowInfo } from '../types/models'

export function useTauriEvents() {
  const addLogEntry = useAppState((s) => s.addLogEntry)
  const setSendingState = useAppState((s) => s.setSendingState)
  const deselectWindow = useAppState((s) => s.deselectWindow)
  const showToast = useAppState((s) => s.showToast)

  useEffect(() => {
    const unlisteners: Promise<UnlistenFn>[] = []

    unlisteners.push(
      listen<LogEntry>('tapir://log', (e) => {
        addLogEntry(e.payload)
      })
    )

    unlisteners.push(
      listen<SendingState>('tapir://state-change', (e) => {
        setSendingState(e.payload)
      })
    )

    unlisteners.push(
      listen<number[]>('tapir://targets-invalidated', (e) => {
        const deselectByPid = useAppState.getState().deselectByPid
        for (const pid of e.payload) {
          deselectByPid(pid)
        }
        showToast(`${e.payload.length} target(s) lost`, 'var(--orange)')
      })
    )

    return () => {
      unlisteners.forEach((p) => p.then((f) => f()))
    }
  }, [])
}

export const tauriCommands = {
  checkPermission: () => invoke<boolean>('check_permission'),
  requestPermission: () => invoke<boolean>('request_permission'),
  openSettings: () => invoke<void>('open_settings'),
  scanWindows: () => invoke<WindowInfo[]>('scan_windows'),
  validateWindows: (windows: [number, number][]) => invoke<number[]>('validate_windows', { windows }),
  startSending: (targets: WindowInfo[], steps: KeyStep[], intervalMs: number, repeatCount: number | null) =>
    invoke<void>('start_sending', { targets, steps, intervalMs, repeatCount }),
  pauseSending: () => invoke<void>('pause_sending'),
  resumeSending: () => invoke<void>('resume_sending'),
  stopSending: () => invoke<void>('stop_sending'),
  getSenderStatus: () => invoke<SenderStatus>('get_sender_status'),
}
```

- [ ] **Step 4: Commit**

```bash
git add src/hooks/ package.json package-lock.json
git commit -m "feat: add Zustand state store and Tauri IPC hooks"
```

---

## Task 12: Frontend — Pixel UI Components (Atoms)

**Files:**
- Create: `src/components/ui/PixelPanel.tsx`
- Create: `src/components/ui/PixelButton.tsx`
- Create: `src/components/ui/PixelBadge.tsx`
- Create: `src/components/ui/PixelToggle.tsx`
- Create: `src/components/ui/PixelInput.tsx`
- Create: `src/components/ui/PixelDropdown.tsx`
- Create: `src/components/ui/SegmentButton.tsx`
- Create: `src/components/ui/PixelDivider.tsx`
- Create: `src/components/ui/FlowLayout.tsx`
- Create: `src/components/ui/IntervalProgressBar.tsx`
- Create: `src/components/ui/RepeatModeStrip.tsx`
- Create: `src/components/ui/index.ts`

Each component follows the Flexoki Light pixel-art aesthetic from the spec. Implement each with CSS-in-JS using inline styles + CSS variables for consistency.

- [ ] **Step 1: Create all UI atom components**

Implement each component per the spec descriptions in Section 4 (UI Components). Key behaviors:

- **PixelPanel**: `bg-secondary`, 1px border, optional accent header, `shadow-panel`
- **PixelButton**: 3 variants (default/primary/danger), hover lift, press `translateY(1px)`, 120ms transitions
- **PixelBadge**: Capsule shape, 8% opacity bg of color, 35% opacity border
- **PixelToggle**: 14x14 checkbox, accent when active, 120ms slide, scale 0.85 on press
- **PixelInput**: Menlo 12px, `bg-primary`, bottom border, accent focus
- **PixelDropdown**: `bg-secondary`, accent border on focus, dropdown with hover highlight
- **SegmentButton**: Horizontal group, active segment = accent bg at 12% opacity
- **PixelDivider**: 1px `border` color, optional centered label
- **FlowLayout**: `display: flex; flex-wrap: wrap; gap: 4px`
- **IntervalProgressBar**: Segmented LED bar, CSS animation fills segments
- **RepeatModeStrip**: Infinite/N-repeat toggle + preset buttons (1/3/5/10/50/100)

- [ ] **Step 2: Create src/components/ui/index.ts barrel export**

```typescript
export { PixelPanel } from './PixelPanel'
export { PixelButton } from './PixelButton'
export { PixelBadge } from './PixelBadge'
export { PixelToggle } from './PixelToggle'
export { PixelInput } from './PixelInput'
export { PixelDropdown } from './PixelDropdown'
export { SegmentButton } from './SegmentButton'
export { PixelDivider } from './PixelDivider'
export { FlowLayout } from './FlowLayout'
export { IntervalProgressBar } from './IntervalProgressBar'
export { RepeatModeStrip } from './RepeatModeStrip'
```

- [ ] **Step 3: Verify frontend builds**

Run: `cd /Users/joejiang/Desktop/tapir && npm run build`

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add src/components/ui/
git commit -m "feat: add Flexoki Light pixel UI atom components"
```

---

## Task 13: Frontend — App Layout Shell

**Files:**
- Create: `src/components/TitleBar.tsx`
- Create: `src/components/Sidebar.tsx`
- Create: `src/components/StatusBar.tsx`
- Modify: `src/App.tsx`

- [ ] **Step 1: Create TitleBar.tsx**

Custom title bar (no native decorations). Contains:
- `data-tauri-drag-region` for window dragging
- App name "TAPIR" in display font
- PixelBadge for target count and key step count
- Version "v2.0"

- [ ] **Step 2: Create Sidebar.tsx**

120px wide left sidebar with:
- 4 step circles (0-3) with click handlers
- Active step highlighted with accent color
- Badge counts (target count on step 1, key count on step 2)
- Forward navigation gated by prerequisites
- Sequence mini-preview (FlowLayout chips of step names)
- Current sending state indicator at bottom

- [ ] **Step 3: Create StatusBar.tsx**

Fixed bottom bar showing:
- Permission status (green dot / red dot)
- Target label ("N target(s)")
- Send count
- Interval display
- Sending state

- [ ] **Step 4: Update App.tsx with layout**

```tsx
import { TitleBar } from './components/TitleBar'
import { Sidebar } from './components/Sidebar'
import { StatusBar } from './components/StatusBar'
import { SystemView } from './components/SystemView'
import { WindowSelector } from './components/WindowSelector'
import { KeyConfig } from './components/KeyConfig'
import { SendControl } from './components/SendControl'
import { useAppState } from './hooks/useAppState'
import { useTauriEvents } from './hooks/useTauriCommand'
import './theme/global.css'

const steps = [SystemView, WindowSelector, KeyConfig, SendControl]

export default function App() {
  useTauriEvents()
  const currentStep = useAppState((s) => s.currentStep)
  const toast = useAppState((s) => s.toast)
  const StepComponent = steps[currentStep]

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh' }}>
      <TitleBar />
      <div style={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
        <Sidebar />
        <main style={{ flex: 1, overflow: 'auto', padding: 16 }}>
          <StepComponent />
        </main>
      </div>
      <StatusBar />
      {toast && (
        <div style={{
          position: 'fixed', bottom: 40, left: '50%', transform: 'translateX(-50%)',
          background: 'var(--bg-tertiary)', border: `1px solid ${toast.color}`,
          padding: '6px 16px', borderRadius: 'var(--radius-md)',
          fontFamily: 'var(--font-mono)', fontSize: 'var(--font-caption)',
          color: toast.color, zIndex: 100,
        }}>
          {toast.message}
        </div>
      )}
    </div>
  )
}
```

Note: `SystemView`, `WindowSelector`, `KeyConfig`, `SendControl` will be created as stub components initially.

- [ ] **Step 5: Create StepNavBar component**

Create `src/components/StepNavBar.tsx` — bottom nav bar inside the main content area with:
- BACK button (disabled on step 0)
- NEXT button (disabled if prerequisites not met, hidden on step 3)
- RESET button (calls `reset()` from Zustand store, returns to step 0)
- Place this inside `<main>` below `<StepComponent />` in App.tsx

- [ ] **Step 6: Create stub page components**

Create minimal placeholder components for `SystemView.tsx`, `WindowSelector.tsx`, `KeyConfig.tsx`, `SendControl.tsx` — each rendering their step name. These will be fleshed out in subsequent tasks.

- [ ] **Step 6: Verify app layout renders**

Run: `cd /Users/joejiang/Desktop/tapir && npm run tauri dev`

Expected: Window shows TitleBar + Sidebar + main content + StatusBar layout with "SystemView" placeholder.

- [ ] **Step 7: Commit**

```bash
git add src/components/ src/App.tsx
git commit -m "feat: add app layout shell (TitleBar, Sidebar, StatusBar, step routing)"
```

---

## Task 14: Frontend — Step 0 SystemView (Permission)

**Files:**
- Modify: `src/components/SystemView.tsx`

- [ ] **Step 1: Implement SystemView**

Full permission page with:
- Large status indicator (green checkmark or red X)
- "GRANT" PixelButton (calls `tauriCommands.requestPermission()`)
- "CHECK" PixelButton (calls `tauriCommands.checkPermission()`)
- Instructions text for manual granting
- Technical details panel (platform: macOS, engine: Tauri/Rust, sandbox status)
- On mount: auto-check permission

- [ ] **Step 2: Verify permission flow**

Run: `npm run tauri dev`

Expected: SystemView shows permission status. Clicking CHECK queries the system. Clicking GRANT opens the system prompt or Settings.

- [ ] **Step 3: Commit**

```bash
git add src/components/SystemView.tsx
git commit -m "feat: implement Step 0 permission page with accessibility check"
```

---

## Task 15: Frontend — Step 1 WindowSelector

**Files:**
- Modify: `src/components/WindowSelector.tsx`

- [ ] **Step 1: Implement WindowSelector**

Full window selection page with:
- SCAN PixelButton (calls `tauriCommands.scanWindows()`, stores in `scannedWindows`)
- PixelInput search bar (filters by owner name / window name, case-insensitive)
- Scrollable window list: each row shows owner name, window name, PID, on-screen badge
- Click to toggle selection (multi-select)
- Selected windows highlighted with accent border
- Selection count badge
- CLEAR ALL button

- [ ] **Step 2: Verify scanning and selection**

Run: `npm run tauri dev`

Navigate to Step 1. Click SCAN. Expected: Window list populates. Click windows to select/deselect.

- [ ] **Step 3: Commit**

```bash
git add src/components/WindowSelector.tsx
git commit -m "feat: implement Step 1 window selector with scan, search, multi-select"
```

---

## Task 16: Frontend — Step 2 KeyConfig

**Files:**
- Modify: `src/components/KeyConfig.tsx`
- Create: `src/components/KeyStepCard.tsx`

- [ ] **Step 1: Install dnd-kit**

Run: `cd /Users/joejiang/Desktop/tapir && npm install @dnd-kit/core @dnd-kit/sortable @dnd-kit/utilities`

- [ ] **Step 2: Implement KeyStepCard**

Individual key step card with:
- SegmentButton for mode selection (KEY / TXT / CMB)
- KEY mode: PixelDropdown for key name + 4 PixelToggles for modifiers (Cmd/Shift/Opt/Ctrl)
- TEXT mode: PixelInput for text content + PixelToggle for append enter
- COMBO mode: PixelToggle + PixelDropdown for prefix key, PixelInput for text, PixelToggle + PixelDropdown for suffix key
- Drag handle, move up/down buttons, duplicate button, delete button
- Disabled when sending

- [ ] **Step 3: Implement KeyConfig**

Full key configuration page with:
- Top: FlowLayout sequence preview (chips showing step display names, color-coded by mode)
- Interval control: PixelInput for interval in ms
- Add buttons: + KEY, + TEXT, + COMBO
- DndContext with SortableContext wrapping KeyStepCard list
- Drag-to-reorder with smooth animations

- [ ] **Step 4: Verify key step CRUD and drag reorder**

Run: `npm run tauri dev`

Navigate to Step 2. Add KEY/TEXT/COMBO steps. Verify mode switching, drag reorder, duplicate, delete.

- [ ] **Step 5: Commit**

```bash
git add src/components/KeyConfig.tsx src/components/KeyStepCard.tsx package.json package-lock.json
git commit -m "feat: implement Step 2 key config with drag-to-reorder"
```

---

## Task 17: Frontend — Step 3 SendControl + EventLog

**Files:**
- Modify: `src/components/SendControl.tsx`
- Create: `src/components/EventLog.tsx`

- [ ] **Step 1: Implement EventLog**

Scrollable timestamped log panel with:
- Auto-scroll pinned to bottom (ref-based scroll)
- PixelToggle to disable auto-scroll
- CLEAR button
- Each entry: timestamp (HH:MM:SS.mmm), color-coded tag (KEY=cyan, SYS=green, ERR=red, WRN=orange), message
- Max 500 entries (handled by store)

- [ ] **Step 2: Implement SendControl**

Full send control page with:
- Large state indicator (IDLE / TRANSMITTING / PAUSED)
- Send count display (large font)
- Cycles completed display
- IntervalProgressBar (animated during sending)
- RepeatModeStrip (infinite / N-repeat with presets)
- Action buttons: START (calls `tauriCommands.startSending()`), PAUSE, RESUME, STOP
- Preflight warnings if targets or keys missing
- EventLog component at bottom
- Polling: `setInterval` every 100ms calls `tauriCommands.getSenderStatus()` to update counts

- [ ] **Step 3: Verify full send flow**

Run: `npm run tauri dev`

1. Grant accessibility permission
2. Scan and select a target (e.g., TextEdit)
3. Add a TEXT step with "hello"
4. Navigate to Step 3, click START
5. Expected: Tapir activates TextEdit and types "hello" repeatedly

- [ ] **Step 4: Commit**

```bash
git add src/components/SendControl.tsx src/components/EventLog.tsx
git commit -m "feat: implement Step 3 send control with event log"
```

---

## Task 18: Integration Polish

**Files:**
- Modify: multiple components for animation and edge case handling

- [ ] **Step 1: Add CSS transitions**

Add smooth transitions to:
- Step switching (opacity fade)
- Sidebar step indicators
- Toast appear/disappear
- Button hover/press states
- Window list item selection

- [ ] **Step 2: Handle edge cases**

- Sidebar: grey out inaccessible steps
- SendControl: disable START when no targets or no steps
- KeyConfig: disable editing during active send
- WindowSelector: show "(no windows found)" empty state after scan
- EventLog: "(no events)" empty state

- [ ] **Step 3: Add keyboard shortcut**

- `Cmd+1-4` to switch steps (where allowed)
- `Cmd+Enter` to start/stop sending

- [ ] **Step 4: Verify all interactions**

Run: `npm run tauri dev`

Test the full workflow end-to-end. Verify all transitions are smooth, edge cases handled.

- [ ] **Step 5: Commit**

```bash
git add src/
git commit -m "feat: polish interactions, transitions, and edge cases"
```

---

## Task 19: App Icons

**Files:**
- Copy/generate icons into `src-tauri/icons/`

- [ ] **Step 1: Generate app icons**

Use the existing `scripts/gen_icon.py` to generate icons, or copy from `TapirApp/Assets.xcassets/AppIcon.appiconset/`. Place into `src-tauri/icons/`:
- `32x32.png`
- `128x128.png`
- `128x128@2x.png` (256px)
- `icon.icns` (generated from 1024px source)
- `icon.ico` (for cross-platform)

- [ ] **Step 2: Verify icons show in dev build**

Run: `npm run tauri dev`

Expected: Dock icon shows Tapir icon.

- [ ] **Step 3: Commit**

```bash
git add src-tauri/icons/
git commit -m "feat: add app icons for macOS bundle"
```

---

## Task 20: Build & Packaging Verification

**Files:**
- No new files, verification task

- [ ] **Step 1: Production build**

Run:
```bash
cd /Users/joejiang/Desktop/tapir
npm run tauri build
```

Expected: Produces `src-tauri/target/release/bundle/macos/Tapir.app` and `Tapir.dmg`.

- [ ] **Step 2: Verify .app runs standalone**

Run:
```bash
open src-tauri/target/release/bundle/macos/Tapir.app
```

Expected: App launches, full workflow works.

- [ ] **Step 3: Verify entitlements**

Run:
```bash
codesign -d --entitlements - src-tauri/target/release/bundle/macos/Tapir.app
```

Expected: Shows `com.apple.security.app-sandbox = true`.

- [ ] **Step 4: Test sandbox behavior**

With the .app bundle running:
1. Grant accessibility permission
2. Open TextEdit
3. Configure a TEXT step and send
4. Verify keys arrive in TextEdit

If CGEvent.post fails in sandbox, switch to Path B (AppleScript) or Path C (Developer ID) per spec Section 6.

- [ ] **Step 5: Commit final state**

```bash
git add -A
git commit -m "feat: Tapir v2.0 Rust rewrite complete"
```
