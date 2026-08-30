import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Estado dos botoes laterais da caneta lido diretamente do Win32 WM_POINTER API.
class StylusNativeStateData {
  final bool isPrimaryBarrelPressed;
  final bool isSecondaryBarrelPressed;
  final bool isInvertedEraser;

  const StylusNativeStateData({
    required this.isPrimaryBarrelPressed,
    required this.isSecondaryBarrelPressed,
    required this.isInvertedEraser,
  });

  static const StylusNativeStateData released = StylusNativeStateData(
    isPrimaryBarrelPressed: false,
    isSecondaryBarrelPressed: false,
    isInvertedEraser: false,
  );
}

/// Singleton que recebe eventos de hardware de caneta diretamente do runner C++ Win32
/// atraves do canal connotes/stylus_state usando BasicMessageChannel com codec binario.
class StylusNativeChannel {
  StylusNativeChannel._();
  static final StylusNativeChannel instance = StylusNativeChannel._();

  StylusNativeStateData _state = StylusNativeStateData.released;
  StylusNativeStateData get state => _state;

  final _channel = const BasicMessageChannel<ByteData?>(
    'connotes/stylus_state',
    BinaryCodec(),
  );

  final List<void Function(StylusNativeStateData)> _listeners = [];

  void initialize() {
    _channel.setMessageHandler((ByteData? message) async {
      if (message == null) return null;
      _state = _parse(message);
      for (final fn in List.from(_listeners)) {
        fn(_state);
      }
      return null;
    });
  }

  void addListener(void Function(StylusNativeStateData) fn) {
    _listeners.add(fn);
  }

  void removeListener(void Function(StylusNativeStateData) fn) {
    _listeners.remove(fn);
  }

  void updateStateForTesting(StylusNativeStateData state) {
    _state = state;
    for (final fn in List.from(_listeners)) {
      fn(_state);
    }
  }

  StylusNativeStateData _parse(ByteData data) {
    bool b1 = false;
    bool b2 = false;
    bool eraser = false;

    try {
      int offset = 0;
      final type = data.getUint8(offset++);
      if (type != 13) return StylusNativeStateData.released;

      int count = (data.getUint8(offset++) << 24) |
                  (data.getUint8(offset++) << 16) |
                  (data.getUint8(offset++) << 8) |
                  data.getUint8(offset++);

      for (int i = 0; i < count; i++) {
        final keyType = data.getUint8(offset++);
        if (keyType != 7) break;
        final keyLen = data.getUint8(offset++);
        final keyChars = List<int>.generate(keyLen, (_) => data.getUint8(offset++));
        final key = String.fromCharCodes(keyChars);
        final valType = data.getUint8(offset++);
        final val = valType == 1;
        if (key == 'b1') b1 = val;
        else if (key == 'b2') b2 = val;
        else if (key == 'eraser') eraser = val;
      }
    } catch (_) {}

    return StylusNativeStateData(
      isPrimaryBarrelPressed: b1,
      isSecondaryBarrelPressed: b2,
      isInvertedEraser: eraser,
    );
  }
}
