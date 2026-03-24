//! Tauri IPC commands for the sender state machine.

use tauri::{AppHandle, State};
use tokio::sync::Mutex;

use crate::models::log_entry::SenderStatus;
use crate::models::{KeyStep, TapirError, WindowInfo};
use crate::state::SenderManager;

/// Managed state wrapper so Tauri can inject it.
pub struct SenderState(pub Mutex<Option<SenderManager>>);

#[tauri::command]
pub async fn start_sending(
    state: State<'_, SenderState>,
    app_handle: AppHandle,
    targets: Vec<WindowInfo>,
    steps: Vec<KeyStep>,
    interval_ms: u64,
    repeat_count: u64,
) -> Result<(), TapirError> {
    let mut guard = state.0.lock().await;

    // Stop any existing sender first
    if let Some(ref mut mgr) = *guard {
        mgr.stop().await;
    }

    let mut mgr = SenderManager::new(app_handle);
    mgr.start(targets, steps, interval_ms, repeat_count).await?;
    *guard = Some(mgr);
    Ok(())
}

#[tauri::command]
pub async fn pause_sending(state: State<'_, SenderState>) -> Result<(), TapirError> {
    let mut guard = state.0.lock().await;
    if let Some(ref mut mgr) = *guard {
        mgr.pause().await;
    }
    Ok(())
}

#[tauri::command]
pub async fn resume_sending(state: State<'_, SenderState>) -> Result<(), TapirError> {
    let mut guard = state.0.lock().await;
    if let Some(ref mut mgr) = *guard {
        mgr.resume().await;
    }
    Ok(())
}

#[tauri::command]
pub async fn stop_sending(state: State<'_, SenderState>) -> Result<(), TapirError> {
    let mut guard = state.0.lock().await;
    if let Some(ref mut mgr) = *guard {
        mgr.stop().await;
    }
    *guard = None;
    Ok(())
}

#[tauri::command]
pub async fn get_sender_status(state: State<'_, SenderState>) -> Result<SenderStatus, TapirError> {
    let guard = state.0.lock().await;
    match &*guard {
        Some(mgr) => Ok(mgr.status().await),
        None => Ok(SenderStatus {
            state: crate::models::log_entry::SendingState::Idle,
            send_count: 0,
            cycles_completed: 0,
        }),
    }
}
