use eframe::egui::{Color32, Rounding, Stroke};

/// Sistema de Design Centralizado: Liquid Glass Aesthetic & Paleta Aurora Boreal
pub struct LiquidGlassTheme;

impl LiquidGlassTheme {
    // --- CORES DE FUNDO & ATMOSFERA AURORA BOREAL ---
    pub fn bg_obsidian() -> Color32 {
        Color32::from_rgb(7, 9, 14) // #07090e
    }

    pub fn bg_glow_emerald() -> Color32 {
        Color32::from_rgba_unmultiplied(0, 255, 157, 20) // Verde Esmeralda Aurora
    }

    pub fn bg_glow_cyan() -> Color32 {
        Color32::from_rgba_unmultiplied(0, 225, 255, 22) // Ciano Boreal
    }

    pub fn bg_glow_purple() -> Color32 {
        Color32::from_rgba_unmultiplied(45, 15, 65, 40)
    }

    pub fn bg_glow_violet() -> Color32 {
        Color32::from_rgba_unmultiplied(157, 78, 221, 24) // Violeta Místico
    }

    // --- CORES DE PAINÉIS LIQUID GLASS ---
    pub fn glass_panel_bg() -> Color32 {
        Color32::from_rgba_unmultiplied(14, 18, 28, 225) // Deep Frosted Glass
    }

    pub fn glass_panel_border() -> Color32 {
        Color32::from_rgba_unmultiplied(255, 255, 255, 30) // Borda sutil de vidro
    }

    pub fn glass_header_bg() -> Color32 {
        Color32::from_rgba_unmultiplied(20, 26, 40, 190)
    }

    // --- ACCENTS & NEON AURORA GLOWS ---
    pub fn accent_emerald() -> Color32 {
        Color32::from_rgb(0, 255, 157)
    }

    pub fn accent_cyan() -> Color32 {
        Color32::from_rgb(0, 225, 255)
    }

    pub fn accent_violet() -> Color32 {
        Color32::from_rgb(157, 78, 221)
    }

    pub fn accent_gold() -> Color32 {
        Color32::from_rgb(255, 215, 0)
    }

    pub fn selected_border(color: Color32) -> Stroke {
        Stroke::new(1.8_f32, color)
    }

    pub fn normal_border() -> Stroke {
        Stroke::new(1.0_f32, Self::glass_panel_border())
    }

    // --- ARREDONDAMENTOS ORGÂNICOS ---
    pub fn panel_radius() -> Rounding {
        Rounding::same(16.0)
    }

    pub fn card_radius() -> Rounding {
        Rounding::same(14.0)
    }

    pub fn button_radius() -> Rounding {
        Rounding::same(8.0)
    }

    pub fn capsule_radius() -> Rounding {
        Rounding::same(24.0)
    }

    // --- TIPOGRAFIA ---
    pub fn text_primary() -> Color32 {
        Color32::from_rgb(240, 245, 255)
    }

    pub fn text_secondary() -> Color32 {
        Color32::from_rgb(150, 165, 185)
    }

    pub fn text_muted() -> Color32 {
        Color32::from_rgb(90, 105, 125)
    }
}
