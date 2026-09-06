import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:connotes_app/models/canvas_card_model.dart';
import 'package:connotes_app/services/media_compression_service.dart';
import 'package:connotes_app/widgets/card_magnetic_snapper.dart';
import 'package:connotes_app/widgets/ink_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaCompressionService Tests', () {
    test('comprime e redimensiona imagem maior que 1920px', () async {
      // Cria imagem sintética 2400x1200
      final image = img.Image(width: 2400, height: 1200);
      img.fill(image, color: img.ColorRgb8(0, 225, 255));
      final rawPng = img.encodePng(image);

      final result = await MediaCompressionService.compressImageBytes(rawPng, maxDimension: 1920);

      expect(result, isNotNull);
      expect(result!.originalWidth, equals(2400));
      expect(result.originalHeight, equals(1200));
      expect(result.compressedWidth, equals(1920));
      expect(result.compressedHeight, equals(960));
      expect(result.aspectRatio, closeTo(2.0, 0.01));
      expect(result.dataUri.startsWith('data:image/'), isTrue);
      expect(result.byteSize, greaterThan(0));
    });

    test('preserva dimensões quando menor que maxDimension', () async {
      final image = img.Image(width: 800, height: 600);
      img.fill(image, color: img.ColorRgb8(255, 0, 128));
      final rawJpg = img.encodeJpg(image, quality: 90);

      final result = await MediaCompressionService.compressImageBytes(rawJpg, maxDimension: 1920);

      expect(result, isNotNull);
      expect(result!.originalWidth, equals(800));
      expect(result.originalHeight, equals(600));
      expect(result.compressedWidth, equals(800));
      expect(result.compressedHeight, equals(600));
      expect(result.aspectRatio, closeTo(1.333, 0.01));
    });
  });

  group('CanvasCardModel Media Tests', () {
    test('serialização e desserialização de CardType.media', () {
      final card = CanvasCardModel(
        id: 'test_media_1',
        cardType: CardType.media,
        title: 'Esquema Elétrico',
        x: 150.0,
        y: 250.0,
        width: 400.0,
        height: 300.0,
        mediaData: 'data:image/webp;base64,AAAA',
        originalAspectRatio: 1.5,
        lockAspectRatio: true,
        mediaFit: BoxFit.cover,
        caption: 'Figura 1: Circuito RLC',
      );

      final map = card.toMap();
      expect(map['cardType'], equals('media'));
      expect(map['mediaData'], equals('data:image/webp;base64,AAAA'));
      expect(map['originalAspectRatio'], equals(1.5));
      expect(map['lockAspectRatio'], isTrue);
      expect(map['mediaFit'], equals('cover'));
      expect(map['caption'], equals('Figura 1: Circuito RLC'));

      final restored = CanvasCardModel.fromMap(map);
      expect(restored.id, equals(card.id));
      expect(restored.cardType, equals(CardType.media));
      expect(restored.title, equals(card.title));
      expect(restored.mediaData, equals(card.mediaData));
      expect(restored.originalAspectRatio, equals(1.5));
      expect(restored.lockAspectRatio, isTrue);
      expect(restored.mediaFit, equals(BoxFit.cover));
      expect(restored.caption, equals('Figura 1: Circuito RLC'));
    });

    test('cálculo de altura mínima respeita proporção travada para mídias', () {
      final card = CanvasCardModel(
        id: 'test_media_2',
        cardType: CardType.media,
        x: 0.0,
        y: 0.0,
        width: 400.0,
        height: 200.0,
        originalAspectRatio: 2.0,
        lockAspectRatio: true,
      );

      // minHeight = width / originalAspectRatio = 400 / 2.0 = 200.0
      expect(card.calculateMinHeight(), equals(200.0));
    });

    test('serializa e desserializa invertLuminance e isDrawOverMode', () {
      final card = CanvasCardModel(
        id: 'test_media_stem',
        cardType: CardType.media,
        x: 10.0,
        y: 20.0,
        width: 300.0,
        height: 200.0,
        invertLuminance: true,
        isDrawOverMode: true,
      );

      final map = card.toMap();
      expect(map['invertLuminance'], isTrue);
      expect(map['isDrawOverMode'], isTrue);

      final restored = CanvasCardModel.fromMap(map);
      expect(restored.invertLuminance, isTrue);
      expect(restored.isDrawOverMode, isTrue);
    });
  });

  group('CardMagneticSnapper Tests', () {
    test('snap à borda esquerda de outro card', () {
      final card1 = CanvasCardModel(
        id: 'card1',
        x: 100.0,
        y: 100.0,
        width: 200.0,
        height: 150.0,
      );

      // Target posicionado a 105.0 (diff 5px < threshold 10px)
      final result = CardMagneticSnapper.snap(
        targetX: 105.0,
        targetY: 300.0,
        width: 200.0,
        height: 150.0,
        currentCardId: 'card2',
        otherCards: [card1],
        snapToGrid: false,
      );

      expect(result.snappedX, isTrue);
      expect(result.x, equals(100.0));
    });

    test('snap à direita de outro card (encadeamento horizontal)', () {
      final card1 = CanvasCardModel(
        id: 'card1',
        x: 100.0,
        y: 100.0,
        width: 200.0,
        height: 150.0,
      );

      // card1 termina em x = 300.0. Target tenta se posicionar em x = 304.0
      final result = CardMagneticSnapper.snap(
        targetX: 304.0,
        targetY: 100.0,
        width: 150.0,
        height: 100.0,
        currentCardId: 'card2',
        otherCards: [card1],
        snapToGrid: false,
      );

      expect(result.snappedX, isTrue);
      expect(result.x, equals(300.0));
    });

    test('não realiza snap em espaço vazio do canvas', () {
      final result = CardMagneticSnapper.snap(
        targetX: 54.0,
        targetY: 82.0,
        width: 100.0,
        height: 100.0,
        currentCardId: 'card_alone',
        otherCards: [],
        gridSpacing: 28.0,
        snapToGrid: true,
      );

      expect(result.snappedX, isFalse);
      expect(result.snappedY, isFalse);
      expect(result.x, equals(54.0));
      expect(result.y, equals(82.0));
    });

    test('serializa e desserializa rotation e attachedStrokeIds', () {
      final card = CanvasCardModel(
        id: 'test_card_rotation',
        x: 50.0,
        y: 60.0,
        rotation: 1.5708,
        attachedStrokeIds: ['stroke_1', 'stroke_2'],
      );

      final json = card.toJson();
      expect(json['rotation'], equals(1.5708));
      expect(json['attachedStrokeIds'], equals(['stroke_1', 'stroke_2']));

      final restored = CanvasCardModel.fromJson(json);
      expect(restored.rotation, equals(1.5708));
      expect(restored.attachedStrokeIds, equals(['stroke_1', 'stroke_2']));
    });
  });

  group('Attached Strokes Synchronization Tests', () {
    test('StrokePoint translate e rotateAround transladam e rotacionam com precisão', () {
      final point = StrokePoint(point: const Offset(100, 100), pressure: 0.8, tilt: 0.2);
      final translated = point.translate(20, -10);
      expect(translated.point.dx, closeTo(120, 0.001));
      expect(translated.point.dy, closeTo(90, 0.001));
      expect(translated.pressure, equals(0.8));

      const cardCenter = Offset(100, 50);
      // Rotaciona 90 graus (pi / 2) ao redor do centro (100, 50)
      // dx = 100 - 100 = 0, dy = 100 - 50 = 50
      // rotated: x = 100 + (0*0 - 50*1) = 50, y = 50 + (0*1 + 50*0) = 50
      final rotated = point.rotateAround(cardCenter, math.pi / 2);
      expect(rotated.point.dx, closeTo(50, 0.001));
      expect(rotated.point.dy, closeTo(50, 0.001));
    });

    test('CanvasCardModel calcula center e expõe type alias corretamente', () {
      final card = CanvasCardModel(
        id: 'card_center_test',
        x: 100,
        y: 200,
        width: 300,
        height: 100,
        cardType: CardType.media,
      );
      expect(card.type, equals(CardType.media));
      expect(card.center, equals(const Offset(250, 250)));
    });
  });
}
