/// Controles de overlay no modo fullscreen do player.
///
/// Extraído de `video_player_screen.dart` para reduzir o tamanho do
/// arquivo orquestrador. Responsabilidades:
/// - Botão voltar + título do episódio
/// - Botões de navegação entre episódios (próximo/anterior)
/// - Botão de pular intro/outro (AniSkip)
library;

import 'package:flutter/material.dart';

import '../../core/widgets/focusable_widget.dart';
import '../../core/widgets/skip_button.dart';

/// Controles de overlay exibidos sobre o player no modo fullscreen.
///
/// [Uso]:
/// ```dart
/// VideoPlayerOverlayControls(
///   isTV: _isTVDevice == true,
///   showOverlayControls: _showOverlayControls,
///   displayLabel: _displayLabel,
///   showSkipButton: showSkipButton,
///   skipButtonLabel: skipButtonLabel,
///   hasPreviousEpisode: _hasPreviousEpisode,
///   hasNextEpisode: _hasNextEpisode,
///   onBack: _exitFullscreen,
///   onPreviousEpisode: _goToPreviousEpisode,
///   onNextEpisode: _goToNextEpisode,
///   onSkipIntroOutro: skipIntroOutro,
/// )
/// ```
class VideoPlayerOverlayControls extends StatelessWidget {
  final bool isTV;
  final bool showOverlayControls;
  final String displayLabel;
  final bool showSkipButton;
  final String skipButtonLabel;
  final bool hasPreviousEpisode;
  final bool hasNextEpisode;
  final VoidCallback onBack;
  final VoidCallback onPreviousEpisode;
  final VoidCallback onNextEpisode;
  final VoidCallback onSkipIntroOutro;

  const VideoPlayerOverlayControls({
    super.key,
    required this.isTV,
    required this.showOverlayControls,
    required this.displayLabel,
    required this.showSkipButton,
    required this.skipButtonLabel,
    required this.hasPreviousEpisode,
    required this.hasNextEpisode,
    required this.onBack,
    required this.onPreviousEpisode,
    required this.onNextEpisode,
    required this.onSkipIntroOutro,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: isTV ? 16 : 8,
      left: isTV ? 16 : 8,
      right: isTV ? 80 : 60,
      child: AnimatedOpacity(
        opacity: showOverlayControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Row(
              children: [
                FocusableWidget(
                  onSelect: onBack,
                  borderRadius: 24,
                  focusPadding: EdgeInsets.zero,
                  focusScale: 1.05,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    '  $displayLabel',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botões de navegação entre episódios no overlay de fullscreen.
class EpisodeNavigationOverlay extends StatelessWidget {
  final bool isTV;
  final bool showOverlayControls;
  final bool hasPreviousEpisode;
  final bool hasNextEpisode;
  final VoidCallback onPreviousEpisode;
  final VoidCallback onNextEpisode;

  const EpisodeNavigationOverlay({
    super.key,
    required this.isTV,
    required this.showOverlayControls,
    required this.hasPreviousEpisode,
    required this.hasNextEpisode,
    required this.onPreviousEpisode,
    required this.onNextEpisode,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: isTV ? 40 : 80,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: showOverlayControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasPreviousEpisode)
                FocusableWidget(
                  onSelect: onPreviousEpisode,
                  borderRadius: 24,
                  focusPadding: EdgeInsets.zero,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.skip_previous_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              if (hasNextEpisode)
                FocusableWidget(
                  onSelect: onNextEpisode,
                  borderRadius: 24,
                  focusPadding: EdgeInsets.zero,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper do botão de pular intro/outro no overlay de fullscreen.
class SkipButtonOverlay extends StatelessWidget {
  final bool showSkipButton;
  final String skipButtonLabel;
  final bool isTV;
  final VoidCallback onSkip;

  const SkipButtonOverlay({
    super.key,
    required this.showSkipButton,
    required this.skipButtonLabel,
    required this.isTV,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: isTV ? 40 : 80,
      right: isTV ? 40 : 24,
      child: SafeArea(
        child: IgnorePointer(
          ignoring: !showSkipButton,
          child: SkipButton(
            onSkip: onSkip,
            label: skipButtonLabel,
            show: showSkipButton,
          ),
        ),
      ),
    );
  }
}
