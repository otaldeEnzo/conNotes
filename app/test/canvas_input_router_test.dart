import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connotes_app/controllers/canvas_input_context.dart';
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/services/settings_service.dart';
import 'package:connotes_app/services/stylus_native_channel.dart';
import 'package:connotes_app/widgets/canvas_input_router.dart';
import 'package:connotes_app/widgets/ink_models.dart';
import 'package:connotes_app/widgets/laser_pointer.dart';
import 'package:connotes_app/widgets/note_models.dart';
import 'package:connotes_app/widgets/selection_models.dart';
import 'package:connotes_app/widgets/settings_models.dart';
import 'package:connotes_app/widgets/smart_shapes.dart';
import 'package:connotes_app/widgets/stem_protractor_model.dart';
import 'package:connotes_app/widgets/stem_ruler_model.dart';
import 'package:connotes_app/widgets/undo_commands.dart';

class _FakeCanvasInputContext implements CanvasInputContext {
  @override
  NoteDocument? currentNote = NoteDocument(
    id: 'test_note',
    title: 'Test Note',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  String activeTool = 'pen';

  @override
  SelectionState selectionState = SelectionState.empty();

  @override
  SelectionType selectionType = SelectionType.lasso;

  @override
  Offset panOffset = Offset.zero;

  @override
  double zoomScale = 1.0;

  @override
  Offset? mousePos;

  @override
  double smoothedPressure = 0.5;

  @override
  int lastPointerTimestampMs = 0;

  @override
  Offset? lastPointerCanvasPoint;

  @override
  ShapeType activeShapeType = ShapeType.rectangle;

  @override
  bool isGridMenuOpen = false;

  @override
  StemRulerState rulerState = const StemRulerState();

  @override
  StemProtractorState protractorState = const StemProtractorState();

  @override
  String? selectedCardId;

  @override
  LaserPointerEngine laserEngine = LaserPointerEngine();

  @override
  double eraserRadius = 24.0;

  @override
  bool isPalmRejectionEnabled = true;

  // Trackers
  bool eraseCalled = false;
  EraserMode? lastEraserMode;
  bool sampleColorCalled = false;
  bool interactingCalled = false;

  @override
  void eraseStrokesNear(Offset canvasPoint, {EraserMode? mode}) {
    eraseCalled = true;
    lastEraserMode = mode;
  }

  @override
  void scheduleEraseCommit() {}

  @override
  Color? sampleColorAt(Offset canvasPoint) {
    sampleColorCalled = true;
    return Colors.cyan;
  }

  @override
  CanvasCardModel? findCardAtPoint(Offset canvasPoint) => null;

  @override
  void hideUIElementsOnInteraction() {}

  @override
  void incrementCommittedStrokes() {}

  @override
  void incrementStrokesVersion() {}

  @override
  void insertCardAt(Offset canvasPoint) {}

  @override
  void pushCommand(UndoCommand command, {required bool execute, NoteDocument? note}) {}

  @override
  void scheduleAutoSave() {}

  @override
  void selectCard(String? id) {
    selectedCardId = id;
  }

  @override
  void setInteracting() {
    interactingCalled = true;
  }

  @override
  void triggerHapticFeedback() {}

  @override
  void triggerSelectionUpdate() {}

  @override
  void updateMousePos(Offset? pos) {
    mousePos = pos;
  }

  @override
  void updatePointerInfo(int timestampMs, Offset? canvasPoint) {
    lastPointerTimestampMs = timestampMs;
    lastPointerCanvasPoint = canvasPoint;
  }

  @override
  void updateProtractorState(StemProtractorState state) {
    protractorState = state;
  }

  @override
  void updateRulerState(StemRulerState state) {
    rulerState = state;
  }

  @override
  void updateSelectionState(SelectionState state) {
    selectionState = state;
  }

  @override
  void updateSmoothedPressure(double pressure) {
    smoothedPressure = pressure;
  }

  @override
  void onBarrelButtonPressed({required bool isPressed, Offset? position}) {}

  @override
  void onInvertedStylusChanged({required bool isInverted}) {}

  @override
  void onPalmContactRejected({required Offset position, required double contactSize}) {}

  @override
  void onStylusHover({Offset? position, double? pressure, double? tilt, double? distance}) {}
}

void main() {
  testWidgets('CanvasInputRouter stylus barrel action routing test', (WidgetTester tester) async {
    final fakeContext = _FakeCanvasInputContext();
    final strokeUpdateNotifier = ValueNotifier<int>(0);
    final selectionUpdateNotifier = ValueNotifier<int>(0);
    final panNotifier = ValueNotifier<Offset>(Offset.zero);
    final zoomNotifier = ValueNotifier<double>(1.0);

    const activePenPreset = PenSlotPreset(
      id: 'slot_1',
      name: 'Pen',
      color: Colors.white,
      strokeWidth: 2.0,
    );

    // 1. Configure settings to strokeEraser (Hold mode)
    SettingsService.instance.updateSettingsInMemory(const AppSettingsState(
      stylusPrimaryBarrelAction: StylusBarrelAction.strokeEraser,
      stylusPrimaryTriggerMode: StylusTriggerMode.hold,
      stylusSecondaryBarrelAction: StylusBarrelAction.disabled,
      enableStylusHoverPreview: true,
    ));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanvasInputRouter(
            canvasContext: fakeContext,
            activePenPreset: activePenPreset,
            activeStrokeUpdateNotifier: strokeUpdateNotifier,
            selectionUpdateNotifier: selectionUpdateNotifier,
            panNotifier: panNotifier,
            zoomNotifier: zoomNotifier,
            onCommitStroke: (_) {},
            onScheduleBounceCheck: () {},
            child: Container(color: Colors.black),
          ),
        ),
      ),
    );

    // Simula PointerDown com Barrel Button ativo (kSecondaryStylusButton)
    final gesture = await tester.createGesture(kind: PointerDeviceKind.stylus, buttons: kSecondaryStylusButton);
    await gesture.down(const Offset(100, 100));
    await tester.pump();

    expect(fakeContext.eraseCalled, isTrue);
    expect(fakeContext.lastEraserMode, equals(EraserMode.stroke));

    await gesture.up();
    await gesture.removePointer();
    await tester.pump();

    // 2. Configure settings to colorPicker
    fakeContext.sampleColorCalled = false;
    SettingsService.instance.updateSettingsInMemory(const AppSettingsState(
      stylusPrimaryBarrelAction: StylusBarrelAction.colorPicker,
      stylusPrimaryTriggerMode: StylusTriggerMode.hold,
      stylusSecondaryBarrelAction: StylusBarrelAction.disabled,
      enableStylusHoverPreview: true,
    ));
    await tester.pump();

    final gesture2 = await tester.createGesture(kind: PointerDeviceKind.stylus, buttons: kSecondaryStylusButton);
    await gesture2.down(const Offset(150, 150));
    await tester.pump();

    expect(fakeContext.sampleColorCalled, isTrue);
    await gesture2.up();
    await gesture2.removePointer();
    await tester.pump();
  });

  testWidgets('CanvasInputRouter suppresses drawing strokes when interacting with cards', (WidgetTester tester) async {
    final fakeContext = _FakeCanvasInputContext();
    final testCard = CanvasCardModel(
      id: 'card_touch_test',
      x: 50,
      y: 50,
      width: 300,
      height: 200,
      title: 'Card Under Test',
    );
    fakeContext.currentNote?.cards.add(testCard);

    final strokeUpdateNotifier = ValueNotifier<int>(0);
    final selectionUpdateNotifier = ValueNotifier<int>(0);
    final panNotifier = ValueNotifier<Offset>(Offset.zero);
    final zoomNotifier = ValueNotifier<double>(1.0);

    const activePenPreset = PenSlotPreset(
      id: 'slot_1',
      name: 'Pen',
      color: Colors.white,
      strokeWidth: 2.0,
    );

    bool strokeCommitted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanvasInputRouter(
            canvasContext: fakeContext,
            activePenPreset: activePenPreset,
            activeStrokeUpdateNotifier: strokeUpdateNotifier,
            selectionUpdateNotifier: selectionUpdateNotifier,
            panNotifier: panNotifier,
            zoomNotifier: zoomNotifier,
            onCommitStroke: (_) {
              strokeCommitted = true;
            },
            onScheduleBounceCheck: () {},
            child: Container(color: Colors.black),
          ),
        ),
      ),
    );

    // Click/Drag on top of the card at (100, 100)
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(const Offset(100, 100));
    await tester.pump();
    await gesture.moveTo(const Offset(120, 120));
    await tester.pump();
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();

    // No stroke should be committed because it was on a card
    expect(strokeCommitted, isFalse);
    expect(fakeContext.selectedCardId, equals('card_touch_test'));
  });

  testWidgets('CanvasInputRouter handles Middle Click (buttons == 4) Pan immediately', (WidgetTester tester) async {
    final fakeContext = _FakeCanvasInputContext();
    final strokeUpdateNotifier = ValueNotifier<int>(0);
    final selectionUpdateNotifier = ValueNotifier<int>(0);
    final panNotifier = ValueNotifier<Offset>(Offset.zero);
    final zoomNotifier = ValueNotifier<double>(1.0);
    bool bounceCheckCalled = false;

    const activePenPreset = PenSlotPreset(
      id: 'slot_1',
      name: 'Pen',
      color: Colors.white,
      strokeWidth: 2.0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanvasInputRouter(
            canvasContext: fakeContext,
            activePenPreset: activePenPreset,
            activeStrokeUpdateNotifier: strokeUpdateNotifier,
            selectionUpdateNotifier: selectionUpdateNotifier,
            panNotifier: panNotifier,
            zoomNotifier: zoomNotifier,
            onCommitStroke: (_) {},
            onScheduleBounceCheck: () {
              bounceCheckCalled = true;
            },
            child: Container(color: Colors.black),
          ),
        ),
      ),
    );

    // Middle click down (buttons: kMiddleMouseButton = 4)
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kMiddleMouseButton);
    await gesture.down(const Offset(200, 200));
    await tester.pump();
    await gesture.moveTo(const Offset(150, 150));
    await tester.pump();

    // Pan notifier should have been updated by delta (-50, -50)
    expect(panNotifier.value, equals(const Offset(-50, -50)));

    await gesture.up();
    await gesture.removePointer();
    await tester.pump();

    expect(bounceCheckCalled, isTrue);
  });

  testWidgets('CanvasInputRouter Stylus Toggle vs Hold mode and Settings reset', (WidgetTester tester) async {
    final fakeContext = _FakeCanvasInputContext();
    final strokeUpdateNotifier = ValueNotifier<int>(0);
    final selectionUpdateNotifier = ValueNotifier<int>(0);
    final panNotifier = ValueNotifier<Offset>(Offset.zero);
    final zoomNotifier = ValueNotifier<double>(1.0);

    const activePenPreset = PenSlotPreset(
      id: 'slot_1',
      name: 'Pen',
      color: Colors.white,
      strokeWidth: 2.0,
    );

    // Configure primary button to Toggle mode with strokeEraser
    SettingsService.instance.updateSettingsInMemory(const AppSettingsState(
      stylusPrimaryBarrelAction: StylusBarrelAction.strokeEraser,
      stylusPrimaryTriggerMode: StylusTriggerMode.toggle,
      stylusSecondaryBarrelAction: StylusBarrelAction.disabled,
      enableStylusHoverPreview: true,
    ));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanvasInputRouter(
            canvasContext: fakeContext,
            activePenPreset: activePenPreset,
            activeStrokeUpdateNotifier: strokeUpdateNotifier,
            selectionUpdateNotifier: selectionUpdateNotifier,
            panNotifier: panNotifier,
            zoomNotifier: zoomNotifier,
            onCommitStroke: (_) {},
            onScheduleBounceCheck: () {},
            child: Container(color: Colors.black),
          ),
        ),
      ),
    );

    // 1. Hover with stylus
    final stylus = await tester.createGesture(kind: PointerDeviceKind.stylus);
    await stylus.addPointer(location: const Offset(100, 100));
    await tester.pump();

    // Toggle ON via barrel button click event
    StylusNativeChannel.instance.updateStateForTesting(const StylusNativeStateData(
      isPrimaryBarrelPressed: true,
      isSecondaryBarrelPressed: false,
      isInvertedEraser: false,
    ));
    StylusNativeChannel.instance.updateStateForTesting(StylusNativeStateData.released);
    await tester.pump();

    // 2. Now drawing with stylus tip executes the toggled action (strokeEraser)
    fakeContext.eraseCalled = false;
    await stylus.down(const Offset(120, 120));
    await tester.pump();

    expect(fakeContext.eraseCalled, isTrue);

    await stylus.up();
    await tester.pump();

    // 3. Toggle OFF by clicking barrel button again
    StylusNativeChannel.instance.updateStateForTesting(const StylusNativeStateData(
      isPrimaryBarrelPressed: true,
      isSecondaryBarrelPressed: false,
      isInvertedEraser: false,
    ));
    StylusNativeChannel.instance.updateStateForTesting(StylusNativeStateData.released);
    await tester.pump();

    // 4. Now drawing with stylus tip returns to default tool (pen) and doesn't call erase
    fakeContext.eraseCalled = false;
    await stylus.down(const Offset(140, 140));
    await tester.pump();

    expect(fakeContext.eraseCalled, isFalse);

    await stylus.up();
    await stylus.removePointer();
    await tester.pump();
  });
}

