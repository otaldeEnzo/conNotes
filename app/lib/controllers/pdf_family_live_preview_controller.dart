import 'package:flutter/material.dart';

class PdfCardLiveTransform {
  final double scale;
  final Offset translation;
  final double finalWidth;
  final double finalHeight;
  final double finalX;
  final double finalY;

  const PdfCardLiveTransform({
    this.scale = 1.0,
    this.translation = Offset.zero,
    required this.finalWidth,
    required this.finalHeight,
    required this.finalX,
    required this.finalY,
  });
}

class PdfFamilyLivePreviewState {
  final String? activeFamilyId;
  final Map<String, PdfCardLiveTransform>? cardTransforms;

  const PdfFamilyLivePreviewState({
    this.activeFamilyId,
    this.cardTransforms,
  });

  bool get isActive => activeFamilyId != null && cardTransforms != null;
}

class PdfFamilyLivePreviewController extends ValueNotifier<PdfFamilyLivePreviewState> {
  static final PdfFamilyLivePreviewController instance = PdfFamilyLivePreviewController._();

  PdfFamilyLivePreviewController._() : super(const PdfFamilyLivePreviewState());

  void beginInteraction(String familyId) {
    value = PdfFamilyLivePreviewState(
      activeFamilyId: familyId,
      cardTransforms: const {},
    );
  }

  void updateInteraction(Map<String, PdfCardLiveTransform> cardTransforms) {
    if (value.activeFamilyId != null) {
      value = PdfFamilyLivePreviewState(
        activeFamilyId: value.activeFamilyId,
        cardTransforms: cardTransforms,
      );
    }
  }

  void endInteraction() {
    value = const PdfFamilyLivePreviewState();
  }
}
