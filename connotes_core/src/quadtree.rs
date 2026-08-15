use std::collections::HashSet;
use uuid::Uuid;
use crate::document::InkStroke;
use crate::geometry::compute_bounds;

/// Dimensão padrão de cada Tile no canvas infinito (512x512 unidades lógicas)
pub const TILE_SIZE: f32 = 512.0;

/// Identificador de coordenadas de um Tile (coluna X, linha Y)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct TileCoord {
    pub x: i32,
    pub y: i32,
}

impl TileCoord {
    pub fn from_world_pos(x: f32, y: f32) -> Self {
        Self {
            x: (x / TILE_SIZE).floor() as i32,
            y: (y / TILE_SIZE).floor() as i32,
        }
    }
}

/// Sistema de Gerenciamento de Tiles para Viewport Culling ultra-eficiente.
#[derive(Debug, Clone, Default)]
pub struct TileManager {
    tiles: std::collections::HashMap<TileCoord, HashSet<Uuid>>,
    stroke_tiles: std::collections::HashMap<Uuid, HashSet<TileCoord>>,
}

impl TileManager {
    pub fn new() -> Self {
        Self::default()
    }

    /// Adiciona um traço mapeando-o para todos os tiles que ele intersecta.
    pub fn insert_stroke(&mut self, stroke: &InkStroke) {
        if stroke.points.is_empty() {
            return;
        }

        let (min, max) = compute_bounds(&stroke.points, stroke.stroke_width);
        let min_tile = TileCoord::from_world_pos(min.x, min.y);
        let max_tile = TileCoord::from_world_pos(max.x, max.y);

        let mut occupied = HashSet::new();

        for tx in min_tile.x..=max_tile.x {
            for ty in min_tile.y..=max_tile.y {
                let coord = TileCoord { x: tx, y: ty };
                self.tiles.entry(coord).or_default().insert(stroke.id);
                occupied.insert(coord);
            }
        }

        self.stroke_tiles.insert(stroke.id, occupied);
    }

    /// Remove um traço de todos os seus tiles associados.
    pub fn remove_stroke(&mut self, stroke_id: &Uuid) {
        if let Some(coords) = self.stroke_tiles.remove(stroke_id) {
            for coord in coords {
                if let Some(set) = self.tiles.get_mut(&coord) {
                    set.remove(stroke_id);
                    if set.is_empty() {
                        self.tiles.remove(&coord);
                    }
                }
            }
        }
    }

    /// Retorna todos os IDs únicos de traços visíveis na viewport delimitada por (min_x, min_y) até (max_x, max_y).
    pub fn query_viewport(&self, min_x: f32, min_y: f32, max_x: f32, max_y: f32) -> HashSet<Uuid> {
        let min_tile = TileCoord::from_world_pos(min_x, min_y);
        let max_tile = TileCoord::from_world_pos(max_x, max_y);

        let mut visible_strokes = HashSet::new();

        for tx in min_tile.x..=max_tile.x {
            for ty in min_tile.y..=max_tile.y {
                let coord = TileCoord { x: tx, y: ty };
                if let Some(set) = self.tiles.get(&coord) {
                    for id in set {
                        visible_strokes.insert(*id);
                    }
                }
            }
        }

        visible_strokes
    }

    pub fn clear(&mut self) {
        self.tiles.clear();
        self.stroke_tiles.clear();
    }
}
