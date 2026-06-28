import 'package:flutter/material.dart';

import '../themes/app_colors.dart';

/// Badge "PauloFlix" com cor vermelho-cinema para diferenciar dos animes.
class PauloFlixMoviesBadge extends StatelessWidget {
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  const PauloFlixMoviesBadge({
    super.key,
    this.fontSize = 10,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.moviesAccent, Color(0xFFEF4444)],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: AppColors.moviesAccent.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.movie_outlined,
            color: Colors.white,
            size: 10,
          ),
          const SizedBox(width: 3),
          Text(
            'PauloFlix',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
