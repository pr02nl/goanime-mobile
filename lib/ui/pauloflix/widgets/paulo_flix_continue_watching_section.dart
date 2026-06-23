/// Seção "Continue assistindo" — carrossel horizontal de animes PauloFlix
/// com progresso parcial (Fase 5.2 do plano
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`).
///
/// **Quando renderiza:**
/// - `contents.isEmpty` → `SizedBox.shrink()` (seção some).
/// - `contents.isNotEmpty` → `NetflixCarousel` com 1 `NetflixCard` por
///   anime. Tap no card chama `onContentTap(content)`.
///
/// **Por que `StatelessWidget`:** a reatividade fica no
/// `PauloFlixContinueWatchingViewModel` (Fase 5.1) que escuta o
/// `watchInProgressContents` do repo. Este widget só renderiza o
/// snapshot atual.
///
/// **Uso:**
/// ```dart
/// ChangeNotifierProvider(
///   create: (ctx) => PauloFlixContinueWatchingViewModel(
///     repository: ctx.read<PauloFlixEpisodeProgressRepository>(),
///   ),
///   child: Consumer<PauloFlixContinueWatchingViewModel>(
///     builder: (_, vm, _) => PauloFlixContinueWatchingSection(
///       contents: vm.contents,
///       onContentTap: (c) => ...,
///     ),
///   ),
/// )
/// ```
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/pauloflix_content.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/focusable_widget.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/netflix_carousel.dart';

class PauloFlixContinueWatchingSection extends StatelessWidget {
  /// Lista de animes em andamento. Quando vazia, a section some.
  final List<PauloFlixContent> contents;

  /// Callback ao tocar num card. Recebe o `PauloFlixContent` clicado.
  final void Function(PauloFlixContent content)? onContentTap;

  /// `true` em TV (layout wide). Passado ao `NetflixCarousel` e
  /// `NetflixCard` para ajuste de tamanho.
  final bool isTV;

  const PauloFlixContinueWatchingSection({
    super.key,
    required this.contents,
    this.onContentTap,
    this.isTV = false,
  });

  @override
  Widget build(BuildContext context) {
    // Lista vazia → section some (sem espaço no layout).
    if (contents.isEmpty) {
      return const SizedBox.shrink();
    }

    return NetflixCarousel(
      title: 'Continue assistindo',
      isTV: isTV,
      items: contents
          .map(
            (c) => _buildCard(context, c),
          )
          .toList(),
    );
  }

  /// Constrói um `NetflixCard` para 1 anime. Usa `FocusableWidget`
  /// (skill `flutter-reactivity-gotchas` #14) para suportar D-pad na TV.
  Widget _buildCard(BuildContext context, PauloFlixContent content) {
    return FocusableWidget(
      onSelect: () => onContentTap?.call(content),
      borderRadius: 6,
      focusPadding: EdgeInsets.zero,
      child: NetflixCard(
        imageUrl: content.imageUrl ?? '',
        title: content.displayName,
        // `overlayWidget` é onde o NetflixCard aceita widgets extras
        // sobre a imagem — usaremos no futuro para mostrar
        // "Xmin restantes" ou barra de progresso do anime.
        // Por enquanto fica sem (a barra de progresso está no card
        // de episode, não no card de anime).
        showTitle: true,
        showRating: false, // PauloFlix não tem rating por anime
        isTV: isTV,
        onTap: () => onContentTap?.call(content),
        // `width`/`height` default do NetflixCard (120x180 mobile,
        // 160x240 TV). Não precisa customizar aqui.
      ),
    );
  }
}

/// Placeholder para futuras extensões (barra de progresso do anime
/// no card). Mantido aqui para documentar a intenção.
@visibleForTesting
class ContinueWatchingCardOverlay extends StatelessWidget {
  final double progress;
  const ContinueWatchingCardOverlay({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 3,
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }
}

// CachedNetworkImage importado para uso futuro (quando quisermos mostrar
// a imagem com fade-in). Mantido para evitar warning de unused.
// ignore: unused_element
const _kKeepImports = CachedNetworkImage;
