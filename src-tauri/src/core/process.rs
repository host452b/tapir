//! Process and window validation helpers.
//!
//! Used to check whether a target window/process is still alive before
//! attempting to send keystrokes.

/// Returns `true` if a process with the given `pid` is still running.
///
/// Uses `kill(pid, 0)` which checks for existence without sending a signal.
pub fn is_process_alive(pid: i32) -> bool {
    if pid <= 0 {
        return false;
    }
    unsafe { libc::kill(pid, 0) == 0 }
}

// ── macOS implementation ──────────────────────────────────────────────
#[cfg(target_os = "macos")]
mod platform {
    use core_foundation::base::TCFType;
    use core_graphics::window::{
        copy_window_info, kCGNullWindowID, kCGWindowListExcludeDesktopElements,
        kCGWindowListOptionAll, kCGWindowNumber,
    };

    /// Returns `true` if a window with `window_id` still exists.
    ///
    /// Queries the system window list and searches for a matching window number.
    /// Falls back to [`super::is_process_alive`] if the window is not found.
    pub fn is_window_valid(window_id: u32, pid: i32) -> bool {
        let options = kCGWindowListOptionAll | kCGWindowListExcludeDesktopElements;
        if let Some(window_list) = copy_window_info(options, kCGNullWindowID) {
            for entry in window_list.iter() {
                // Each entry is a CFDictionary behind a void pointer.
                use core_foundation::dictionary::CFDictionary;
                use core_foundation::number::CFNumber;
                use core_foundation::string::CFString;

                let dict: CFDictionary<CFString, *const core::ffi::c_void> =
                    unsafe { TCFType::wrap_under_get_rule(*entry as _) };

                let key = unsafe { CFString::wrap_under_get_rule(kCGWindowNumber) };
                if let Some(num_ref) = dict.find(key.as_concrete_TypeRef()) {
                    let num: CFNumber =
                        unsafe { TCFType::wrap_under_get_rule(*num_ref as _) };
                    if let Some(wid) = num.to_i64() {
                        if wid as u32 == window_id {
                            return true;
                        }
                    }
                }
            }
        }

        // Window not found in list — fall back to PID alive check.
        super::is_process_alive(pid)
    }
}

// ── Non-macOS stub ────────────────────────────────────────────────────
#[cfg(not(target_os = "macos"))]
mod platform {
    pub fn is_window_valid(_window_id: u32, pid: i32) -> bool {
        super::is_process_alive(pid)
    }
}

pub use platform::is_window_valid;
