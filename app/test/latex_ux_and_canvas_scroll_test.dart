import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/models/latex_symbols_catalog.dart';
import 'package:connotes_app/widgets/latex_symbols_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LaTeX Catalog & Degree Symbol Tests', () {
    test('Kelvin / Grau symbol has {}^\\circ for proper KaTeX baseline rendering', () {
      final results = searchLatexSymbols(query: 'grau');
      expect(results, isNotEmpty);
      final grau = results.firstWhere((i) => i.label.contains('Grau'));
      expect(grau.latex, equals(r'{}^\circ'));
    });

    test('Latex Symbol search filters by query accurately', () {
      final integralResults = searchLatexSymbols(query: 'integral');
      expect(integralResults, isNotEmpty);
      expect(integralResults.every((item) =>
        item.label.toLowerCase().contains('integral') ||
        item.latex.toLowerCase().contains('int') ||
        item.keywords.any((k) => k.toLowerCase().contains('integral'))
      ), isTrue);
    });
    test('All catalog items with hasSelectionPlaceholder contain #SEL#', () {
      for (final item in kLatexCatalog) {
        if (item.hasSelectionPlaceholder) {
          expect(
            item.template.contains('#SEL#'),
            isTrue,
            reason: 'Item ${item.label} (${item.latex}) is marked with hasSelectionPlaceholder but lacks #SEL# in template',
          );
        }
      }
    });
  });

  group('LatexSymbolsDrawer Widget Tests', () {
    testWidgets('Drawer renders with category pills and handles horizontal wheel scroll', (tester) async {
      LatexSymbolItem? selectedItem;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LatexSymbolsDrawer(
              maxHeight: 300,
              showHeaderSearch: true,
              onSelectSymbol: (item) => selectedItem = item,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify category "Todos" pill is rendered
      expect(find.textContaining('Todos'), findsOneWidget);

      // Send pointer scroll event over the category area
      final categoryFinder = find.textContaining('Todos');
      final location = tester.getCenter(categoryFinder);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: location,
          scrollDelta: const Offset(0, 100),
        ),
      );
      await tester.pumpAndSettle();

      // Interaction completed cleanly without errors
      expect(selectedItem, isNull);
    });

    testWidgets('Drawer external search query filters symbols cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LatexSymbolsDrawer(
              maxHeight: 300,
              searchQuery: 'alfa',
              showHeaderSearch: false,
              onSelectSymbol: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When searching for "alfa", alpha should be present via Tooltip
      expect(
        find.byWidgetPredicate((w) => w is Tooltip && (w.message?.contains('Alfa') ?? false)),
        findsOneWidget,
      );
    });
  });
}
