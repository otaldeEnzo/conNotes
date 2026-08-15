use glam::Vec2;
use crate::document::{InkStroke, StrokePoint};

/// Calcula o Bounding Box mínimo e máximo (min_xy, max_xy) com padding de espessura usando SIMD glam::Vec2.
#[inline]
pub fn compute_bounds(points: &[StrokePoint], stroke_width: f32) -> (Vec2, Vec2) {
    if points.is_empty() {
        return (Vec2::ZERO, Vec2::ZERO);
    }

    let mut min = Vec2::splat(f32::MAX);
    let mut max = Vec2::splat(f32::MIN);

    for p in points {
        let v = Vec2::new(p.x, p.y);
        min = min.min(v);
        max = max.max(v);
    }

    let padding = Vec2::splat(stroke_width * 0.5);
    (min - padding, max + padding)
}

/// Distância perpendicular de um ponto p ao segmento (a -> b) usando projeção vetorial glam::Vec2.
#[inline]
fn perpendicular_distance(p: Vec2, a: Vec2, b: Vec2) -> f32 {
    let ab = b - a;
    let len_sq = ab.length_squared();
    if len_sq <= 1e-6 {
        return (p - a).length();
    }
    let ap = p - a;
    let t = (ap.dot(ab) / len_sq).clamp(0.0, 1.0);
    let projection = a + ab * t;
    (p - projection).length()
}

/// Algoritmo Ramer-Douglas-Peucker (RDP) para simplificação rápida de curvas vetoriais.
/// Reduz drasticamente a quantidade de pontos sem perder a fidelidade estética.
pub fn simplify_rdp(points: &[StrokePoint], epsilon: f32) -> Vec<StrokePoint> {
    if points.len() <= 2 {
        return points.to_vec();
    }

    let mut dmax = 0.0f32;
    let mut index = 0;
    let end = points.len() - 1;

    let a = Vec2::new(points[0].x, points[0].y);
    let b = Vec2::new(points[end].x, points[end].y);

    for i in 1..end {
        let p = Vec2::new(points[i].x, points[i].y);
        let d = perpendicular_distance(p, a, b);
        if d > dmax {
            index = i;
            dmax = d;
        }
    }

    if dmax > epsilon {
        let mut left = simplify_rdp(&points[0..=index], epsilon);
        let mut right = simplify_rdp(&points[index..=end], epsilon);
        left.pop(); // Remove ponto duplicado na junção
        left.append(&mut right);
        left
    } else {
        vec![points[0], points[end]]
    }
}

/// Interpolação de Spline Cúbica Catmull-Rom para suavização ultra-fluida de traços.
pub fn catmull_rom_interpolate(
    p0: Vec2,
    p1: Vec2,
    p2: Vec2,
    p3: Vec2,
    t: f32,
) -> Vec2 {
    let t2 = t * t;
    let t3 = t2 * t;

    0.5 * (
        (2.0 * p1) +
        (-p0 + p2) * t +
        (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
        (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
    )
}

/// Suaviza uma lista de pontos aplicando Catmull-Rom com número configurável de passos por segmento.
pub fn smooth_stroke(points: &[StrokePoint], steps_per_segment: usize) -> Vec<StrokePoint> {
    if points.len() < 3 || steps_per_segment <= 1 {
        return points.to_vec();
    }

    let mut smoothed = Vec::with_capacity(points.len() * steps_per_segment);
    let count = points.len();

    for i in 0..count - 1 {
        let p0_idx = if i == 0 { 0 } else { i - 1 };
        let p1_idx = i;
        let p2_idx = i + 1;
        let p3_idx = if i + 2 < count { i + 2 } else { count - 1 };

        let p0 = Vec2::new(points[p0_idx].x, points[p0_idx].y);
        let p1 = Vec2::new(points[p1_idx].x, points[p1_idx].y);
        let p2 = Vec2::new(points[p2_idx].x, points[p2_idx].y);
        let p3 = Vec2::new(points[p3_idx].x, points[p3_idx].y);

        let pr1 = points[p1_idx].pressure;
        let pr2 = points[p2_idx].pressure;
        let ts1 = points[p1_idx].timestamp;
        let ts2 = points[p2_idx].timestamp;

        for step in 0..steps_per_segment {
            let t = step as f32 / steps_per_segment as f32;
            let interpolated_pos = catmull_rom_interpolate(p0, p1, p2, p3, t);
            let pressure = pr1 + (pr2 - pr1) * t;
            let timestamp = ts1 + ((ts2.saturating_sub(ts1)) as f32 * t) as u64;

            smoothed.push(StrokePoint {
                x: interpolated_pos.x,
                y: interpolated_pos.y,
                pressure,
                timestamp,
            });
        }
    }

    if let Some(&last) = points.last() {
        smoothed.push(last);
    }

    smoothed
}

/// Ray Casting 2D de alta performance: testa se um ponto 2D está dentro de um polígono arbitrário (Lasso Selection).
#[inline]
pub fn point_in_polygon(point: Vec2, polygon: &[Vec2]) -> bool {
    if polygon.len() < 3 {
        return false;
    }

    let mut inside = false;
    let mut j = polygon.len() - 1;

    for i in 0..polygon.len() {
        let pi = polygon[i];
        let pj = polygon[j];

        if ((pi.y > point.y) != (pj.y > point.y))
            && (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x)
        {
            inside = !inside;
        }
        j = i;
    }

    inside
}

/// Testa se um traço é selecionado por um laço (se ao menos uma fração significativa ou a maioria dos pontos está no polígono).
pub fn stroke_selected_by_lasso(stroke: &InkStroke, polygon: &[Vec2]) -> bool {
    if stroke.points.is_empty() || polygon.len() < 3 {
        return false;
    }

    // Amostragem rápida (se tiver muitos pontos, testa a cada N pontos para O(1) perceptível)
    let step = (stroke.points.len() / 32).max(1);
    let mut inside_count = 0;
    let mut total_samples = 0;

    for p in stroke.points.iter().step_by(step) {
        total_samples += 1;
        if point_in_polygon(Vec2::new(p.x, p.y), polygon) {
            inside_count += 1;
        }
    }

    // Se mais de 50% dos pontos amostrados estão dentro do polígono
    inside_count * 2 >= total_samples
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bounds_computation() {
        let points = vec![
            StrokePoint { x: 10.0, y: 20.0, pressure: 1.0, timestamp: 0 },
            StrokePoint { x: 50.0, y: 80.0, pressure: 1.0, timestamp: 1 },
        ];
        let (min, max) = compute_bounds(&points, 4.0);
        assert_eq!(min, Vec2::new(8.0, 18.0));
        assert_eq!(max, Vec2::new(52.0, 82.0));
    }

    #[test]
    fn test_point_in_polygon() {
        let poly = vec![
            Vec2::new(0.0, 0.0),
            Vec2::new(100.0, 0.0),
            Vec2::new(100.0, 100.0),
            Vec2::new(0.0, 100.0),
        ];
        assert!(point_in_polygon(Vec2::new(50.0, 50.0), &poly));
        assert!(!point_in_polygon(Vec2::new(150.0, 50.0), &poly));
    }

    #[test]
    fn test_rdp_simplification() {
        let points = vec![
            StrokePoint { x: 0.0, y: 0.0, pressure: 1.0, timestamp: 0 },
            StrokePoint { x: 1.0, y: 0.1, pressure: 1.0, timestamp: 1 },
            StrokePoint { x: 2.0, y: -0.1, pressure: 1.0, timestamp: 2 },
            StrokePoint { x: 10.0, y: 0.0, pressure: 1.0, timestamp: 3 },
        ];
        let simplified = simplify_rdp(&points, 0.5);
        assert_eq!(simplified.len(), 2);
    }
}
