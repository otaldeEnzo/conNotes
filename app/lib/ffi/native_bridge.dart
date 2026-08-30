import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

// Definições de tipos C-ABI
typedef ConnotesCreateDocumentNative = ffi.Pointer<Utf8> Function();
typedef ConnotesCreateDocumentDart = ffi.Pointer<Utf8> Function();

typedef ConnotesDestroyDocumentNative = ffi.Void Function(ffi.Pointer<Utf8> docId);
typedef ConnotesDestroyDocumentDart = void Function(ffi.Pointer<Utf8> docId);

final class NativeStrokePoint extends ffi.Struct {
  @ffi.Float()
  external double x;

  @ffi.Float()
  external double y;

  @ffi.Float()
  external double pressure;

  @ffi.Uint64()
  external int timestamp;
}

typedef ConnotesAddStrokeNative = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> docId,
  ffi.Pointer<NativeStrokePoint> points,
  ffi.Size count,
  ffi.Float r,
  ffi.Float g,
  ffi.Float b,
  ffi.Float a,
  ffi.Float strokeWidth,
);
typedef ConnotesAddStrokeDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> docId,
  ffi.Pointer<NativeStrokePoint> points,
  int count,
  double r,
  double g,
  double b,
  double a,
  double strokeWidth,
);

typedef ConnotesDuplicateStrokesNative = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> docId,
  ffi.Pointer<Utf8> idsJson,
  ffi.Float dx,
  ffi.Float dy,
);
typedef ConnotesDuplicateStrokesDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8> docId,
  ffi.Pointer<Utf8> idsJson,
  double dx,
  double dy,
);

typedef ConnotesUndoNative = ffi.Bool Function(ffi.Pointer<Utf8> docId);
typedef ConnotesUndoDart = bool Function(ffi.Pointer<Utf8> docId);

typedef ConnotesRedoNative = ffi.Bool Function(ffi.Pointer<Utf8> docId);
typedef ConnotesRedoDart = bool Function(ffi.Pointer<Utf8> docId);

typedef ConnotesFreeStringNative = ffi.Void Function(ffi.Pointer<Utf8> ptr);
typedef ConnotesFreeStringDart = void Function(ffi.Pointer<Utf8> ptr);

typedef ConnotesInitTextureNative = ffi.Int64 Function(ffi.Pointer<Utf8> docId);
typedef ConnotesInitTextureDart = int Function(ffi.Pointer<Utf8> docId);

typedef ConnotesSendDrawEventNative = ffi.Void Function(ffi.Pointer<Utf8> docId, ffi.Pointer<Utf8> eventJson);
typedef ConnotesSendDrawEventDart = void Function(ffi.Pointer<Utf8> docId, ffi.Pointer<Utf8> eventJson);

typedef ConnotesRenderTickNative = ffi.Void Function(ffi.Pointer<Utf8> docId);
typedef ConnotesRenderTickDart = void Function(ffi.Pointer<Utf8> docId);

final class StylusNativeStateFfi extends ffi.Struct {
  @ffi.Bool()
  external bool is_contact;
  
  @ffi.Bool()
  external bool is_barrel_primary_pressed;
  
  @ffi.Bool()
  external bool is_barrel_secondary_pressed;
  
  @ffi.Bool()
  external bool is_inverted_eraser;
  
  @ffi.Float()
  external double pressure;
  
  @ffi.Int32()
  external int tilt_x;
  
  @ffi.Int32()
  external int tilt_y;
  
  @ffi.Uint32()
  external int button_count;
}

typedef ConnotesGetStylusStateNative = ffi.Pointer<StylusNativeStateFfi> Function();
typedef ConnotesGetStylusStateDart = ffi.Pointer<StylusNativeStateFfi> Function();

typedef ConnotesQueryStylusCapsNative = ffi.Uint32 Function();
typedef ConnotesQueryStylusCapsDart = int Function();

/// Ponte FFI de alta performance para comunicação direta com o motor nativo `connotes_core`.
class ConnotesNativeBridge {
  static ConnotesNativeBridge? _instance;
  static ConnotesNativeBridge get instance => _instance ??= ConnotesNativeBridge._();

  late final ffi.DynamicLibrary _dylib;
  late final ffi.DynamicLibrary _processLib;
  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  late final ConnotesCreateDocumentDart _createDocument;
  late final ConnotesDestroyDocumentDart _destroyDocument;
  late final ConnotesAddStrokeDart _addStroke;
  late final ConnotesDuplicateStrokesDart _duplicateStrokes;
  late final ConnotesUndoDart _undo;
  late final ConnotesRedoDart _redo;
  late final ConnotesFreeStringDart _freeString;
  late final ConnotesInitTextureDart _initTexture;
  late final ConnotesSendDrawEventDart _sendDrawEvent;
  late final ConnotesRenderTickDart _renderTick;

  ConnotesGetStylusStateDart? _getStylusState;
  ConnotesQueryStylusCapsDart? _queryStylusCaps;

  ConnotesNativeBridge._() {
    _init();
  }

  void _init() {
    try {
      if (Platform.isWindows) {
        _dylib = ffi.DynamicLibrary.open('connotes_core.dll');
        _processLib = ffi.DynamicLibrary.process();
      } else if (Platform.isAndroid) {
        _dylib = ffi.DynamicLibrary.open('libconnotes_core.so');
        _processLib = ffi.DynamicLibrary.process();
      } else if (Platform.isMacOS) {
        _dylib = ffi.DynamicLibrary.open('libconnotes_core.dylib');
        _processLib = ffi.DynamicLibrary.process();
      } else {
        _dylib = ffi.DynamicLibrary.process();
        _processLib = _dylib;
      }

      _createDocument = _dylib
          .lookup<ffi.NativeFunction<ConnotesCreateDocumentNative>>('connotes_create_document')
          .asFunction();

      _destroyDocument = _dylib
          .lookup<ffi.NativeFunction<ConnotesDestroyDocumentNative>>('connotes_destroy_document')
          .asFunction();

      _addStroke = _dylib
          .lookup<ffi.NativeFunction<ConnotesAddStrokeNative>>('connotes_add_stroke')
          .asFunction();

      _duplicateStrokes = _dylib
          .lookup<ffi.NativeFunction<ConnotesDuplicateStrokesNative>>('connotes_duplicate_strokes')
          .asFunction();

      _undo = _dylib
          .lookup<ffi.NativeFunction<ConnotesUndoNative>>('connotes_undo')
          .asFunction();

      _redo = _dylib
          .lookup<ffi.NativeFunction<ConnotesRedoNative>>('connotes_redo')
          .asFunction();

      _freeString = _dylib
          .lookup<ffi.NativeFunction<ConnotesFreeStringNative>>('connotes_free_string')
          .asFunction();

      _initTexture = _dylib
          .lookup<ffi.NativeFunction<ConnotesInitTextureNative>>('connotes_init_texture')
          .asFunction();

      _sendDrawEvent = _dylib
          .lookup<ffi.NativeFunction<ConnotesSendDrawEventNative>>('connotes_send_draw_event')
          .asFunction();

      _renderTick = _dylib
          .lookup<ffi.NativeFunction<ConnotesRenderTickNative>>('connotes_render_tick')
          .asFunction();

      try {
        if (Platform.isWindows) {
          _getStylusState = _processLib
              .lookup<ffi.NativeFunction<ConnotesGetStylusStateNative>>('getStylusRealtimeState')
              .asFunction();
          _queryStylusCaps = _processLib
              .lookup<ffi.NativeFunction<ConnotesQueryStylusCapsNative>>('connotes_query_stylus_caps')
              .asFunction();
        }
      } catch (e) {
        // Ignora caso não esteja rodando nativo no Windows ou se símbolos não exportados.
      }

      _isAvailable = true;
    } catch (e) {
      _isAvailable = false;
    }
  }

  String? createDocument() {
    if (!_isAvailable) return null;
    final ptr = _createDocument();
    if (ptr == ffi.nullptr) return null;
    final str = ptr.toDartString();
    _freeString(ptr);
    return str;
  }

  String? addStroke(String docId, List<dynamic> points, {required double r, required double g, required double b, required double a, required double strokeWidth}) {
    if (!_isAvailable || points.isEmpty) return null;
    final docIdPtr = docId.toNativeUtf8();
    final pointsPtr = calloc<NativeStrokePoint>(points.length);
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      pointsPtr[i].x = p.point.dx;
      pointsPtr[i].y = p.point.dy;
      pointsPtr[i].pressure = p.pressure;
      pointsPtr[i].timestamp = 0;
    }

    final resultPtr = _addStroke(docIdPtr, pointsPtr, points.length, r, g, b, a, strokeWidth);
    calloc.free(docIdPtr);
    calloc.free(pointsPtr);

    if (resultPtr == ffi.nullptr) return null;
    final strokeId = resultPtr.toDartString();
    _freeString(resultPtr);
    return strokeId;
  }

  void destroyDocument(String docId) {
    if (!_isAvailable) return;
    final docIdPtr = docId.toNativeUtf8();
    _destroyDocument(docIdPtr);
    calloc.free(docIdPtr);
  }

  List<String> duplicateStrokes(String docId, List<String> ids, double dx, double dy) {
    if (!_isAvailable) return [];
    final docIdPtr = docId.toNativeUtf8();
    final idsJsonPtr = jsonEncode(ids).toNativeUtf8();

    final resultPtr = _duplicateStrokes(docIdPtr, idsJsonPtr, dx, dy);

    calloc.free(docIdPtr);
    calloc.free(idsJsonPtr);

    if (resultPtr == ffi.nullptr) return [];
    final jsonStr = resultPtr.toDartString();
    _freeString(resultPtr);

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  bool undo(String docId) {
    if (!_isAvailable) return false;
    final docIdPtr = docId.toNativeUtf8();
    final res = _undo(docIdPtr);
    calloc.free(docIdPtr);
    return res;
  }

  bool redo(String docId) {
    if (!_isAvailable) return false;
    final docIdPtr = docId.toNativeUtf8();
    final res = _redo(docIdPtr);
    calloc.free(docIdPtr);
    return res;
  }

  int? initTexture(String docId) {
    if (!_isAvailable) return null;
    final docIdPtr = docId.toNativeUtf8();
    final res = _initTexture(docIdPtr);
    calloc.free(docIdPtr);
    return res;
  }

  void sendDrawEvent(String docId, String eventJson) {
    if (!_isAvailable) return;
    final docIdPtr = docId.toNativeUtf8();
    final eventJsonPtr = eventJson.toNativeUtf8();
    _sendDrawEvent(docIdPtr, eventJsonPtr);
    calloc.free(docIdPtr);
    calloc.free(eventJsonPtr);
  }

  void renderTick(String docId) {
    if (!_isAvailable) return;
    final docIdPtr = docId.toNativeUtf8();
    _renderTick(docIdPtr);
    calloc.free(docIdPtr);
  }

  /// Recupera o estado em tempo real da caneta via Win32.
  StylusNativeStateFfi? getStylusRealtimeState() {
    if (_getStylusState != null) {
      final ptr = _getStylusState!();
      if (ptr != ffi.nullptr) {
        return ptr.ref;
      }
    }
    return null;
  }

  /// Retorna as capacidades (ex: contagem de botões laterais detectados via HID).
  int getConnectedStylusCapabilities() {
    if (_queryStylusCaps != null) {
      return _queryStylusCaps!();
    }
    return 2; // Padrão
  }
}
