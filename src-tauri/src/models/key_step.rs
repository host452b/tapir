use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct KeyStep {
    pub id: String,
    pub mode: StepMode,
    pub key_name: String,
    pub with_command: bool,
    pub with_shift: bool,
    pub with_option: bool,
    pub with_control: bool,
    pub text_content: String,
    pub append_enter: bool,
    pub has_prefix_key: bool,
    pub prefix_key_name: String,
    pub has_suffix_key: bool,
    pub suffix_key_name: String,
}

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum StepMode {
    Key,
    Text,
    Combo,
}
