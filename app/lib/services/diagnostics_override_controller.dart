import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Modos de visualização da Suíte de Diagnósticos e Telemetria
enum PerformanceHudDisplayMode {
  off,
  miniHud,
  fullDashboard,
}

/// Controlador reativo de interruptores de diagnóstico e isolamento de gargalos (Killswitches).
class DiagnosticsOverrideController extends ChangeNotifier {
  static final DiagnosticsOverrideController instance = DiagnosticsOverrideController._internal();

  DiagnosticsOverrideController._internal();

  PerformanceHudDisplayMode _hudMode = PerformanceHudDisplayMode.miniHud;
  PerformanceHudDisplayMode get hudMode => _hudMode;

  bool _bypassBackdropFilter = false;
  bool get bypassBackdropFilter => _bypassBackdropFilter;

  bool _pauseIdleAnimations = false;
  bool get pauseIdleAnimations => _pauseIdleAnimations;

  bool _debugRepaintRainbow = false;
  bool get debugRepaintRainbow => _debugRepaintRainbow;

  bool _showNativeOverlay = false;
  bool get showNativeOverlay => _showNativeOverlay;

  void cycleHudMode() {
    switch (_hudMode) {
      case PerformanceHudDisplayMode.off:
        _hudMode = PerformanceHudDisplayMode.miniHud;
        break;
      case PerformanceHudDisplayMode.miniHud:
        _hudMode = PerformanceHudDisplayMode.fullDashboard;
        break;
      case PerformanceHudDisplayMode.fullDashboard:
        _hudMode = PerformanceHudDisplayMode.off;
        break;
    }
    notifyListeners();
  }

  void setHudMode(PerformanceHudDisplayMode mode) {
    if (_hudMode == mode) return;
    _hudMode = mode;
    notifyListeners();
  }

  void toggleBypassBackdropFilter() {
    _bypassBackdropFilter = !_bypassBackdropFilter;
    notifyListeners();
  }

  void togglePauseIdleAnimations() {
    _pauseIdleAnimations = !_pauseIdleAnimations;
    notifyListeners();
  }

  void toggleRepaintRainbow() {
    _debugRepaintRainbow = !_debugRepaintRainbow;
    debugRepaintRainbowEnabled = _debugRepaintRainbow;
    notifyListeners();
  }

  void toggleNativeOverlay() {
    _showNativeOverlay = !_showNativeOverlay;
    notifyListeners();
  }
}
