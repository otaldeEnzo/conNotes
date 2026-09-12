import 'package:flutter/material.dart';
import '../widgets/settings_models.dart';
import '../widgets/ink_models.dart';
import '../theme/moscaro_v2_tokens.dart';
import '../services/settings_service.dart';

/// Controller dedicado para gerenciar os Slots de Caneta do Usuário.
/// Carrega e persiste automaticamente qualquer adição, edição, reordenação ou remoção.
class PenSlotsController extends ChangeNotifier {
  PenSlotsController._();
  static final PenSlotsController instance = PenSlotsController._();

  List<PenSlotPreset> _slots = List.of(AppSettingsState.defaultPenSlots);
  String _activeSlotId = AppSettingsState.defaultPenSlots.first.id;

  List<PenSlotPreset> get slots => List.unmodifiable(_slots);
  String get activeSlotId => _activeSlotId;

  PenSlotPreset get activePreset {
    return _slots.firstWhere(
      (s) => s.id == _activeSlotId,
      orElse: () => _slots.isNotEmpty ? _slots.first : AppSettingsState.defaultPenSlots.first,
    );
  }

  void initialize(AppSettingsState settings) {
    final effective = settings.effectivePenSlots;
    if (effective.isNotEmpty) {
      _slots = List.of(effective);
      if (!_slots.any((s) => s.id == _activeSlotId)) {
        _activeSlotId = _slots.first.id;
      }
    }
    notifyListeners();
  }

  void selectSlot(String slotId) {
    if (_activeSlotId != slotId && _slots.any((s) => s.id == slotId)) {
      _activeSlotId = slotId;
      notifyListeners();
    }
  }

  Future<void> addNewSlot() async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newSlot = PenSlotPreset(
      id: newId,
      name: 'Slot ${_slots.length + 1}',
      color: MoscaroTokens.stemPalette[_slots.length % MoscaroTokens.stemPalette.length],
      strokeWidth: 3.0,
      toolType: InkToolType.technical,
      enablePressure: false,
    );
    _slots.add(newSlot);
    _activeSlotId = newId;
    notifyListeners();
    await _persist();
  }

  Future<void> updateSlot(PenSlotPreset updated) async {
    final idx = _slots.indexWhere((s) => s.id == updated.id);
    if (idx != -1) {
      _slots[idx] = updated;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> reorderSlots(int oldIndex, int newIndex) async {
    final item = _slots.removeAt(oldIndex);
    _slots.insert(newIndex, item);
    notifyListeners();
    await _persist();
  }

  Future<void> deleteSlot(String slotId) async {
    _slots.removeWhere((s) => s.id == slotId);
    if (_activeSlotId == slotId && _slots.isNotEmpty) {
      _activeSlotId = _slots.first.id;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> updateActiveSlotColor(Color newColor) async {
    final idx = _slots.indexWhere((s) => s.id == _activeSlotId);
    if (idx != -1) {
      _slots[idx] = _slots[idx].copyWith(color: newColor);
      notifyListeners();
      await _persist();
    }
  }

  Future<void> _persist() async {
    final current = SettingsService.instance.currentSettings;
    final updated = current.copyWith(penSlots: _slots);
    await SettingsService.instance.saveSettings(updated);
  }
}
