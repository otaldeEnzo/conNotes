import 'package:flutter/material.dart';
import 'ink_models.dart';
import 'note_models.dart';
import '../models/canvas_card_model.dart';

/// Interface para todos os comandos de Undo/Redo no formato Command Pattern
abstract class UndoCommand {
  void execute(NoteDocument note);
  void undo(NoteDocument note);
}

/// Comando para adicionar um novo traço
class AddStrokeCommand implements UndoCommand {
  final InkStroke stroke;

  AddStrokeCommand(this.stroke);

  @override
  void execute(NoteDocument note) {
    note.addStroke(stroke);
  }

  @override
  void undo(NoteDocument note) {
    note.removeStroke(stroke.id);
  }
}

/// Comando para remover um ou mais traços
class RemoveStrokesCommand implements UndoCommand {
  final List<InkStroke> strokes;

  RemoveStrokesCommand(this.strokes);

  @override
  void execute(NoteDocument note) {
    note.removeAllStrokes(strokes.map((s) => s.id));
  }

  @override
  void undo(NoteDocument note) {
    note.addAllStrokes(strokes);
  }
}

/// Comando para mudar a cor de traços
class ChangeColorCommand implements UndoCommand {
  final Map<String, Color> previousColors;
  final Map<String, Color> newColors;

  ChangeColorCommand({
    required this.previousColors,
    required this.newColors,
  });

  @override
  void execute(NoteDocument note) {
    _applyColors(note, newColors);
  }

  @override
  void undo(NoteDocument note) {
    _applyColors(note, previousColors);
  }

  void _applyColors(NoteDocument note, Map<String, Color> colors) {
    for (final entry in colors.entries) {
      final id = entry.key;
      final color = entry.value;
      final stroke = note.getStroke(id);
      if (stroke != null) {
        final updatedStroke = InkStroke(
          id: stroke.id,
          points: stroke.points,
          color: color,
          strokeWidth: stroke.strokeWidth,
          toolType: stroke.toolType,
          enablePressure: stroke.enablePressure,
          boundingBox: stroke.boundingBox,
          cachedPath: stroke.cachedPath,
          transform: stroke.transform,
        );
        note.updateStroke(updatedStroke);
      }
    }
  }
}

/// Comando para duplicar traços
class DuplicateStrokesCommand implements UndoCommand {
  final List<InkStroke> duplicatedStrokes;

  DuplicateStrokesCommand(this.duplicatedStrokes);

  @override
  void execute(NoteDocument note) {
    note.addAllStrokes(duplicatedStrokes);
  }

  @override
  void undo(NoteDocument note) {
    note.removeAllStrokes(duplicatedStrokes.map((s) => s.id));
  }
}

/// Comando para mover traços
class MoveStrokesCommand implements UndoCommand {
  final List<InkStroke> originalStrokes;
  final List<InkStroke> updatedStrokes;

  MoveStrokesCommand({
    required this.originalStrokes,
    required this.updatedStrokes,
  });

  @override
  void execute(NoteDocument note) {
    note.updateAllStrokes(updatedStrokes);
  }

  @override
  void undo(NoteDocument note) {
    note.updateAllStrokes(originalStrokes);
  }
}

/// Comando para adicionar um novo card
class AddCardCommand implements UndoCommand {
  final CanvasCardModel card;

  AddCardCommand(this.card);

  @override
  void execute(NoteDocument note) {
    if (!note.cards.any((c) => c.id == card.id)) {
      note.cards.add(card);
    }
  }

  @override
  void undo(NoteDocument note) {
    note.cards.removeWhere((c) => c.id == card.id);
  }
}

/// Comando para remover um card
class RemoveCardCommand implements UndoCommand {
  final CanvasCardModel card;

  RemoveCardCommand(this.card);

  @override
  void execute(NoteDocument note) {
    note.cards.removeWhere((c) => c.id == card.id);
  }

  @override
  void undo(NoteDocument note) {
    if (!note.cards.any((c) => c.id == card.id)) {
      note.cards.add(card);
    }
  }
}

/// Comando para atualizar/modificar um card (título, conteúdo, tamanho, posição, formatação)
class UpdateCardCommand implements UndoCommand {
  final String cardId;
  final CanvasCardModel previousCard;
  final CanvasCardModel newCard;

  UpdateCardCommand({
    required this.cardId,
    required this.previousCard,
    required this.newCard,
  });

  @override
  void execute(NoteDocument note) {
    final idx = note.cards.indexWhere((c) => c.id == cardId);
    if (idx != -1) {
      note.cards[idx] = newCard;
    }
  }

  @override
  void undo(NoteDocument note) {
    final idx = note.cards.indexWhere((c) => c.id == cardId);
    if (idx != -1) {
      note.cards[idx] = previousCard;
    }
  }
}

/// Gerenciador de Desfazer/Refazer
class AppUndoManager {
  final Map<String, List<UndoCommand>> _undoStacks = {};
  final Map<String, List<UndoCommand>> _redoStacks = {};
  
  // Limite máximo de comandos em memória (ex: previne memory leak se rodar pra sempre)
  static const int _maxHistory = 100;

  bool canUndo(NoteDocument note) => _undoStacks[note.id]?.isNotEmpty ?? false;
  bool canRedo(NoteDocument note) => _redoStacks[note.id]?.isNotEmpty ?? false;

  void pushCommand(UndoCommand command, {required bool execute, required NoteDocument note}) {
    if (execute) {
      command.execute(note);
    }
    
    _undoStacks.putIfAbsent(note.id, () => []).add(command);
    _redoStacks[note.id]?.clear(); // Qualquer nova ação invalida a pilha de Redo
    
    if (_undoStacks[note.id]!.length > _maxHistory) {
      _undoStacks[note.id]!.removeAt(0);
    }
  }

  void undo(NoteDocument note) {
    if (!canUndo(note)) return;
    
    final command = _undoStacks[note.id]!.removeLast();
    command.undo(note);
    _redoStacks.putIfAbsent(note.id, () => []).add(command);
  }

  void redo(NoteDocument note) {
    if (!canRedo(note)) return;
    
    final command = _redoStacks[note.id]!.removeLast();
    command.execute(note);
    _undoStacks.putIfAbsent(note.id, () => []).add(command);
  }
}

/// Comando em lote para executar múltiplos comandos como um único passo
class BatchCommand implements UndoCommand {
  final List<UndoCommand> commands;

  BatchCommand(this.commands);

  @override
  void execute(NoteDocument note) {
    for (final command in commands) {
      command.execute(note);
    }
  }

  @override
  void undo(NoteDocument note) {
    for (final command in commands.reversed) {
      command.undo(note);
    }
  }
}
