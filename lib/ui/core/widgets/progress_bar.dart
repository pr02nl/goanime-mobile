import 'package:flutter/material.dart';

import '../themes/app_colors.dart';

/// Barra de progresso horizontal reutilizável entre módulos (animes e filmes).
///
/// Quando `isCompleted` é `true`, exibe um indicador verde "✓ Completo".
/// Caso contrário, exibe `LinearProgressIndicator` com `ratio` e,
/// opcionalmente, um `timeLabel` no formato "12:30 / 24:00".
class ProgressBar extends StatelessWidget {
  /// Fração de progresso (0.0 a 1.0).
  final double ratio;

  final bool isTV;

  /// Label de tempo no formato "12:30 / 24:00".
  final String? timeLabel;

  /// Se `true`, exibe indicador verde em vez da barra.
  final bool isCompleted;

  /// Cor da barra de progresso.
  final Color accentColor;

  const ProgressBar({
    super.key,
    required this.ratio,
    this.isTV = false,
    this.timeLabel,
    this.isCompleted = false,
    this.accentColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 12),
          const SizedBox(width: 4),
          Text(
            'Completo',
            style: TextStyle(
              color: Colors.green,
              fontSize: isTV ? 12 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ),
        if (timeLabel != null && timeLabel!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              timeLabel!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: isTV ? 11 : 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
