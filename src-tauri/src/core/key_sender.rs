//! Key event sender — synthesizes and posts CGEvent keyboard events.
//!
//! Ports the logic from `TapirApp/Services/KeyEventSender.swift`.
//! The timing values (5ms, 8ms, 10ms, 20ms, 30ms) are empirically tuned
//! and must be preserved.

// ── macOS implementation ──────────────────────────────────────────────
#[cfg(target_os = "macos")]
mod platform {
    use std::thread;
    use std::time::Duration;

    use core_graphics::event::{CGEvent, CGEventFlags, CGEventTapLocation};
    use core_graphics::event_source::{CGEventSource, CGEventSourceStateID};

    use crate::tapir_core::accessibility;
    use crate::models::TapirError;

    /// Activate the window belonging to the given PID by bringing its
    /// application to the foreground.
    pub fn activate_window(pid: i32) -> Result<(), TapirError> {
        use objc2_app_kit::{NSApplicationActivationOptions, NSRunningApplication};

        let app = NSRunningApplication::runningApplicationWithProcessIdentifier(pid)
            .ok_or(TapirError::InvalidTarget { pid })?;

        #[allow(deprecated)] // ActivateIgnoringOtherApps deprecated in macOS 14
        app.activateWithOptions(NSApplicationActivationOptions::ActivateIgnoringOtherApps);

        thread::sleep(Duration::from_millis(50));
        Ok(())
    }

    /// Send a keyboard event (key down + key up) with optional modifier flags.
    pub fn send_key(key_code: u16, modifiers: Vec<String>) -> Result<(), TapirError> {
        if !accessibility::is_trusted() {
            return Err(TapirError::NoPermission);
        }

        let source = CGEventSource::new(CGEventSourceStateID::HIDSystemState).map_err(|()| {
            TapirError::EventCreationFailed {
                message: "failed to create CGEventSource".into(),
            }
        })?;

        let flags = map_modifier_flags(&modifiers);

        let key_down =
            CGEvent::new_keyboard_event(source.clone(), key_code, true).map_err(|()| {
                TapirError::EventCreationFailed {
                    message: format!("failed to create key-down event for keycode {}", key_code),
                }
            })?;
        let key_up =
            CGEvent::new_keyboard_event(source, key_code, false).map_err(|()| {
                TapirError::EventCreationFailed {
                    message: format!("failed to create key-up event for keycode {}", key_code),
                }
            })?;

        key_down.set_flags(flags);
        key_up.set_flags(flags);

        key_down.post(CGEventTapLocation::HID);
        thread::sleep(Duration::from_millis(10));
        key_up.post(CGEventTapLocation::HID);

        Ok(())
    }

    /// Type a string character-by-character using unicode key events.
    ///
    /// Each character is encoded to UTF-16 and sent as a key-down/key-up pair
    /// with keycode 0. If `append_enter` is true, a Return key (code 36) is
    /// sent after the text.
    pub fn send_text(text: &str, append_enter: bool) -> Result<(), TapirError> {
        if !accessibility::is_trusted() {
            return Err(TapirError::NoPermission);
        }

        let source = CGEventSource::new(CGEventSourceStateID::HIDSystemState).map_err(|()| {
            TapirError::EventCreationFailed {
                message: "failed to create CGEventSource".into(),
            }
        })?;

        for ch in text.chars() {
            let utf16: Vec<u16> = ch.encode_utf16(&mut [0u16; 2]).to_vec();

            let key_down = CGEvent::new_keyboard_event(source.clone(), 0, true).map_err(|()| {
                TapirError::EventCreationFailed {
                    message: "failed to create key-down event for text char".into(),
                }
            })?;
            let key_up = CGEvent::new_keyboard_event(source.clone(), 0, false).map_err(|()| {
                TapirError::EventCreationFailed {
                    message: "failed to create key-up event for text char".into(),
                }
            })?;

            key_down.set_string_from_utf16_unchecked(&utf16);
            key_up.set_string_from_utf16_unchecked(&utf16);

            key_down.post(CGEventTapLocation::HID);
            thread::sleep(Duration::from_millis(5));
            key_up.post(CGEventTapLocation::HID);
            thread::sleep(Duration::from_millis(8));
        }

        if append_enter {
            thread::sleep(Duration::from_millis(10));
            let flags = CGEventFlags::CGEventFlagNull;
            post_single_key(&source, 36, flags)?; // 36 = Return
        }

        Ok(())
    }

    /// Execute a combo sequence: optional prefix key, type text, optional suffix key.
    pub fn send_combo(
        text: &str,
        prefix_key_code: Option<u16>,
        suffix_key_code: Option<u16>,
    ) -> Result<(), TapirError> {
        if !accessibility::is_trusted() {
            return Err(TapirError::NoPermission);
        }

        let source = CGEventSource::new(CGEventSourceStateID::HIDSystemState).map_err(|()| {
            TapirError::EventCreationFailed {
                message: "failed to create CGEventSource".into(),
            }
        })?;

        let flags = CGEventFlags::CGEventFlagNull;

        // Prefix key
        if let Some(code) = prefix_key_code {
            post_single_key(&source, code, flags)?;
            thread::sleep(Duration::from_millis(30));
        }

        // Type text characters
        for ch in text.chars() {
            let utf16: Vec<u16> = ch.encode_utf16(&mut [0u16; 2]).to_vec();

            let key_down = CGEvent::new_keyboard_event(source.clone(), 0, true).map_err(|()| {
                TapirError::EventCreationFailed {
                    message: "failed to create key-down event for combo text char".into(),
                }
            })?;
            let key_up = CGEvent::new_keyboard_event(source.clone(), 0, false).map_err(|()| {
                TapirError::EventCreationFailed {
                    message: "failed to create key-up event for combo text char".into(),
                }
            })?;

            key_down.set_string_from_utf16_unchecked(&utf16);
            key_up.set_string_from_utf16_unchecked(&utf16);

            key_down.post(CGEventTapLocation::HID);
            thread::sleep(Duration::from_millis(5));
            key_up.post(CGEventTapLocation::HID);
            thread::sleep(Duration::from_millis(8));
        }

        // Suffix key
        if let Some(code) = suffix_key_code {
            thread::sleep(Duration::from_millis(20));
            post_single_key(&source, code, flags)?;
        }

        Ok(())
    }

    /// Post a single key down + key up via the HID event tap.
    fn post_single_key(
        source: &CGEventSource,
        key_code: u16,
        flags: CGEventFlags,
    ) -> Result<(), TapirError> {
        let key_down =
            CGEvent::new_keyboard_event(source.clone(), key_code, true).map_err(|()| {
                TapirError::EventCreationFailed {
                    message: format!(
                        "failed to create key-down event for keycode {}",
                        key_code
                    ),
                }
            })?;
        let key_up =
            CGEvent::new_keyboard_event(source.clone(), key_code, false).map_err(|()| {
                TapirError::EventCreationFailed {
                    message: format!("failed to create key-up event for keycode {}", key_code),
                }
            })?;

        key_down.set_flags(flags);
        key_up.set_flags(flags);

        key_down.post(CGEventTapLocation::HID);
        thread::sleep(Duration::from_millis(10));
        key_up.post(CGEventTapLocation::HID);

        Ok(())
    }

    /// Map modifier name strings to CGEventFlags.
    fn map_modifier_flags(modifiers: &[String]) -> CGEventFlags {
        let mut flags = CGEventFlags::CGEventFlagNull;
        for modifier in modifiers {
            match modifier.as_str() {
                "command" => flags |= CGEventFlags::CGEventFlagCommand,
                "shift" => flags |= CGEventFlags::CGEventFlagShift,
                "option" | "alt" => flags |= CGEventFlags::CGEventFlagAlternate,
                "control" => flags |= CGEventFlags::CGEventFlagControl,
                _ => {}
            }
        }
        flags
    }
}

// ── Non-macOS stubs ───────────────────────────────────────────────────
#[cfg(not(target_os = "macos"))]
mod platform {
    use crate::models::TapirError;

    pub fn activate_window(_pid: i32) -> Result<(), TapirError> {
        Err(TapirError::SendFailed {
            message: "activate_window is only supported on macOS".into(),
        })
    }

    pub fn send_key(_key_code: u16, _modifiers: Vec<String>) -> Result<(), TapirError> {
        Err(TapirError::SendFailed {
            message: "send_key is only supported on macOS".into(),
        })
    }

    pub fn send_text(_text: &str, _append_enter: bool) -> Result<(), TapirError> {
        Err(TapirError::SendFailed {
            message: "send_text is only supported on macOS".into(),
        })
    }

    pub fn send_combo(
        _text: &str,
        _prefix_key_code: Option<u16>,
        _suffix_key_code: Option<u16>,
    ) -> Result<(), TapirError> {
        Err(TapirError::SendFailed {
            message: "send_combo is only supported on macOS".into(),
        })
    }
}

// ── Re-exports ────────────────────────────────────────────────────────
pub use platform::{activate_window, send_combo, send_key, send_text};
