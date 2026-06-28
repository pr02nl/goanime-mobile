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

import '../../../domain/models/paulo_flix_progress_stats.dart';
import '../../../domain/models/pauloflix_content.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/focusable_widget.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/netflix_carousel.dart';
import '../../core/widgets/progress_overlay.dart';

class PauloFlixContinueWatchingSection extends StatelessWidget {
  /// Lista de animes em andamento. Quando vazia, a section some.
  final List<PauloFlixContent> contents;

  /// Callback ao tocar num card. Recebe o `PauloFlixContent` clicado.
  final void Function(PauloFlixContent content)? onContentTap;

  /// `true` em TV (layout wide). Passado ao `NetflixCarousel` e
  /// `NetflixCard` para ajuste de tamanho.
  final bool isTV;

  /// Mapa `contentId → stats` para overlays de progresso nos cards.
  /// Quando vazio, nenhum overlay é exibido.
  final Map<int, PauloFlixProgressStats> statsById;

  const PauloFlixContinueWatchingSection({
    super.key,
    required this.contents,
    this.onContentTap,
    this.isTV = false,
    this.statsById = const {},
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

  /// Constrói um `NetflixCard` para 1 anime com overlay de progresso.
  Widget _buildCard(BuildContext context, PauloFlixContent content) {
    final overlay = content.id != null
        ? _buildProgressOverlay(statsById[content.id!])
        : null;

    return FocusableWidget(
      onSelect: () => onContentTap?.call(content),
      borderRadius: 6,
      focusPadding: EdgeInsets.zero,
      child: NetflixCard(
        imageUrl: content.imageUrl ?? '',
        title: content.displayName,
        showTitle: true,
        showRating: false,
        isTV: isTV,
        overlayWidget: overlay,
        onTap: () => onContentTap?.call(content),
      ),
    );
  }

  /// Constrói o overlay de progresso baseado nos stats.
  /// Badge ✓ verde se completo, barra de progresso se em andamento,
  /// ou `null` se sem dados.
  Widget? _buildProgressOverlay(PauloFlixProgressStats? stats) {
    if (stats == null) return null;

    final hasProgress = stats.isAnimeCompleted ||
        stats.isAnimeInProgress ||
        stats.completedEpisodes > 0;
    if (!hasProgress) return null;

    return ProgressOverlay.build(
      ratio: stats.progressRatio,
      isCompleted: stats.isAnimeCompleted,
      accentColor: AppColors.primary,
      fractionText: stats.totalEpisodes > 0
          ? '${stats.completedEpisodes}/${stats.totalEpisodes}'
          : null,
    );
  }
}

// CachedNetworkImage importado para uso futuro.
// ignore: unused_element
const _kKeepImports = CachedNetworkImage;
