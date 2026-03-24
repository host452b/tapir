use tapir::tapir_core::key_codes;

#[test]
fn test_lookup_letter_keys() {
    assert_eq!(key_codes::lookup("A"), Some(0));
    assert_eq!(key_codes::lookup("S"), Some(1));
    assert_eq!(key_codes::lookup("Z"), Some(6));
}

#[test]
fn test_lookup_special_keys() {
    assert_eq!(key_codes::lookup("Return"), Some(36));
    assert_eq!(key_codes::lookup("Tab"), Some(48));
    assert_eq!(key_codes::lookup("Space"), Some(49));
    assert_eq!(key_codes::lookup("Delete"), Some(51));
    assert_eq!(key_codes::lookup("Escape"), Some(53));
}

#[test]
fn test_lookup_function_keys() {
    assert_eq!(key_codes::lookup("F1"), Some(122));
    assert_eq!(key_codes::lookup("F12"), Some(111));
}

#[test]
fn test_lookup_arrow_keys() {
    assert_eq!(key_codes::lookup("Left"), Some(123));
    assert_eq!(key_codes::lookup("Right"), Some(124));
    assert_eq!(key_codes::lookup("Down"), Some(125));
    assert_eq!(key_codes::lookup("Up"), Some(126));
}

#[test]
fn test_lookup_unknown_key() {
    assert_eq!(key_codes::lookup("INVALID"), None);
}

#[test]
fn test_all_key_names_non_empty() {
    let names = key_codes::all_key_names();
    assert!(
        names.len() > 50,
        "Expected more than 50 key names, got {}",
        names.len()
    );
}
