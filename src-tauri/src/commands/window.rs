//! Tauri IPC commands for window scanning and validation.

use crate::models::{TapirError, WindowInfo};
use crate::tapir_core::{process, window_scanner};

#[tauri::command]
pub fn scan_windows() -> Result<Vec<WindowInfo>, TapirError> {
    window_scanner::scan_windows()
}

/// Validate a list of windows.
///
/// Accepts a list of `(window_id, pid)` tuples and returns the PIDs of any
/// that are no longer alive.
#[tauri::command]
pub fn validate_windows(windows: Vec<(u32, i32)>) -> Vec<i32> {
    windows
        .into_iter()
        .filter(|(wid, pid)| !process::is_window_valid(*wid, *pid))
        .map(|(_wid, pid)| pid)
        .collect()
}
