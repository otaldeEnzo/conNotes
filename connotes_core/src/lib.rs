use serde::{Deserialize, Serialize};

/// Opções de Fundo do Canvas conforme regras do conNotes
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum BackgroundType {
    /// Matriz de pontos interativa com efeito Glow reativo ao ponteiro do mouse
    DotGrid,
    /// Linhas horizontais discretas para anotações manuscritas/caderno
    Pautado,
    /// Fundo limpo e minimalista
    EmBranco,
}

impl Default for BackgroundType {
    fn default() -> Self {
        BackgroundType::DotGrid
    }
}

/// Ponto 2D do Canvas com coordenada x, y e pressão da caneta (Stylus)
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct StrokePoint {
    pub x: f32,
    pub y: f32,
    pub pressure: f32,
    pub timestamp: u64,
}

/// Um traço vetorial de escrita/desenho manual
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InkStroke {
    pub id: String,
    pub points: Vec<StrokePoint>,
    pub color_rgba: [f32; 4],
    pub stroke_width: f32,
}

/// Estado global do Canvas Nativo mantido pelo Rust Core
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CanvasState {
    pub pan_x: f32,
    pub pan_y: f32,
    pub zoom: f32,
    pub mouse_x: f32,
    pub mouse_y: f32,
    pub background: BackgroundType,
    pub strokes: Vec<InkStroke>,
}

impl Default for CanvasState {
    fn default() -> Self {
        Self {
            pan_x: 0.0,
            pan_y: 0.0,
            zoom: 1.0,
            mouse_x: -1000.0,
            mouse_y: -1000.0,
            background: BackgroundType::DotGrid,
            strokes: Vec::new(),
        }
    }
}

impl CanvasState {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn update_mouse_position(&mut self, x: f32, y: f32) {
        self.mouse_x = x;
        self.mouse_y = y;
    }

    pub fn set_background(&mut self, bg: BackgroundType) {
        self.background = bg;
    }

    pub fn add_stroke(&mut self, stroke: InkStroke) {
        self.strokes.push(stroke);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_canvas_initialization() {
        let canvas = CanvasState::new();
        assert_eq!(canvas.background, BackgroundType::DotGrid);
        assert_eq!(canvas.zoom, 1.0);
    }
}
