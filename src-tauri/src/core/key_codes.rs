use std::collections::HashMap;
use std::sync::LazyLock;

/// Static mapping from key name to macOS CGKeyCode (u16).
///
/// These values match the virtual key codes used by CGEvent on macOS and
/// mirror the constants from the original SwiftUI KeyCodes.swift.
static KEY_MAP: LazyLock<HashMap<&'static str, u16>> = LazyLock::new(|| {
    let entries: Vec<(&str, u16)> = vec![
        // Letters
        ("A", 0),
        ("S", 1),
        ("D", 2),
        ("F", 3),
        ("H", 4),
        ("G", 5),
        ("Z", 6),
        ("X", 7),
        ("C", 8),
        ("V", 9),
        ("B", 11),
        ("Q", 12),
        ("W", 13),
        ("E", 14),
        ("R", 15),
        ("Y", 16),
        ("T", 17),
        ("O", 31),
        ("U", 32),
        ("I", 34),
        ("P", 35),
        ("L", 37),
        ("J", 38),
        ("K", 40),
        ("N", 45),
        ("M", 46),
        // Numbers
        ("1", 18),
        ("2", 19),
        ("3", 20),
        ("4", 21),
        ("5", 23),
        ("6", 22),
        ("7", 26),
        ("8", 28),
        ("9", 25),
        ("0", 29),
        // Symbols
        ("=", 24),
        ("-", 27),
        ("]", 30),
        ("[", 33),
        ("'", 39),
        (";", 41),
        ("\\", 42),
        (",", 43),
        ("/", 44),
        (".", 47),
        ("`", 50),
        // Special
        ("Return", 36),
        ("Tab", 48),
        ("Space", 49),
        ("Delete", 51),
        ("Escape", 53),
        ("ForwardDelete", 117),
        // Function keys
        ("F1", 122),
        ("F2", 120),
        ("F3", 99),
        ("F4", 118),
        ("F5", 96),
        ("F6", 97),
        ("F7", 98),
        ("F8", 100),
        ("F9", 101),
        ("F10", 109),
        ("F11", 103),
        ("F12", 111),
        // Arrow keys
        ("Left", 123),
        ("Right", 124),
        ("Down", 125),
        ("Up", 126),
        // Navigation
        ("Home", 115),
        ("End", 119),
        ("PageUp", 116),
        ("PageDown", 121),
    ];

    entries.into_iter().collect()
});

/// Look up a macOS virtual key code by name.
///
/// The name is case-sensitive and must match exactly (e.g. "A", "Return", "F1").
/// Returns `None` if the key name is not recognized.
pub fn lookup(name: &str) -> Option<u16> {
    KEY_MAP.get(name).copied()
}

/// Return all recognized key names in arbitrary order.
#[allow(dead_code)]
pub fn all_key_names() -> Vec<&'static str> {
    KEY_MAP.keys().copied().collect()
}
