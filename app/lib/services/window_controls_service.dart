import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Serviço singleton para controle nativo da janela Windows (Minimizar, Maximizar, Fechar, Drag).
class WindowControlsService {
  WindowControlsService._();
  static final WindowControlsService instance = WindowControlsService._();

  static const MethodChannel _channel = MethodChannel('connotes/window_controls');

  final ValueNotifier<bool> isMaximizedNotifier = ValueNotifier<bool>(false);

  Future<void> minimize() async {
    try {
      await _channel.invokeMethod<bool>('minimize');
    } catch (e) {
      debugPrint('[WindowControls] Erro ao minimizar: $e');
    }
  }

  Future<void> maximizeOrRestore() async {
    try {
      final res = await _channel.invokeMethod<bool>('maximize_or_restore');
      if (res != null) {
        isMaximizedNotifier.value = res;
      }
    } catch (e) {
      debugPrint('[WindowControls] Erro ao alternar maximizar: $e');
    }
  }

  Future<void> close() async {
    try {
      await _channel.invokeMethod<bool>('close');
    } catch (e) {
      debugPrint('[WindowControls] Erro ao fechar janela: $e');
    }
  }

  Future<void> startDrag() async {
    try {
      await _channel.invokeMethod<bool>('start_drag');
    } catch (e) {
      debugPrint('[WindowControls] Erro ao iniciar drag de janela: $e');
    }
  }

  Future<void> checkIsMaximized() async {
    try {
      final res = await _channel.invokeMethod<bool>('is_maximized');
      if (res != null) {
        isMaximizedNotifier.value = res;
      }
    } catch (_) {}
  }
}
