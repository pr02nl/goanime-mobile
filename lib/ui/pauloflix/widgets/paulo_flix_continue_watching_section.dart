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

    if (stats.isAnimeCompleted) {
      // Badge ✓ verde.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 10),
            SizedBox(width: 2),
            Text(
              'Completo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (stats.isAnimeInProgress || stats.completedEpisodes > 0) {
      // Barra de progresso com texto "3/12".
      final ratio = stats.progressRatio;
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
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      ];
      if (stats.totalEpisodes > 0) {
        children.addAll([
          const SizedBox(height: 2),
          Text(
            '${stats.completedEpisodes}/${stats.totalEpisodes}',
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

// CachedNetworkImage importado para uso futuro.
// ignore: unused_element
const _kKeepImports = CachedNetworkImage;
