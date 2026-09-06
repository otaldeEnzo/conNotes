import '../models/canvas_card_model.dart';

/// Resultado do cálculo de alinhamento magnético (Snapping).
class CardSnapResult {
  final double x;
  final double y;
  final bool snappedX;
  final bool snappedY;

  const CardSnapResult({
    required this.x,
    required this.y,
    this.snappedX = false,
    this.snappedY = false,
  });
}

/// Utilitário estático de snapping magnético para posicionamento de cards no Canvas.
/// Alinha bordas e centro a outros cards e ao grid de pontos.
class CardMagneticSnapper {
  /// Tolerância em pixels do canvas para acionar o magnetismo
  static const double snapThreshold = 10.0;

  /// Calcula a posição ajustada com magnetismo
  static CardSnapResult snap({
    required double targetX,
    required double targetY,
    required double width,
    required double height,
    required String currentCardId,
    required List<CanvasCardModel> otherCards,
    double gridSpacing = 28.0,
    bool snapToGrid = true,
    bool snapToCards = true,
  }) {
    double bestX = targetX;
    double bestY = targetY;
    double minDiffX = snapThreshold;
    double minDiffY = snapThreshold;
    bool didSnapX = false;
    bool didSnapY = false;

    final targetRight = targetX + width;
    final targetCenterX = targetX + width / 2.0;
    final targetBottom = targetY + height;
    final targetCenterY = targetY + height / 2.0;

    // 1. Snapping a outros Cards vizinhos
    if (snapToCards) {
      for (final card in otherCards) {
        if (card.id == currentCardId) continue;

        final otherRight = card.x + card.width;
        final otherCenterX = card.x + card.width / 2.0;
        final otherBottom = card.y + card.height;
        final otherCenterY = card.y + card.height / 2.0;

        // --- EIXO X ---
        // Alinhar Esquerda com Esquerda
        final diffLeftLeft = (targetX - card.x).abs();
        if (diffLeftLeft < minDiffX) {
          minDiffX = diffLeftLeft;
          bestX = card.x;
          didSnapX = true;
        }

        // Alinhar Esquerda com Direita
        final diffLeftRight = (targetX - otherRight).abs();
        if (diffLeftRight < minDiffX) {
          minDiffX = diffLeftRight;
          bestX = otherRight;
          didSnapX = true;
        }

        // Alinhar Direita com Esquerda
        final diffRightLeft = (targetRight - card.x).abs();
        if (diffRightLeft < minDiffX) {
          minDiffX = diffRightLeft;
          bestX = card.x - width;
          didSnapX = true;
        }

        // Alinhar Direita com Direita
        final diffRightRight = (targetRight - otherRight).abs();
        if (diffRightRight < minDiffX) {
          minDiffX = diffRightRight;
          bestX = otherRight - width;
          didSnapX = true;
        }

        // Alinhar Centros X
        final diffCenterX = (targetCenterX - otherCenterX).abs();
        if (diffCenterX < minDiffX) {
          minDiffX = diffCenterX;
          bestX = otherCenterX - width / 2.0;
          didSnapX = true;
        }

        // --- EIXO Y ---
        // Alinhar Topo com Topo
        final diffTopTop = (targetY - card.y).abs();
        if (diffTopTop < minDiffY) {
          minDiffY = diffTopTop;
          bestY = card.y;
          didSnapY = true;
        }

        // Alinhar Topo com Base
        final diffTopBottom = (targetY - otherBottom).abs();
        if (diffTopBottom < minDiffY) {
          minDiffY = diffTopBottom;
          bestY = otherBottom;
          didSnapY = true;
        }

        // Alinhar Base com Topo
        final diffBottomTop = (targetBottom - card.y).abs();
        if (diffBottomTop < minDiffY) {
          minDiffY = diffBottomTop;
          bestY = card.y - height;
          didSnapY = true;
        }

        // Alinhar Base com Base
        final diffBottomBottom = (targetBottom - otherBottom).abs();
        if (diffBottomBottom < minDiffY) {
          minDiffY = diffBottomBottom;
          bestY = otherBottom - height;
          didSnapY = true;
        }

        // Alinhar Centros Y
        final diffCenterY = (targetCenterY - otherCenterY).abs();
        if (diffCenterY < minDiffY) {
          minDiffY = diffCenterY;
          bestY = otherCenterY - height / 2.0;
          didSnapY = true;
        }
      }
    }

    // Snapping only activates when near other cards.
    // When moving in empty canvas space, original coordinates are preserved.

    return CardSnapResult(
      x: bestX,
      y: bestY,
      snappedX: didSnapX,
      snappedY: didSnapY,
    );
  }
}
