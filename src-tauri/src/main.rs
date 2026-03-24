// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
#![deny(unused_imports, dead_code)]

mod commands;
mod models;
mod state;

#[path = "core/mod.rs"]
mod tapir_core;

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(commands::sender::SenderState(
            tokio::sync::Mutex::new(None),
        ))
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
