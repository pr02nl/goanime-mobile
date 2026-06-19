import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/anime.dart';
import '../themes/app_colors.dart';
import 'focusable_widget.dart';

class AnimeResultCard extends StatelessWidget {
  final Anime anime;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onEpisodesTap;

  const AnimeResultCard({
    super.key,
    required this.anime,
    required this.index,
    required this.onTap,
    this.onEpisodesTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final indexLabel = (index + 1).toString().padLeft(2, '0');
    final hasImage = anime.imageUrl.isNotEmpty;

    return FocusableWidget(
      onSelect: onTap,
      borderRadius: 24,
      focusPadding: EdgeInsets.zero,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
              colorScheme.surface,
            ],
          ),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Anime Cover Image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 80,
                  height: 110,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  ),
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: anime.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            return _buildPlaceholder(
                              colorScheme,
                              indexLabel,
                              theme,
                            );
                          },
                        )
                      : _buildPlaceholder(colorScheme, indexLabel, theme),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            anime.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: anime.source == AnimeSource.animeFire
                                ? AppColors.warning.withValues(alpha: 0.2)
                                : AppColors.secondary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: anime.source == AnimeSource.animeFire
                                  ? AppColors.warning.withValues(alpha: 0.5)
                                  : AppColors.secondary.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            anime.sourceName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: anime.source == AnimeSource.animeFire
                                  ? AppColors.warning
                                  : AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (anime.genres.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: anime.genres.take(2).map((genre) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              genre,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (anime.averageScore != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(anime.averageScore! / 10).toStringAsFixed(1)}/10',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.75,
                              ),
                            ),
                          ),
                          if (anime.episodeCount != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.movie_filter_rounded,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${anime.episodeCount} eps',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ] else
                      Text(
                        'Toque para ver epis?dios',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.72,
                          ),
                          letterSpacing: 0.1,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onEpisodesTap != null)
                // FocusableWidget: nó de foco independente do pai (que é o
                // FocusableWidget do card inteiro), permite ao d-pad pousar
                // especificamente no botão play de cada resultado.
                // Em mobile/tablet cai no fallback GestureDetector puro.
                FocusableWidget(
                  onSelect: () => onEpisodesTap?.call(),
                  borderRadius: 16,
                  focusPadding: EdgeInsets.zero,
                  focusScale: 1.05,
                  // InkWell removido: o FocusableWidget já injeta splash
                  // nativo via Material+InkWell (lib/widgets/focusable_widget.dart).
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: colorScheme.primary.withValues(alpha: 0.12),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(
    ColorScheme colorScheme,
    String indexLabel,
    ThemeData theme,
  ) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.8),
            colorScheme.secondaryContainer.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_rounded,
            size: 32,
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 4),
          Text(
            '#$indexLabel',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Anime Detail Screen - Estilo Crunchyroll
