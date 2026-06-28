import 'package:flutter/material.dart';

import '../../core/widgets/progress_overlay.dart';

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
    return ProgressOverlay.build(
      ratio: progress.ratio,
      isCompleted: progress.isCompleted,
      accentColor: const Color(0xFFDC2626),
    );
  }
}
