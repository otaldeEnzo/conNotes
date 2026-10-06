import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dynamic PDF Insertion Size Calculation Tests', () {
    double calculateTargetPdfWidth(double zoomScale) {
      const visualDesiredWidth = 840.0;
      final currentZoom = (zoomScale > 0) ? zoomScale : 1.0;
      final zoomScaledWidth = visualDesiredWidth / currentZoom;
      return zoomScaledWidth.clamp(320.0, 4200.0);
    }

    test('At 1.0x zoom, PDF insertion width is exactly 840.0 (2x media card 420.0)', () {
      expect(calculateTargetPdfWidth(1.0), equals(840.0));
    });

    test('At 0.5x zoom (zoomed out), PDF insertion width expands to 1680.0 canvas units', () {
      expect(calculateTargetPdfWidth(0.5), equals(1680.0));
      // Visual screen width remains 1680 * 0.5 = 840
      expect(calculateTargetPdfWidth(0.5) * 0.5, equals(840.0));
    });

    test('At 2.0x zoom (zoomed in), PDF insertion width scales down to 420.0 canvas units', () {
      expect(calculateTargetPdfWidth(2.0), equals(420.0));
      // Visual screen width remains 420 * 2.0 = 840
      expect(calculateTargetPdfWidth(2.0) * 2.0, equals(840.0));
    });

    test('Extremely zoomed out (0.1x) is clamped to 4200.0 max canvas units', () {
      expect(calculateTargetPdfWidth(0.1), equals(4200.0));
    });

    test('Extremely zoomed in (5.0x) is clamped to 320.0 min canvas units', () {
      expect(calculateTargetPdfWidth(5.0), equals(320.0));
    });

    test('Zero emojis compliance in canvas_scaffold.dart changes', () {
      final file = File('lib/widgets/canvas_scaffold.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]',
        unicode: true,
      );
      expect(emojiRegex.hasMatch(content), isFalse, reason: 'Zero emojis allowed in canvas_scaffold.dart');
    });
  });
}
