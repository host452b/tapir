# Tapir — App Store Listing (ASO)

> 提交 App Store Connect 时直接复制粘贴使用

---

## 1. App Name（30 字符限制）

```
Tapir - Keyboard Automation
```

**备选：**
- `Tapir - Auto Key Sender`
- `Tapir - Key Macro Tool`

---

## 2. Subtitle（30 字符限制）

```
Send Keys to Any App Window
```

**备选：**
- `Automate Keystrokes for macOS`
- `Key Event Automation Tool`

---

## 3. Keywords（100 字符，逗号分隔，不加空格）

```
keyboard,macro,keystroke,hotkey,shortcut,autotype,repeat,typing,simulate,input,automation,sender,batch,sequence,combo
```

**字符计数：** 98/100

**策略：**
- 不重复 Name/Subtitle 中已有的词（Apple 自动索引）
- 覆盖同义词：keyboard/keystroke/hotkey/shortcut/typing
- 覆盖动作词：autotype/repeat/simulate/sender/batch
- 覆盖组合词：sequence/combo/macro/input

---

## 4. Category

| 类型 | 选择 |
|------|------|
| Primary | **Utilities** |
| Secondary | **Developer Tools** |

---

## 5. Description（4000 字符限制）

```
Tapir is a keyboard automation tool for macOS that sends key events to any target application window.

Whether you need to automate repetitive typing, send keyboard shortcuts to background apps, or build complex key sequences — Tapir handles it with precision timing and a clean, guided workflow.

WHAT TAPIR DOES

• Scan all visible windows on your Mac and select one or multiple targets
• Build key sequences with three flexible modes:
  - KEY: single key press with Cmd/Shift/Opt/Ctrl modifiers
  - TEXT: type strings character by character, optionally press Enter
  - COMBO: prefix key → text → suffix key (great for chat, forms, and terminals)
• Drag to reorder steps, duplicate, or remove them
• Set precise timing intervals between steps (100ms to 10,000,000ms)
• Choose repeat mode: infinite loop or a specific number of cycles
• Monitor everything with a real-time event log

HOW IT WORKS

1. PERMISSION — Grant Accessibility access (one-time setup)
2. TARGET — Scan and select which app window(s) receive your keys
3. KEYS — Build your key sequence with drag-and-drop
4. CONTROL — Start, pause, resume, or stop at any time

BUILT FOR PRECISION

Tapir uses the macOS CGEvent API to synthesize keyboard events with carefully tuned timing:
• 10ms key hold duration for reliable delivery
• 5-8ms inter-character delay for natural text input
• Configurable step intervals for your exact workflow

DESIGNED WITH CARE

• Flexoki Light color theme — easy on the eyes
• Menlo monospace typography throughout
• Pixel-art inspired UI components
• Smooth 120ms transitions and animations
• Real-time progress bar and event counter

PRIVACY & SECURITY

• Requires only Accessibility permission — no network, no file access
• App Sandbox enabled
• No data collection, no analytics, no tracking
• Your key sequences stay on your device

PERFECT FOR

• Automating repetitive data entry
• Sending commands to terminal sessions
• Testing keyboard shortcuts in other apps
• Filling forms with predefined text
• Chat message automation
• Game key macros
• QA and UI testing workflows

Built with Rust (Tauri v2) for performance and safety. Native macOS integration through CGEvent API. Requires macOS 14.0 (Sonoma) or later.
```

**字符计数：** ~1700/4000

---

## 6. Promotional Text（170 字符，可随时更新，不影响审核）

```
Automate any keyboard input on your Mac. Build key sequences, send to any window, repeat with precision timing. Fast, native, private.
```

---

## 7. What's New (Version 2.1)

```
Complete rewrite in Rust for better performance and reliability.

• New: Tauri v2 engine (Rust backend)
• New: React + TypeScript frontend
• New: Flexoki Light theme
• New: Multi-target window support
• New: Drag-to-reorder key steps
• New: App Sandbox enabled
• Improved: Key event timing precision
• Improved: Process tree detection
• Improved: Guided 4-step workflow
```

---

## 8. Support URL

```
https://github.com/host452b/tapir/issues
```

---

## 9. Privacy Policy URL

```
https://github.com/host452b/tapir/blob/main/PRIVACY.md
```

需要创建 `PRIVACY.md`（见下方模板）。

---

## 10. Screenshots 规格

| 尺寸 | 用途 |
|------|------|
| 1280 x 800 | 13 inch MacBook 必需 |
| 1440 x 900 | 可选但推荐 |
| 2560 x 1600 | Retina 推荐 |
| 2880 x 1800 | 15 inch Retina |

**推荐 5 张截图内容：**

1. **Step 1: TARGET** — 窗口扫描列表，多选目标，搜索功能
2. **Step 2: KEYS** — 序列配置，三种模式，拖拽排序
3. **Step 3: CONTROL** — 发送中状态，进度条，事件日志
4. **Step 0: SYSTEM** — 权限授权页面，技术信息
5. **About/Overview** — 整体 UI 展示，Flexoki Light 主题

---

## 11. App Review Notes（审核备注）

```
Tapir requires Accessibility permission to send keyboard events to other applications via the macOS CGEvent API.

To test the app:
1. Launch Tapir
2. Click "GRANT" to enable Accessibility permission in System Settings
3. Click "SCAN" to discover windows
4. Select a target window (e.g., TextEdit)
5. Add a TEXT step (e.g., "hello world")
6. Click START — Tapir will activate the target window and type the text

The app uses CGEvent.post(kCGHIDEventTap) which is a public macOS API. No private APIs are used.

Test account: Not required (no login/account needed).
```

---

## 12. App Information

| 字段 | 值 |
|------|------|
| Bundle ID | `com.tapir.app` |
| SKU | `tapir-macos-2024` |
| Content Rights | Does not contain third-party content |
| Age Rating | 4+ |
| Copyright | 2026 Tapir |
| License | MIT |

---

## 13. Localization（本地化优先级）

| 语言 | 优先级 | Name | Subtitle |
|------|--------|------|----------|
| English (US) | P0 | Tapir - Keyboard Automation | Send Keys to Any App Window |
| Chinese Simplified | P1 | Tapir - 键盘自动化 | 向任意窗口发送按键 |
| Japanese | P2 | Tapir - キーボード自動化 | 任意のウィンドウにキー送信 |

每种语言有独立的 Keywords 100 字符配额。

**中文 Keywords：**
```
键盘,自动化,按键,宏,快捷键,自动输入,重复,模拟,批量,序列,组合键,发送,打字,热键,效率
```

---

## PRIVACY.md 模板

创建 `PRIVACY.md` 放在仓库根目录：

```markdown
# Privacy Policy

**Tapir** does not collect, store, or transmit any personal data.

## Data Collection
- No analytics or tracking
- No network requests
- No user accounts
- No data leaves your device

## Permissions
Tapir requests only **Accessibility** permission, which is required
to send keyboard events to other applications via the macOS CGEvent API.

## Contact
For privacy questions: https://github.com/host452b/tapir/issues

Last updated: 2026-03-24
```
