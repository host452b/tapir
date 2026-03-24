//! Tauri IPC commands for Accessibility permission management.

use crate::tapir_core::accessibility;

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
