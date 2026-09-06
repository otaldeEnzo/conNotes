import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Resultado da compressao e ingestao de uma midia.
class CompressedMediaResult {
  final String dataUri;
  final int originalWidth;
  final int originalHeight;
  final int compressedWidth;
  final int compressedHeight;
  final int byteSize;

  double get aspectRatio => originalWidth > 0 && originalHeight > 0
      ? originalWidth / originalHeight
      : 1.0;

  const CompressedMediaResult({
    required this.dataUri,
    required this.originalWidth,
    required this.originalHeight,
    required this.compressedWidth,
    required this.compressedHeight,
    required this.byteSize,
  });
}

/// Servico modular para compressao assincrona de midias em Dart Isolate.
/// Garante que decodificacao, downscale e encoding nao bloqueiem a thread principal da UI.
class MediaCompressionService {
  MediaCompressionService._();

  static const int defaultMaxDimension = 1920;
  static const int defaultQuality = 82;

  /// Processa bytes brutos da imagem em uma Isolate de segundo plano.
  /// Redimensiona bilinearmente se ultrapassar [maxDimension] e codifica
  /// no formato mais eficiente (WebP/PNG com transparencia ou JPEG otimizado).
  static Future<CompressedMediaResult?> compressImageBytes(
    Uint8List rawBytes, {
    int maxDimension = defaultMaxDimension,
    int quality = defaultQuality,
  }) async {
    if (rawBytes.isEmpty) return null;

    try {
      return await compute(_isolateProcessImage, {
        'bytes': rawBytes,
        'maxDimension': maxDimension,
        'quality': quality,
      });
    } catch (e) {
      debugPrint('[MediaCompressionService] Falha na compressao em Isolate: $e');
      return null;
    }
  }

  /// Metodo estatico executado dentro do Isolate.
  static CompressedMediaResult? _isolateProcessImage(Map<String, dynamic> params) {
    final rawBytes = params['bytes'] as Uint8List;
    final maxDimension = params['maxDimension'] as int;
    final quality = params['quality'] as int;

    // 1. Deteccao rapida de GIF animado (magic bytes 'GIF87a' ou 'GIF89a')
    final isGif = rawBytes.length > 3 &&
        rawBytes[0] == 0x47 &&
        rawBytes[1] == 0x49 &&
        rawBytes[2] == 0x46;

    if (isGif) {
      final decoded = img.decodeGif(rawBytes);
      if (decoded != null) {
        final b64 = base64Encode(rawBytes);
        return CompressedMediaResult(
          dataUri: 'data:image/gif;base64,$b64',
          originalWidth: decoded.width,
          originalHeight: decoded.height,
          compressedWidth: decoded.width,
          compressedHeight: decoded.height,
          byteSize: rawBytes.length,
        );
      }
    }

    // 2. Decodifica imagem padrao (PNG, JPG, WebP, etc.)
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return null;

    final origW = decoded.width;
    final origH = decoded.height;

    img.Image processed = decoded;
    if (origW > maxDimension || origH > maxDimension) {
      if (origW >= origH) {
        final targetW = maxDimension;
        final targetH = ((origH * maxDimension) / origW).round();
        processed = img.copyResize(
          decoded,
          width: targetW,
          height: targetH,
          interpolation: img.Interpolation.linear,
        );
      } else {
        final targetH = maxDimension;
        final targetW = ((origW * maxDimension) / origH).round();
        processed = img.copyResize(
          decoded,
          width: targetW,
          height: targetH,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // 3. Seleciona o formato mais compacto:
    // Se tiver canal alfa (transparencia), compara WebP lossless e PNG.
    // Se for opaca (fotos, prints comuns), utiliza JPEG com qualidade calibrada.
    Uint8List encodedBytes;
    String mimeType;

    if (processed.hasAlpha) {
      final webpBytes = img.WebPEncoder().encode(processed);
      final pngBytes = img.encodePng(processed, level: 6);
      if (webpBytes.length < pngBytes.length) {
        encodedBytes = webpBytes;
        mimeType = 'image/webp';
      } else {
        encodedBytes = pngBytes;
        mimeType = 'image/png';
      }
    } else {
      encodedBytes = img.encodeJpg(processed, quality: quality);
      mimeType = 'image/jpeg';
    }

    final b64 = base64Encode(encodedBytes);
    return CompressedMediaResult(
      dataUri: 'data:$mimeType;base64,$b64',
      originalWidth: origW,
      originalHeight: origH,
      compressedWidth: processed.width,
      compressedHeight: processed.height,
      byteSize: encodedBytes.length,
    );
  }
}
