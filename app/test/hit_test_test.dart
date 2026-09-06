import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class InfiniteHitTestStack extends Stack {
  const InfiniteHitTestStack({
    super.key,
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
    super.children,
  });

  @override
  RenderStack createRenderObject(BuildContext context) {
    return RenderInfiniteHitTestStack(
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      fit: fit,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderStack renderObject) {
    super.updateRenderObject(context, renderObject);
  }
}

class RenderInfiniteHitTestStack extends RenderStack {
  RenderInfiniteHitTestStack({
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
  });

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position) || hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

void main() {
  testWidgets('InfiniteHitTestStack passes tap to out-of-bounds child with transform', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 800,
          height: 600,
          child: Transform.translate(
            offset: const Offset(-1000, -1000), // pan
            child: InfiniteHitTestStack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 1000,
                  top: 1000,
                  width: 100,
                  height: 100,
                  child: GestureDetector(
                    onTap: () => tapped = true,
                    child: Container(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Tap at screen (50, 50) which maps to stack (1050, 1050)
    await tester.tapAt(const Offset(50, 50));
    expect(tapped, isTrue);
  });
}
