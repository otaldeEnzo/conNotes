import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/theme/moscaro_theme_controller.dart';
import 'package:connotes_app/theme/moscaro_v2_tokens.dart';
import 'package:connotes_app/widgets/moscaro_sleek_scrollbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MoscaroSleekScrollbar Tests', () {
    testWidgets('renders Scrollbar with Moscaro sleek geometry and theme accent', (tester) async {
      final scrollController = ScrollController();
      final theme = MoscaroThemeController.instance.currentTheme;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              width: 200,
              child: MoscaroSleekScrollbar(
                controller: scrollController,
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 50,
                  itemBuilder: (context, index) => SizedBox(
                    height: 30,
                    child: Text('Item $index', style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find RawScrollbar
      final rawScrollbarFinder = find.byType(RawScrollbar);
      expect(rawScrollbarFinder, findsOneWidget);

      final RawScrollbar rawScrollbar = tester.widget(rawScrollbarFinder);
      expect(rawScrollbar.thickness, 4.0);
      expect(rawScrollbar.radius, const Radius.circular(8.0));
      // Default thumb color should incorporate theme.accentPrimary
      expect(rawScrollbar.thumbColor, theme.accentPrimary.withValues(alpha: MoscaroTokens.isLight ? 0.55 : 0.38));
    });

    testWidgets('supports explicit custom thumbColor and thickness', (tester) async {
      final scrollController = ScrollController();
      const customColor = Color(0xFFFF0055);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              width: 200,
              child: MoscaroSleekScrollbar(
                controller: scrollController,
                thickness: 6.0,
                thumbColor: customColor,
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 20,
                  itemBuilder: (context, index) => SizedBox(
                    height: 30,
                    child: Text('Item $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final RawScrollbar rawScrollbar = tester.widget(find.byType(RawScrollbar));
      expect(rawScrollbar.thickness, 6.0);
      expect(rawScrollbar.thumbColor, customColor);
    });
  });
}
