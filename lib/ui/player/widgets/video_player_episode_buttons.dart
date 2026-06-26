/// Botões de navegação entre episódios no estilo MaterialDesktop.
///
/// Projetados para serem usados no `bottomButtonBar` do
/// `MaterialDesktopVideoControlsThemeData`, integrando-se nativamente
/// aos controles do player.
///
/// Em Android TV esses botões são navegados via D-pad, então cada um é
/// envolvido em um [FocusableWidget] para que o foco D-pad os alcance.
/// Sem isso, o traversal de foco passa por cima deles e o usuário não
/// consegue acionar o episódio seguinte/anterior pelo controle remoto.
library;

import 'package:flutter/material.dart';

import '../../core/widgets/focusable_widget.dart';

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
  final FocusNode? focusNode;

  const EpisodeSkipNextButton({
    super.key,
    this.onPressed,
    this.icon,
    this.iconSize = 28.0,
    this.iconColor = const Color(0xFFFFFFFF),
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    // FocusableWidget envolve o IconButton para que o foco D-pad alcance
    // o botão em Android TV. Em mobile/desktop o FocusableWidget é um
    // no-op visível (não atrapalha o touch/mouse).
    return FocusableWidget(
      onSelect: onPressed,
      focusNode: focusNode,
      borderRadius: 24,
      focusPadding: const EdgeInsets.all(8),
      focusScale: 1.1,
      child: IconButton(
        onPressed: onPressed,
        icon: icon ?? const Icon(Icons.skip_next_rounded),
        iconSize: iconSize,
        color: iconColor,
        tooltip: 'Next episode',
      ),
    );
  }
}

/// Botão de "episódio anterior" no estilo MaterialDesktop.
class EpisodeSkipPreviousButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final double iconSize;
  final Color iconColor;
  final FocusNode? focusNode;

  const EpisodeSkipPreviousButton({
    super.key,
    this.onPressed,
    this.icon,
    this.iconSize = 28.0,
    this.iconColor = const Color(0xFFFFFFFF),
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onPressed,
      focusNode: focusNode,
      borderRadius: 24,
      focusPadding: const EdgeInsets.all(8),
      focusScale: 1.1,
      child: IconButton(
        onPressed: onPressed,
        icon: icon ?? const Icon(Icons.skip_previous_rounded),
        iconSize: iconSize,
        color: iconColor,
        tooltip: 'Previous episode',
      ),
    );
  }
}
