use criterion::{black_box, criterion_group, criterion_main, Criterion};
use connotes_core::document::{Document, InkStroke, StrokePoint};
use connotes_core::geometry::{point_in_polygon, simplify_rdp};
use connotes_core::tessellation::StrokeTessellator;
use glam::Vec2;

fn bench_geometry(c: &mut Criterion) {
    // 1. Benchmark de Simplificação RDP com 10.000 pontos
    let mut points = Vec::with_capacity(10_000);
    for i in 0..10_000 {
        points.push(StrokePoint {
            x: i as f32,
            y: (i as f32 * 0.1).sin() * 20.0,
            pressure: 1.0,
            timestamp: i as u64,
        });
    }

    c.bench_function("rdp_simplify_10k_points", |b| {
        b.iter(|| {
            simplify_rdp(black_box(&points), black_box(1.5));
        })
    });

    // 2. Benchmark de Tesselação de Traço Denso em TriangleStrip
    let stroke = InkStroke::new(points.clone(), [1.0, 1.0, 1.0, 1.0], 5.0);
    c.bench_function("tessellate_dense_stroke", |b| {
        b.iter(|| {
            StrokeTessellator::tessellate(black_box(&stroke), black_box(1));
        })
    });

    // 3. Benchmark de Ray Casting Lasso Selection
    let polygon = vec![
        Vec2::new(0.0, 0.0),
        Vec2::new(5000.0, 0.0),
        Vec2::new(5000.0, 5000.0),
        Vec2::new(0.0, 5000.0),
    ];
    let test_point = Vec2::new(2500.0, 2500.0);
    c.bench_function("lasso_ray_casting", |b| {
        b.iter(|| {
            point_in_polygon(black_box(test_point), black_box(&polygon));
        })
    });

    // 4. Benchmark de Duplicação Paralela com Rayon
    let mut doc = Document::new();
    let mut ids = Vec::new();
    for _ in 0..50 {
        let s = InkStroke::new(points[0..500].to_vec(), [1.0, 0.0, 0.0, 1.0], 4.0);
        ids.push(s.id);
        doc.add_stroke(s);
    }

    c.bench_function("duplicate_50_dense_strokes_parallel", |b| {
        b.iter(|| {
            let mut test_doc = doc.clone();
            test_doc.duplicate_strokes_parallel(black_box(&ids), black_box(50.0), black_box(50.0));
        })
    });
}

criterion_group!(benches, bench_geometry);
criterion_main!(benches);
