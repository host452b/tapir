//! Window scanner — discovers all windows and builds a process hierarchy tree.
//!
//! Ports the logic from `TapirApp/Services/WindowScanner.swift`.

// ── macOS implementation ──────────────────────────────────────────────
#[cfg(target_os = "macos")]
mod platform {
    use std::collections::{HashMap, HashSet};

    use core_foundation::base::TCFType;
    use core_foundation::dictionary::CFDictionary;
    use core_foundation::number::CFNumber;
    use core_foundation::string::CFString;
    use core_graphics::window::{
        copy_window_info, kCGNullWindowID, kCGWindowLayer, kCGWindowListExcludeDesktopElements,
        kCGWindowListOptionAll, kCGWindowListOptionOnScreenOnly, kCGWindowName, kCGWindowNumber,
        kCGWindowOwnerName, kCGWindowOwnerPID,
    };

    use crate::models::{TapirError, WindowInfo};

    // ── kinfo_proc layout (arm64 macOS) ──────────────────────────────
    //
    // The `libc` crate does not expose `kinfo_proc` on macOS.
    // We define the struct layout using known offsets from <sys/sysctl.h>:
    //   sizeof(kinfo_proc)      = 648
    //   kp_proc.p_pid  offset   = 40   (i32)
    //   kp_eproc.e_ppid offset  = 560  (i32)

    const KINFO_PROC_SIZE: usize = 648;
    const P_PID_OFFSET: usize = 40;
    const E_PPID_OFFSET: usize = 560;

    /// Read an i32 from a byte slice at the given offset.
    fn read_i32_at(buf: &[u8], offset: usize) -> i32 {
        let bytes: [u8; 4] = buf[offset..offset + 4].try_into().unwrap();
        i32::from_ne_bytes(bytes)
    }

    // ── CFDictionary helpers ──────────────────────────────────────────

    /// Extract an i64 value from a CFDictionary using a CFStringRef key constant.
    fn cf_dict_get_i64_key(
        dict: &CFDictionary<CFString, *const core::ffi::c_void>,
        key: &CFString,
    ) -> Option<i64> {
        let val = dict.find(key.as_concrete_TypeRef())?;
        let num: CFNumber = unsafe { TCFType::wrap_under_get_rule(*val as _) };
        num.to_i64()
    }

    /// Extract a String value from a CFDictionary using a CFStringRef key constant.
    fn cf_dict_get_string_key(
        dict: &CFDictionary<CFString, *const core::ffi::c_void>,
        key: &CFString,
    ) -> Option<String> {
        let val = dict.find(key.as_concrete_TypeRef())?;
        let cf_str: CFString = unsafe { TCFType::wrap_under_get_rule(*val as _) };
        Some(cf_str.to_string())
    }

    // ── sysctl helpers ────────────────────────────────────────────────

    /// Get the parent PID for a given PID using sysctl.
    fn get_parent_pid(pid: i32) -> i32 {
        let mut mib: [libc::c_int; 4] =
            [libc::CTL_KERN, libc::KERN_PROC, libc::KERN_PROC_PID, pid];
        let mut buf = vec![0u8; KINFO_PROC_SIZE];
        let mut size = KINFO_PROC_SIZE;

        let ret = unsafe {
            libc::sysctl(
                mib.as_mut_ptr(),
                mib.len() as u32,
                buf.as_mut_ptr() as *mut libc::c_void,
                &mut size,
                std::ptr::null_mut(),
                0,
            )
        };

        if ret == 0 && size > 0 {
            read_i32_at(&buf, E_PPID_OFFSET)
        } else {
            0
        }
    }

    /// Scan the entire process table in one pass and build a parent -> [child] map.
    fn build_child_pid_map() -> HashMap<i32, Vec<i32>> {
        let mut mib: [libc::c_int; 3] = [libc::CTL_KERN, libc::KERN_PROC, libc::KERN_PROC_ALL];
        let mut size: libc::size_t = 0;

        // First call: determine required buffer size.
        let ret = unsafe {
            libc::sysctl(
                mib.as_mut_ptr(),
                mib.len() as u32,
                std::ptr::null_mut(),
                &mut size,
                std::ptr::null_mut(),
                0,
            )
        };
        if ret != 0 {
            return HashMap::new();
        }

        let proc_count = size / KINFO_PROC_SIZE;
        if proc_count == 0 {
            return HashMap::new();
        }

        let mut buf = vec![0u8; size];

        let ret = unsafe {
            libc::sysctl(
                mib.as_mut_ptr(),
                mib.len() as u32,
                buf.as_mut_ptr() as *mut libc::c_void,
                &mut size,
                std::ptr::null_mut(),
                0,
            )
        };
        if ret != 0 {
            return HashMap::new();
        }

        let actual_count = size / KINFO_PROC_SIZE;
        let mut map: HashMap<i32, Vec<i32>> = HashMap::new();
        for i in 0..actual_count {
            let base = i * KINFO_PROC_SIZE;
            let entry = &buf[base..base + KINFO_PROC_SIZE];
            let ppid = read_i32_at(entry, E_PPID_OFFSET);
            let child_pid = read_i32_at(entry, P_PID_OFFSET);
            if ppid != child_pid {
                map.entry(ppid).or_default().push(child_pid);
            }
        }
        map
    }

    // ── Intermediate raw window struct ────────────────────────────────

    struct RawWindow {
        window_id: u32,
        owner_name: String,
        window_name: String,
        pid: i32,
        is_on_screen: bool,
    }

    // ── Main scan function ────────────────────────────────────────────

    pub fn scan_windows() -> Result<Vec<WindowInfo>, TapirError> {
        // Wrap the CFStringRef constants once.
        let key_window_number = unsafe { CFString::wrap_under_get_rule(kCGWindowNumber) };
        let key_owner_pid = unsafe { CFString::wrap_under_get_rule(kCGWindowOwnerPID) };
        let key_layer = unsafe { CFString::wrap_under_get_rule(kCGWindowLayer) };
        let key_owner_name = unsafe { CFString::wrap_under_get_rule(kCGWindowOwnerName) };
        let key_window_name = unsafe { CFString::wrap_under_get_rule(kCGWindowName) };

        // Pass 1: all windows.
        let all_options = kCGWindowListOptionAll | kCGWindowListExcludeDesktopElements;
        let window_list = copy_window_info(all_options, kCGNullWindowID).ok_or_else(|| {
            TapirError::WindowScanFailed {
                message: "CGWindowListCopyWindowInfo returned null".into(),
            }
        })?;

        // Pass 2: on-screen window IDs.
        let on_screen_options =
            kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements;
        let on_screen_ids: HashSet<u32> = copy_window_info(on_screen_options, kCGNullWindowID)
            .map(|list| {
                list.iter()
                    .filter_map(|entry| {
                        let dict: CFDictionary<CFString, *const core::ffi::c_void> =
                            unsafe { TCFType::wrap_under_get_rule(*entry as _) };
                        cf_dict_get_i64_key(&dict, &key_window_number).map(|id| id as u32)
                    })
                    .collect()
            })
            .unwrap_or_default();

        let my_pid = std::process::id() as i32;

        // Filter and collect raw windows.
        let mut raw_windows: Vec<RawWindow> = Vec::new();
        for entry in window_list.iter() {
            let dict: CFDictionary<CFString, *const core::ffi::c_void> =
                unsafe { TCFType::wrap_under_get_rule(*entry as _) };

            // Required fields.
            let window_id = match cf_dict_get_i64_key(&dict, &key_window_number) {
                Some(v) => v as u32,
                None => continue,
            };
            let pid = match cf_dict_get_i64_key(&dict, &key_owner_pid) {
                Some(v) => v as i32,
                None => continue,
            };
            let layer = match cf_dict_get_i64_key(&dict, &key_layer) {
                Some(v) => v,
                None => continue,
            };

            // Only normal windows (layer 0).
            if layer != 0 {
                continue;
            }

            // Skip own process.
            if pid == my_pid {
                continue;
            }

            let owner_name = cf_dict_get_string_key(&dict, &key_owner_name).unwrap_or_default();
            let window_name =
                cf_dict_get_string_key(&dict, &key_window_name).unwrap_or_default();

            // Skip windows with neither name.
            if owner_name.is_empty() && window_name.is_empty() {
                continue;
            }

            raw_windows.push(RawWindow {
                window_id,
                owner_name,
                window_name,
                pid,
                is_on_screen: on_screen_ids.contains(&window_id),
            });
        }

        // Collect unique PIDs that own at least one window.
        let unique_pids: HashSet<i32> = raw_windows.iter().map(|w| w.pid).collect();

        // Parent PID for each windowed process.
        let mut pid_to_parent_pid: HashMap<i32, i32> = HashMap::new();
        for &pid in &unique_pids {
            pid_to_parent_pid.insert(pid, get_parent_pid(pid));
        }

        // Build full process tree, then keep only windowed children.
        let full_child_map = build_child_pid_map();
        let mut pid_to_windowed_children: HashMap<i32, Vec<i32>> = HashMap::new();
        for &pid in &unique_pids {
            let windowed_children: Vec<i32> = full_child_map
                .get(&pid)
                .map(|children| {
                    children
                        .iter()
                        .filter(|c| unique_pids.contains(c))
                        .copied()
                        .collect()
                })
                .unwrap_or_default();
            if !windowed_children.is_empty() {
                pid_to_windowed_children.insert(pid, windowed_children);
            }
        }

        // Set of PIDs that are children of another windowed process.
        let child_pid_set: HashSet<i32> = pid_to_windowed_children
            .values()
            .flat_map(|children| children.iter().copied())
            .collect();

        // Window count per PID.
        let mut pid_window_count: HashMap<i32, u32> = HashMap::new();
        for raw in &raw_windows {
            *pid_window_count.entry(raw.pid).or_insert(0) += 1;
        }

        // Build final WindowInfo vec.
        let mut windows: Vec<WindowInfo> = Vec::with_capacity(raw_windows.len());
        for raw in &raw_windows {
            let parent_pid = *pid_to_parent_pid.get(&raw.pid).unwrap_or(&0);
            let is_child = child_pid_set.contains(&raw.pid);
            let child_pids = pid_to_windowed_children.get(&raw.pid);
            let sub_window_count = *pid_window_count.get(&raw.pid).unwrap_or(&1);

            let mut parent_windowed_pid: i32 = 0;
            if is_child {
                for (&candidate, children) in &pid_to_windowed_children {
                    if children.contains(&raw.pid) {
                        parent_windowed_pid = candidate;
                        break;
                    }
                }
            }

            windows.push(WindowInfo {
                id: raw.window_id,
                owner_name: raw.owner_name.clone(),
                window_name: raw.window_name.clone(),
                pid: raw.pid,
                parent_pid,
                parent_windowed_pid,
                is_child_process: is_child,
                child_process_count: child_pids.map_or(0, |c| c.len() as u32),
                sub_window_count,
                is_on_screen: raw.is_on_screen,
            });
        }

        Ok(windows)
    }
}

// ── Non-macOS stub ───────────────────────────────────────────────────
#[cfg(not(target_os = "macos"))]
mod platform {
    use crate::models::{TapirError, WindowInfo};

    pub fn scan_windows() -> Result<Vec<WindowInfo>, TapirError> {
        Ok(Vec::new())
    }
}

// ── Re-export ────────────────────────────────────────────────────────
pub use platform::scan_windows;
