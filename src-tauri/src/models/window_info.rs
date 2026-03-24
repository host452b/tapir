use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct WindowInfo {
    pub id: u32,
    pub owner_name: String,
    pub window_name: String,
    pub pid: i32,
    pub parent_pid: i32,
    pub parent_windowed_pid: i32,
    pub is_child_process: bool,
    pub child_process_count: u32,
    pub sub_window_count: u32,
    pub is_on_screen: bool,
}
