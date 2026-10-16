import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:connotes_app/models/pdf_internal_object_models.dart';
import 'package:connotes_app/services/pdf_page_spatial_index.dart';
import 'package:connotes_app/services/pdf_region_crop_helper.dart';

class _FakePdfPageTextFragment implements PdfPageTextFragment {
  @override
  final int index;
  @override
  final int length;
  @override
  final PdfRect bounds;
  @override
  final List<PdfRect> charRects;

  _FakePdfPageTextFragment({
    required this.index,
    required this.length,
    required this.bounds,
    required this.charRects,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePdfPageText implements PdfPageText {
  @override
  final int pageNumber;
  @override
  final String fullText;
  @override
  final List<PdfPageTextFragment> fragments;

  _FakePdfPageText({
    required this.pageNumber,
    required this.fullText,
    required this.fragments,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PdfPageSpatialIndex Tests', () {
    test('Constructs spatial index from page text fragments and clusters into lines', () {
      const text = 'Hello world\nSecond line';
      final fragments = [
        _FakePdfPageTextFragment(
          index: 0,
          length: 11,
          bounds: const PdfRect(10, 270, 120, 290),
          charRects: List.generate(
            11,
            (i) => PdfRect(10.0 + (i * 10.0), 270.0, 20.0 + (i * 10.0), 290.0),
          ),
        ),
        _FakePdfPageTextFragment(
          index: 12,
          length: 11,
          bounds: const PdfRect(10, 240, 120, 260),
          charRects: List.generate(
            11,
            (i) => PdfRect(10.0 + (i * 10.0), 240.0, 20.0 + (i * 10.0), 260.0),
          ),
        ),
      ];

      final fakePageText = _FakePdfPageText(
        pageNumber: 1,
        fullText: text,
        fragments: fragments,
      );

      final index = PdfPageSpatialIndex.fromPageText(
        pageText: fakePageText,
        pageNumber: 1,
        nativeWidth: 200,
        nativeHeight: 300,
      );

      expect(index.lines.length, equals(2));
      expect(index.lines[0].startIndex, equals(0));
      expect(index.lines[1].startIndex, equals(12));

      // Test hit testing on first line
      final hitChar = index.findNearestCharIndex(
        displayPos: const Offset(35, 15),
        displayWidth: 200,
        displayHeight: 300,
      );
      expect(hitChar, equals(2)); // index 2 corresponds to x = 30..40

      // Test hit testing before start of second line (margin / start of line)
      // Line 1 is at display Y = 40..60, X = 10..120. Click at X = 5 (margin), Y = 50 (middle of line 2)
      final hitLine2Start = index.findNearestCharIndex(
        displayPos: const Offset(5, 50),
        displayWidth: 200,
        displayHeight: 300,
      );
      expect(hitLine2Start, equals(12)); // must pick line 2's first char, NOT line 1!

      // Test double-click word boundaries
      final wordRange = index.findWordBoundaries(2); // inside "Hello"
      expect(wordRange.start, equals(0));
      expect(wordRange.end, equals(5));

      // Test triple-click paragraph boundaries (selects multi-line paragraph)
      final paraRange = index.findParagraphBoundaries(2);
      expect(paraRange.start, equals(0));
      expect(paraRange.end, equals(23)); // entire multi-line paragraph
    });

    test('buildSelectionState produces consolidated bounding rects', () {
      const text = 'Physics 101';
      final fragments = [
        _FakePdfPageTextFragment(
          index: 0,
          length: 11,
          bounds: const PdfRect(0, 0, 110, 20),
          charRects: List.generate(
            11,
            (i) => PdfRect(i * 10.0, 0.0, (i + 1) * 10.0, 20.0),
          ),
        ),
      ];

      final fakePageText = _FakePdfPageText(
        pageNumber: 1,
        fullText: text,
        fragments: fragments,
      );

      final index = PdfPageSpatialIndex.fromPageText(
        pageText: fakePageText,
        pageNumber: 1,
        nativeWidth: 110,
        nativeHeight: 20,
      );

      final selection = index.buildSelectionState(
        charA: 0,
        charB: 7, // "Physics"
        displayWidth: 110,
        displayHeight: 20,
      );

      expect(selection.selectedText, equals('Physics'));
      expect(selection.rects.length, equals(1));
      expect(selection.bounds.width, equals(70.0));
    });

    test('Correctly indexes and selects vertical text (e.g. chart axis labels)', () {
      const text = 'Amplitude (dB)';
      // Vertical text running along Y: X is constant 10..20, Y goes from 250 down to 100 in PDF space
      final fragments = [
        _FakePdfPageTextFragment(
          index: 0,
          length: text.length,
          bounds: const PdfRect(10, 100, 25, 250),
          charRects: List.generate(
            text.length,
            (i) => PdfRect(10.0, 240.0 - (i * 10.0), 25.0, 250.0 - (i * 10.0)),
          ),
        ),
      ];

      final fakePageText = _FakePdfPageText(
        pageNumber: 1,
        fullText: text,
        fragments: fragments,
      );

      final index = PdfPageSpatialIndex.fromPageText(
        pageText: fakePageText,
        pageNumber: 1,
        nativeWidth: 200,
        nativeHeight: 300,
      );

      expect(index.lines.length, equals(1));
      expect(index.lines.first.isVertical, isTrue);

      // Hit testing along vertical axis
      final hitChar = index.findNearestCharIndex(
        displayPos: const Offset(15, 55), // corresponds to char index 0
        displayWidth: 200,
        displayHeight: 300,
      );
      expect(hitChar, equals(0));

      // Paragraph selection on vertical text selects full vertical label
      final paraRange = index.findParagraphBoundaries(hitChar);
      expect(paraRange.start, equals(0));
      expect(paraRange.end, equals(text.length));
    });

    test('cleanStemText sanitizes chemical ions and broken formula newlines', () {
      const rawStem = 'forças de coesão dos íons Na"\r\ne Cl\r\n#';
      final cleaned = PdfPageSpatialIndex.cleanStemText(rawStem);
      expect(cleaned, contains('Na⁺'));
      expect(cleaned, contains('Cl⁻'));
      expect(cleaned.contains('Na"\n'), isFalse);
      expect(cleaned.contains('\n#'), isFalse);

      // Verify user reported chemistry ions
      final cuClean = PdfPageSpatialIndex.cleanStemText('cátions: Cu 2" (azul)');
      expect(cuClean, contains('Cu²⁺'));

      final feClean = PdfPageSpatialIndex.cleanStemText('Fe3⁺ (amarelo), Ni2⁺ (verde)');
      expect(feClean, contains('Fe³⁺'));
      expect(feClean, contains('Ni²⁺'));

      final mnoClean = PdfPageSpatialIndex.cleanStemText('ânions: MnO# 4 (violeta)');
      expect(mnoClean, contains('MnO₄⁻'));

      final crClean = PdfPageSpatialIndex.cleanStemText('Cr2O 2 7# (laranja)');
      expect(crClean, contains('Cr₂O₇²⁻'));

      // Verify normal dialogue/prose quotes are preserved
      const prose = 'Ele disse: "Olá mundo".';
      expect(PdfPageSpatialIndex.cleanStemText(prose), equals(prose));
    });

    test('cleanStemText automatically dehyphenates line-broken words and purges tofu-box control glyphs', () {
      // Simula o caso real relatado pelo usuário no livro FELTRE:
      const brokenText = 'Essas partícu-\nlas vão se dispersando e atingem o maior núme-\r\nro de moléculas.';
      final cleaned = PdfPageSpatialIndex.cleanStemText(brokenText);

      expect(cleaned, contains('partículas'));
      expect(cleaned, contains('número'));
      expect(cleaned.contains('partícu-'), isFalse);
      expect(cleaned.contains('núme-'), isFalse);

      // Simula caracteres nulos ou soft-hyphens invisíveis que viram [] no Flutter:
      const tofuText = 'partícu\u00ad\nlas e núme\u0002\nro com glifo \uFFFD nulo';
      final cleanedTofu = PdfPageSpatialIndex.cleanStemText(tofuText);
      expect(cleanedTofu, contains('partículas'));
      expect(cleanedTofu, contains('número'));
      expect(cleanedTofu.contains('\uFFFD'), isFalse);
      expect(cleanedTofu.contains('\u00ad'), isFalse);
    });
  });

  group('PdfInternalObject Models', () {
    test('Preserves classification properties and copyWith', () {
      const obj = PdfInternalObject(
        id: 'obj_1',
        pageNumber: 2,
        bounds: Rect.fromLTWH(50, 50, 200, 150),
        type: PdfInternalObjectType.image,
      );

      expect(obj.isImage, isTrue);
      expect(obj.isTable, isFalse);
      expect(obj.isFormula, isFalse);

      final updated = obj.copyWith(type: PdfInternalObjectType.formula);
      expect(updated.isFormula, isTrue);
      expect(updated.isImage, isFalse);
    });

    test('calculateAdjacentCardPosition aligns exactly with selection cropTop and cardX + width', () {
      final pos = PdfRegionCropHelper.calculateAdjacentCardPosition(
        cardX: 100.0,
        cardWidth: 800.0,
        cardY: 50.0,
        pageTopOffset: 0.0,
        cropTop: 120.0,
        gap: 28.0,
      );

      expect(pos.dx, equals(100.0 + 800.0 + 28.0)); // 928.0
      expect(pos.dy, equals(50.0 + 0.0 + 120.0)); // 170.0
    });
  });
}
