import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/anime.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/focusable_widget.dart';

class AnimeDetailScreen extends StatelessWidget {
  final Anime anime;

  const AnimeDetailScreen({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasBanner = anime.bannerUrl.isNotEmpty;
    final hasDescription = anime.description.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar com Banner
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Banner ou Gradiente
                  if (hasBanner)
                    CachedNetworkImage(
                      imageUrl: anime.bannerUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colorScheme.primary, colorScheme.secondary],
                        ),
                      ),
                    ),
                  // Overlay Gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Conteúdo Principal
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header com Capa e Info Principal
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Capa
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: anime.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: anime.imageUrl,
                                width: 100,
                                height: 145,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 100,
                                  height: 145,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 100,
                                  height: 145,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.movie_rounded,
                                    size: 40,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : Container(
                                width: 100,
                                height: 145,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primaryContainer,
                                      colorScheme.secondaryContainer,
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.movie_rounded,
                                  size: 40,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),

                      // Info Principal
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anime.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),

                            // Rating
                            if (anime.averageScore != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade600,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      (anime.averageScore! / 10)
                                          .toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),

                            // Informações secundárias
                            _buildInfoRow(
                              context,
                              Icons.movie_filter_rounded,
                              anime.episodeCount != null
                                  ? '${anime.episodeCount} eps'
                                  : 'Episódios variados',
                            ),
                            if (anime.status != null) ...[
                              const SizedBox(height: 5),
                              _buildInfoRow(
                                context,
                                Icons.radio_button_checked,
                                _translateStatus(anime.status!, l10n),
                              ),
                            ],
                            if (anime.aniListData?.format != null) ...[
                              const SizedBox(height: 5),
                              _buildInfoRow(
                                context,
                                Icons.category_rounded,
                                anime.aniListData!.format!.displayName,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Botão "Assistir Episódios"
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FocusableWidget(
                      onSelect: () {
                        HapticFeedback.lightImpact();
                        context.pushNamed(
                          'episode-list',
                          extra: anime,
                        );
                      },
                      borderRadius: 12,
                      focusPadding: EdgeInsets.zero,
                      child: FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.pushNamed(
                            'episode-list',
                            extra: anime,
                          );
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: Text(
                          l10n.watchEpisodes,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Gêneros
                if (anime.genres.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.genres,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: anime.genres.map((genre) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.secondary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                genre,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Descrição/Sinopse
                if (hasDescription) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.synopsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _cleanDescription(anime.description),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                              fontSize: 14,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Informações Adicionais
                if (anime.aniListData != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.information,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              if (anime.aniListData!.season != null &&
                                  anime.aniListData!.seasonYear != null)
                                _buildInfoTile(
                                  context,
                                  l10n.seasonLabel,
                                  '${_translateSeason(anime.aniListData!.season!, l10n)} ${anime.aniListData!.seasonYear}',
                                ),
                              if (anime.anilistId != null)
                                _buildInfoTile(
                                  context,
                                  l10n.anilistId,
                                  anime.anilistId.toString(),
                                ),
                              if (anime.malId != null)
                                _buildInfoTile(
                                  context,
                                  l10n.malId,
                                  anime.malId.toString(),
                                ),
                              if (anime.aniListData!.popularity != null)
                                _buildInfoTile(
                                  context,
                                  l10n.popularity,
                                  '#${anime.aniListData!.popularity}',
                                  isLast: true,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    String label,
    String value, {
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 10),
          Divider(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            height: 1,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  String _cleanDescription(String description) => stripHtml(description);

  String _translateStatus(String status, AppLocalizations l10n) {
    switch (status.toUpperCase()) {
      case 'FINISHED':
        return l10n.finished;
      case 'RELEASING':
      case 'CURRENTLY_AIRING':
        return l10n.currentlyAiring;
      case 'NOT_YET_RELEASED':
        return l10n.notYetAired;
      case 'CANCELLED':
        return l10n.cancelled;
      case 'HIATUS':
        return l10n.hiatus;
      default:
        return status;
    }
  }

  String _translateSeason(String season, AppLocalizations l10n) {
    switch (season.toUpperCase()) {
      case 'WINTER':
        return l10n.winter;
      case 'SPRING':
        return l10n.spring;
      case 'SUMMER':
        return l10n.summer;
      case 'FALL':
        return l10n.fall;
      default:
        return season;
    }
  }
}
