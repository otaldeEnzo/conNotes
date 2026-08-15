use glam::Vec2;
use crate::document::StrokePoint;

/// Módulo de Predição de Tinta de Baixa Latência (Ink Prediction)
/// Extrapola os próximos 2-3 pontos com base na velocidade e aceleração vetorial
pub struct InkPredictor;

impl InkPredictor {
    /// Prediz os próximos `count` pontos futuros dado um histórico recente de pontos
    pub fn predict_next_points(history: &[StrokePoint], count: usize) -> Vec<StrokePoint> {
        if history.len() < 2 || count == 0 {
            return Vec::new();
        }

        let len = history.len();
        let p_last = &history[len - 1];
        let p_prev = &history[len - 2];

        let dt = (p_last.timestamp.saturating_sub(p_prev.timestamp)).max(1) as f32;
        let v_last = Vec2::new(p_last.x - p_prev.x, p_last.y - p_prev.y) / dt;

        let mut velocity = v_last;
        let mut predicted = Vec::with_capacity(count);

        let mut curr_pos = Vec2::new(p_last.x, p_last.y);
        let step_dt = 8.0; // Intervalo típico de 125Hz em ms

        for i in 1..=count {
            curr_pos += velocity * step_dt;
            // Amortecimento suave de velocidade para evitar overshoot
            velocity *= 0.92;

            predicted.push(StrokePoint {
                x: curr_pos.x,
                y: curr_pos.y,
                pressure: p_last.pressure,
                timestamp: p_last.timestamp + (i as f32 * step_dt) as u64,
            });
        }

        predicted
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ink_prediction() {
        let history = vec![
            StrokePoint { x: 0.0, y: 0.0, pressure: 1.0, timestamp: 0 },
            StrokePoint { x: 10.0, y: 0.0, pressure: 1.0, timestamp: 10 },
        ];

        let predicted = InkPredictor::predict_next_points(&history, 2);
        assert_eq!(predicted.len(), 2);
        assert!(predicted[0].x > 10.0);
        assert_eq!(predicted[0].y, 0.0);
    }
}
