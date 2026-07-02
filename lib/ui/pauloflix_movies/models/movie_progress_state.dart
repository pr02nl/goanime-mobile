import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/widgets/completed_badge.dart';
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

  /// Posição em segundos (para exibir tempo decorrido).
  final int? positionSeconds;

  /// Duração total em segundos (para exibir tempo restante).
  final int? durationSeconds;

  /// Se está em andamento (pos > 0 e não completo).
  bool get isInProgress => !isCompleted && ratio > 0;

  /// Se nunca foi assistido.
  bool get isNew => ratio == 0;

  /// Label formatado "12:30 / 24:00" para exibição no card.
  String? get timeLabel =>
      positionSeconds != null && durationSeconds != null && durationSeconds! > 0
          ? ProgressOverlay.buildTimeLabel(
              positionSeconds: positionSeconds,
              durationSeconds: durationSeconds,
            )
          : null;

  const MovieProgressState({
    required this.ratio,
    this.isCompleted = false,
    this.positionSeconds,
    this.durationSeconds,
  });

  /// Constrói o widget de overlay de progresso para cards.
  ///
  /// Retorna um badge verde ✓ se completo (via `CompletedBadge.cardOverlay()`),
  /// uma barra vermelha se em andamento (via `ProgressOverlay.build()`), ou
  /// `null` se nunca assistido.
  ///
  /// Quando em andamento, mostra também o label de tempo decorrido/total
  /// (ex: "12:30 / 24:00").
  static Widget? buildOverlayWidget(MovieProgressState? progress) {
    if (progress == null) return null;
    if (progress.isCompleted) {
      return CompletedBadge.cardOverlay();
    }
    if (progress.ratio > 0) {
      return ProgressOverlay.build(
        ratio: progress.ratio,
        isCompleted: false,
        accentColor: AppColors.moviesAccent,
        timeLabel: progress.timeLabel,
      );
    }
    return null;
  }
}
