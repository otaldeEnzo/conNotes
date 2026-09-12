import 'package:flutter/material.dart';
import 'ink_models.dart';
import 'note_models.dart';
import '../models/canvas_card_model.dart';

/// Interface para todos os comandos de Undo/Redo no formato Command Pattern
abstract class UndoCommand {
  void execute(NoteDocument note);
  void undo(NoteDocument note);
  Map<String, dynamic> toJson();

  static UndoCommand? fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'addStroke':
        return AddStrokeCommand.fromJson(json);
      case 'removeStrokes':
        return RemoveStrokesCommand.fromJson(json);
      case 'changeColor':
        return ChangeColorCommand.fromJson(json);
      case 'duplicateStrokes':
        return DuplicateStrokesCommand.fromJson(json);
      case 'moveStrokes':
        return MoveStrokesCommand.fromJson(json);
      case 'addCard':
        return AddCardCommand.fromJson(json);
      case 'removeCard':
        return RemoveCardCommand.fromJson(json);
      case 'updateCard':
        return UpdateCardCommand.fromJson(json);
      case 'batch':
        return BatchCommand.fromJson(json);
      case 'syncCardStrokes':
        return SyncCardStrokesCommand.fromJson(json);
      default:
        return null;
    }
  }
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

  @override
  Map<String, dynamic> toJson() => {
    'type': 'addStroke',
    'stroke': stroke.toJson(),
  };

  factory AddStrokeCommand.fromJson(Map<String, dynamic> json) {
    return AddStrokeCommand(InkStroke.fromJson(json['stroke'] as Map<String, dynamic>));
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

  @override
  Map<String, dynamic> toJson() => {
    'type': 'removeStrokes',
    'strokes': strokes.map((s) => s.toJson()).toList(),
  };

  factory RemoveStrokesCommand.fromJson(Map<String, dynamic> json) {
    final list = (json['strokes'] as List<dynamic>?) ?? [];
    return RemoveStrokesCommand(
      list.map((s) => InkStroke.fromJson(s as Map<String, dynamic>)).toList(),
    );
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

  @override
  Map<String, dynamic> toJson() => {
    'type': 'changeColor',
    'previousColors': previousColors.map((k, v) => MapEntry(k, v.toARGB32())),
    'newColors': newColors.map((k, v) => MapEntry(k, v.toARGB32())),
  };

  factory ChangeColorCommand.fromJson(Map<String, dynamic> json) {
    final prevMap = (json['previousColors'] as Map<String, dynamic>?) ?? {};
    final newMap = (json['newColors'] as Map<String, dynamic>?) ?? {};
    return ChangeColorCommand(
      previousColors: prevMap.map((k, v) => MapEntry(k, Color((v as num).toInt()))),
      newColors: newMap.map((k, v) => MapEntry(k, Color((v as num).toInt()))),
    );
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

  @override
  Map<String, dynamic> toJson() => {
    'type': 'duplicateStrokes',
    'duplicatedStrokes': duplicatedStrokes.map((s) => s.toJson()).toList(),
  };

  factory DuplicateStrokesCommand.fromJson(Map<String, dynamic> json) {
    final list = (json['duplicatedStrokes'] as List<dynamic>?) ?? [];
    return DuplicateStrokesCommand(
      list.map((s) => InkStroke.fromJson(s as Map<String, dynamic>)).toList(),
    );
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

  @override
  Map<String, dynamic> toJson() => {
    'type': 'moveStrokes',
    'originalStrokes': originalStrokes.map((s) => s.toJson()).toList(),
    'updatedStrokes': updatedStrokes.map((s) => s.toJson()).toList(),
  };

  factory MoveStrokesCommand.fromJson(Map<String, dynamic> json) {
    final origList = (json['originalStrokes'] as List<dynamic>?) ?? [];
    final updList = (json['updatedStrokes'] as List<dynamic>?) ?? [];
    return MoveStrokesCommand(
      originalStrokes: origList.map((s) => InkStroke.fromJson(s as Map<String, dynamic>)).toList(),
      updatedStrokes: updList.map((s) => InkStroke.fromJson(s as Map<String, dynamic>)).toList(),
    );
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

  @override
  Map<String, dynamic> toJson() => {
    'type': 'addCard',
    'card': card.toMap(),
  };

  factory AddCardCommand.fromJson(Map<String, dynamic> json) {
    return AddCardCommand(CanvasCardModel.fromMap(json['card'] as Map<String, dynamic>));
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

  @override
  Map<String, dynamic> toJson() => {
    'type': 'removeCard',
    'card': card.toMap(),
  };

  factory RemoveCardCommand.fromJson(Map<String, dynamic> json) {
    return RemoveCardCommand(CanvasCardModel.fromMap(json['card'] as Map<String, dynamic>));
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

  @override
  Map<String, dynamic> toJson() => {
    'type': 'updateCard',
    'cardId': cardId,
    'previousCard': previousCard.toMap(),
    'newCard': newCard.toMap(),
  };

  factory UpdateCardCommand.fromJson(Map<String, dynamic> json) {
    return UpdateCardCommand(
      cardId: json['cardId'] as String? ?? '',
      previousCard: CanvasCardModel.fromMap(json['previousCard'] as Map<String, dynamic>),
      newCard: CanvasCardModel.fromMap(json['newCard'] as Map<String, dynamic>),
    );
  }
}

/// Gerenciador Universal de Desfazer/Refazer com suporte a persistência por Nota
class AppUndoManager {
  static final AppUndoManager instance = AppUndoManager._internal();
  AppUndoManager._internal();
  factory AppUndoManager() => instance;

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

  void clear() {
    _undoStacks.clear();
    _redoStacks.clear();
  }

  /// Serializa o histórico de Undo e Redo de uma nota para persistência no arquivo .cncanvas
  Map<String, dynamic> serializeHistory(String noteId, {int maxCommands = 50}) {
    final undoList = _undoStacks[noteId] ?? [];
    final redoList = _redoStacks[noteId] ?? [];

    final startIdx = undoList.length > maxCommands ? undoList.length - maxCommands : 0;
    final trimmedUndo = undoList.sublist(startIdx);

    final startRedoIdx = redoList.length > maxCommands ? redoList.length - maxCommands : 0;
    final trimmedRedo = redoList.sublist(startRedoIdx);

    return {
      'undoStack': trimmedUndo.map((c) => c.toJson()).toList(),
      'redoStack': trimmedRedo.map((c) => c.toJson()).toList(),
    };
  }

  /// Restaura as pilhas de Undo e Redo a partir de dados serializados
  void restoreHistory(String noteId, Map<String, dynamic>? historyData) {
    if (historyData == null) return;
    try {
      final rawUndo = historyData['undoStack'] as List<dynamic>?;
      if (rawUndo != null && rawUndo.isNotEmpty) {
        final stack = <UndoCommand>[];
        for (final item in rawUndo) {
          if (item is Map) {
            final cmd = UndoCommand.fromJson(Map<String, dynamic>.from(item));
            if (cmd != null) stack.add(cmd);
          }
        }
        _undoStacks[noteId] = stack;
      }

      final rawRedo = historyData['redoStack'] as List<dynamic>?;
      if (rawRedo != null && rawRedo.isNotEmpty) {
        final stack = <UndoCommand>[];
        for (final item in rawRedo) {
          if (item is Map) {
            final cmd = UndoCommand.fromJson(Map<String, dynamic>.from(item));
            if (cmd != null) stack.add(cmd);
          }
        }
        _redoStacks[noteId] = stack;
      }
    } catch (e) {
      debugPrint('[AppUndoManager] Erro ao restaurar histórico de $noteId: $e');
    }
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

  @override
  Map<String, dynamic> toJson() => {
    'type': 'batch',
    'commands': commands.map((c) => c.toJson()).toList(),
  };

  factory BatchCommand.fromJson(Map<String, dynamic> json) {
    final rawCmds = (json['commands'] as List<dynamic>?) ?? [];
    final List<UndoCommand> parsed = [];
    for (final c in rawCmds) {
      if (c is Map<String, dynamic>) {
        final cmd = UndoCommand.fromJson(c);
        if (cmd != null) parsed.add(cmd);
      }
    }
    return BatchCommand(parsed);
  }
}

/// Comando atômico para sincronizar os traços de um card de mídia (ex: após edição no Lightbox)
class SyncCardStrokesCommand implements UndoCommand {
  final String cardId;
  final List<InkStroke> oldStrokes;
  final List<InkStroke> newStrokes;

  SyncCardStrokesCommand({
    required this.cardId,
    required this.oldStrokes,
    required this.newStrokes,
  });

  @override
  void execute(NoteDocument note) {
    final oldIds = oldStrokes.map((s) => s.id).toSet();
    note.removeAllStrokes(oldIds);
    note.addAllStrokes(newStrokes);
    final idx = note.cards.indexWhere((c) => c.id == cardId);
    if (idx != -1) {
      note.cards[idx] = note.cards[idx].copyWith(
        attachedStrokeIds: newStrokes.map((s) => s.id).toList(),
      );
    }
  }

  @override
  void undo(NoteDocument note) {
    final newIds = newStrokes.map((s) => s.id).toSet();
    note.removeAllStrokes(newIds);
    note.addAllStrokes(oldStrokes);
    final idx = note.cards.indexWhere((c) => c.id == cardId);
    if (idx != -1) {
      note.cards[idx] = note.cards[idx].copyWith(
        attachedStrokeIds: oldStrokes.map((s) => s.id).toList(),
      );
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'syncCardStrokes',
    'cardId': cardId,
    'oldStrokes': oldStrokes.map((s) => s.toJson()).toList(),
    'newStrokes': newStrokes.map((s) => s.toJson()).toList(),
  };

  factory SyncCardStrokesCommand.fromJson(Map<String, dynamic> json) {
    final rawOld = (json['oldStrokes'] as List<dynamic>?) ?? [];
    final rawNew = (json['newStrokes'] as List<dynamic>?) ?? [];
    return SyncCardStrokesCommand(
      cardId: json['cardId'] as String? ?? '',
      oldStrokes: rawOld.map((s) => InkStroke.fromJson(s as Map<String, dynamic>)).toList(),
      newStrokes: rawNew.map((s) => InkStroke.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}
