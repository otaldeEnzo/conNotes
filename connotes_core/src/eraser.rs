use std::collections::{HashMap, HashSet};
use uuid::Uuid;
use crate::document::InkStroke;

/// Grid de Hashing Espacial 2D otimizado para operações O(1) de borracha / hit-testing.
#[derive(Debug, Clone)]
pub struct SpatialHashGrid {
    pub cell_size: f32,
    cells: HashMap<(i32, i32), HashSet<Uuid>>,
    stroke_to_cells: HashMap<Uuid, HashSet<(i32, i32)>>,
}

impl Default for SpatialHashGrid {
    fn default() -> Self {
        Self::new(64.0)
    }
}

impl SpatialHashGrid {
    pub fn new(cell_size: f32) -> Self {
        Self {
            cell_size: if cell_size <= 0.0 { 64.0 } else { cell_size },
            cells: HashMap::new(),
            stroke_to_cells: HashMap::new(),
        }
    }

    #[inline]
    fn world_to_cell(&self, x: f32, y: f32) -> (i32, i32) {
        (
            (x / self.cell_size).floor() as i32,
            (y / self.cell_size).floor() as i32,
        )
    }

    /// Insere todos os pontos/segmentos do traço no grid com raio correspondente à espessura.
    pub fn insert_stroke(&mut self, stroke: &InkStroke) {
        if stroke.points.is_empty() {
            return;
        }

        let radius = (stroke.stroke_width / 2.0).max(1.0);
        let mut occupied_cells = HashSet::new();

        for i in 0..stroke.points.len() {
            let p1 = &stroke.points[i];
            
            // Rasteriza bounding box do ponto na célula
            let min_cell = self.world_to_cell(p1.x - radius, p1.y - radius);
            let max_cell = self.world_to_cell(p1.x + radius, p1.y + radius);

            for cx in min_cell.0..=max_cell.0 {
                for cy in min_cell.1..=max_cell.1 {
                    occupied_cells.insert((cx, cy));
                }
            }

            // Se houver próximo ponto, rasteriza linha intermediária para traços rápidos sem buracos
            if i + 1 < stroke.points.len() {
                let p2 = &stroke.points[i + 1];
                let dx = p2.x - p1.x;
                let dy = p2.y - p1.y;
                let dist = (dx * dx + dy * dy).sqrt();
                let steps = (dist / (self.cell_size * 0.5)).ceil() as usize;

                for s in 1..steps {
                    let t = s as f32 / steps as f32;
                    let mx = p1.x + dx * t;
                    let my = p1.y + dy * t;
                    let cell = self.world_to_cell(mx, my);
                    occupied_cells.insert(cell);
                }
            }
        }

        for cell in &occupied_cells {
            self.cells.entry(*cell).or_default().insert(stroke.id);
        }

        self.stroke_to_cells.insert(stroke.id, occupied_cells);
    }

    /// Remove um traço de todas as células indexadas em O(K) onde K = células ocupadas
    pub fn remove_stroke(&mut self, stroke_id: &Uuid) {
        if let Some(cells) = self.stroke_to_cells.remove(stroke_id) {
            for cell in cells {
                if let Some(set) = self.cells.get_mut(&cell) {
                    set.remove(stroke_id);
                    if set.is_empty() {
                        self.cells.remove(&cell);
                    }
                }
            }
        }
    }

    /// Consulta IDs de traços próximos a um ponto dentro do raio da borracha em O(1) células
    pub fn query_point(&self, x: f32, y: f32, radius: f32) -> Vec<Uuid> {
        let min_cell = self.world_to_cell(x - radius, y - radius);
        let max_cell = self.world_to_cell(x + radius, y + radius);

        let mut results = HashSet::new();

        for cx in min_cell.0..=max_cell.0 {
            for cy in min_cell.1..=max_cell.1 {
                if let Some(stroke_ids) = self.cells.get(&(cx, cy)) {
                    for id in stroke_ids {
                        results.insert(*id);
                    }
                }
            }
        }

        results.into_iter().collect()
    }

    pub fn clear(&mut self) {
        self.cells.clear();
        self.stroke_to_cells.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::document::StrokePoint;

    #[test]
    fn test_spatial_hash_grid_hit() {
        let mut grid = SpatialHashGrid::new(64.0);
        let stroke = InkStroke::new(
            vec![
                StrokePoint { x: 10.0, y: 10.0, pressure: 1.0, timestamp: 0 },
                StrokePoint { x: 20.0, y: 20.0, pressure: 1.0, timestamp: 1 },
            ],
            [0.0, 0.0, 0.0, 1.0],
            4.0,
        );
        let stroke_id = stroke.id;
        grid.insert_stroke(&stroke);

        let hits = grid.query_point(15.0, 15.0, 10.0);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0], stroke_id);

        let miss = grid.query_point(500.0, 500.0, 10.0);
        assert!(miss.is_empty());

        grid.remove_stroke(&stroke_id);
        let hits_after = grid.query_point(15.0, 15.0, 10.0);
        assert!(hits_after.is_empty());
    }
}
