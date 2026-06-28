import 'package:flutter/material.dart';

import '../themes/app_colors.dart';
import 'completed_badge.dart';

/// Widget de overlay de progresso para cards na grid e carrosséis.
///
/// Unifica a exibição de progresso entre filmes (red theme) e animes
/// (purple theme), eliminando a duplicação de código que existia em
/// 4 lugares diferentes.
///
/// Uso:
/// ```dart
/// NetflixCard(
///   overlayWidget: ProgressOverlay.build(
///     ratio: 0.5,
///     isCompleted: true,
///     accentColor: Color(0xFFDC2626), // vermelho filmes
///   ),
/// )
/// ```
class ProgressOverlay {
  ProgressOverlay._();

  /// Constrói o widget de overlay de progresso.
  ///
  /// [ratio] — fração de progresso (0.0 a 1.0). Usado apenas para
  ///   a barra de progresso quando não completo.
  /// [isCompleted] — se o conteúdo foi totalmente assistido. Quando
  ///   `true`, exibe badge verde ✓ "Completo".
  /// [accentColor] — cor da barra de progresso (ex: vermelho para
  ///   filmes, roxo para animes).
  /// [fractionText] — texto opcional como "3/12" exibido abaixo da
  ///   barra. Usado para animes (total de episódios), ignorado para
  ///   filmes (só 1 parte).
  ///
  /// Retorna `null` quando não há progresso (nenhum overlay exibido).
  static Widget? build({
    required double ratio,
    required bool isCompleted,
    Color accentColor = AppColors.moviesAccent,
    String? fractionText,
  }) {
    if (isCompleted) {
      return CompletedBadge.cardOverlay();
    }

    if (ratio > 0) {
      // Em andamento: barra de progresso + texto opcional.
      final children = <Widget>[
        SizedBox(
          width: 70,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ),
      ];
      if (fractionText != null && fractionText.isNotEmpty) {
        children.addAll([
          const SizedBox(height: 2),
          Text(
            fractionText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]);
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }

    return null;
  }
}
