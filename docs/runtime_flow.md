# Tapir v2 — Runtime Flow & Code Division

## Architecture Overview

```
┌───────────────────────────────────────────────────────┐
│                    React Frontend                      │
│  App.tsx → Sidebar / TitleBar / StatusBar / StepViews  │
│  Zustand Store (useAppState.ts) ← single source of truth │
├───────────────────────────────────────────────────────┤
│              Tauri IPC Bridge                          │
│  invoke() → 10 commands    ← events (3 channels)      │
├───────────────────────────────────────────────────────┤
│    commands/          state/           core/           │
│  (thin wrappers)   (SenderManager)  (pure Rust FFI)   │
├───────────────────────────────────────────────────────┤
│              macOS System APIs                         │
│  CGEvent · CGWindowList · AXIsProcessTrusted · sysctl  │
└───────────────────────────────────────────────────────┘
```

---

## Rust Backend (`src-tauri/src/`)

### Entry Point: `main.rs`

启动 Tauri 应用，注册 10 个 IPC 命令和托管状态：

```
main()
  → tauri::Builder::default()
    → .manage(SenderState(Mutex<Option<SenderManager>>))
    → .invoke_handler([10 commands])
    → .run()
```

### Layer 1: `commands/` — IPC 薄层

仅做参数转换，调用 core 或 state：

| 文件 | 命令 | 调用 |
|------|------|------|
| `accessibility.rs` | `check_permission() → bool` | `core::accessibility::is_trusted()` |
| | `request_permission() → bool` | `core::accessibility::request_with_prompt()` |
| | `open_settings()` | `core::accessibility::open_settings()` |
| `window.rs` | `scan_windows() → Vec<WindowInfo>` | `core::window_scanner::scan_windows()` |
| | `validate_windows([(wid,pid)]) → Vec<pid>` | `core::process::is_window_valid()` |
| `sender.rs` | `start_sending(targets, steps, interval, repeat)` | `SenderManager::start()` |
| | `pause_sending()` | `SenderManager::pause()` |
| | `resume_sending()` | `SenderManager::resume()` |
| | `stop_sending()` | `SenderManager::stop()` |
| | `get_sender_status() → SenderStatus` | `SenderManager::status()` |

### Layer 2: `state/sender_state.rs` — 发送状态机

`SenderManager` 管理发送生命周期：

```
SenderManager {
    state: Arc<Mutex<SendingState>>       // Idle | Running | Paused
    send_count: Arc<AtomicU64>            // 已发送事件数
    cycles_completed: Arc<AtomicU64>      // 已完成循环数
    cancel_token: Option<CancellationToken>  // 优雅停止
    pause_notify: Arc<Notify>             // 暂停/恢复信号
    shared_targets: Arc<Mutex<Vec<WindowInfo>>>  // 验证循环可移除死进程
}
```

`start()` 启动两个 tokio task：

**发送循环（Send Loop）：**
```
loop {
    if paused → await pause_notify
    if all targets gone → auto-pause
    for target in shared_targets:
        key_sender::activate_window(pid)   // 切到前台
        send_step(step)                     // 发送当前步骤
    advance step_index
    if cycle complete && repeat_count reached → stop
    sleep(interval_ms)
}
```

**验证循环（Validation Loop）：**
```
every 3 seconds:
    for target in shared_targets:
        if !process::is_process_alive(pid):
            remove from shared_targets
            emit "tapir://targets-invalidated"
```

### Layer 3: `core/` — 纯 Rust，无 Tauri 依赖

| 模块 | 职责 | 关键函数 |
|------|------|---------|
| `key_codes.rs` | CGKeyCode 映射 (72键) | `lookup(name) → Option<u16>` |
| `key_sender.rs` | CGEvent 合成 & 发送 | `activate_window(pid)`, `send_key()`, `send_text()`, `send_combo()` |
| `window_scanner.rs` | 窗口扫描 + 进程树 | `scan_windows() → Vec<WindowInfo>` |
| `accessibility.rs` | 辅助功能权限 | `is_trusted()`, `request_with_prompt()`, `open_settings()` |
| `process.rs` | 进程存活检查 | `is_process_alive(pid)`, `is_window_valid(wid, pid)` |

### `core/key_sender.rs` — 按键发送细节

```
send_key(key_code, modifiers):
    CGEventSource(HIDSystemState)
    CGEvent::new_keyboard_event(key_code, keyDown=true)
    set_flags(Command|Shift|Option|Control)
    event.post(CGEventTapLocation::HID)   // → 发到前台窗口
    sleep(10ms)
    event.post(keyUp)

send_text(text, append_enter):
    for char in text:
        encode UTF-16
        CGEvent(keycode=0) + set_string_from_utf16
        post(down), sleep(5ms), post(up), sleep(8ms)
    if append_enter: send Return(36)

send_combo(text, prefix, suffix):
    prefix key (10ms hold) → 30ms delay
    text chars (5ms + 8ms each)
    20ms delay → suffix key (10ms hold)

activate_window(pid):
    NSRunningApplication::runningApplicationWithProcessIdentifier(pid)
    app.activateWithOptions(ActivateIgnoringOtherApps)
    sleep(50ms)
```

### `core/window_scanner.rs` — 窗口扫描细节

```
scan_windows():
    Pass 1: CGWindowListCopyWindowInfo(optionAll | excludeDesktopElements)
            → 所有窗口（含后台/最小化）
    Pass 2: CGWindowListCopyWindowInfo(optionOnScreenOnly | excludeDesktopElements)
            → 构建 on_screen_ids: HashSet<u32>

    Filter: layer == 0, not self PID, has name

    sysctl(KERN_PROC_ALL) → 构建 parent→children 进程树
    get_parent_pid(pid) → sysctl(KERN_PROC_PID)

    For each window → WindowInfo {
        parent_windowed_pid  // 最近的有窗口的祖先进程
        child_process_count  // 子进程中有窗口的数量
        sub_window_count     // 该进程拥有的窗口数
        is_on_screen         // 在 on_screen_ids 集合中
    }
```

### `models/` — 共享数据类型

```
KeyStep        { id, mode, key_name, modifiers, text_content, ... }
StepMode       { Key | Text | Combo }       // serde → "key"/"text"/"combo"
WindowInfo     { id, owner_name, pid, parent_windowed_pid, is_on_screen, ... }
LogEntry       { id, timestamp, entry_type, message }
SendingState   { Idle | Running | Paused }  // serde → "idle"/"running"/"paused"
SenderStatus   { state, send_count, cycles_completed }
TapirError     { NoPermission | EventCreationFailed | ... }  // serde tag="type"
```

所有 struct 使用 `#[serde(rename_all = "camelCase")]`，enum 使用 `#[serde(rename_all = "lowercase")]`，确保与 TypeScript 类型一一对应。

---

## React Frontend (`src/`)

### 状态管理：`hooks/useAppState.ts`

Zustand store 是整个前端的 single source of truth：

```
AppState {
    // 工作流
    currentStep: 0|1|2|3

    // 权限
    hasPermission: boolean

    // 窗口
    scannedWindows: WindowInfo[]
    selectedWindows: WindowInfo[]
    searchQuery: string

    // 按键序列
    keySteps: KeyStep[]
    intervalMs: number (default 2000)

    // 发送状态
    sendingState: 'idle' | 'running' | 'paused'
    sendCount, cyclesCompleted, repeatCount

    // 日志 & Toast
    logEntries: LogEntry[] (max 500)
    autoScroll: boolean
    toast: { message, color } | null
}
```

### IPC 通信：`hooks/useTauriCommand.ts`

**前端 → 后端（invoke 调用）：**
```typescript
tauriCommands = {
    checkPermission:  () => invoke<boolean>('check_permission')
    requestPermission: () => invoke<boolean>('request_permission')
    openSettings:     () => invoke<void>('open_settings')
    scanWindows:      () => invoke<WindowInfo[]>('scan_windows')
    validateWindows:  (w) => invoke<number[]>('validate_windows', { windows: w })
    startSending:     (targets, steps, intervalMs, repeatCount) => invoke(...)
    pauseSending:     () => invoke('pause_sending')
    resumeSending:    () => invoke('resume_sending')
    stopSending:      () => invoke('stop_sending')
    getSenderStatus:  () => invoke<SenderStatus>('get_sender_status')
}
```

**后端 → 前端（事件推送）：**
```
useTauriEvents() hook 监听：
    "tapir://log"                → addLogEntry(payload)
    "tapir://state-change"       → setSendingState(payload)
    "tapir://targets-invalidated" → deselectByPid(each pid) + toast
```

### 组件树

```
App.tsx
├── TitleBar          "TAPIR" + badges + About 按钮
│   └── AboutPanel    模态弹窗（版本/技术信息）
├── Sidebar           4 步骤导航 + 状态指示器
├── <main>
│   ├── SystemView        Step 0: 权限检查/授权
│   ├── WindowSelector    Step 1: 扫描/搜索/多选窗口
│   │   └── WindowRow     单个窗口行（owner, name, PID, on-screen）
│   ├── KeyConfig         Step 2: 序列配置 + 拖拽排序
│   │   └── KeyStepCard   单个步骤卡片（模式/按键/文本/修饰键）
│   ├── SendControl       Step 3: 发送控制 + 状态显示
│   │   └── EventLog      时间戳日志（自动滚动/清除）
│   └── StepNavBar        BACK / NEXT / RESET 导航
└── StatusBar         底部状态栏（权限/目标/间隔/状态）
```

### UI 原子组件（`components/ui/`）

| 组件 | 用途 |
|------|------|
| `PixelPanel` | 卡片容器（accent header, shadow） |
| `PixelButton` | 按钮（default/primary/danger, 3D 按压效果） |
| `PixelBadge` | 小标签（胶囊形，语义色） |
| `PixelToggle` | 复选框（14x14, checkmark） |
| `PixelInput` | 输入框（底部边框, accent focus） |
| `PixelDropdown` | 下拉选择（native select 包装） |
| `SegmentButton` | 分段选择器（KEY/TXT/CMB） |
| `PixelDivider` | 分割线（可选居中标签） |
| `FlowLayout` | Flex 换行容器 |
| `IntervalProgressBar` | 10段 LED 进度条 |
| `RepeatModeStrip` | 重复模式配置（∞/N× + 快选） |

---

## 关键场景数据流

### A. 启动 → 权限检查

```
App mount
  → useTauriEvents() 注册 3 个事件监听器
  → SystemView mount
    → useEffect → tauriCommands.checkPermission()
      → [IPC] invoke("check_permission")
        → Rust: accessibility::is_trusted()
          → FFI: AXIsProcessTrusted()
        → return bool
      → setHasPermission(result)
      → Sidebar/StepNavBar re-render (hasPermission 变化)
```

### B. 扫描 → 窗口列表

```
User clicks SCAN
  → WindowSelector.handleScan()
    → tauriCommands.scanWindows()
      → [IPC] invoke("scan_windows")
        → Rust: window_scanner::scan_windows()
          → CGWindowListCopyWindowInfo (2 passes)
          → sysctl KERN_PROC_ALL (process tree)
          → filter + construct Vec<WindowInfo>
        → return JSON array
      → setScannedWindows(windows)
      → showToast("Found N window(s)")
    → filtered = useMemo(scannedWindows filter by searchQuery)
    → render WindowRow for each
```

### C. 开始发送

```
User clicks START
  → SendControl.handleStart()
    → tauriCommands.startSending(selectedWindows, keySteps, intervalMs, repeatCount)
      → [IPC] invoke("start_sending", { targets, steps, ... })
        → Rust: SenderManager::start()
          → validate steps & targets
          → set state = Running
          → emit "tapir://state-change" → Running
          → emit "tapir://log" → "Started: N targets, M steps..."
          → tokio::spawn(send_loop)
          → tokio::spawn(validation_loop)

[Send Loop - runs on tokio runtime]
  → for each step:
      → for each target:
          → key_sender::activate_window(pid)
            → NSRunningApplication.activate()
            → sleep(50ms)
          → send_step(step) match mode:
              Key:   key_sender::send_key(code, modifiers)
              Text:  key_sender::send_text(content, append_enter)
              Combo: key_sender::send_combo(content, prefix, suffix)
          → emit "tapir://log" → "Sent X to AppName"
          → increment send_count
      → advance step_index
      → if cycle complete → increment cycles_completed
      → sleep(interval_ms)

[Frontend polls status every 200ms while running]
  → setInterval → tauriCommands.getSenderStatus()
    → [IPC] → SenderManager::status()
    → update sendCount, cyclesCompleted in Zustand
```

### D. 验证循环 → 目标丢失

```
[Validation Loop - every 3 seconds]
  → for each target in shared_targets:
      → process::is_process_alive(pid)
        → libc::kill(pid, 0)
      → if dead:
          → remove from shared_targets (Arc<Mutex<Vec>>)
          → collect dead_pids

  → if dead_pids not empty:
      → emit "tapir://targets-invalidated" [pid1, pid2, ...]
        → [Frontend event listener]
          → deselectByPid(pid) for each
          → showToast("N target(s) lost")
      → emit "tapir://log" → "N target(s) no longer available"

  → [Send Loop checks shared_targets]
      → if empty → auto-pause
        → set state = Paused
        → emit "tapir://state-change" → Paused
        → emit "tapir://log" → "All targets lost — paused"
        → await pause_notify (blocks until resume)
```

---

## 线程模型

```
Main Thread (Tauri/WebView)
├── React UI rendering
├── IPC command dispatch
└── Event listener callbacks

Tokio Runtime (Rust async)
├── Send Loop task
│   └── spawn_blocking → key_sender FFI calls (CGEvent)
├── Validation Loop task
│   └── process::is_process_alive (sync, fast)
└── IPC command handlers (async)

macOS System
├── CGEvent HID event tap (receives posted events)
├── Accessibility permission daemon
└── WindowServer (provides window list)
```
