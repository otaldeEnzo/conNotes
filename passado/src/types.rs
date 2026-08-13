use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, PartialEq, Debug, Serialize, Deserialize)]
pub enum PaperMode {
    DotGrid,       // Pontilhado dinâmico
    Grid,          // Quadriculado
    Lined,         // Pautado (Caderno com Margem Vermelha)
    Isometric,     // Isométrico
    Hexagonal,     // Hexagonal Honeycomb (Química Orgânica)
    IsometricDots, // Pontos Isométricos
    Blank,         // Liso
}

impl PaperMode {
    pub fn icon(&self) -> &'static str {
        match self {
            PaperMode::DotGrid => "⠶",
            PaperMode::Grid => "▦",
            PaperMode::Lined => "≡",
            PaperMode::Isometric => "⟁",
            PaperMode::Hexagonal => "⬢",
            PaperMode::IsometricDots => "⋮",
            PaperMode::Blank => "□",
        }
    }
}

#[derive(Clone, PartialEq, Debug, Serialize, Deserialize)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

#[derive(Clone, PartialEq, Debug, Serialize, Deserialize)]
pub struct Stroke {
    pub points: Vec<Point>,
    pub color: String,
    pub thickness: f64,
    pub is_highlighter: bool,
}

#[derive(Clone, PartialEq, Debug, Serialize, Deserialize)]
pub struct NoteCard {
    pub id: usize,
    pub number: String,
    pub card_type: String, // "math", "plot", "code", "text"
    pub title: String,
    pub content: String,
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    pub selected: bool,
    #[serde(default)]
    pub collapsed: bool,
    #[serde(default)]
    pub locked: bool,
    #[serde(default)]
    pub accent_color: Option<String>,
}

#[derive(Clone, PartialEq, Debug, Serialize, Deserialize)]
pub struct Connector {
    pub id: usize,
    pub from_id: usize,
    pub to_id: usize,
    pub color: String,
    #[serde(default)]
    pub label: Option<String>,
    #[serde(default)]
    pub line_style: Option<String>,
}

#[derive(Clone, PartialEq, Debug, Serialize, Deserialize)]
pub struct NoteItem {
    pub id: usize,
    pub title: String,
    pub parent_id: Option<usize>,
    pub folder_id: Option<usize>,
    pub icon: String,
    pub cards: Vec<NoteCard>,
    pub connectors: Vec<Connector>,
    pub strokes: Vec<Stroke>,
    pub tags: Vec<String>,
    #[serde(default)]
    pub paper_mode: Option<PaperMode>,
    #[serde(default)]
    pub note_type: Option<String>,
}

#[derive(Clone, PartialEq, Debug, Serialize, Deserialize)]
pub struct FolderItem {
    pub id: usize,
    pub name: String,
    pub expanded: bool,
    pub parent_id: Option<usize>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum OperationDelta {
    FullSync {
        folders: Vec<FolderItem>,
        notes: Vec<NoteItem>,
    },
    MoveCard {
        note_id: usize,
        card_id: usize,
        x: f64,
        y: f64,
    },
    ResizeCard {
        note_id: usize,
        card_id: usize,
        width: f64,
        height: f64,
    },
    AddCard {
        note_id: usize,
        card: NoteCard,
    },
    DeleteCard {
        note_id: usize,
        card_id: usize,
    },
    AddStroke {
        note_id: usize,
        stroke: Stroke,
    },
    ClearStrokes {
        note_id: usize,
    },
    UpdateCardText {
        note_id: usize,
        card_id: usize,
        content: String,
    },
    PairingRequest {
        pin: String,
        device_id: String,
        device_name: String,
    },
    PairingResponse {
        success: bool,
        device_id: String,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SyncMessage {
    pub sender_id: String,
    pub delta: OperationDelta,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct UserProfile {
    pub user_id: String,
    pub device_name: String,
    pub secret_pin: String,
    pub created_at: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DeviceItem {
    pub device_id: String,
    pub device_name: String,
    pub paired_at: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CustomThemePreset {
    pub name: String,
    pub color_bg: String,
    pub color_details: String,
    pub color_accent: String,
    pub color_neon: String,
    pub color_text: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct VisualConfig {
    pub smart_snap: String, // "10px", "20px", "50px", "free"
    pub smart_guides: bool,
    pub theme_preset: String, // "Nebulosa Escura", "Grid Cyberpunk", "Aurora Boreal", "Circuito Digital"
    pub performance_preset: String, // "ultra", "balanced", "battery"
    pub typography_font: String,
    pub font_size: String,
    pub line_height: String,
    pub letter_spacing: String,
    // theme studio granular colors
    pub color_bg: String,
    pub color_details: String,
    pub color_accent: String,
    pub color_neon: String,
    pub color_text: String,
    pub custom_bg_image: Option<String>,
    #[serde(default)]
    pub saved_user_themes: Vec<CustomThemePreset>,
}

impl Default for VisualConfig {
    fn default() -> Self {
        Self {
            smart_snap: "20px".to_string(),
            smart_guides: true,
            theme_preset: "Aurora Boreal".to_string(),
            performance_preset: "ultra".to_string(),
            typography_font: "Inter".to_string(),
            font_size: "14px".to_string(),
            line_height: "1.5".to_string(),
            letter_spacing: "0px".to_string(),
            color_bg: "#05070c".to_string(),
            color_details: "#1a1e29".to_string(),
            color_accent: "#00e1ff".to_string(),
            color_neon: "#00e1ff".to_string(),
            color_text: "#ffffff".to_string(),
            custom_bg_image: None,
            saved_user_themes: vec![],
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AppSettings {
    #[serde(default = "default_sound")]
    pub sound_enabled: bool,
    #[serde(default = "default_volume")]
    pub ui_volume: String,
    #[serde(default = "default_language")]
    pub language: String,
    #[serde(default = "default_shortcuts")]
    pub shortcuts: std::collections::HashMap<String, String>,
}

fn default_sound() -> bool { true }
fn default_volume() -> String { "50".to_string() }
fn default_language() -> String { "pt".to_string() }
fn default_shortcuts() -> std::collections::HashMap<String, String> {
    let mut map = std::collections::HashMap::new();
    map.insert("Ctrl+K".to_string(), "omnibar".to_string());
    map.insert("Ctrl+N".to_string(), "new_note".to_string());
    map.insert("Delete".to_string(), "delete_card".to_string());
    map
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            sound_enabled: default_sound(),
            ui_volume: default_volume(),
            language: default_language(),
            shortcuts: default_shortcuts(),
        }
    }
}
