use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use uuid::Uuid;

use crate::eraser::SpatialHashGrid;
use crate::spatial::SpatialIndex;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
#[repr(C)]
pub struct StrokePoint {
    pub x: f32,
    pub y: f32,
    pub pressure: f32,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InkStroke {
    pub id: Uuid,
    pub points: Vec<StrokePoint>,
    pub color_rgba: [f32; 4],
    pub stroke_width: f32,
    pub version: u64,
}

impl InkStroke {
    pub fn new(points: Vec<StrokePoint>, color_rgba: [f32; 4], stroke_width: f32) -> Self {
        Self {
            id: Uuid::new_v4(),
            points,
            color_rgba,
            stroke_width,
            version: 0,
        }
    }

    /// Duplica o traço com deslocamento (dx, dy), gerando novo UUID e reutilizando alocação de buffer
    pub fn duplicate_offset(&self, dx: f32, dy: f32) -> Self {
        let mut new_points = Vec::with_capacity(self.points.len());
        for p in &self.points {
            new_points.push(StrokePoint {
                x: p.x + dx,
                y: p.y + dy,
                pressure: p.pressure,
                timestamp: p.timestamp,
            });
        }

        Self {
            id: Uuid::new_v4(),
            points: new_points,
            color_rgba: self.color_rgba,
            stroke_width: self.stroke_width,
            version: 0,
        }
    }

    /// Translada os pontos do traço no lugar
    pub fn translate(&mut self, dx: f32, dy: f32) {
        for p in &mut self.points {
            p.x += dx;
            p.y += dy;
        }
        self.version += 1;
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum BackgroundType {
    DotGrid,
    Pautado,
    EmBranco,
}

impl Default for BackgroundType {
    fn default() -> Self {
        BackgroundType::DotGrid
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Document {
    pub id: Uuid,
    pub pan_x: f32,
    pub pan_y: f32,
    pub zoom: f32,
    pub background: BackgroundType,
    pub strokes: Vec<InkStroke>,
    pub doc_version: u64,

    #[serde(skip)]
    pub spatial_index: SpatialIndex,

    #[serde(skip)]
    pub eraser_grid: SpatialHashGrid,

    #[serde(skip)]
    pub tile_manager: crate::quadtree::TileManager,
}

impl Default for Document {
    fn default() -> Self {
        Self {
            id: Uuid::new_v4(),
            pan_x: 0.0,
            pan_y: 0.0,
            zoom: 1.0,
            background: BackgroundType::DotGrid,
            strokes: Vec::new(),
            doc_version: 0,
            spatial_index: SpatialIndex::new(),
            eraser_grid: SpatialHashGrid::new(64.0),
            tile_manager: crate::quadtree::TileManager::new(),
        }
    }
}

impl Document {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add_stroke(&mut self, stroke: InkStroke) {
        self.spatial_index.insert(&stroke);
        self.eraser_grid.insert_stroke(&stroke);
        self.tile_manager.insert_stroke(&stroke);
        self.strokes.push(stroke);
        self.doc_version += 1;
    }

    pub fn delete_strokes(&mut self, ids: &[Uuid]) {
        let set: HashSet<Uuid> = ids.iter().copied().collect();
        for id in ids {
            self.eraser_grid.remove_stroke(id);
            self.tile_manager.remove_stroke(id);
        }

        self.strokes.retain(|s| {
            if set.contains(&s.id) {
                self.spatial_index.remove(s);
                false
            } else {
                true
            }
        });
        self.doc_version += 1;
    }

    /// Duplicação paralela de alta escala usando Rayon (memcpy e offsets SIMD)
    pub fn duplicate_strokes_parallel(&mut self, ids: &[Uuid], dx: f32, dy: f32) -> Vec<Uuid> {
        let set: HashSet<Uuid> = ids.iter().copied().collect();

        // Filtra e duplica paralelamente com Rayon
        let matching_strokes: Vec<&InkStroke> = self
            .strokes
            .iter()
            .filter(|s| set.contains(&s.id))
            .collect();

        let new_strokes: Vec<InkStroke> = matching_strokes
            .into_par_iter()
            .map(|s| s.duplicate_offset(dx, dy))
            .collect();

        let new_ids: Vec<Uuid> = new_strokes.iter().map(|s| s.id).collect();

        for stroke in new_strokes {
            self.add_stroke(stroke);
        }

        new_ids
    }

    /// Translada múltiplos traços simultaneamente em paralelo
    pub fn translate_strokes_parallel(&mut self, ids: &[Uuid], dx: f32, dy: f32) {
        let set: HashSet<Uuid> = ids.iter().copied().collect();

        // Remove do spatial index / eraser antes de mover
        for s in &self.strokes {
            if set.contains(&s.id) {
                self.spatial_index.remove(s);
                self.eraser_grid.remove_stroke(&s.id);
                self.tile_manager.remove_stroke(&s.id);
            }
        }

        // Translada em paralelo
        self.strokes.par_iter_mut().for_each(|s| {
            if set.contains(&s.id) {
                s.translate(dx, dy);
            }
        });

        // Re-insere nos índices espaciais
        for s in &self.strokes {
            if set.contains(&s.id) {
                self.spatial_index.insert(s);
                self.eraser_grid.insert_stroke(s);
                self.tile_manager.insert_stroke(s);
            }
        }

        self.doc_version += 1;
    }

    /// Recria os índices espaciais a partir da lista de traços (ex: após carregar do disco)
    pub fn rebuild_indexes(&mut self) {
        self.spatial_index = SpatialIndex::new();
        self.eraser_grid = SpatialHashGrid::new(64.0);
        self.tile_manager = crate::quadtree::TileManager::new();
        for s in &self.strokes {
            self.spatial_index.insert(s);
            self.eraser_grid.insert_stroke(s);
            self.tile_manager.insert_stroke(s);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_document_duplicate_parallel() {
        let mut doc = Document::new();
        let stroke1 = InkStroke::new(
            vec![
                StrokePoint { x: 10.0, y: 10.0, pressure: 1.0, timestamp: 0 },
                StrokePoint { x: 20.0, y: 20.0, pressure: 1.0, timestamp: 1 },
            ],
            [1.0, 0.0, 0.0, 1.0],
            2.0,
        );
        let id1 = stroke1.id;
        doc.add_stroke(stroke1);

        let new_ids = doc.duplicate_strokes_parallel(&[id1], 50.0, 50.0);
        assert_eq!(new_ids.len(), 1);
        assert_eq!(doc.strokes.len(), 2);
        assert_eq!(doc.strokes[1].points[0].x, 60.0);
        assert_eq!(doc.strokes[1].points[0].y, 60.0);
    }
}
