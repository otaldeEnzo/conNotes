import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Stack customizado para o Canvas e Cards que permite hit-testing em qualquer coordenada 2D,
/// sem ser bloqueado pela restrição padrão `_size.contains(position)` do RenderBox pai.
class InfiniteHitTestStack extends Stack {
  final bool unconstrainedPositionedLayout;

  const InfiniteHitTestStack({
    super.key,
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior = Clip.none,
    super.children = const <Widget>[],
    this.unconstrainedPositionedLayout = false,
  });

  @override
  RenderStack createRenderObject(BuildContext context) {
    return RenderInfiniteHitTestStack(
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      fit: fit,
      clipBehavior: clipBehavior,
      unconstrainedPositionedLayout: unconstrainedPositionedLayout,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderInfiniteHitTestStack renderObject) {
    super.updateRenderObject(context, renderObject);
    renderObject.unconstrainedPositionedLayout = unconstrainedPositionedLayout;
  }
}

class RenderInfiniteHitTestStack extends RenderStack {
  bool unconstrainedPositionedLayout;

  RenderInfiniteHitTestStack({
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior = Clip.none,
    this.unconstrainedPositionedLayout = false,
  });

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // Bypassa a checagem padrão `size.contains(position)` do RenderBox pai,
    // permitindo hit-testing em qualquer coordenada do canvas infinito ou além da bounding box do Stack!
    if (hitTestChildren(result, position: position) || hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  void performLayout() {
    super.performLayout();
    if (unconstrainedPositionedLayout) {
      RenderBox? child = firstChild;
      while (child != null) {
        final StackParentData childParentData = child.parentData! as StackParentData;
        if (childParentData.isPositioned) {
          child.layout(const BoxConstraints(), parentUsesSize: false);
        }
        child = childParentData.nextSibling;
      }
    }
  }
}

/// SizedBox customizado que permite hit-testing em qualquer coordenada 2D
/// além dos limites de sua bounding box (width/height), integrando-se ao ecossistema InfiniteHitTestStack.
class InfiniteHitTestSizedBox extends SingleChildRenderObjectWidget {
  final double? width;
  final double? height;

  const InfiniteHitTestSizedBox({
    super.key,
    this.width,
    this.height,
    super.child,
  });

  @override
  RenderConstrainedBox createRenderObject(BuildContext context) {
    return RenderInfiniteHitTestConstrainedBox(
      additionalConstraints: _additionalConstraints,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderConstrainedBox renderObject) {
    renderObject.additionalConstraints = _additionalConstraints;
  }

  BoxConstraints get _additionalConstraints {
    return BoxConstraints.tightFor(width: width, height: height);
  }
}

class RenderInfiniteHitTestConstrainedBox extends RenderConstrainedBox {
  RenderInfiniteHitTestConstrainedBox({
    super.child,
    required super.additionalConstraints,
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
