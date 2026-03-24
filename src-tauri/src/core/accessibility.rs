//! Accessibility permission helpers for macOS.
//!
//! Wraps the Accessibility API to check and request permission for
//! CGEvent-based keyboard automation.

// ── macOS implementation ──────────────────────────────────────────────
#[cfg(target_os = "macos")]
mod platform {
    use core_foundation::base::TCFType;
    use core_foundation::boolean::CFBoolean;
    use core_foundation::dictionary::CFDictionary;
    use core_foundation::string::CFString;

    #[link(name = "ApplicationServices", kind = "framework")]
    extern "C" {
        fn AXIsProcessTrusted() -> bool;
        fn AXIsProcessTrustedWithOptions(options: core_foundation::dictionary::CFDictionaryRef) -> bool;
    }

    /// Returns `true` if this process already has Accessibility permission.
    pub fn is_trusted() -> bool {
        unsafe { AXIsProcessTrusted() }
    }

    /// Asks the system to prompt the user for Accessibility permission.
    ///
    /// Returns `true` if permission is already granted (the prompt is still
    /// shown when it is not).
    pub fn request_with_prompt() -> bool {
        let key = CFString::new("AXTrustedCheckOptionPrompt");
        let value = CFBoolean::true_value();
        let pairs = [(key, value)];
        let options = CFDictionary::from_CFType_pairs(&pairs);

        unsafe { AXIsProcessTrustedWithOptions(options.as_concrete_TypeRef()) }
    }

    /// Opens System Settings at the Accessibility privacy pane.
    pub fn open_settings() {
        use objc2_app_kit::NSWorkspace;
        use objc2_foundation::{NSString, NSURL};

        let url_string =
            NSString::from_str("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility");
        if let Some(url) = NSURL::URLWithString(&url_string) {
            let workspace = NSWorkspace::sharedWorkspace();
            workspace.openURL(&url);
        }
    }
}

// ── Non-macOS stubs ───────────────────────────────────────────────────
#[cfg(not(target_os = "macos"))]
mod platform {
    pub fn is_trusted() -> bool {
        false
    }

    pub fn request_with_prompt() -> bool {
        false
    }

    pub fn open_settings() {}
}

// ── Re-exports ────────────────────────────────────────────────────────
pub use platform::{is_trusted, open_settings, request_with_prompt};
