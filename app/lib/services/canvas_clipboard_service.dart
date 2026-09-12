import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pasteboard/pasteboard.dart';
import '../models/canvas_card_model.dart';
import '../widgets/ink_models.dart';
import '../widgets/note_models.dart';
import '../widgets/selection_models.dart';
import '../widgets/undo_commands.dart';
import '../widgets/selection_overlay_painter.dart';
import 'media_compression_service.dart';
import '../dev_hub/dev_hub_server.dart';
import 'workspace_storage_service.dart';

/// Resultado de uma ação de colagem no Canvas.
class CanvasPasteResult {
  final List<CanvasCardModel> pastedCards;
  final List<InkStroke> pastedStrokes;
  final SelectionState newSelectionState;
  final String? singleSelectedCardId;

  const CanvasPasteResult({
    required this.pastedCards,
    required this.pastedStrokes,
    required this.newSelectionState,
    this.singleSelectedCardId,
  });
}

/// Serviço isolado responsável por todas as operações de cópia e colagem no Canvas
/// (mídia pura para Windows/OS, traços e cards estruturados).
class CanvasClipboardService {
  CanvasClipboardService._();
  static final CanvasClipboardService instance = CanvasClipboardService._();

  List<CanvasCardModel> _clipboardCards = [];
  List<InkStroke> _clipboardStrokes = [];
  int _counter = 0;

  bool get hasInternalClipboard => _clipboardCards.isNotEmpty || _clipboardStrokes.isNotEmpty;

  /// Executa o fluxo de cópia (Ctrl+C).
  /// Se um card de mídia estiver selecionado, extrai a imagem pura e grava no clipboard do OS.
  /// Caso contrário, armazena traços e cards no clipboard interno com bounding boxes preservados.
  Future<void> copy({
    required NoteDocument note,
    required SelectionState selectionState,
    required String? selectedCardId,
  }) async {
    _clipboardCards.clear();
    _clipboardStrokes.clear();

    final selectedCards = <CanvasCardModel>[];
    if (selectionState.selectedCardIds.isNotEmpty) {
      for (final cardId in selectionState.selectedCardIds) {
        final c = note.cards.cast<CanvasCardModel?>().firstWhere((card) => card?.id == cardId, orElse: () => null);
        if (c != null) selectedCards.add(c);
      }
    } else if (selectedCardId != null) {
      final c = note.cards.cast<CanvasCardModel?>().firstWhere((card) => card?.id == selectedCardId, orElse: () => null);
      if (c != null) selectedCards.add(c);
    }

    final selectedStrokes = <InkStroke>[];
    if (selectionState.selectedStrokeIds.isNotEmpty) {
      for (final strokeId in selectionState.selectedStrokeIds) {
        final s = note.getStroke(strokeId);
        if (s != null) selectedStrokes.add(s);
      }
    }

    // Se houver card de mídia selecionado, copia a imagem pura para a área de transferência do sistema
    CanvasCardModel? mediaCardToCopy;
    if (selectedCards.length == 1 && selectedCards.first.cardType == CardType.media) {
      mediaCardToCopy = selectedCards.first;
    } else if (selectedCardId != null) {
      final c = note.cards.cast<CanvasCardModel?>().firstWhere((card) => card?.id == selectedCardId, orElse: () => null);
      if (c != null && c.cardType == CardType.media) {
        mediaCardToCopy = c;
      }
    }

    if (mediaCardToCopy != null && mediaCardToCopy.mediaData != null && mediaCardToCopy.mediaData!.isNotEmpty) {
      try {
        final mediaData = mediaCardToCopy.mediaData!;
        Uint8List? bytes;
        if (mediaData.startsWith('data:') && mediaData.contains(',')) {
          bytes = base64Decode(mediaData.split(',').last);
        } else {
          final file = File(mediaData);
          if (file.existsSync()) {
            bytes = await file.readAsBytes();
          } else {
            bytes = base64Decode(mediaData);
          }
        }

        if (bytes != null && bytes.isNotEmpty) {
          await Pasteboard.writeImage(bytes);
          try {
            final tempDir = Directory.systemTemp;
            final tempPng = File('${tempDir.path}\\connotes_clipboard_${DateTime.now().millisecondsSinceEpoch}.png');
            await tempPng.writeAsBytes(bytes);
            await Pasteboard.writeFiles([tempPng.path]);
          } catch (fileErr) {
            debugPrint('[CanvasClipboardService] Aviso ao registrar arquivo png no clipboard: $fileErr');
          }
          _clipboardCards.clear();
          _clipboardStrokes.clear();
          DevHubServer.instance.logAction('Copiar Imagem Mídia para Clipboard do Sistema (${bytes.lengthInBytes ~/ 1024} KB)');
          return;
        }
      } catch (e) {
        debugPrint('[CanvasClipboardService] Erro ao gravar imagem no clipboard: $e');
      }
    }

    _clipboardCards = List<CanvasCardModel>.from(selectedCards.where((c) => c.cardType != CardType.media));
    _clipboardStrokes = List<InkStroke>.from(selectedStrokes);

    DevHubServer.instance.logAction('Copiar (${_clipboardCards.length} cards, ${_clipboardStrokes.length} traços)');
  }

  /// Executa o fluxo de colagem (Ctrl+V).
  /// Prioriza traços/cards copiados internamente. Se vazio, consome imagem externa do clipboard do sistema.
  Future<CanvasPasteResult?> paste({
    required NoteDocument note,
    required Offset canvasMousePos,
    required double zoomScale,
    required SelectionType selectionType,
    required AppUndoManager undoManager,
    required void Function(NoteDocument note, List<InkStroke> strokes) ingestStrokesAdaptively,
  }) async {
    // 1. Se houver conteúdo interno copiado no conNotes (prioridade absoluta)
    if (_clipboardCards.isNotEmpty || _clipboardStrokes.isNotEmpty) {
      double minX = double.infinity, minY = double.infinity;
      double maxX = -double.infinity, maxY = -double.infinity;

      for (final c in _clipboardCards) {
        if (c.x < minX) minX = c.x;
        if (c.y < minY) minY = c.y;
        if (c.x + c.width > maxX) maxX = c.x + c.width;
        if (c.y + c.height > maxY) maxY = c.y + c.height;
      }
      for (final s in _clipboardStrokes) {
        final b = s.boundingBox ?? SelectionGeometry.computeStrokeBounds(s);
        if (b.left < minX) minX = b.left;
        if (b.top < minY) minY = b.top;
        if (b.right > maxX) maxX = b.right;
        if (b.bottom > maxY) maxY = b.bottom;
      }

      final Rect originalBounds = (minX.isFinite && minY.isFinite)
          ? Rect.fromLTRB(minX, minY, maxX, maxY)
          : const Rect.fromLTWH(0, 0, 300, 200);

      final offsetToMouse = canvasMousePos.dx > 0
          ? (canvasMousePos - originalBounds.center)
          : const Offset(30.0, 30.0);

      final nowMicro = DateTime.now().microsecondsSinceEpoch;
      final allNewCards = <CanvasCardModel>[];
      final allNewCardIds = <String>{};
      final allNewStrokes = <InkStroke>[];
      final allNewSelectedIds = <String>{};

      for (var i = 0; i < _clipboardCards.length; i++) {
        final c = _clipboardCards[i];
        final newId = 'card_${nowMicro}_${_counter++}_$i';
        final clone = c.copyWith(
          id: newId,
          x: c.x + offsetToMouse.dx,
          y: c.y + offsetToMouse.dy,
        );
        allNewCards.add(clone);
        allNewCardIds.add(newId);
      }

      for (var i = 0; i < _clipboardStrokes.length; i++) {
        final s = _clipboardStrokes[i];
        final newId = '${nowMicro}_${_counter++}_${s.id}';
        final clone = InkStroke(
          id: newId,
          points: s.points,
          transform: s.transform + offsetToMouse,
          color: s.color,
          strokeWidth: s.strokeWidth,
          toolType: s.toolType,
          enablePressure: s.enablePressure,
          boundingBox: s.boundingBox?.shift(offsetToMouse),
          cachedPath: s.cachedPath,
          cachedRawPoints: s.cachedRawPoints,
        );
        allNewStrokes.add(clone);
        allNewSelectedIds.add(newId);
      }

      final commands = <UndoCommand>[];
      for (final card in allNewCards) {
        commands.add(AddCardCommand(card));
      }
      if (allNewStrokes.isNotEmpty) {
        ingestStrokesAdaptively(note, allNewStrokes);
        commands.add(DuplicateStrokesCommand(allNewStrokes));
      }

      if (commands.length == 1) {
        undoManager.pushCommand(commands.first, execute: true, note: note);
      } else if (commands.length > 1) {
        undoManager.pushCommand(BatchCommand(commands), execute: true, note: note);
      }

      WorkspaceStorageService.instance.scheduleAutoSave(note);
      DevHubServer.instance.logAction('Colar (${allNewCards.length} cards, ${allNewStrokes.length} traços)');

      return CanvasPasteResult(
        pastedCards: allNewCards,
        pastedStrokes: allNewStrokes,
        singleSelectedCardId: allNewCardIds.length == 1 ? allNewCardIds.first : null,
        newSelectionState: SelectionState(
          type: selectionType,
          selectedStrokeIds: allNewSelectedIds,
          selectedCardIds: allNewCardIds,
          bounds: originalBounds.shift(offsetToMouse),
          dragOffset: Offset.zero,
        ),
      );
    }

    // 2. Se a clipboard interna estiver vazia, verifica imagem no clipboard nativo do OS
    try {
      final clipboardImage = await Pasteboard.image;
      if (clipboardImage != null && clipboardImage.isNotEmpty) {
        final compressed = await MediaCompressionService.compressImageBytes(clipboardImage);
        if (compressed != null) {
          final nowMicro = DateTime.now().microsecondsSinceEpoch;
          final newId = 'card_media_${nowMicro}_${_counter++}';

          final visualDesiredWidth = 420.0;
          final zoomScaledWidth = visualDesiredWidth / (zoomScale > 0 ? zoomScale : 1.0);
          final targetWidth = zoomScaledWidth.clamp(160.0, 1400.0);
          final targetHeight = compressed.aspectRatio > 0
              ? (targetWidth / compressed.aspectRatio)
              : 220.0;

          final newCard = CanvasCardModel(
            id: newId,
            cardType: CardType.media,
            title: 'Mídia',
            mediaData: compressed.dataUri,
            originalAspectRatio: compressed.aspectRatio,
            lockAspectRatio: true,
            x: canvasMousePos.dx - (targetWidth / 2),
            y: canvasMousePos.dy - (targetHeight / 2),
            width: targetWidth,
            height: targetHeight,
          );

          undoManager.pushCommand(
            AddCardCommand(newCard),
            execute: true,
            note: note,
          );

          WorkspaceStorageService.instance.scheduleAutoSave(note);
          DevHubServer.instance.logAction('Colar Mídia do Clipboard do OS (${compressed.byteSize ~/ 1024} KB)');

          return CanvasPasteResult(
            pastedCards: [newCard],
            pastedStrokes: [],
            singleSelectedCardId: newCard.id,
            newSelectionState: SelectionState.empty(),
          );
        }
      }
    } catch (e) {
      debugPrint('[CanvasClipboardService] Erro ao obter imagem da área de transferência: $e');
    }

    return null;
  }
}
