import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/widgets/selection_models.dart';
import 'package:connotes_app/widgets/ink_models.dart';
import 'package:connotes_app/widgets/note_models.dart';
import 'package:connotes_app/handlers/selection_input_handler.dart';

void main() {
  group('Selection Geometry & Edge Resize Tests', () {
    const testBounds = Rect.fromLTWH(100.0, 100.0, 200.0, 150.0);
    const zoomScale = 1.0;

    test('getHandleAtPoint accurately detects 4 corners with high priority', () {
      final inflated = testBounds.inflate(6.0);

      // Top-Left corner
      expect(
        SelectionGeometry.getHandleAtPoint(inflated.topLeft, testBounds, zoomScale),
        equals(SelectionHandleType.topLeft),
      );

      // Top-Right corner
      expect(
        SelectionGeometry.getHandleAtPoint(inflated.topRight, testBounds, zoomScale),
        equals(SelectionHandleType.topRight),
      );

      // Bottom-Left corner
      expect(
        SelectionGeometry.getHandleAtPoint(inflated.bottomLeft, testBounds, zoomScale),
        equals(SelectionHandleType.bottomLeft),
      );

      // Bottom-Right corner
      expect(
        SelectionGeometry.getHandleAtPoint(inflated.bottomRight, testBounds, zoomScale),
        equals(SelectionHandleType.bottomRight),
      );
    });

    test('getHandleAtPoint accurately detects 4 edges (~14px thickness)', () {
      final inflated = testBounds.inflate(6.0);

      // Top Edge (along center of top line)
      expect(
        SelectionGeometry.getHandleAtPoint(Offset(inflated.center.dx, inflated.top), testBounds, zoomScale),
        equals(SelectionHandleType.topEdge),
      );

      // Bottom Edge (along center of bottom line)
      expect(
        SelectionGeometry.getHandleAtPoint(Offset(inflated.center.dx, inflated.bottom), testBounds, zoomScale),
        equals(SelectionHandleType.bottomEdge),
      );

      // Left Edge (along center of left line)
      expect(
        SelectionGeometry.getHandleAtPoint(Offset(inflated.left, inflated.center.dy), testBounds, zoomScale),
        equals(SelectionHandleType.leftEdge),
      );

      // Right Edge (along center of right line)
      expect(
        SelectionGeometry.getHandleAtPoint(Offset(inflated.right, inflated.center.dy), testBounds, zoomScale),
        equals(SelectionHandleType.rightEdge),
      );
    });

    test('getHandleAtPoint returns none for inner points and far outer points', () {
      // Inside center of selection box (should be none, handled as drag body)
      expect(
        SelectionGeometry.getHandleAtPoint(testBounds.center, testBounds, zoomScale),
        equals(SelectionHandleType.none),
      );

      // Far outside
      expect(
        SelectionGeometry.getHandleAtPoint(const Offset(0.0, 0.0), testBounds, zoomScale),
        equals(SelectionHandleType.none),
      );
    });
  });

  group('Selection Input Handler Transformation Lifecycle', () {
    late NoteDocument note;
    late SelectionInputHandler handler;
    late ValueNotifier<int> updateNotifier;
    bool interactingCalled = false;

    setUp(() {
      updateNotifier = ValueNotifier<int>(0);
      interactingCalled = false;
      handler = SelectionInputHandler(
        selectionUpdateNotifier: updateNotifier,
        onInteracting: () => interactingCalled = true,
      );

      note = NoteDocument(
        id: 'note_1',
        title: 'Test Note',
        strokes: [
          InkStroke(
            id: 'stroke_1',
            points: [
              StrokePoint(point: const Offset(100, 100)),
              StrokePoint(point: const Offset(200, 200)),
            ],
            color: const Color(0xFF000000),
            strokeWidth: 4.0,
            boundingBox: const Rect.fromLTWH(95, 95, 110, 110),
          ),
        ],
      );
    });

    test('Resizing via Right Edge updates transformBounds and consolidates stroke points', () {
      SelectionState state = SelectionState(
        selectedStrokeIds: {'stroke_1'},
        bounds: const Rect.fromLTWH(100, 100, 100, 100),
      );

      // 1. Start resizing on right edge
      final inflated = state.bounds!.inflate(6.0);
      final rightEdgePoint = Offset(inflated.right, inflated.center.dy);
      handler.startSelection(
        canvasPoint: rightEdgePoint,
        selectionState: state,
        selectionType: SelectionType.rectangle,
        zoomScale: 1.0,
        currentNote: note,
        onUpdateState: (newState) => state = newState,
      );

      expect(state.activeHandle, equals(SelectionHandleType.rightEdge));
      expect(state.isTransforming, isTrue);

      // 2. Drag right edge by +50px
      handler.updateSelection(
        canvasPoint: rightEdgePoint + const Offset(50, 0),
        selectionState: state,
        selectionType: SelectionType.rectangle,
        zoomScale: 1.0,
        onUpdateState: (newState) => state = newState,
      );

      expect(state.transformBounds, isNotNull);
      expect(state.transformBounds!.width, equals(150.0));
      expect(state.transformBounds!.height, equals(100.0));

      // 3. Finish resizing
      handler.finishSelection(
        selectionState: state,
        currentNote: note,
        onUpdateState: (newState) => state = newState,
      );

      expect(state.activeHandle, equals(SelectionHandleType.none));
      expect(state.transformBounds, isNull);
      expect(state.bounds!.width, equals(150.0));

      final updatedStroke = note.getStroke('stroke_1');
      expect(updatedStroke, isNotNull);
      expect(updatedStroke!.points.last.point.dx, equals(250.0));
      expect(updatedStroke.points.last.point.dy, equals(200.0));
      expect(updatedStroke.transform, equals(Offset.zero));
    });

    test('Dragging selection consolidates stroke points into absolute world space with transform = Offset.zero', () {
      SelectionState state = SelectionState(
        selectedStrokeIds: {'stroke_1'},
        bounds: const Rect.fromLTWH(100, 100, 100, 100),
      );

      // 1. Start drag inside selection body
      handler.startSelection(
        canvasPoint: const Offset(150, 150),
        selectionState: state,
        selectionType: SelectionType.rectangle,
        zoomScale: 1.0,
        currentNote: note,
        onUpdateState: (newState) => state = newState,
      );

      expect(state.isDraggingSelection, isTrue);

      // 2. Drag by (30, 40)
      handler.updateSelection(
        canvasPoint: const Offset(180, 190),
        selectionState: state,
        selectionType: SelectionType.rectangle,
        zoomScale: 1.0,
        onUpdateState: (newState) => state = newState,
      );

      expect(state.dragOffset, equals(const Offset(30, 40)));

      // 3. Finish drag
      handler.finishSelection(
        selectionState: state,
        currentNote: note,
        onUpdateState: (newState) => state = newState,
      );

      expect(state.isDraggingSelection, isFalse);
      expect(state.dragOffset, equals(Offset.zero));
      expect(state.bounds, equals(const Rect.fromLTWH(130, 140, 100, 100)));

      final updatedStroke = note.getStroke('stroke_1');
      expect(updatedStroke, isNotNull);
      expect(updatedStroke!.transform, equals(Offset.zero));
      expect(updatedStroke.points.first.point, equals(const Offset(130, 140)));
      expect(updatedStroke.points.last.point, equals(const Offset(230, 240)));
    });
  });
}

