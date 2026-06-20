/// Botões de navegação entre episódios no estilo MaterialDesktop.
///
/// Projetados para serem usados no `bottomButtonBar` do
/// `MaterialDesktopVideoControlsThemeData`, integrando-se nativamente
/// aos controles do player.
library;

import 'package:flutter/material.dart';

/// Botão de "próximo episódio" no estilo MaterialDesktop.
///
/// [Uso]:
/// ```dart
/// MaterialDesktopVideoControlsThemeData(
///   bottomButtonBar: [
///     EpisodeSkipPreviousButton(onPressed: () => goToPrevious()),
///     MaterialDesktopPlayOrPauseButton(),
///     EpisodeSkipNextButton(onPressed: () => goToNext()),
///     // ... outros botões
///   ],
/// )
/// ```
class EpisodeSkipNextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final double iconSize;
  final Color iconColor;

  const EpisodeSkipNextButton({
    super.key,
    this.onPressed,
    this.icon,
    this.iconSize = 28.0,
    this.iconColor = const Color(0xFFFFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: icon ?? const Icon(Icons.skip_next_rounded),
      iconSize: iconSize,
      color: iconColor,
      tooltip: 'Next episode',
    );
  }
}

/// Botão de "episódio anterior" no estilo MaterialDesktop.
class EpisodeSkipPreviousButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final double iconSize;
  final Color iconColor;

  const EpisodeSkipPreviousButton({
    super.key,
    this.onPressed,
    this.icon,
    this.iconSize = 28.0,
    this.iconColor = const Color(0xFFFFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: icon ?? const Icon(Icons.skip_previous_rounded),
      iconSize: iconSize,
      color: iconColor,
      tooltip: 'Previous episode',
    );
  }
}
