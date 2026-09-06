import 'package:flutter/foundation.dart';
import '../widgets/settings_models.dart';

class CanvasUiController extends ChangeNotifier {
  bool _isAIOpen = false;
  bool _isSettingsOpen = false;
  bool _isSidebarOpen = false;
  bool _isGridMenuOpen = false;
  bool _isCardsSubBarVisible = false;
  bool _isPenSubBarVisible = false;
  String _activeTool = 'pen';
  String? _selectedCardId;
  SettingsCategory _activeSettingsCategory = SettingsCategory.visual;

  bool get isAIOpen => _isAIOpen;
  bool get isSettingsOpen => _isSettingsOpen;
  bool get isSidebarOpen => _isSidebarOpen;
  bool get isGridMenuOpen => _isGridMenuOpen;
  bool get isCardsSubBarVisible => _isCardsSubBarVisible;
  bool get isPenSubBarVisible => _isPenSubBarVisible;
  String get activeTool => _activeTool;
  String? get selectedCardId => _selectedCardId;
  SettingsCategory get activeSettingsCategory => _activeSettingsCategory;

  void toggleAI() {
    _isAIOpen = !_isAIOpen;
    notifyListeners();
  }

  void closeAI() {
    if (_isAIOpen) {
      _isAIOpen = false;
      notifyListeners();
    }
  }

  void openAI() {
    if (!_isAIOpen) {
      _isAIOpen = true;
      notifyListeners();
    }
  }

  void toggleSettings() {
    _isSettingsOpen = !_isSettingsOpen;
    notifyListeners();
  }

  void closeSettings() {
    if (_isSettingsOpen) {
      _isSettingsOpen = false;
      notifyListeners();
    }
  }

  void openSettings() {
    if (!_isSettingsOpen) {
      _isSettingsOpen = true;
      notifyListeners();
    }
  }

  void toggleSidebar() {
    _isSidebarOpen = !_isSidebarOpen;
    notifyListeners();
  }

  void closeSidebar() {
    if (_isSidebarOpen) {
      _isSidebarOpen = false;
      notifyListeners();
    }
  }

  void toggleGridMenu() {
    _isGridMenuOpen = !_isGridMenuOpen;
    notifyListeners();
  }

  void closeGridMenu() {
    if (_isGridMenuOpen) {
      _isGridMenuOpen = false;
      notifyListeners();
    }
  }

  void toggleCardsSubBar() {
    _isCardsSubBarVisible = !_isCardsSubBarVisible;
    notifyListeners();
  }

  void closeCardsSubBar() {
    if (_isCardsSubBarVisible) {
      _isCardsSubBarVisible = false;
      notifyListeners();
    }
  }

  void setCardsSubBarVisible(bool visible) {
    if (_isCardsSubBarVisible != visible) {
      _isCardsSubBarVisible = visible;
      notifyListeners();
    }
  }

  void togglePenSubBar() {
    _isPenSubBarVisible = !_isPenSubBarVisible;
    notifyListeners();
  }

  void setActiveTool(String tool) {
    if (_activeTool != tool) {
      _activeTool = tool;
      notifyListeners();
    }
  }

  void setSelectedCardId(String? id) {
    if (_selectedCardId != id) {
      _selectedCardId = id;
      notifyListeners();
    }
  }

  void setActiveSettingsCategory(SettingsCategory category) {
    if (_activeSettingsCategory != category) {
      _activeSettingsCategory = category;
      notifyListeners();
    }
  }

  void closeAllOverlays() {
    bool changed = false;
    if (_isGridMenuOpen) {
      _isGridMenuOpen = false;
      changed = true;
    }
    if (_isCardsSubBarVisible) {
      _isCardsSubBarVisible = false;
      changed = true;
    }
    if (_isSettingsOpen) {
      _isSettingsOpen = false;
      changed = true;
    }
    if (_isPenSubBarVisible) {
      _isPenSubBarVisible = false;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }
}
