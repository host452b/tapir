use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum TapirError {
    NoPermission,
    EventCreationFailed { message: String },
    InvalidTarget { pid: i32 },
    NoStepsConfigured,
    WindowScanFailed { message: String },
    SendFailed { message: String },
}

impl std::fmt::Display for TapirError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            TapirError::NoPermission => write!(f, "Accessibility permission not granted"),
            TapirError::EventCreationFailed { message } => {
                write!(f, "Event creation failed: {}", message)
            }
            TapirError::InvalidTarget { pid } => {
                write!(f, "Invalid target process: pid {}", pid)
            }
            TapirError::NoStepsConfigured => write!(f, "No key steps configured"),
            TapirError::WindowScanFailed { message } => {
                write!(f, "Window scan failed: {}", message)
            }
            TapirError::SendFailed { message } => {
                write!(f, "Send failed: {}", message)
            }
        }
    }
}

impl std::error::Error for TapirError {}

// Tauri v2 provides a blanket `impl<T: Serialize> From<T> for InvokeError`,
// so TapirError is automatically convertible via Serialize — no manual impl needed.
