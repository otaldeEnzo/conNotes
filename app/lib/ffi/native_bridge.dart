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

/// Ponte FFI de alta performance para comunicação direta com o motor nativo `connotes_core`.
class ConnotesNativeBridge {
  static ConnotesNativeBridge? _instance;
  static ConnotesNativeBridge get instance => _instance ??= ConnotesNativeBridge._();

  late final ffi.DynamicLibrary _dylib;
  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  late final ConnotesCreateDocumentDart _createDocument;
  late final ConnotesDestroyDocumentDart _destroyDocument;
  late final ConnotesAddStrokeDart _addStroke;
  late final ConnotesDuplicateStrokesDart _duplicateStrokes;
  late final ConnotesUndoDart _undo;
  late final ConnotesRedoDart _redo;
  late final ConnotesFreeStringDart _freeString;

  ConnotesNativeBridge._() {
    _init();
  }

  void _init() {
    try {
      if (Platform.isWindows) {
        _dylib = ffi.DynamicLibrary.open('connotes_core.dll');
      } else if (Platform.isAndroid) {
        _dylib = ffi.DynamicLibrary.open('libconnotes_core.so');
      } else if (Platform.isMacOS) {
        _dylib = ffi.DynamicLibrary.open('libconnotes_core.dylib');
      } else {
        _dylib = ffi.DynamicLibrary.process();
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
}
