//! SenderManager — state machine that drives the send loop.
//!
//! Spawns two tokio tasks:
//!   1. **send loop** — iterates steps across all targets, respects pause/resume.
//!   2. **validation loop** — every 3 s checks that target processes are alive.

use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;

use tauri::{AppHandle, Emitter};
use tokio::sync::{Mutex, Notify};
use tokio_util::sync::CancellationToken;

use crate::models::log_entry::{SenderStatus, SendingState};
use crate::models::{KeyStep, LogEntry, StepMode, TapirError, WindowInfo};
use crate::tapir_core::{key_codes, key_sender, process};

// ── SenderManager ────────────────────────────────────────────────────

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

    pub async fn status(&self) -> SenderStatus {
        let state = self.state.lock().await.clone();
        SenderStatus {
            state,
            send_count: self.send_count.load(Ordering::Relaxed),
            cycles_completed: self.cycles_completed.load(Ordering::Relaxed),
        }
    }

    pub async fn start(
        &mut self,
        targets: Vec<WindowInfo>,
        steps: Vec<KeyStep>,
        interval_ms: u64,
        repeat_count: u64,
    ) -> Result<(), TapirError> {
        if steps.is_empty() {
            return Err(TapirError::NoStepsConfigured);
        }
        if targets.is_empty() {
            return Err(TapirError::SendFailed {
                message: "No targets selected".into(),
            });
        }

        // Reset counters
        self.send_count.store(0, Ordering::Relaxed);
        self.cycles_completed.store(0, Ordering::Relaxed);

        // Set state to Running
        {
            let mut s = self.state.lock().await;
            *s = SendingState::Running;
        }

        let token = CancellationToken::new();
        self.cancel_token = Some(token.clone());

        let shared_targets: Arc<Mutex<Vec<WindowInfo>>> = Arc::new(Mutex::new(targets));

        // Emit initial state change
        emit_state_change(&self.app_handle, SendingState::Running);

        // Spawn send loop
        {
            let state = Arc::clone(&self.state);
            let send_count = Arc::clone(&self.send_count);
            let cycles_completed = Arc::clone(&self.cycles_completed);
            let pause_notify = Arc::clone(&self.pause_notify);
            let token = token.clone();
            let targets = Arc::clone(&shared_targets);
            let app_handle = self.app_handle.clone();

            tokio::spawn(async move {
                send_loop(
                    state,
                    send_count,
                    cycles_completed,
                    pause_notify,
                    token,
                    targets,
                    steps,
                    interval_ms,
                    repeat_count,
                    app_handle,
                )
                .await;
            });
        }

        // Spawn validation loop
        {
            let token = token.clone();
            let targets = Arc::clone(&shared_targets);
            let app_handle = self.app_handle.clone();
            let state = Arc::clone(&self.state);
            let pause_notify = Arc::clone(&self.pause_notify);

            tokio::spawn(async move {
                validation_loop(token, targets, app_handle, state, pause_notify).await;
            });
        }

        Ok(())
    }

    pub async fn pause(&mut self) {
        let mut s = self.state.lock().await;
        if *s == SendingState::Running {
            *s = SendingState::Paused;
            emit_state_change(&self.app_handle, SendingState::Paused);
        }
    }

    pub async fn resume(&mut self) {
        let mut s = self.state.lock().await;
        if *s == SendingState::Paused {
            *s = SendingState::Running;
            self.pause_notify.notify_one();
            emit_state_change(&self.app_handle, SendingState::Running);
        }
    }

    pub async fn stop(&mut self) {
        if let Some(token) = self.cancel_token.take() {
            token.cancel();
        }
        // Wake up the pause notify in case the send loop is waiting
        self.pause_notify.notify_one();

        let mut s = self.state.lock().await;
        *s = SendingState::Idle;
        self.send_count.store(0, Ordering::Relaxed);
        self.cycles_completed.store(0, Ordering::Relaxed);
        emit_state_change(&self.app_handle, SendingState::Idle);
    }
}

// ── Send loop ────────────────────────────────────────────────────────

async fn send_loop(
    state: Arc<Mutex<SendingState>>,
    send_count: Arc<AtomicU64>,
    cycles_completed: Arc<AtomicU64>,
    pause_notify: Arc<Notify>,
    token: CancellationToken,
    shared_targets: Arc<Mutex<Vec<WindowInfo>>>,
    steps: Vec<KeyStep>,
    interval_ms: u64,
    repeat_count: u64,
    app_handle: AppHandle,
) {
    let mut step_index: usize = 0;

    loop {
        // Check cancellation
        if token.is_cancelled() {
            return;
        }

        // Respect pause
        {
            let s = state.lock().await;
            if *s == SendingState::Paused {
                drop(s);
                // Wait for resume or cancellation
                tokio::select! {
                    _ = pause_notify.notified() => {},
                    _ = token.cancelled() => return,
                }
                // Re-check after waking
                let s = state.lock().await;
                if *s == SendingState::Idle {
                    return;
                }
                continue;
            } else if *s == SendingState::Idle {
                return;
            }
        }

        // Get current targets snapshot
        let targets = {
            let t = shared_targets.lock().await;
            t.clone()
        };

        if targets.is_empty() {
            // Auto-pause if all targets are gone
            let mut s = state.lock().await;
            if *s == SendingState::Running {
                *s = SendingState::Paused;
                emit_state_change(&app_handle, SendingState::Paused);
                emit_log(
                    &app_handle,
                    "warning",
                    "All targets are gone - auto-paused",
                );
            }
            drop(s);
            // Wait for resume (new targets might be added) or cancellation
            tokio::select! {
                _ = pause_notify.notified() => {},
                _ = token.cancelled() => return,
            }
            continue;
        }

        let step = &steps[step_index];

        // Execute step against all targets
        for target in &targets {
            if token.is_cancelled() {
                return;
            }

            let step_name = step_display_name(step);

            // Activate window then send step — both are blocking CGEvent calls,
            // so run them on a blocking thread to avoid starving the tokio runtime.
            let pid = target.pid;
            let step_clone = step.clone();
            let result = tokio::task::spawn_blocking(move || -> Result<(), TapirError> {
                key_sender::activate_window(pid)?;
                send_step(&step_clone)?;
                Ok(())
            })
            .await;

            match result {
                Ok(Ok(())) => {
                    send_count.fetch_add(1, Ordering::Relaxed);
                    emit_log(
                        &app_handle,
                        "send",
                        &format!(
                            "Sent {} to {} (pid {})",
                            step_name, target.owner_name, target.pid
                        ),
                    );
                }
                Ok(Err(e)) => {
                    emit_log(
                        &app_handle,
                        "error",
                        &format!(
                            "Failed to send {} to {} (pid {}): {}",
                            step_name, target.owner_name, target.pid, e
                        ),
                    );
                }
                Err(join_err) => {
                    emit_log(
                        &app_handle,
                        "error",
                        &format!("Task panicked: {}", join_err),
                    );
                }
            }
        }

        // Advance step index and track cycles
        step_index += 1;
        if step_index >= steps.len() {
            step_index = 0;
            let completed = cycles_completed.fetch_add(1, Ordering::Relaxed) + 1;

            // repeat_count == 0 means infinite
            if repeat_count > 0 && completed >= repeat_count {
                emit_log(
                    &app_handle,
                    "info",
                    &format!("Completed {} cycles - stopping", completed),
                );
                let mut s = state.lock().await;
                *s = SendingState::Idle;
                emit_state_change(&app_handle, SendingState::Idle);
                return;
            }
        }

        // Wait for the interval before next step
        tokio::select! {
            _ = tokio::time::sleep(tokio::time::Duration::from_millis(interval_ms)) => {},
            _ = token.cancelled() => return,
        }
    }
}

// ── Validation loop ──────────────────────────────────────────────────

async fn validation_loop(
    token: CancellationToken,
    shared_targets: Arc<Mutex<Vec<WindowInfo>>>,
    app_handle: AppHandle,
    state: Arc<Mutex<SendingState>>,
    pause_notify: Arc<Notify>,
) {
    loop {
        tokio::select! {
            _ = tokio::time::sleep(tokio::time::Duration::from_secs(3)) => {},
            _ = token.cancelled() => return,
        }

        let mut targets = shared_targets.lock().await;
        let mut dead_pids: Vec<i32> = Vec::new();

        targets.retain(|t| {
            let alive = process::is_process_alive(t.pid);
            if !alive {
                dead_pids.push(t.pid);
            }
            alive
        });

        if !dead_pids.is_empty() {
            let _ = app_handle.emit("tapir://targets-invalidated", &dead_pids);
            emit_log(
                &app_handle,
                "warning",
                &format!("Removed dead targets: {:?}", dead_pids),
            );

            // If no targets remain, auto-pause
            if targets.is_empty() {
                drop(targets); // release lock before acquiring state lock
                let mut s = state.lock().await;
                if *s == SendingState::Running {
                    *s = SendingState::Paused;
                    emit_state_change(&app_handle, SendingState::Paused);
                    emit_log(
                        &app_handle,
                        "warning",
                        "All targets are gone - auto-paused",
                    );
                    pause_notify.notify_one();
                }
            }
        }
    }
}

// ── Helper: send a single step ───────────────────────────────────────

fn send_step(step: &KeyStep) -> Result<(), TapirError> {
    match step.mode {
        StepMode::Key => {
            let key_code = key_codes::lookup(&step.key_name).ok_or_else(|| {
                TapirError::SendFailed {
                    message: format!("Unknown key name: {}", step.key_name),
                }
            })?;
            let mut modifiers: Vec<String> = Vec::new();
            if step.with_command {
                modifiers.push("command".into());
            }
            if step.with_shift {
                modifiers.push("shift".into());
            }
            if step.with_option {
                modifiers.push("option".into());
            }
            if step.with_control {
                modifiers.push("control".into());
            }
            key_sender::send_key(key_code, modifiers)
        }
        StepMode::Text => key_sender::send_text(&step.text_content, step.append_enter),
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

// ── Helper: human-readable step name ─────────────────────────────────

fn step_display_name(step: &KeyStep) -> String {
    match step.mode {
        StepMode::Key => {
            let mut parts: Vec<&str> = Vec::new();
            if step.with_command {
                parts.push("Cmd");
            }
            if step.with_shift {
                parts.push("Shift");
            }
            if step.with_option {
                parts.push("Opt");
            }
            if step.with_control {
                parts.push("Ctrl");
            }
            parts.push(&step.key_name);
            parts.join("+")
        }
        StepMode::Text => {
            let preview = if step.text_content.len() > 20 {
                format!("{}...", &step.text_content[..20])
            } else {
                step.text_content.clone()
            };
            if step.append_enter {
                format!("Text \"{}\" + Enter", preview)
            } else {
                format!("Text \"{}\"", preview)
            }
        }
        StepMode::Combo => {
            let mut desc = String::new();
            if step.has_prefix_key {
                desc.push_str(&step.prefix_key_name);
                desc.push_str(" -> ");
            }
            let preview = if step.text_content.len() > 20 {
                format!("{}...", &step.text_content[..20])
            } else {
                step.text_content.clone()
            };
            desc.push_str(&format!("\"{}\"", preview));
            if step.has_suffix_key {
                desc.push_str(" -> ");
                desc.push_str(&step.suffix_key_name);
            }
            format!("Combo [{}]", desc)
        }
    }
}

// ── Event helpers ────────────────────────────────────────────────────

fn emit_state_change(app_handle: &AppHandle, state: SendingState) {
    let _ = app_handle.emit("tapir://state-change", &state);
}

fn emit_log(app_handle: &AppHandle, entry_type: &str, message: &str) {
    let entry = LogEntry::new(entry_type, message);
    let _ = app_handle.emit("tapir://log", &entry);
}
