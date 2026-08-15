use rstar::{RTree, RTreeObject, AABB};
use uuid::Uuid;
use crate::document::InkStroke;

#[derive(Debug, Clone, PartialEq)]
pub struct StrokeBoundingBox {
    pub id: Uuid,
    pub envelope: AABB<[f32; 2]>,
}

impl RTreeObject for StrokeBoundingBox {
    type Envelope = AABB<[f32; 2]>;

    fn envelope(&self) -> Self::Envelope {
        self.envelope
    }
}

impl StrokeBoundingBox {
    pub fn from_stroke(stroke: &InkStroke) -> Self {
        if stroke.points.is_empty() {
            return Self {
                id: stroke.id,
                envelope: AABB::from_corners([0.0, 0.0], [0.0, 0.0]),
            };
        }

        let mut min_x = f32::MAX;
        let mut min_y = f32::MAX;
        let mut max_x = f32::MIN;
        let mut max_y = f32::MIN;

        let padding = stroke.stroke_width / 2.0;

        for p in &stroke.points {
            if p.x < min_x { min_x = p.x; }
            if p.y < min_y { min_y = p.y; }
            if p.x > max_x { max_x = p.x; }
            if p.y > max_y { max_y = p.y; }
        }

        Self {
            id: stroke.id,
            envelope: AABB::from_corners(
                [min_x - padding, min_y - padding],
                [max_x + padding, max_y + padding],
            ),
        }
    }
}

#[derive(Debug, Clone)]
pub struct SpatialIndex {
    tree: RTree<StrokeBoundingBox>,
}

impl Default for SpatialIndex {
    fn default() -> Self {
        Self::new()
    }
}

impl SpatialIndex {
    pub fn new() -> Self {
        Self {
            tree: RTree::new(),
        }
    }

    pub fn insert(&mut self, stroke: &InkStroke) {
        let bbox = StrokeBoundingBox::from_stroke(stroke);
        self.tree.insert(bbox);
    }

    pub fn remove(&mut self, stroke: &InkStroke) {
        let bbox = StrokeBoundingBox::from_stroke(stroke);
        self.tree.remove(&bbox);
    }

    pub fn query_rect(&self, min_x: f32, min_y: f32, max_x: f32, max_y: f32) -> Vec<Uuid> {
        let envelope = AABB::from_corners([min_x, min_y], [max_x, max_y]);
        self.tree
            .locate_in_envelope_intersecting(&envelope)
            .map(|item| item.id)
            .collect()
    }
}

