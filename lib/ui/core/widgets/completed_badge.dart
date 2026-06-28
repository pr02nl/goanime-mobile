import 'package:flutter/material.dart';

/// Badge verde "✓ Completo" reutilizável entre cards, banners e telas
/// de detalhe.
///
/// Disponibiliza três variantes pré-definidas via construtores nomeados
/// ou customização total via parâmetros.
///
/// Uso:
/// ```dart
/// // Card overlay (padrão, tamanho pequeno)
/// CompletedBadge.cardOverlay()
///
/// // Hero banner (tamanho grande com borda)
/// CompletedBadge.heroBanner()
///
/// // Tela de detalhes (fundo transparente, texto verde)
/// CompletedBadge.detailScreen()
/// ```
class CompletedBadge extends StatelessWidget {
  final EdgeInsets padding;
  final Color backgroundColor;
  final BoxBorder? border;
  final double borderRadius;
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final double gap;
  final String label;
  final Color textColor;
  final double fontSize;
  final FontWeight fontWeight;

  const CompletedBadge({
    super.key,
    required this.padding,
    required this.backgroundColor,
    this.border,
    required this.borderRadius,
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.gap,
    required this.label,
    required this.textColor,
    required this.fontSize,
    required this.fontWeight,
  });

  // ─── Variantes pré-definidas ────────────────────────────────────────

  /// Tamanho pequeno, fundo sólido, sem borda.
  /// Usado como overlay em cards (ProgressOverlay).
  CompletedBadge.cardOverlay({super.key})
    : padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      backgroundColor = Colors.green.withValues(alpha: 0.9),
      border = null,
      borderRadius = 4,
      icon = Icons.check_circle,
      iconColor = Colors.white,
      iconSize = 10,
      gap = 2,
      label = 'Completo',
      textColor = Colors.white,
      fontSize = 9,
      fontWeight = FontWeight.w700;

  /// Tamanho grande, fundo sólido, borda sutil greenAccent.
  /// Usado no canto do hero banner.
  CompletedBadge.heroBanner({super.key})
    : padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      backgroundColor = Colors.green.withValues(alpha: 0.9),
      border = Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
      borderRadius = 6,
      icon = Icons.check_circle,
      iconColor = Colors.white,
      iconSize = 16,
      gap = 6,
      label = 'Completo',
      textColor = Colors.white,
      fontSize = 13,
      fontWeight = FontWeight.bold;

  /// Tamanho médio, fundo translúcido, texto e ícone verdes.
  /// Usado na linha de metadados da tela de detalhes.
  CompletedBadge.detailScreen({super.key})
    : padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      backgroundColor = Colors.green.withValues(alpha: 0.2),
      border = Border.all(color: Colors.green.withValues(alpha: 0.5)),
      borderRadius = 4,
      icon = Icons.check_circle,
      iconColor = Colors.green,
      iconSize = 14,
      gap = 4,
      label = 'Completo',
      textColor = Colors.green,
      fontSize = 12,
      fontWeight = FontWeight.bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: iconSize),
          SizedBox(width: gap),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          ),
        ],
      ),
    );
  }
}
