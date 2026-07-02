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
  /// [timeLabel] — texto opcional de tempo decorrido/total como
  ///   "12:30 / 24:00" exibido ao lado da barra. Usado para filmes
  ///   e episódios individuais onde faz sentido mostrar o tempo
  ///   exato de progresso.
  ///
  /// Retorna `null` quando não há progresso (nenhum overlay exibido).
  static Widget? build({
    required double ratio,
    required bool isCompleted,
    Color accentColor = AppColors.moviesAccent,
    String? fractionText,
    String? timeLabel,
  }) {
    if (isCompleted) {
      return CompletedBadge.cardOverlay();
    }

    if (ratio > 0) {
      // Em andamento: barra de progresso + textos opcionais.
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

      // Tempo decorrido / total (ex: "12:30 / 24:00").
      if (timeLabel != null && timeLabel.isNotEmpty) {
        children.addAll([
          const SizedBox(height: 2),
          Text(
            timeLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ]);
      }

      // Fração de episódios (ex: "3/12").
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

  /// Formata [seconds] no formato "MM:SS" ou "H:MM:SS".
  ///
  /// Exemplos:
  /// - 0 segundos → "0:00"
  /// - 65 segundos → "1:05"
  /// - 3661 segundos → "1:01:01"
  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Constrói um label de tempo no formato "12:30 / 24:00" a partir
  /// de [positionSeconds] e [durationSeconds].
  ///
  /// Retorna `null` se [durationSeconds] for nulo ou zero.
  static String? buildTimeLabel({
    required int? positionSeconds,
    required int? durationSeconds,
  }) {
    final dur = durationSeconds;
    final pos = positionSeconds;
    if (dur == null || dur <= 0 || pos == null || pos <= 0) return null;
    return '${formatDuration(pos)} / ${formatDuration(dur)}';
  }
}
