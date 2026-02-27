import Cocoa
import FlutterMacOS
import ApplicationServices
import Darwin

/// native plugin that handles window scanning, key event sending,
/// and accessibility permission management via FlutterMethodChannel.
class KeySenderPlugin {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.tapir/native",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler(handle)
    }

    // MARK: - method channel dispatcher

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getWindows":
            result(getWindows())

        case "checkAccessibility":
            result(checkAccessibility())

        case "requestAccessibility":
            requestAccessibility()
            result(true)

        case "sendKeyEvent":
            sendKeyEvent(call.arguments, result: result)

        case "sendText":
            sendText(call.arguments, result: result)

        case "sendCombo":
            sendCombo(call.arguments, result: result)

        case "isWindowValid":
            isWindowValid(call.arguments, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - process tree helpers

    /// get the parent process id (ppid) for a given pid using sysctl.
    /// returns 0 if the lookup fails.
    private func getParentPid(of pid: pid_t) -> pid_t {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]

        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        if result == 0 && size > 0 {
            return info.kp_eproc.e_ppid
        }
        return 0
    }

    /// build a map of parentPid -> [childPid] by scanning the process table ONCE.
    /// much more efficient than calling getChildPids per-PID, which would scan
    /// the entire table N times.
    private func buildChildPidMap() -> [pid_t: [pid_t]] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
        var size: Int = 0

        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0 else {
            return [:]
        }

        let procCount = size / MemoryLayout<kinfo_proc>.stride
        guard procCount > 0 else {
            return [:]
        }

        var procList = [kinfo_proc](repeating: kinfo_proc(), count: procCount)
        guard sysctl(&mib, UInt32(mib.count), &procList, &size, nil, 0) == 0 else {
            return [:]
        }

        let actualCount = size / MemoryLayout<kinfo_proc>.stride

        // single pass: group all children by their parent pid
        var map: [pid_t: [pid_t]] = [:]
        for i in 0..<actualCount {
            let ppid = procList[i].kp_eproc.e_ppid
            let childPid = procList[i].kp_proc.p_pid
            if ppid != childPid {
                map[ppid, default: []].append(childPid)
            }
        }

        return map
    }

    // MARK: - window scanning

    /// scan all visible on-screen windows and return their info as a list of dictionaries.
    /// includes process hierarchy: parentPid, whether it's a child process window,
    /// and how many sub-process windows exist under the same parent.
    private func getWindows() -> [[String: Any]] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
                as? [[String: Any]] else {
            return []
        }

        let myPid = ProcessInfo.processInfo.processIdentifier

        // phase 1: collect raw window data
        struct RawWindow {
            let windowId: Int
            let ownerName: String
            let windowName: String
            let pid: Int
        }

        var rawWindows: [RawWindow] = []

        for info in windowInfoList {
            guard let windowId = info[kCGWindowNumber as String] as? Int,
                  let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let pid = info[kCGWindowOwnerPID as String] as? Int else {
                continue
            }

            // only layer 0 (normal windows)
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else {
                continue
            }

            // skip our own app
            if pid == myPid {
                continue
            }

            let windowName = info[kCGWindowName as String] as? String ?? ""

            if windowName.isEmpty && ownerName.isEmpty {
                continue
            }

            rawWindows.append(RawWindow(
                windowId: windowId,
                ownerName: ownerName,
                windowName: windowName,
                pid: pid
            ))
        }

        // phase 2: collect unique pids and build process tree
        let uniquePids = Set(rawWindows.map { pid_t($0.pid) })

        // for each pid, get its ppid
        var pidToParentPid: [pid_t: pid_t] = [:]
        for pid in uniquePids {
            pidToParentPid[pid] = getParentPid(of: pid)
        }

        // scan the process table once and build the full child map
        let fullChildMap = buildChildPidMap()

        // for each pid, find child pids that also have windows
        var pidToChildPids: [pid_t: [pid_t]] = [:]
        for pid in uniquePids {
            let children = fullChildMap[pid] ?? []
            let windowedChildren = children.filter { uniquePids.contains($0) }
            if !windowedChildren.isEmpty {
                pidToChildPids[pid] = windowedChildren
            }
        }

        // build a set of all pids that are children of another windowed pid
        var childPidSet: Set<pid_t> = []
        for (_, children) in pidToChildPids {
            for child in children {
                childPidSet.insert(child)
            }
        }

        // phase 3: count sub-windows per pid (same process, multiple windows)
        var pidWindowCount: [pid_t: Int] = [:]
        for raw in rawWindows {
            let p = pid_t(raw.pid)
            pidWindowCount[p, default: 0] += 1
        }

        // phase 4: build result with hierarchy info
        var windows: [[String: Any]] = []

        for raw in rawWindows {
            let p = pid_t(raw.pid)
            let parentPid = pidToParentPid[p] ?? 0
            let isChildProcess = childPidSet.contains(p)
            let childPids = pidToChildPids[p] ?? []
            let subWindowCount = pidWindowCount[p] ?? 1

            // find the parent process pid if this is a child of another windowed process
            var parentWindowedPid: Int = 0
            if isChildProcess {
                // walk up to find which windowed pid is the parent
                for (candidate, children) in pidToChildPids {
                    if children.contains(p) {
                        parentWindowedPid = Int(candidate)
                        break
                    }
                }
            }

            windows.append([
                "windowId": raw.windowId,
                "ownerName": raw.ownerName,
                "windowName": raw.windowName,
                "pid": raw.pid,
                "parentPid": Int(parentPid),
                "isChildProcess": isChildProcess,
                "parentWindowedPid": parentWindowedPid,
                "childProcessCount": childPids.count,
                "subWindowCount": subWindowCount,
            ])
        }

        return windows
    }

    // MARK: - accessibility permission

    /// check if accessibility permission is granted.
    /// required for CGEvent posting to other processes.
    private func checkAccessibility() -> Bool {
        return AXIsProcessTrusted()
    }

    /// prompt the user to grant accessibility permission.
    /// this opens system preferences to the accessibility pane.
    private func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - key event sending

    /// send a keyboard event (key down + key up) to a specific process identified by pid.
    /// supports modifier keys (command, shift, option, control).
    private func sendKeyEvent(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let pid = args["pid"] as? Int,
              let keyCode = args["keyCode"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "missing required arguments: pid, keyCode",
                details: nil
            ))
            return
        }

        // safety check: verify accessibility permission before sending
        guard AXIsProcessTrusted() else {
            result(FlutterError(
                code: "NO_PERMISSION",
                message: "accessibility permission not granted",
                details: nil
            ))
            return
        }

        let modifiers = args["modifiers"] as? [String] ?? []

        // build modifier flags
        var flags: CGEventFlags = []
        for modifier in modifiers {
            switch modifier {
            case "command":
                flags.insert(.maskCommand)
            case "shift":
                flags.insert(.maskShift)
            case "option":
                flags.insert(.maskAlternate)
            case "control":
                flags.insert(.maskControl)
            default:
                break
            }
        }

        // create key down event
        guard let keyDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(keyCode),
            keyDown: true
        ) else {
            result(FlutterError(
                code: "EVENT_FAILED",
                message: "failed to create key down event",
                details: nil
            ))
            return
        }
        keyDown.flags = flags

        // create key up event
        guard let keyUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(keyCode),
            keyDown: false
        ) else {
            result(FlutterError(
                code: "EVENT_FAILED",
                message: "failed to create key up event",
                details: nil
            ))
            return
        }
        keyUp.flags = flags

        // dispatch to a background queue so the usleep between keyDown/keyUp
        // does not block the Flutter engine main thread
        let targetPid = pid_t(pid)
        DispatchQueue.global(qos: .userInitiated).async {
            keyDown.postToPid(targetPid)

            // small delay between key down and key up for realistic key press
            usleep(10000) // 10ms

            keyUp.postToPid(targetPid)

            DispatchQueue.main.async {
                result(true)
            }
        }
    }

    // MARK: - text sending

    /// type a string of characters to a process by synthesizing unicode key events.
    /// optionally appends an Enter (Return) key press at the end.
    /// args: pid (Int), text (String), appendEnter (Bool)
    private func sendText(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let pid = args["pid"] as? Int,
              let text = args["text"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "missing required arguments: pid, text",
                details: nil
            ))
            return
        }

        guard AXIsProcessTrusted() else {
            result(FlutterError(
                code: "NO_PERMISSION",
                message: "accessibility permission not granted",
                details: nil
            ))
            return
        }

        let appendEnter = args["appendEnter"] as? Bool ?? false
        let targetPid = pid_t(pid)

        DispatchQueue.global(qos: .userInitiated).async {
            // type each character using CGEvent with unicode string
            for char in text {
                let utf16 = Array(String(char).utf16)
                guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                      let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
                    continue
                }
                keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)

                keyDown.postToPid(targetPid)
                usleep(5000) // 5ms between key down and up
                keyUp.postToPid(targetPid)
                usleep(8000) // 8ms between characters for reliable input
            }

            // optionally press Enter after the text
            if appendEnter {
                usleep(10000) // small pause before Enter
                let enterCode: CGKeyCode = 0x24 // kVK_Return
                if let enterDown = CGEvent(keyboardEventSource: nil, virtualKey: enterCode, keyDown: true),
                   let enterUp = CGEvent(keyboardEventSource: nil, virtualKey: enterCode, keyDown: false) {
                    enterDown.postToPid(targetPid)
                    usleep(10000)
                    enterUp.postToPid(targetPid)
                }
            }

            DispatchQueue.main.async {
                result(true)
            }
        }
    }

    // MARK: - combo sending (prefix key → text → suffix key)

    /// execute a combo sequence: optional prefix key, type text, optional suffix key.
    /// designed for chat/dialog automation (e.g., Tab → "hello" → Enter).
    /// args: pid (Int), text (String),
    ///       prefixKeyCode (Int?), suffixKeyCode (Int?)
    private func sendCombo(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let pid = args["pid"] as? Int,
              let text = args["text"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "missing required arguments: pid, text",
                details: nil
            ))
            return
        }

        guard AXIsProcessTrusted() else {
            result(FlutterError(
                code: "NO_PERMISSION",
                message: "accessibility permission not granted",
                details: nil
            ))
            return
        }

        let prefixKeyCode = args["prefixKeyCode"] as? Int
        let suffixKeyCode = args["suffixKeyCode"] as? Int
        let targetPid = pid_t(pid)

        DispatchQueue.global(qos: .userInitiated).async {
            // step 1: prefix key (if provided)
            if let code = prefixKeyCode {
                self.postSingleKey(CGKeyCode(code), flags: [], to: targetPid)
                usleep(30000) // 30ms pause after prefix key
            }

            // step 2: type text characters
            for char in text {
                let utf16 = Array(String(char).utf16)
                guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                      let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
                    continue
                }
                keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                keyDown.postToPid(targetPid)
                usleep(5000)
                keyUp.postToPid(targetPid)
                usleep(8000)
            }

            // step 3: suffix key (if provided)
            if let code = suffixKeyCode {
                usleep(20000) // 20ms pause before suffix key
                self.postSingleKey(CGKeyCode(code), flags: [], to: targetPid)
            }

            DispatchQueue.main.async {
                result(true)
            }
        }
    }

    /// helper: post a single key down + key up to a process
    private func postSingleKey(_ keyCode: CGKeyCode, flags: CGEventFlags, to pid: pid_t) {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            return
        }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.postToPid(pid)
        usleep(10000)
        keyUp.postToPid(pid)
    }

    // MARK: - window validation

    /// check if a window with the given windowId still exists on screen.
    /// used to detect when the target window is closed or minimized.
    private func isWindowValid(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let windowId = args["windowId"] as? Int else {
            result(false)
            return
        }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
                as? [[String: Any]] else {
            result(false)
            return
        }

        for info in windowInfoList {
            if let wId = info[kCGWindowNumber as String] as? Int, wId == windowId {
                result(true)
                return
            }
        }

        result(false)
    }
}
