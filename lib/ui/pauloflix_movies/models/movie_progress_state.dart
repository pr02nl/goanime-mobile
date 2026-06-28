import 'package:flutter/material.dart';

/// Estado de progresso de um filme para exibição visual na grid.
///
/// Usado pela home de filmes para passar informações de progresso
/// do banco para os widgets de card sem expor o model de domínio
/// completo.
class MovieProgressState {
  /// Fração de progresso (0.0 a 1.0).
  final double ratio;

  /// Se o filme foi completamente assistido (≥ 90%).
  final bool isCompleted;

  /// Se está em andamento (pos > 0 e não completo).
  bool get isInProgress => !isCompleted && ratio > 0;

  /// Se nunca foi assistido.
  bool get isNew => ratio == 0;

  const MovieProgressState({
    required this.ratio,
    this.isCompleted = false,
  });

  /// Constrói o widget de overlay de progresso para cards.
  ///
  /// Retorna um badge verde ✓ se completo, uma barra vermelha se
  /// em andamento, ou `null` se nunca assistido.
  static Widget? buildOverlayWidget(MovieProgressState? progress) {
    if (progress == null) return null;
    if (progress.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 10),
            SizedBox(width: 2),
            Text(
              'Completo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    if (progress.isInProgress) {
      return SizedBox(
        width: 70,
        height: 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress.ratio,
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
          ),
        ),
      );
    }
    return null;
  }
}
